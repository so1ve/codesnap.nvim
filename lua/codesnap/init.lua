local static = require("codesnap.static")
local table_utils = require("codesnap.utils.table")
local config_module = require("codesnap.config")
local modal = require("codesnap.modal")
local path = require("codesnap.path")
local async = assert(vim.async, "CodeSnap requires Neovim nightly with vim.async")
local is_linux = vim.uv.os_uname().sysname == "Linux"

local main = { cwd = static.cwd }
local active_task

function main.setup(config)
  static.config = table_utils.merge_config(static.config, config or {})
  if static.config.snapshot_config then
    path.expand_paths_in_config(static.config.snapshot_config)
  end
end

-- Native rendering needs a worker because coroutines cannot interrupt it
local function render(request)
  return async.await(function(done)
    local exited = false
    local close_callback
    local process = vim.system({
      vim.v.progpath,
      "--headless",
      "-u",
      "NONE",
      "-i",
      "NONE",
      "-n",
      "-l",
      vim.fs.joinpath(static.cwd, "lua", "codesnap", "worker.lua"),
    }, { stdin = vim.json.encode(request), text = true, detach = is_linux, cwd = request.cwd }, function(result)
      exited = true
      vim.schedule(function()
        if close_callback then
          close_callback()
        else
          done(result)
        end
      end)
    end)

    return {
      close = function(_, callback)
        if exited then
          callback()
        else
          close_callback = callback
          -- Use SIGKILL: native code blocks Neovim's SIGTERM handler
          if not process:is_closing() and is_linux then
            -- The worker's process group includes any unfinished clipboard handoff
            local killed, err, code = vim.uv.kill(-process.pid, "sigkill")
            if not killed and code ~= "ESRCH" then
              error(err, 0)
            end
          elseif not process:is_closing() then
            process:kill("sigkill")
          end
        end
      end,
    }
  end)
end

local function start(operation, save_path, highlight)
  if active_task and not active_task:completed() then
    error("A snapshot is already running; use :CodeSnapCancel to cancel it", 0)
  end

  -- Capture before yielding so later edits cannot change this request
  local config = config_module.get_config()
  local filetype = vim.bo.filetype
  local highlight_color = static.config.highlight_color
  local request = { operation = operation, config = config, save_path = save_path, cwd = vim.uv.cwd() }

  if is_linux and operation ~= "save" then
    -- arboard's thread dies with the worker; these tools fork clipboard owners
    if vim.env.WAYLAND_DISPLAY and vim.env.WAYLAND_DISPLAY ~= "" then
      request.clipboard = {
        "wl-copy",
        "--type",
        operation == "copy_ascii" and "text/plain;charset=utf-8" or "image/png",
      }
    elseif vim.env.DISPLAY and vim.env.DISPLAY ~= "" then
      request.clipboard = {
        "xclip",
        "-selection",
        "clipboard",
        "-t",
        operation == "copy_ascii" and "UTF8_STRING" or "image/png",
        "-i",
      }
    else
      error("Clipboard copy requires a Wayland or X11 session", 0)
    end
    if vim.fn.executable(request.clipboard[1]) ~= 1 then
      error("Clipboard copy requires " .. request.clipboard[1] .. " on PATH", 0)
    end
  end

  -- Clear these marks before the modal or user changes the current buffer
  vim.cmd("delmarks <>")

  local task = async.run("CodeSnap", function()
    if highlight then
      local selection = async.await(3, modal.pop_modal, config.content.content, filetype)
      if not selection then
        return false
      end
      config.content.highlight_lines = { { selection[1], selection[2], highlight_color } }
    end

    if save_path then
      -- A same-directory rename preserves the destination until rendering succeeds
      local fd, temp = vim.uv.fs_mkstemp(vim.fs.joinpath(vim.fs.dirname(save_path), ".codesnap-XXXXXX"))
      assert(fd, temp)
      request.temporary_path = temp
      assert(vim.uv.fs_close(fd))
    elseif request.clipboard then
      request.temporary_path = vim.fn.tempname()
    end

    local result = render(request)
    if result.code ~= 0 then
      local message = ("Snapshot worker exited with code %d (signal %d)\n%s\n%s"):format(
        result.code,
        result.signal,
        result.stderr,
        result.stdout
      )
      error(vim.trim(message), 0)
    end
    return true
  end)

  active_task = task
  task:on_complete(function(err, completed)
    if request.temporary_path then
      vim.uv.fs_unlink(request.temporary_path)
    end
    -- Another completion callback may already have started the next snapshot
    if active_task == task then
      active_task = nil
    end
    if err == "closed" or (not err and not completed) then
      vim.notify("Snapshot cancelled")
    elseif err then
      vim.notify(tostring(err), vim.log.levels.ERROR)
    elseif save_path then
      vim.notify("Saved snapshot to " .. save_path)
    elseif operation == "copy_ascii" then
      vim.notify("Copied ASCII snapshot to clipboard")
    else
      vim.notify("Copied snapshot to clipboard")
    end
  end)

  return task
end

function main.save(save_path)
  if not save_path or save_path == "" then
    error("Save path is not specified", 0)
  end
  save_path = vim.fn.fnamemodify(vim.fn.expand(save_path), ":p")
  if vim.fn.isdirectory(save_path) == 1 then
    save_path = vim.fs.joinpath(save_path, os.date("CodeSnap_%Y-%m-%d_at_%H:%M:%S.png"))
  end
  local extension = vim.fs.ext(save_path)
  if extension and extension ~= "png" then
    error("The extension of save_path should be .png", 0)
  end
  return start("save", save_path)
end

function main.copy()
  return start("copy")
end

function main.copy_ascii()
  return start("copy_ascii")
end

function main.copy_highlight()
  return start("copy", nil, true)
end

function main.cancel()
  if active_task then
    active_task:close()
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if active_task then
      local task = active_task
      task:close()
      -- Let cancellation reap the worker and remove its temporary file
      task:pwait(1000)
    end
  end,
})

return main

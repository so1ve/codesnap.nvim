-- Run with a nightly that provides vim.async:
-- nvim --headless -u NONE -i NONE -l tests/async.lua
assert(vim.async, "This test requires Neovim nightly with vim.async")
assert(vim.uv.os_uname().sysname == "Linux", "The clipboard fixtures require Linux")

local source_root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ":p")))
local temp = vim.fn.tempname()
local plugin_root = vim.fs.joinpath(temp, "codesnap.nvim")
local messages = {}
vim.notify = function(message, level)
  assert(not vim.in_fast_event(), "UI notification ran in a fast callback")
  messages[#messages + 1] = { message = message, level = level }
end

local function copy_tree(source, target)
  vim.fn.mkdir(target, "p")
  for name, kind in vim.fs.dir(source) do
    local src = vim.fs.joinpath(source, name)
    local dst = vim.fs.joinpath(target, name)
    if kind == "directory" then
      copy_tree(src, dst)
    else
      assert(vim.uv.fs_copyfile(src, dst))
    end
  end
end

copy_tree(vim.fs.joinpath(source_root, "lua"), vim.fs.joinpath(plugin_root, "lua"))
copy_tree(vim.fs.joinpath(source_root, "plugin"), vim.fs.joinpath(plugin_root, "plugin"))
assert(
  vim.uv.fs_copyfile(
    vim.fs.joinpath(source_root, "tests", "fixtures", "module.lua"),
    vim.fs.joinpath(plugin_root, "lua", "codesnap", "module.lua")
  )
)
vim.opt.runtimepath:prepend(plugin_root)
vim.env.CODESNAP_TEST_OUTPUT = vim.fs.joinpath(temp, "clipboard.json")
vim.env.CODESNAP_TEST_STARTED = vim.fs.joinpath(temp, "started")
vim.env.CODESNAP_TEST_HELPER = vim.fs.joinpath(temp, "helper")
vim.env.CODESNAP_TEST_OWNER = vim.fs.joinpath(temp, "owner")
vim.env.CODESNAP_TEST_MODE = "normal"
local bin = vim.fs.joinpath(temp, "bin")
vim.fn.mkdir(bin, "p")
local clipboard_script = vim.fn.readfile(vim.fs.joinpath(source_root, "tests", "fixtures", "clipboard.py"))
local python = vim.fn.exepath("python3")
assert(python ~= "", "The clipboard fixture requires Python 3")
table.insert(clipboard_script, 1, "#!" .. python)
for _, executable in ipairs({ "wl-copy", "xclip" }) do
  local target = vim.fs.joinpath(bin, executable)
  vim.fn.writefile(clipboard_script, target)
  assert(vim.uv.fs_chmod(target, 493))
end
local test_path = bin .. ":" .. vim.env.PATH
vim.env.PATH = test_path
vim.env.WAYLAND_DISPLAY = "codesnap-test"
vim.env.DISPLAY = "codesnap-test"

local codesnap = require("codesnap")
dofile(vim.fs.joinpath(plugin_root, "plugin", "codesnap.lua"))
local source = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(source, vim.fs.joinpath(temp, "original.lua"))
local original = { "local x = 1", "local y = 2", "print(x + y)" }

local function select_source()
  vim.api.nvim_set_current_buf(source)
  vim.api.nvim_buf_set_lines(source, 0, -1, false, original)
  vim.api.nvim_buf_set_mark(source, "<", 1, 0, {})
  vim.api.nvim_buf_set_mark(source, ">", #original, 0, {})
  codesnap.setup({
    show_workspace = false,
    show_line_number = true,
    snapshot_config = { theme = "candy", code_config = { font_family = "Original Font" } },
  })
end

local function read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

local function no_temporary_files()
  for name in vim.fs.dir(temp) do
    assert(not name:match("^%.codesnap%-"), "leaked temporary image: " .. name)
  end
end

local function wait_started()
  assert(
    vim.wait(5000, function()
      return vim.uv.fs_stat(vim.env.CODESNAP_TEST_STARTED) ~= nil
    end, 10),
    "worker did not start"
  )
end

local function reset_worker(mode)
  vim.uv.fs_unlink(vim.env.CODESNAP_TEST_STARTED)
  vim.uv.fs_unlink(vim.env.CODESNAP_TEST_OUTPUT)
  vim.uv.fs_unlink(vim.env.CODESNAP_TEST_HELPER)
  vim.env.CODESNAP_TEST_MODE = mode or "normal"
end

local ok, err = xpcall(function()
  select_source()
  assert(package.loaded["codesnap.module"] == nil, "native library loaded in UI process")
  local output = vim.fs.joinpath(temp, "snapshot.png")
  local ticks = 0
  local timer = vim.uv.new_timer()
  timer:start(10, 10, function()
    ticks = ticks + 1
  end)
  local task = codesnap.save(output)
  assert(not task:completed(), "save blocked until completion")
  local other = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(other)
  vim.api.nvim_buf_set_lines(other, 0, -1, false, { "new buffer" })
  vim.api.nvim_buf_set_mark(other, "<", 1, 0, {})
  codesnap.setup({ snapshot_config = { theme = "changed", code_config = { font_family = "Changed Font" } } })
  assert(task:wait(5000))
  timer:stop()
  timer:close()
  assert(ticks > 3, "parent event loop did not run during rendering")
  local config = vim.json.decode(read(output))
  assert(config.content.content == table.concat(original, "\n"), "selection changed after submission")
  assert(config.code_config.font_family == "Original Font", "configuration was not captured")
  assert(config.theme == "resolved:candy", "theme was not resolved in worker")
  assert(vim.api.nvim_get_current_buf() == other, "completion changed current buffer")
  assert(vim.api.nvim_buf_get_mark(other, "<")[1] == 1, "completion cleared a later selection")
  assert(tonumber(read(vim.env.CODESNAP_TEST_STARTED)) ~= vim.fn.getpid(), "render ran in parent")
  no_temporary_files()

  -- Exercise the Ex command and the ASCII Lua API without changing the real clipboard
  reset_worker()
  select_source()
  vim.cmd("CodeSnap")
  assert(vim.wait(5000, function()
    return messages[#messages].message == "Copied snapshot to clipboard"
  end, 10))
  local copied = vim.json.decode(read(vim.env.CODESNAP_TEST_OUTPUT))
  assert(copied.operation == "copy")
  assert(copied.config.content.content == table.concat(original, "\n"))
  assert(vim.uv.fs_stat(copied.input_path) == nil, "copied PNG temporary file leaked")
  assert(vim.deep_equal(copied.arguments, { "--type", "image/png" }))
  reset_worker()
  select_source()
  codesnap.setup({ show_line_number = false })
  assert(codesnap.copy_ascii():wait(5000))
  local ascii = vim.json.decode(read(vim.env.CODESNAP_TEST_OUTPUT))
  assert(ascii.operation == "copy_ascii")
  assert(ascii.config.content.start_line_number == nil, "line number leaked from earlier request")
  assert(vim.deep_equal(ascii.arguments, { "--type", "text/plain;charset=utf-8" }))

  reset_worker()
  select_source()
  codesnap.setup({ snapshot_config = { title = "binary-fixture" } })
  assert(codesnap.copy():wait(5000))
  copied = vim.json.decode(read(vim.env.CODESNAP_TEST_OUTPUT))
  assert(copied.data_hex == "89504e470d0a1a0a00ff7061796c6f61640a", "PNG bytes changed in transport")
  codesnap.setup({ snapshot_config = { title = "none" } })

  reset_worker()
  select_source()
  vim.env.WAYLAND_DISPLAY = nil
  assert(codesnap.copy():wait(5000))
  copied = vim.json.decode(read(vim.env.CODESNAP_TEST_OUTPUT))
  assert(vim.deep_equal(copied.arguments, { "-selection", "clipboard", "-t", "image/png", "-i" }))
  select_source()
  assert(codesnap.copy_ascii():wait(5000))
  ascii = vim.json.decode(read(vim.env.CODESNAP_TEST_OUTPUT))
  assert(vim.deep_equal(ascii.arguments, { "-selection", "clipboard", "-t", "UTF8_STRING", "-i" }))
  vim.env.WAYLAND_DISPLAY = "codesnap-test"

  select_source()
  vim.env.PATH = ""
  local available, missing = pcall(codesnap.copy)
  vim.env.PATH = test_path
  assert(not available and tostring(missing):find("requires wl-copy on PATH", 1, true))

  reset_worker("owner")
  select_source()
  assert(codesnap.copy():wait(5000), "clipboard owner kept the worker's output pipe open")
  local owner = tonumber(read(vim.env.CODESNAP_TEST_OWNER))
  assert(vim.uv.kill(owner, 0), "clipboard owner died with the worker")
  assert(vim.uv.kill(owner, "sigkill"))

  reset_worker("provider-fail")
  select_source()
  local copied_ok, copy_error = codesnap.copy():pwait(5000)
  assert(not copied_ok and tostring(copy_error):find("wl-copy exited with code 4", 1, true))
  local helper = vim.json.decode(read(vim.env.CODESNAP_TEST_HELPER))
  assert(vim.uv.fs_stat(helper.input_path) == nil, "failed clipboard handoff leaked its input")

  reset_worker("provider-slow")
  select_source()
  local copying = codesnap.copy()
  assert(
    vim.wait(5000, function()
      return vim.uv.fs_stat(vim.env.CODESNAP_TEST_HELPER) ~= nil
    end, 10),
    "clipboard helper did not start"
  )
  helper = vim.json.decode(read(vim.env.CODESNAP_TEST_HELPER))
  codesnap.cancel()
  local cancelled, cancel_error = copying:pwait(5000)
  assert(not cancelled and cancel_error == "closed")
  assert(
    vim.wait(1000, function()
      return vim.uv.kill(helper.pid, 0) == nil
    end, 10),
    "cancelled clipboard helper is still alive"
  )
  assert(vim.uv.fs_stat(helper.input_path) == nil, "cancelled clipboard handoff leaked its input")

  -- A worker error must report failure and leave an existing destination untouched
  reset_worker("fail")
  select_source()
  vim.fn.writefile({ "existing image" }, output)
  local success, failure = codesnap.save(output):pwait(5000)
  assert(not success and tostring(failure):find("fixture render failed", 1, true))
  assert(read(output) == "existing image", "failed save overwrote the destination")
  no_temporary_files()

  reset_worker("crash")
  select_source()
  success, failure = codesnap.save(output):pwait(5000)
  assert(not success and tostring(failure):find("exited with code 7", 1, true))
  assert(read(output) == "existing image", "crashed worker overwrote the destination")
  no_temporary_files()

  reset_worker("slow")
  select_source()
  task = codesnap.save(output)
  wait_started()
  local pid = tonumber(read(vim.env.CODESNAP_TEST_STARTED))
  assert(not pcall(codesnap.copy), "started a second concurrent renderer")
  vim.cmd("CodeSnapCancel")
  success, failure = task:pwait(5000)
  assert(not success and failure == "closed", tostring(failure))
  assert(vim.uv.kill(pid, 0) == nil, "cancelled renderer is still alive")
  assert(read(output) == "existing image", "cancelled save overwrote the destination")
  no_temporary_files()

  reset_worker("slow")
  select_source()
  task = codesnap.save(output)
  wait_started()
  pid = tonumber(read(vim.env.CODESNAP_TEST_STARTED))
  vim.api.nvim_exec_autocmds("VimLeavePre", {})
  assert(task:completed(), "editor-exit cleanup did not wait for the worker")
  assert(vim.uv.kill(pid, 0) == nil, "editor-exit cleanup left a renderer alive")
  no_temporary_files()

  -- The real modal must close when its task is cancelled, and must retain the
  -- originally captured code after confirmation
  reset_worker()
  select_source()
  local windows = #vim.api.nvim_list_wins()
  task = codesnap.copy_highlight()
  local modal_buf = vim.api.nvim_get_current_buf()
  assert(#vim.api.nvim_list_wins() == windows + 1)
  task:close()
  success, failure = task:pwait(5000)
  assert(not success and failure == "closed")
  assert(#vim.api.nvim_list_wins() == windows)
  assert(not vim.api.nvim_buf_is_valid(modal_buf), "cancelled modal buffer leaked")
  select_source()
  task = codesnap.copy_highlight()
  vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
  assert(task:wait(5000) == false, "manually closing the modal did not complete the task")
  select_source()
  task = codesnap.copy_highlight()
  vim.fn.maparg("<CR>", "n", false, true).callback()
  assert(task:wait(5000))
  copied = vim.json.decode(read(vim.env.CODESNAP_TEST_OUTPUT))
  assert(copied.config.content.content == table.concat(original, "\n"))
  assert(copied.config.content.highlight_lines[1][1] == 1)
  assert(copied.config.content.highlight_lines[1][2] == #original)
  no_temporary_files()
end, debug.traceback)

codesnap.cancel()
vim.fn.delete(temp, "rf")
assert(ok, err)
print("CodeSnap async integration tests passed")

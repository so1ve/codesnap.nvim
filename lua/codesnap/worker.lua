local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(arg[0])))
vim.opt.runtimepath:prepend(root)

local request = vim.json.decode(io.read("*a"))
local generator = require("codesnap.module").load_generator()
request.config.theme = generator.parse_code_theme(request.config.theme)

local function copy_file(command, file_path)
  local input = assert(vim.uv.fs_open(file_path, "r", 0))
  local devnull = assert(vim.uv.fs_open("/dev/null", "w", 0))
  local result
  local process
  local spawn_error
  process, spawn_error = vim.uv.spawn(command[1], {
    args = { unpack(command, 2) },
    -- Clipboard daemons must not retain the worker's stdout/stderr pipes
    stdio = { input, devnull, devnull },
  }, function(code, signal)
    result = { code = code, signal = signal }
    process:close()
  end)
  vim.uv.fs_close(input)
  vim.uv.fs_close(devnull)
  assert(process, spawn_error)
  vim.wait(math.huge, function()
    return result ~= nil
  end)
  assert(result.code == 0, ("%s exited with code %d (signal %d)"):format(command[1], result.code, result.signal))
end

if request.temporary_path then
  if request.operation == "copy_ascii" then
    generator.save_ascii(request.temporary_path, request.config)
  else
    generator.save(request.temporary_path, request.config)
  end
  if request.save_path then
    assert(vim.uv.fs_rename(request.temporary_path, request.save_path))
  else
    copy_file(request.clipboard, request.temporary_path)
  end
else
  generator[request.operation](request.config)
end

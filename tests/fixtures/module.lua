-- Stand in for the native renderer at its existing module boundary. Each
-- invocation still runs the real worker in a real Neovim subprocess
local function write(path, content)
  local file = assert(io.open(path, "w"))
  assert(file:write(content))
  assert(file:close())
end

return {
  load_generator = function()
    return {
      parse_code_theme = function(theme)
        write(vim.env.CODESNAP_TEST_STARTED, tostring(vim.fn.getpid()))
        if vim.env.CODESNAP_TEST_MODE == "crash" then
          os.exit(7)
        end
        -- Deliberately block this process, just as the native renderer does
        vim.uv.sleep(vim.env.CODESNAP_TEST_MODE == "slow" and 30000 or 150)
        return "resolved:" .. theme
      end,
      save = function(path, config)
        if config.title == "binary-fixture" then
          write(path, "\137PNG\r\n\26\n\0\255payload\n")
          return
        end
        write(path, vim.json.encode(config))
        if vim.env.CODESNAP_TEST_MODE == "fail" then
          error("fixture render failed")
        end
      end,
      save_ascii = function(path, config)
        write(path, vim.json.encode(config))
      end,
      copy = function()
        error("Linux copy must not use a short-lived native clipboard owner")
      end,
      copy_ascii = function()
        error("Linux ASCII copy must not use a short-lived native clipboard owner")
      end,
    }
  end,
}

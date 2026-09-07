local visual_utils = require("codesnap.utils.visual")
local path_utils = require("codesnap.utils.path")
local string_utils = require("codesnap.utils.string")
local static = require("codesnap.static")
local config_module = {}

function config_module.get_config()
  local code = visual_utils.get_selected_text()

  if string_utils.is_str_empty(code) then
    error("No code is selected", 0)
  end

  local relative_path = path_utils.get_relative_path()
  local config = vim.deepcopy(static.config.snapshot_config)
  config.content = {
    content = code,
    start_line_number = static.config.show_line_number and visual_utils.get_start_line_number() or nil,
    file_path = static.config.show_workspace and path_utils.get_workspace() .. "/" .. relative_path or relative_path,
  }

  return config
end

return config_module

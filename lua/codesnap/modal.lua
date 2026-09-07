local M = {}

-- Pop up a modal dialog with the selected text
-- @param selected_text string The text to display in the modal
-- @param filetype string The filetype for syntax highlighting
-- @param callback function Callback function that receives {start_line, end_line} or nil
function M.pop_modal(selected_text, filetype, callback)
  local selected_lines = vim.split(selected_text, "\n", { plain = true })

  -- Create a new buffer for the floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, selected_lines)

  vim.bo[buf].filetype = filetype

  -- Make the buffer read-only
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.bo[buf].bufhidden = "wipe"

  -- Calculate window size and position
  local width = 0
  for _, line in ipairs(selected_lines) do
    if #line > width then
      width = #line
    end
  end
  width = math.min(width + 4, vim.o.columns - 10)
  local height = math.min(#selected_lines, vim.o.lines - 10)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Select text to highlight (Press Enter to confirm, Esc to cancel) ",
    title_pos = "center",
    focusable = true,
  })

  -- Set window options
  vim.api.nvim_win_set_option(win, "cursorline", true)
  vim.api.nvim_win_set_option(win, "number", true)
  vim.api.nvim_win_set_option(win, "relativenumber", false)

  -- Function to clean up and call callback
  local closed = false
  local function close_and_callback(result)
    if closed then
      return
    end
    closed = true
    -- Close the floating window if it's still valid
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    callback(result)
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if not closed then
        closed = true
        callback(nil)
      end
    end,
  })

  -- Set up keymaps for the floating window
  vim.keymap.set({ "n", "v" }, "<CR>", function()
    -- Get the current mode
    local mode = vim.api.nvim_get_mode().mode

    if mode == "v" or mode == "V" or mode == "\22" then -- \22 is Ctrl-V (visual block mode)
      -- Visual mode - get the selection range before exiting visual mode
      local start_pos = vim.fn.getpos("v")
      local end_pos = vim.fn.getpos(".")

      -- Ensure start_pos is before end_pos
      if start_pos[2] > end_pos[2] then
        start_pos, end_pos = end_pos, start_pos
      end

      -- Exit visual mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

      close_and_callback({ start_pos[2], end_pos[2] }) -- Return line numbers
    else
      -- No selection, return the entire buffer range
      local line_count = vim.api.nvim_buf_line_count(buf)
      close_and_callback({ 1, line_count })
    end
  end, { buffer = buf })

  -- Set up keymap to close window with Esc
  vim.keymap.set({ "n", "v" }, "<Esc>", function()
    close_and_callback(nil) -- User cancelled
  end, { buffer = buf })

  -- Set up keymap to close window with q
  vim.keymap.set("n", "q", function()
    close_and_callback(nil) -- User cancelled
  end, { buffer = buf })

  return {
    close = function(_, callback)
      close_and_callback(nil)
      callback()
    end,
  }
end

return M

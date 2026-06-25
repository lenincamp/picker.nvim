---@diagnostic disable: undefined-global
local M = {}

M.SIGNCOLUMN = "yes:1"
M.STATUSCOLUMN = "%=%{v:lua.require('picker.gutter').status_number()}%s"

local AUX_FILETYPES = {
  netrw = true,
  ["no-neck-pain"] = true,
  picker_dashboard = true,
  pure_dashboard = true,
  snacks_dashboard = true,
}

function M.is_file_window(window)
  window = window or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(window) then
    return false
  end

  local buffer = vim.api.nvim_win_get_buf(window)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  return vim.bo[buffer].buftype == ""
    and not vim.wo[window].diff
    and not AUX_FILETYPES[vim.bo[buffer].filetype]
end

local function status_window()
  local win = vim.g.statusline_winid
  if type(win) == "number" and vim.api.nvim_win_is_valid(win) then
    return win
  end
  return vim.api.nvim_get_current_win()
end

function M.status_number()
  if not M.is_file_window(status_window()) then
    return ""
  end

  return tostring(vim.v.relnum ~= 0 and vim.v.relnum or vim.v.lnum)
end

function M.apply_window(window)
  window = window or vim.api.nvim_get_current_win()
  if not M.is_file_window(window) then
    return
  end

  if vim.wo[window].signcolumn ~= M.SIGNCOLUMN then
    vim.wo[window].signcolumn = M.SIGNCOLUMN
  end

  if vim.wo[window].statuscolumn ~= M.STATUSCOLUMN then
    vim.wo[window].statuscolumn = M.STATUSCOLUMN
  end
end

function M.apply_current_window()
  M.apply_window(vim.api.nvim_get_current_win())
end

return M

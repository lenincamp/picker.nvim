local config = require("picker.dashboard.config")

local M = {}

local RESTORE_NUMBER = "picker_dashboard_restore_number"
local RESTORE_RELATIVENUMBER = "picker_dashboard_restore_relativenumber"

function M.is_dashboard_buffer(bufnr)
  local ft = vim.bo[bufnr].filetype
  if ft == config.current.filetype then
    return true
  end
  for _, legacy in ipairs(config.current.legacy_filetypes or {}) do
    if ft == legacy then
      return true
    end
  end
  return false
end

function M.should_open()
  if not config.current.open_on_startup then
    return false
  end
  if vim.fn.argc() > 0 then
    return false
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(bufnr) ~= "" then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  if vim.api.nvim_buf_line_count(bufnr) > 1 then
    return false
  end
  return vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
end

function M.apply_options(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  vim.api.nvim_set_option_value("number", false, { scope = "local", win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { scope = "local", win = win })
  vim.wo[win].cursorline = false
  vim.wo[win].list = false
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].signcolumn = "no"
  vim.wo[win].statuscolumn = ""
  vim.wo[win].winbar = ""
end

function M.save_restore_state(win)
  win = win or vim.api.nvim_get_current_win()
  vim.w[win][RESTORE_NUMBER] = vim.go.number
  vim.w[win][RESTORE_RELATIVENUMBER] = vim.go.relativenumber
end

function M.restore_options(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  if M.is_dashboard_buffer(vim.api.nvim_win_get_buf(win)) then
    M.apply_options(win)
    return
  end

  local restore_number = vim.w[win][RESTORE_NUMBER]
  local restore_relativenumber = vim.w[win][RESTORE_RELATIVENUMBER]
  if restore_number == nil then
    restore_number = vim.go.number
  end
  if restore_relativenumber == nil then
    restore_relativenumber = vim.go.relativenumber
  end

  vim.api.nvim_set_option_value("number", restore_number, { scope = "local", win = win })
  vim.api.nvim_set_option_value("relativenumber", restore_relativenumber, { scope = "local", win = win })

  local on_restore = config.current.on_restore_window
  if type(on_restore) == "function" then
    pcall(on_restore, win)
  end

  vim.w[win][RESTORE_NUMBER] = nil
  vim.w[win][RESTORE_RELATIVENUMBER] = nil
end

function M.has_pending_restore(win)
  win = win or vim.api.nvim_get_current_win()
  return vim.w[win][RESTORE_NUMBER] ~= nil
end

return M

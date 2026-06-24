local config = require("picker.config")
local util = require("picker.util")

local M = {}

local BUFFER_FLAG = "picker_lazygit"
local LEGACY_BUFFER_FLAG = "native_lazygit"

local function lazygit_cmd()
  local cmd = (config.current.git or {}).lazygit_cmd or { "lazygit" }
  if type(cmd) == "string" then
    return { cmd }
  end
  return cmd
end

local function lazygit_executable()
  local cmd = lazygit_cmd()
  return vim.fn.executable(cmd[1]) == 1
end

local function focus_buffer_window(bufnr)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
        vim.api.nvim_set_current_tabpage(tab)
        vim.api.nvim_set_current_win(win)
        return true
      end
    end
  end
  return false
end

local function is_lazygit_buffer(buf)
  return vim.b[buf][BUFFER_FLAG] == true or vim.b[buf][LEGACY_BUFFER_FLAG] == true
end

local function prepare_terminal_window()
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
end

function M.open(cwd)
  if not lazygit_executable() then
    util.notify("lazygit is not available", vim.log.levels.WARN)
    return
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and is_lazygit_buffer(buf) then
      if focus_buffer_window(buf) then
        prepare_terminal_window()
        vim.cmd("startinsert")
        return
      end
    end
  end

  vim.cmd("tabnew")
  prepare_terminal_window()
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].buflisted = false
  vim.bo[buffer].bufhidden = "wipe"
  vim.b[buffer][BUFFER_FLAG] = true

  vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
    buffer = buffer,
    callback = prepare_terminal_window,
  })

  vim.fn.termopen(lazygit_cmd(), {
    cwd = cwd or vim.fn.getcwd(),
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buffer) then
          pcall(vim.api.nvim_buf_delete, buffer, { force = true })
        end
        if vim.fn.tabpagenr("$") > 1 then
          pcall(vim.cmd, "tabclose")
        end
      end)
    end,
  })
  vim.schedule(prepare_terminal_window)
  vim.cmd("startinsert")
end

return M

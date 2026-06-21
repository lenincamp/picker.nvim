local M = {}

local picker_preview = require("picker.preview")
local preview = require("preview")

function M.close(win, bufnr)
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
  return nil, nil
end

function M.update(win, bufnr, opts)
  local item = opts.item
  local path = picker_preview.path(opts.picker_opts, item)
  local ok_preview, fallback, preview_syntax, preview_highlights
  local content_ok, content_lines, content_syntax, content_highlights = picker_preview.content(
    opts.picker_opts,
    item,
    opts.config.width
  )

  if content_ok ~= nil then
    ok_preview, fallback, preview_syntax, preview_highlights = content_ok, content_lines, content_syntax, content_highlights
  else
    ok_preview, fallback = picker_preview.allowed(opts.picker_opts, path, item)
  end

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true

  if ok_preview then
    local lines = type(fallback) == "table" and fallback or { tostring(fallback or "") }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    if preview_syntax then
      vim.bo[bufnr].syntax = preview_syntax
    elseif path then
      preview.set_syntax(bufnr, path)
    end
    preview.apply_ansi_highlights(bufnr, preview_highlights)
    picker_preview.apply_match(bufnr, opts.namespace, picker_preview.match(opts.picker_opts, item, lines), lines)
  else
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { fallback })
  end

  vim.bo[bufnr].modifiable = false

  if not win or not vim.api.nvim_win_is_valid(win) then
    local ok_win, next_win = pcall(vim.api.nvim_open_win, bufnr, false, opts.config)
    if ok_win then
      win = next_win
      vim.wo[win].wrap = false
      vim.wo[win].number = true
      vim.wo[win].relativenumber = false
      vim.wo[win].cursorline = true
    end
  else
    vim.api.nvim_win_set_buf(win, bufnr)
    pcall(vim.api.nvim_win_set_config, win, opts.config)
  end

  if ok_preview and win and vim.api.nvim_win_is_valid(win) then
    local lnum = picker_preview.target_lnum(opts.picker_opts, item)
    if lnum then
      pcall(vim.api.nvim_win_set_cursor, win, { math.min(lnum, vim.api.nvim_buf_line_count(bufnr)), 0 })
      vim.api.nvim_win_call(win, function() pcall(vim.cmd, "normal! zz") end)
    end
  end

  return win, bufnr
end

return M

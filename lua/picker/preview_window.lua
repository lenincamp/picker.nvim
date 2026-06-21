local M = {}

local picker_preview = require("picker.preview")
local preview = require("preview")

local function normalize_preview_lines(value)
  if type(value) == "table" then
    return #value > 0 and value or { "" }
  end
  return { tostring(value or "") }
end

local function truncate_label(label, width)
  label = tostring(label or "")
  width = math.max(10, width or 30)
  if vim.fn.strdisplaywidth(label) <= width then
    return label
  end
  return vim.fn.strcharpart(label, 0, math.max(1, width - 3)) .. "..."
end

local function preview_label(path, item, width)
  local label = path
  if type(item) == "table" then
    label = label or item.path or item.filename or item.label or item.value
  end
  if type(label) == "string" and label ~= "" then
    label = vim.fn.fnamemodify(label, ":~:.")
  else
    label = "Preview"
  end
  return truncate_label(label, width)
end

local function apply_window_options(win)
  vim.wo[win].wrap = false
  vim.wo[win].number = true
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].list = false
  vim.wo[win].spell = false
  vim.wo[win].colorcolumn = ""
end

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

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
  end
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].syntax = ""
  vim.api.nvim_buf_clear_namespace(bufnr, opts.namespace, 0, -1)

  if ok_preview then
    local lines = normalize_preview_lines(fallback)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    if preview_syntax then
      vim.bo[bufnr].syntax = preview_syntax
    elseif path then
      preview.set_syntax(bufnr, path)
    end
    preview.apply_ansi_highlights(bufnr, preview_highlights)
    picker_preview.apply_match(bufnr, opts.namespace, picker_preview.match(opts.picker_opts, item, lines), lines)
  else
    preview.apply_ansi_highlights(bufnr, nil)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, normalize_preview_lines(fallback))
  end

  vim.bo[bufnr].modifiable = false

  local config = vim.tbl_extend("force", opts.config, {
    title = " " .. preview_label(path, item, opts.config.width - 4) .. " ",
    title_pos = "left",
  })

  if not win or not vim.api.nvim_win_is_valid(win) then
    local ok_win, next_win = pcall(vim.api.nvim_open_win, bufnr, false, config)
    if ok_win then
      win = next_win
      apply_window_options(win)
    end
  else
    vim.api.nvim_win_set_buf(win, bufnr)
    pcall(vim.api.nvim_win_set_config, win, config)
    apply_window_options(win)
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

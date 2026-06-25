local M = {}

function M.define_highlights()
  local status = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
  local float = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
  local menu = vim.api.nvim_get_hl(0, { name = "Pmenu", link = false })
  local accent = vim.api.nvim_get_hl(0, { name = "Title", link = false })
  if not accent.fg then
    accent = vim.api.nvim_get_hl(0, { name = "Directory", link = false })
  end
  local title_hl = {
    fg = accent.fg or status.fg,
    bg = status.bg or float.bg or menu.bg,
    bold = true,
  }
  if not title_hl.bg then
    title_hl.reverse = true
  end
  vim.api.nvim_set_hl(0, "NativePickerTitle", title_hl)
  vim.api.nvim_set_hl(0, "NativePickerStatus", { link = "StatusLineNC", default = true })
  vim.api.nvim_set_hl(0, "NativePickerKey", { link = "Special", default = true })
  local match_hl = vim.api.nvim_get_hl(0, { name = "IncSearch", link = false })
  if not match_hl.fg and not match_hl.bg then
    match_hl = vim.api.nvim_get_hl(0, { name = "Search", link = false })
  end
  match_hl.bold = true
  vim.api.nvim_set_hl(0, "NativePickerMatch", match_hl)
end

function M.padded_line(line, width)
  line = tostring(line or "")
  local padding = math.max(width - vim.fn.strdisplaywidth(line), 0)
  return line .. string.rep(" ", padding)
end

return M

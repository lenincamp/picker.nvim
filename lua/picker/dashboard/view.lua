local config = require("picker.dashboard.config")

local M = {}

local ns = vim.api.nvim_create_namespace("picker_dashboard")
local bit = require("bit")

local LEGACY_GROUPS = {
  PickerDashboardHeader = "SnacksDashboardHeader",
  PickerDashboardSpecial = "SnacksDashboardSpecial",
  PickerDashboardKey = "SnacksDashboardKey",
}

local function color_channel(value, shift)
  return bit.band(bit.rshift(value, shift), 0xff)
end

local function rgb_from_hl(hl)
  if not hl or hl.fg == nil or type(hl.fg) ~= "number" then
    return nil
  end
  return color_channel(hl.fg, 16), color_channel(hl.fg, 8), color_channel(hl.fg, 0)
end

local function relative_luminance(r, g, b)
  local function channel(c)
    c = c / 255
    if c <= 0.03928 then
      return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

function M.is_dark_background()
  if vim.o.background == "light" then
    return false
  end
  if vim.o.background == "dark" then
    return true
  end

  local ok, normal = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  if ok and normal then
    if normal.bg ~= nil and type(normal.bg) == "number" then
      local r = color_channel(normal.bg, 16)
      local g = color_channel(normal.bg, 8)
      local b = color_channel(normal.bg, 0)
      return relative_luminance(r, g, b) < 0.5
    end
    local r, g, b = rgb_from_hl(normal)
    if r then
      return relative_luminance(r, g, b) < 0.5
    end
  end

  return true
end

function M.current_palette()
  local cfg = config.current
  local mode = M.is_dark_background() and "dark" or "light"
  return cfg.highlights[mode], mode
end

function M.setup_highlights()
  local cfg = config.current
  local palette, mode = M.current_palette()
  local groups = cfg.highlight_groups

  vim.api.nvim_set_hl(0, groups.header, palette.header)
  vim.api.nvim_set_hl(0, groups.special, palette.special)
  vim.api.nvim_set_hl(0, groups.key, palette.key)

  for primary, legacy in pairs(LEGACY_GROUPS) do
    vim.api.nvim_set_hl(0, legacy, { link = primary, default = true })
  end

  return mode
end

function M.apply_highlights(bufnr)
  local cfg = config.current
  local groups = cfg.highlight_groups

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for row, line in ipairs(lines) do
    local line_index = row - 1
    if line:find("%[.%]") then
      local key_start, key_end = line:find("%[.%]")
      local nonblank = line:find("%S") or 1
      if nonblank < key_start then
        vim.api.nvim_buf_add_highlight(bufnr, ns, groups.special, line_index, nonblank - 1, key_start - 1)
      end
      vim.api.nvim_buf_add_highlight(bufnr, ns, groups.key, line_index, key_start - 1, key_end)
      if key_end < #line then
        vim.api.nvim_buf_add_highlight(bufnr, ns, groups.special, line_index, key_end, -1)
      end
    elseif line:find("%S") then
      vim.api.nvim_buf_add_highlight(bufnr, ns, groups.header, line_index, 0, -1)
    end
  end
end

function M.refresh_open_buffers()
  M.setup_highlights()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local window = require("picker.dashboard.window")
      if window.is_dashboard_buffer(bufnr) then
        M.apply_highlights(bufnr)
      end
    end
  end
end

return M

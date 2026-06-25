local config = require("picker.dashboard.config")
local content = require("picker.dashboard.content")
local view = require("picker.dashboard.view")

local function assert_eq(a, b, msg)
  if a ~= b then
    error(string.format("%s: expected %s, got %s", msg or "assert_eq", vim.inspect(b), vim.inspect(a)))
  end
end

local function assert_true(v, msg)
  if not v then
    error(msg or "assert_true failed")
  end
end

-- is_dark_background follows vim.o.background
vim.o.background = "dark"
assert_true(view.is_dark_background(), "dark background detected")
local dark_palette, dark_mode = view.current_palette()
assert_eq(dark_palette.header.fg, config.current.highlights.dark.header.fg, "dark palette header color")
assert_eq(dark_mode, "dark", "dark mode label")

vim.o.background = "light"
assert_true(not view.is_dark_background(), "light background detected")

local palette, mode = view.current_palette()
assert_eq(palette.header.fg, config.current.highlights.light.header.fg, "light palette header color")
assert_eq(mode, "light", "light mode label")

-- content layout
local lines = content.centered_lines(config.current.header, config.current.buttons, config.current.icons)
assert_true(#lines > 0, "centered lines generated")
assert_true(content.max_display_width(lines) > 0, "content width > 0")

local menu = content.menu_lines(config.current.buttons, config.current.icons)
for _, line in ipairs(menu) do
  assert_true(line:find("%[f%]") ~= nil or line:find("%[g%]") ~= nil or line:find("%[.%]") ~= nil, "menu line has key")
end

local function hex(value)
  return tonumber(value:gsub("#", ""), 16)
end

-- setup applies highlights for current mode
view.setup_highlights()
local light_hl = vim.api.nvim_get_hl(0, { name = "PickerDashboardHeader", link = false })
assert_eq(light_hl.fg, hex(config.current.highlights.light.header.fg), "setup uses light header on light bg")

vim.o.background = "dark"
view.setup_highlights()
local dark_hl = vim.api.nvim_get_hl(0, { name = "PickerDashboardHeader", link = false })
assert_eq(dark_hl.fg, hex(config.current.highlights.dark.header.fg), "setup uses dark header on dark bg")

-- window.should_open respects argc
local window = require("picker.dashboard.window")
config.apply({ open_on_startup = true })
assert_true(type(window.should_open()) == "boolean", "should_open returns boolean")

-- dashboard buffers do not render gutter line numbers
local gutter = require("picker.gutter")
vim.bo.filetype = config.current.filetype
assert_true(not gutter.is_file_window(vim.api.nvim_get_current_win()), "dashboard is not a file window")
assert_eq(gutter.status_number(), "", "dashboard status number hidden")

print("dashboard: ok")

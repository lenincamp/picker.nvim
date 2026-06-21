local layout = require("picker.layout")

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

-- Test: default layout calculation
vim.o.columns = 120
vim.o.lines = 40
vim.o.cmdheight = 1

local result = layout.calculate({ has_preview = true, layout = "default", max_results = 40 })
assert_true(result.width > 0, "default width > 0")
assert_true(result.height > 0, "default height > 0")
assert_true(result.preview_width > 0, "default preview width > 0")
assert_true(result.preview_height > 0, "default preview height > 0")
assert_eq(result.columns, 120, "columns from vim.o")
print("default layout: ok")

-- Test: intellij_grep layout
local intellij = layout.calculate({ has_preview = true, layout = "intellij_grep", max_results = 40 })
assert_true(intellij.width >= 40, "intellij width >= 40")
assert_true(intellij.preview_width >= intellij.width, "intellij preview full width")
assert_true(intellij.preview_row < intellij.row, "intellij preview above list")
print("intellij_grep layout: ok")

-- Test: input-only layout (no preview)
local input = layout.calculate({ has_preview = false, input_mode = true, max_results = 40 })
assert_eq(input.preview_width, 0, "input only no preview width")
assert_eq(input.preview_height, 0, "input only no preview height")
assert_true(input.width > 0, "input only has width")
print("input-only layout: ok")

-- Test: candidates_config
local candidates = layout.candidates_config(result)
assert_eq(candidates.relative, "editor", "candidates relative")
assert_eq(candidates.style, "minimal", "candidates style")
assert_eq(candidates.border, "single", "candidates border")
assert_true(candidates.focusable, "candidates focusable")
print("candidates_config: ok")

-- Test: preview_config normal
local preview = layout.preview_config(result, false)
assert_eq(preview.relative, "editor", "preview relative")
assert_eq(preview.zindex, 60, "preview zindex normal")
print("preview_config normal: ok")

-- Test: preview_config maximized
local maximized = layout.preview_config(result, true)
assert_eq(maximized.zindex, 80, "preview zindex maximized")
assert_true(maximized.width >= result.columns - 4, "maximized width fills screen")
print("preview_config maximized: ok")

-- Test: position top
local top = layout.calculate({ has_preview = true, layout = "default", max_results = 40, position = "top" })
assert_eq(top.row, 1, "top position row is 1")
assert_eq(top.col, 2, "top position col is 2")
print("position top: ok")

-- Test: small screen
vim.o.columns = 40
vim.o.lines = 12
local small = layout.calculate({ has_preview = true, layout = "intellij_grep", max_results = 40 })
assert_true(small.width >= 36, "small screen width fits")
assert_true(small.height >= 5, "small screen height minimum")
print("small screen: ok")

print("ALL LAYOUT TESTS PASSED")

local navigation = require("picker.navigation")

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

-- Test: page forward
local next_start, changed = navigation.page({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, 1, 8, 1)
assert_true(changed, "page forward changed")
assert_true(next_start > 1, "page forward moved start")
print("page forward: ok")

-- Test: page backward from start
local back_start, back_changed = navigation.page({ 1, 2, 3 }, 1, 8, -1)
assert_eq(back_start, 1, "page backward at start stays")
print("page backward: ok")

-- Test: page when all fit
local _, all_changed = navigation.page({ 1, 2, 3 }, 1, 20, 1)
assert_true(not all_changed, "page no-op when all fit")
print("page all fit: ok")

-- Test: move_cursor creates buffer and window for testing
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "title", "status", "item1", "item2", "item3" })
local win = vim.api.nvim_open_win(buf, true, {
  relative = "editor",
  row = 1,
  col = 1,
  width = 40,
  height = 5,
  style = "minimal",
})
vim.api.nvim_win_set_cursor(win, { 3, 0 })

local moved = navigation.move_cursor(win, { "a", "b", "c" }, 1, 5, 1)
assert_true(moved, "move_cursor returns true")
local cursor = vim.api.nvim_win_get_cursor(win)
assert_eq(cursor[1], 4, "move_cursor moved down")
print("move_cursor: ok")

-- Test: move_cursor clamp
navigation.move_cursor(win, { "a", "b", "c" }, 1, 5, 10)
local clamped = vim.api.nvim_win_get_cursor(win)
assert_true(clamped[1] <= 5, "move_cursor clamped to max")
print("move_cursor clamp: ok")

-- Test: move_cursor empty candidates
local empty_moved = navigation.move_cursor(win, {}, 1, 5, 1)
assert_true(not empty_moved, "move_cursor empty returns false")
print("move_cursor empty: ok")

vim.api.nvim_win_close(win, true)
vim.api.nvim_buf_delete(buf, { force = true })

-- Test: scroll_preview
-- Just ensure it doesn't error with invalid window
navigation.scroll_preview(nil, 5)
navigation.scroll_preview(999999, 5)
print("scroll_preview no crash: ok")

-- Test: jump_group
local group_items = {
  { label = "a", group = "A" },
  { label = "b", group = "A" },
  { label = "c", group = "B" },
  { label = "d", group = "B" },
}

local gbuf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(gbuf, 0, -1, false, { "title", "status", "a", "b", "c", "d" })
local gwin = vim.api.nvim_open_win(gbuf, true, {
  relative = "editor",
  row = 1,
  col = 1,
  width = 40,
  height = 6,
  style = "minimal",
})
vim.api.nvim_win_set_cursor(gwin, { 3, 0 })

local gopts = { group_item = function(item) return item.group end }
local gstart, grow = navigation.jump_group(gopts, gwin, group_items, 1, 6, 1)
assert_true(grow ~= nil, "jump_group finds next group")
print("jump_group: ok")

vim.api.nvim_win_close(gwin, true)
vim.api.nvim_buf_delete(gbuf, { force = true })

print("ALL NAVIGATION TESTS PASSED")

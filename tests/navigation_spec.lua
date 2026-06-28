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

-- Test: advance_selection within the visible page (no re-render)
-- height=5, first_line=3 => visible_limit=2; total=5
local a_start, a_cursor, a_render = navigation.advance_selection(5, 1, 3, 5, 1, 3)
assert_eq(a_start, 1, "advance within page keeps page_start")
assert_eq(a_cursor, 4, "advance within page moves cursor down")
assert_true(not a_render, "advance within page needs no render")
print("advance within page: ok")

-- Test: advance_selection scrolls when passing the bottom edge
local s_start, s_cursor, s_render = navigation.advance_selection(5, 1, 4, 5, 1, 3)
assert_eq(s_start, 2, "advance past edge scrolls page_start")
assert_eq(s_cursor, 4, "advance past edge keeps cursor at bottom")
assert_true(s_render, "advance past edge needs render")
print("advance scroll: ok")

-- Test: advance_selection wraps last -> first
local wl_start, wl_cursor, wl_render = navigation.advance_selection(5, 4, 4, 5, 1, 3)
assert_eq(wl_start, 1, "wrap last->first resets page_start")
assert_eq(wl_cursor, 3, "wrap last->first puts cursor on first row")
assert_true(wl_render, "wrap last->first needs render")
print("advance wrap last->first: ok")

-- Test: advance_selection wraps first -> last
local wf_start, wf_cursor, wf_render = navigation.advance_selection(5, 1, 3, 5, -1, 3)
assert_eq(wf_start, 4, "wrap first->last shows last page")
assert_eq(wf_cursor, 4, "wrap first->last puts cursor on last item")
assert_true(wf_render, "wrap first->last needs render")
print("advance wrap first->last: ok")

-- Test: advance_selection empty list is a no-op
local e_start, e_cursor, e_render = navigation.advance_selection(0, 1, 3, 5, 1, 3)
assert_eq(e_start, 1, "advance empty keeps page_start")
assert_eq(e_cursor, 3, "advance empty keeps cursor")
assert_true(not e_render, "advance empty needs no render")
print("advance empty: ok")

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

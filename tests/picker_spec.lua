local picker = require("picker")

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

-- Test: setup
picker.setup({})
assert_true(picker.is_intellij_grep_enabled(), "default intellij enabled")
print("setup default: ok")

picker.setup({ layout = "default" })
assert_true(not picker.is_intellij_grep_enabled(), "setup layout=default disables intellij")
picker.setup({ layout = "intellij_grep" })
assert_true(picker.is_intellij_grep_enabled(), "setup layout=intellij re-enables")
print("setup layout: ok")

-- Test: set/get intellij
picker.set_intellij_grep(false)
assert_true(not picker.is_intellij_grep_enabled(), "set_intellij false")
picker.set_intellij_grep(true)
assert_true(picker.is_intellij_grep_enabled(), "set_intellij true")
print("set/get intellij: ok")

-- Test: with_layout
picker.set_intellij_grep(true)
local opts = picker.with_layout({ prompt = "test" })
assert_eq(opts.layout, "intellij_grep", "with_layout adds intellij")
assert_eq(opts.prompt, "test", "with_layout preserves opts")
picker.set_intellij_grep(false)
local opts2 = picker.with_layout({ prompt = "test2" })
assert_eq(opts2.layout, nil, "with_layout no intellij returns as-is")
picker.set_intellij_grep(true)
print("with_layout: ok")

-- Test: select_items with empty list notifies
local notified = {}
vim.notify = function(msg, level) notified[#notified + 1] = { msg = msg, level = level } end
picker.select_items({}, { prompt = "Empty" }, function() end)
assert_true(#notified > 0, "empty select_items notifies")
assert_true(notified[1].msg:find("no results", 1, true) ~= nil, "notification mentions no results")
print("select_items empty notifies: ok")

-- Test: select_items opens picker float
notified = {}
picker.select_items(
  { { label = "alpha" }, { label = "beta" } },
  { prompt = "Test Picker" },
  function() end
)
local floats = 0
for _, win in ipairs(vim.api.nvim_list_wins()) do
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= "" then
    floats = floats + 1
  end
end
assert_true(floats >= 1, "select_items opens at least one float")
-- Close it
vim.api.nvim_feedkeys("q", "x", false)
print("select_items opens picker: ok")

-- Test: select_items with on_choice callback
local chosen = nil
picker.select_items(
  { { label = "first", value = "first" }, { label = "second", value = "second" } },
  { prompt = "Choice" },
  function(item) chosen = item end
)
-- Select item 1 via numeric
vim.api.nvim_feedkeys("1", "x", false)
vim.wait(100, function() return chosen ~= nil end, 10)
assert_true(chosen ~= nil, "on_choice called")
assert_eq(chosen.value, "first", "on_choice receives correct item")
print("select_items on_choice: ok")

-- Test: select_items input_mode opens in insert mode
picker.select_items(
  { { label = "input target" } },
  { prompt = "Input Mode", input_mode = true, search_threshold = 0 },
  function() end
)
local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, 2, false)
local status = lines[2] or ""
assert_true(status:find("INS", 1, true) ~= nil, "input_mode shows INS: " .. status)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>q", true, false, true), "x", false)
print("select_items input_mode: ok")

-- Test: resume with no prior search
notified = {}
picker.resume()
assert_true(#notified > 0, "resume with no search notifies")
print("resume no prior: ok")

-- Test: select_items with quickfix
picker.select_items(
  { { label = "qf1.lua", path = "qf1.lua", lnum = 1 }, { label = "qf2.lua", path = "qf2.lua", lnum = 5 } },
  { prompt = "QF Test", preview = function(item) return item.path end },
  function() end
)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-q>", true, false, true), "x", false)
vim.wait(200, function() return #vim.fn.getqflist() > 0 end, 10)
assert_eq(#vim.fn.getqflist(), 2, "C-q populates quickfix")
print("select_items quickfix: ok")

-- Test: multi_select
local multi_chosen = nil
picker.select_items(
  { { label = "m1", value = "m1" }, { label = "m2", value = "m2" } },
  { prompt = "Multi", multi_select = true },
  function(items) multi_chosen = items end
)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space>j<Space><CR>", true, false, true), "x", false)
vim.wait(200, function() return multi_chosen ~= nil end, 10)
assert_true(type(multi_chosen) == "table" and #multi_chosen == 2, "multi-select returns 2 items")
print("multi_select: ok")

print("ALL PICKER TESTS PASSED")

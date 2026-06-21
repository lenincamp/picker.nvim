local picker = require("picker")
local picker_preview = require("picker.preview")

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

local toggled = picker.toggle_intellij_grep()
assert_true(not toggled, "toggle_intellij_grep off")
assert_true(not picker.is_intellij_grep_enabled(), "toggle disabled intellij")
picker.toggle_intellij_grep()
assert_true(picker.is_intellij_grep_enabled(), "toggle_intellij_grep on")

picker.set_intellij_grep(true)
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

-- Test: select_items input_mode opens input float
picker.select_items(
  { { label = "input target" } },
  { prompt = "Input Mode", input_mode = true, search_threshold = 0 },
  function() end
)
-- In input_mode the current buffer is the 1-line input float
local input_buf = vim.api.nvim_get_current_buf()
assert_eq(vim.bo[input_buf].buftype, "nofile", "input_mode current buf is input float")
local win_config = vim.api.nvim_win_get_config(vim.api.nvim_get_current_win())
assert_eq(win_config.height, 1, "input float height is 1")
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

-- Test: preview match uses 1-based columns
local pbuf = vim.api.nvim_create_buf(false, true)
local pns = vim.api.nvim_create_namespace("native_picker_preview_test")
local plines = { "alpha beta" }
vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, plines)
picker_preview.apply_match(pbuf, pns, { lnum = 1, col = 7, length = 4 }, plines)
local extmarks = vim.api.nvim_buf_get_extmarks(pbuf, pns, 0, -1, { details = true })
local found_match = false
for _, mark in ipairs(extmarks) do
  if mark[3] == 6 and mark[4].end_col == 10 then
    found_match = true
    break
  end
end
assert_true(found_match, "preview match highlights expected 1-based column")
vim.api.nvim_buf_delete(pbuf, { force = true })
print("preview match columns: ok")

-- Test: input on_change is deferred out of TextChangedI (fast event)
local picker_input = require("picker.input")
local on_change_text = nil
local input_state = picker_input.open({
  prompt = "Defer",
  row = 0,
  col = 0,
  width = 20,
  on_change = function(text)
    on_change_text = text
    assert_true(not vim.in_fast_event(), "on_change runs outside fast events")
  end,
})
vim.api.nvim_buf_set_lines(input_state.buf, 0, -1, true, { "bar" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input_state.buf })
vim.wait(200, function() return on_change_text == "bar" end, 10)
assert_eq(on_change_text, "bar", "input on_change receives typed text")
picker_input.close(input_state)
print("input on_change defer: ok")

-- Test: input paste updates text and notifies
local paste_change_text = nil
local paste_state = picker_input.open({
  prompt = "Paste",
  row = 0,
  col = 0,
  width = 20,
  on_change = function(text)
    paste_change_text = text
  end,
})
vim.fn.setreg('"', "beta\nignored")
picker_input.paste(paste_state)
vim.wait(200, function() return paste_change_text == "beta ignored" end, 10)
assert_eq(vim.api.nvim_buf_get_lines(paste_state.buf, 0, 1, false)[1], "beta ignored", "paste writes one input line")
assert_eq(paste_change_text, "beta ignored", "paste notifies input change")
picker_input.close(paste_state)
print("input paste updates: ok")

-- Test: native multiline paste collapses and refreshes query
local multiline_change_text = nil
local multiline_state = picker_input.open({
  prompt = "Multiline",
  row = 0,
  col = 0,
  width = 20,
  on_change = function(text)
    multiline_change_text = text
  end,
})
vim.api.nvim_buf_set_lines(multiline_state.buf, 0, -1, false, { "alpha", "beta" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = multiline_state.buf })
vim.wait(200, function() return multiline_change_text == "alpha beta" end, 10)
assert_eq(vim.api.nvim_buf_line_count(multiline_state.buf), 1, "multiline paste collapses input")
assert_eq(multiline_change_text, "alpha beta", "multiline paste notifies collapsed query")
picker_input.refresh(multiline_state)
vim.wait(200, function() return multiline_change_text == "alpha beta" end, 10)
picker_input.close(multiline_state)
print("input multiline paste: ok")

-- Test: input_only + empty candidates opens input float (grep_picker path)
local grep_open_ok, grep_err = pcall(function()
  picker.select_items({}, {
    prompt = "Grep",
    input_mode = true,
    input_only = true,
    layout = "intellij_grep",
    preview = function(item) return item and item.filename end,
    dynamic_items = function(_state, cb) cb({}) return nil end,
    debounce_ms = 140,
  }, function() end)
end)
assert_true(grep_open_ok, "input_only empty open: " .. tostring(grep_err))
local has_input_float = false
for _, win in ipairs(vim.api.nvim_list_wins()) do
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative == "editor" and cfg.height == 1 then
    has_input_float = true
    break
  end
end
assert_true(has_input_float, "input_only empty open creates input float")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>q", true, false, true), "x", false)
print("input_only empty open: ok")

print("ALL PICKER TESTS PASSED")

local quickfix = require("picker.quickfix")

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

-- Test: item with path
local qf = quickfix.item({ path = "src/test.lua", lnum = 10, col = 5, text = "hello" }, {})
assert_eq(qf.filename, "src/test.lua", "qf filename from path")
assert_eq(qf.lnum, 10, "qf lnum")
assert_eq(qf.col, 5, "qf col")
assert_eq(qf.text, "hello", "qf text")
print("quickfix item with path: ok")

-- Test: item with filename
local qf2 = quickfix.item({ filename = "other.lua", lnum = 1 }, {})
assert_eq(qf2.filename, "other.lua", "qf filename field")
assert_eq(qf2.col, 1, "qf default col")
print("quickfix item with filename: ok")

-- Test: item with no path returns nil
local qf3 = quickfix.item({ label = "no path" }, {})
assert_eq(qf3, nil, "qf nil for no path")
print("quickfix item no path: ok")

-- Test: item string returns nil
local qf4 = quickfix.item("string", {})
assert_eq(qf4, nil, "qf nil for string")
print("quickfix item string: ok")

-- Test: item with custom quickfix_item
local custom = quickfix.item({ label = "custom" }, {
  quickfix_item = function(item) return { filename = "custom.lua", lnum = 99, col = 1, text = item.label } end,
})
assert_eq(custom.filename, "custom.lua", "custom qf filename")
assert_eq(custom.lnum, 99, "custom qf lnum")
print("quickfix item custom: ok")

-- Test: items batch
local batch = quickfix.items({
  { path = "a.lua", lnum = 1 },
  { label = "no path" },
  { path = "b.lua", lnum = 2 },
}, {})
assert_eq(#batch, 2, "batch filters non-qf items")
print("quickfix items batch: ok")

print("ALL QUICKFIX TESTS PASSED")

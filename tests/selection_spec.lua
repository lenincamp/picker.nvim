local selection = require("picker.selection")

local function assert_eq(a, b, msg)
  if a ~= b then
    error(string.format("%s: expected %s, got %s", msg or "assert_eq", vim.inspect(b), vim.inspect(a)))
  end
end

-- Test: item_key from label
assert_eq(selection.item_key({}, { label = "hello" }), "hello", "item_key label")

-- Test: item_key from path
assert_eq(selection.item_key({}, { path = "/a/b.lua" }), "/a/b.lua", "item_key path")

-- Test: item_key from bufnr
assert_eq(selection.item_key({}, { bufnr = 42 }), "42", "item_key bufnr")

-- Test: item_key string
assert_eq(selection.item_key({}, "plain"), "plain", "item_key string")

-- Test: item_key custom function
local opts = { item_key = function(item) return item.id end }
assert_eq(selection.item_key(opts, { id = "custom-id", label = "x" }), "custom-id", "item_key custom")
print("item_key: ok")

-- Test: selected_items
local items = {
  { label = "a", path = "a.lua" },
  { label = "b", path = "b.lua" },
  { label = "c", path = "c.lua" },
}
local selected = { ["a.lua"] = true, ["c.lua"] = true }
local result = selection.selected_items(items, {}, selected)
assert_eq(#result, 2, "selected_items count")
assert_eq(result[1].path, "a.lua", "selected_items first")
assert_eq(result[2].path, "c.lua", "selected_items second")
print("selected_items: ok")

-- Test: selected_items empty
local empty = selection.selected_items(items, {}, {})
assert_eq(#empty, 0, "selected_items empty")
print("selected_items empty: ok")

print("ALL SELECTION TESTS PASSED")

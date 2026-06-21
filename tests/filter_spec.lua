local filter = require("picker.filter")

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

-- Test: item_label from table
assert_eq(filter.item_label({ label = "hello" }, {}), "hello", "item_label from table")
assert_eq(filter.item_label({ path = "a/b.lua" }, {}), "a/b.lua", "item_label from path")
assert_eq(filter.item_label("string item", {}), "string item", "item_label from string")
print("item_label: ok")

-- Test: item_matches basic
assert_true(filter.item_matches("foo/bar.lua", "bar"), "item_matches substring")
assert_true(filter.item_matches("foo/bar.lua", "foo bar"), "item_matches multi-token")
assert_true(not filter.item_matches("foo/bar.lua", "zzz"), "item_matches no match")
assert_true(filter.item_matches("foo/bar.lua", ""), "item_matches empty query")
print("item_matches: ok")

-- Test: item_matches glob
assert_true(filter.item_matches("src/app.js", "*.js"), "glob matches js")
assert_true(not filter.item_matches("src/app.ts", "*.js"), "glob rejects ts")
print("item_matches glob: ok")

-- Test: items fuzzy scoring
local items = {
  { label = "frontend/images/patagonia/unchecked.svg" },
  { label = "frontend/images/patagonia/checked.svg" },
  { label = "audit/src/main/java/backend/Backend.java" },
}
local result = filter.items(items, {}, "unchecked")
assert_eq(#result, 1, "fuzzy unchecked count")
assert_true(result[1].label:find("unchecked", 1, true) ~= nil, "fuzzy unchecked match")
print("items fuzzy unchecked: ok")

-- Test: items quoted normalizes
local quoted = filter.items(items, {}, '"unchecked"')
assert_eq(#quoted, 1, "quoted unchecked count")
print("items quoted normalization: ok")

-- Test: items multi-token
local multi = filter.items(items, {}, "frontend svg")
assert_eq(#multi, 2, "multi-token matches both svg")
print("items multi-token: ok")

-- Test: items empty query returns all
local all = filter.items(items, {}, "")
assert_eq(#all, 3, "empty query returns all")
print("items empty query: ok")

-- Test: items no match returns empty
local none = filter.items(items, {}, "zzzzz_nonexistent")
assert_eq(#none, 0, "no match returns empty")
print("items no match: ok")

-- Test: items_async yields before returning results
local async_result = nil
local async_inline = true
filter.items_async(items, { filter_chunk_size = 1 }, "frontend svg", function(result)
  async_result = result
  assert_true(not async_inline, "items_async callback is scheduled")
end)
async_inline = false
vim.wait(500, function() return async_result ~= nil end, 10)
assert_true(async_result ~= nil, "items_async returned")
assert_eq(#async_result, 2, "items_async result count")
print("items_async: ok")

-- Test: match_ranges exact
local ranges = filter.match_ranges("frontend/images/patagonia/unchecked.svg", "unchecked")
assert_eq(#ranges, 1, "match_ranges count")
assert_eq(ranges[1].to - ranges[1].from + 1, 9, "match_ranges length")
print("match_ranges exact: ok")

-- Test: match_ranges fuzzy (short token)
local fuzz_ranges = filter.match_ranges("OwnAccountTransfers.jsx", "oat")
assert_true(#fuzz_ranges > 0, "fuzzy short ranges exist")
print("match_ranges fuzzy: ok")

-- Test: match_positions
local positions = filter.match_positions("hello world", "hel")
assert_eq(#positions, 3, "match_positions count for hel")
assert_eq(positions[1], 1, "match_positions first char")
print("match_positions: ok")

-- Test: by_predicate
local pred_result = filter.by_predicate(items, function(item)
  return item.label:find("java") ~= nil
end)
assert_eq(#pred_result, 1, "by_predicate java")
print("by_predicate: ok")

-- Test: by_regex
local regex_result = filter.by_regex(items, {}, "%.svg$")
assert_eq(#regex_result, 2, "by_regex svg count")
print("by_regex: ok")

-- Test: has_filters
assert_true(not filter.has_filters(nil), "has_filters nil")
assert_true(not filter.has_filters({}), "has_filters empty")
assert_true(filter.has_filters({ { key = "j", label = "JS" } }), "has_filters with filters")
print("has_filters: ok")

-- Test: quick_filter_menu
local menu = filter.quick_filter_menu({ { key = "j", label = "JS" }, { key = "t", label = "TS" } })
assert_true(menu:find("j=JS", 1, true) ~= nil, "quick_filter_menu j=JS")
assert_true(menu:find("t=TS", 1, true) ~= nil, "quick_filter_menu t=TS")
print("quick_filter_menu: ok")

-- Test: items performance with large dataset
local large = {}
for i = 1, 200000 do
  large[i] = { label = string.format("src/domain/module_%03d/OwnAccountTransfersFeature%06d.jsx", i % 997, i) }
end

for _, q in ipairs({ "o", "ow", "own", "ownacct", "ownacct jsx", "zzzz" }) do
  local start = vim.uv.hrtime()
  local result_perf = filter.items(large, {}, q)
  local ms = (vim.uv.hrtime() - start) / 1e6
  assert_true(ms < 500, string.format("filter perf q=%s took %.2fms (>500ms)", q, ms))
  print(string.format("filter perf q=%s results=%d ms=%.2f: ok", q, #result_perf, ms))
end

-- Test: item_group
assert_eq(filter.item_group({ group = "Git" }, {}), "Git", "item_group from table")
assert_eq(filter.item_group({ label = "x" }, {}), nil, "item_group nil when missing")
print("item_group: ok")

print("ALL FILTER TESTS PASSED")

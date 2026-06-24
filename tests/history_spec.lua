package.loaded["picker.history"] = nil
local history = require("picker.history")

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

local scope = "picker_history_spec_" .. tostring(vim.loop.hrtime())
local h = history.new(scope)

assert_true(h:at_tip(), "starts at tip")

h:commit({ query = "alpha" })
local prev = h:back({ query = "live" })
assert_eq(prev.query, "alpha", "back returns previous query")

local forward = h:forward()
assert_eq(forward.query, "live", "forward restores staged query")

h:commit({ query = "second" })
h:commit({ query = "third" })
assert_eq(h:back({ query = "" }).query, "third", "back from tip records live query")
assert_eq(h:back({ query = "" }).query, "second", "back again")

local restored = h:forward()
assert_eq(restored.query, "third", "forward restores newer history")

print("history: ok")

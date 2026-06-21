local proc = require("picker.proc")

local function assert_true(v, msg)
  if not v then
    error(msg or "assert_true failed")
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then
    error(string.format("%s: expected %s, got %s", msg or "assert_eq", vim.inspect(b), vim.inspect(a)))
  end
end

-- Test: spawn returns a handle
local handle = proc.spawn({
  cmd = "echo",
  args = { "hello" },
  on_items = function() end,
  on_done = function() end,
})
assert_true(handle ~= nil, "spawn returns handle")
assert_true(type(handle) == "table", "handle is table")
print("spawn returns handle: ok")

-- Wait for echo to finish
vim.wait(500, function() return handle.handle == nil end)

-- Test: abort sets aborted flag
local handle2 = proc.spawn({
  cmd = "sleep",
  args = { "10" },
  on_items = function() end,
  on_done = function() end,
})
proc.abort(handle2)
assert_true(handle2.aborted, "abort sets aborted")
print("abort sets aborted: ok")

-- Test: abort nil is safe
proc.abort(nil)
print("abort nil: ok")

-- Test: spawn with transform
local done_items = nil
local handle3 = proc.spawn({
  cmd = "printf",
  args = { "one\\ntwo\\nthree\\n" },
  transform = function(line)
    return { label = line:upper() }
  end,
  on_items = function(items)
    done_items = items
  end,
  on_done = function() end,
})

vim.wait(1000, function() return done_items ~= nil end)
assert_true(done_items ~= nil, "transform items received")
assert_true(#done_items >= 1, "transform items count " .. #done_items)
-- Items should have uppercase labels
local found_upper = false
for _, item in ipairs(done_items) do
  if item.label == "ONE" or item.label == "TWO" or item.label == "THREE" then
    found_upper = true
  end
end
assert_true(found_upper, "transform uppercase applied")
print("spawn with transform: ok")

-- Test: spawn with limit
local limit_items = nil
local handle4 = proc.spawn({
  cmd = "seq",
  args = { "1", "10000" },
  limit = 100,
  on_items = function(items)
    limit_items = items
  end,
  on_done = function(items)
    limit_items = items
  end,
})

vim.wait(2000, function() return limit_items ~= nil end)
assert_true(limit_items ~= nil, "limit items received")
assert_true(#limit_items <= 100, "limit respected: " .. #limit_items)
print("spawn with limit: ok")

-- Test: spawn with invalid command
local err_done = false
proc.spawn({
  cmd = "nonexistent_cmd_xyz_789",
  args = {},
  on_items = function() end,
  on_done = function(items, code)
    err_done = true
  end,
})
vim.wait(500, function() return err_done end)
assert_true(err_done, "invalid command calls on_done")
print("spawn invalid command: ok")

print("All proc tests passed")

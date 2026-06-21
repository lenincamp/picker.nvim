local sources = require("picker.sources")

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

-- Test: grep returns a 2-arg function
local grep_fn = sources.grep()
assert_eq(type(grep_fn), "function", "grep returns function")
local info = debug.getinfo(grep_fn, "u")
assert_eq(info.nparams, 2, "grep function has 2 params (async form)")
print("grep function: ok")

-- Test: grep with short query returns empty
local short_result = nil
grep_fn({ query = "a" }, function(items)
  short_result = items
end)
vim.wait(200, function() return short_result ~= nil end)
assert_true(short_result ~= nil, "short query resolved")
assert_eq(#short_result, 0, "short query returns empty")
print("grep min_chars: ok")

-- Test: grep with empty query returns empty
local empty_result = nil
grep_fn({ query = "" }, function(items)
  empty_result = items
end)
vim.wait(200, function() return empty_result ~= nil end)
assert_eq(#empty_result, 0, "empty query returns empty")
print("grep empty query: ok")

-- Test: grep against this test file
local cwd = vim.fn.getcwd()
local grep_fn2 = sources.grep({ cwd = cwd, min_chars = 3 })
local test_items = nil
local handle = grep_fn2({ query = "assert_true" }, function(items)
  test_items = items
end)
vim.wait(3000, function() return test_items ~= nil and #test_items > 0 end)
assert_true(test_items ~= nil, "grep items received")
assert_true(#test_items > 0, "grep found matches: " .. #test_items)
-- Items should have label, path, lnum
local first = test_items[1]
assert_true(first.label ~= nil, "grep item has label")
assert_true(first.lnum ~= nil, "grep item has lnum")
print("grep live search: ok")

-- Test: grep strips wrapping quotes
local quoted_grep_items = nil
grep_fn2({ query = '"assert_true"' }, function(items)
  quoted_grep_items = items
end)
vim.wait(3000, function() return quoted_grep_items ~= nil and #quoted_grep_items > 0 end)
assert_true(quoted_grep_items ~= nil and #quoted_grep_items > 0, "grep quoted query finds matches")
print("grep quoted query: ok")

-- Test: grep quick_filter accepts glob lists
local grep_glob_items = nil
local grep_glob_ok = pcall(function()
  return grep_fn2({ query = "assert_true", quick_filter = { glob = { "*.lua" } } }, function(items)
    grep_glob_items = items
  end)
end)
assert_true(grep_glob_ok, "grep accepts quick_filter glob list")
vim.wait(3000, function() return grep_glob_items ~= nil end)
assert_true(grep_glob_items ~= nil, "grep glob list resolved")
print("grep quick_filter glob list: ok")

-- Test: files returns a 2-arg function
local files_fn = sources.files()
assert_eq(type(files_fn), "function", "files returns function")
local files_info = debug.getinfo(files_fn, "u")
assert_eq(files_info.nparams, 2, "files function has 2 params (async form)")
print("files function: ok")

-- Test: files lists files in cwd
if vim.fn.executable("fd") == 1 or vim.fn.executable("fdfind") == 1 then
  local files_fn2 = sources.files({ cwd = cwd })
  local file_items = nil
  files_fn2({ query = "" }, function(items)
    file_items = items
  end)
  vim.wait(3000, function() return file_items ~= nil and #file_items > 0 end)
  assert_true(file_items ~= nil, "files items received")
  assert_true(#file_items > 0, "files found items: " .. #file_items)
  local f = file_items[1]
  assert_true(f.label ~= nil, "files item has label")
  print("files live search: ok")

  local quoted_file_items = nil
  files_fn2({ query = '"sources"' }, function(items)
    quoted_file_items = items
  end)
  vim.wait(3000, function() return quoted_file_items ~= nil and #quoted_file_items > 0 end)
  assert_true(quoted_file_items ~= nil and #quoted_file_items > 0, "files quoted query finds matches")
  print("files quoted query: ok")

  local filtered_items = nil
  local files_glob_ok = pcall(function()
    return files_fn2({ query = "", quick_filter = { glob = { "*.lua" } } }, function(items)
      filtered_items = items
    end)
  end)
  assert_true(files_glob_ok, "files accepts quick_filter glob list")
  vim.wait(3000, function() return filtered_items ~= nil end)
  assert_true(filtered_items ~= nil, "files glob list resolved")
  print("files quick_filter glob list: ok")
else
  print("files live search: SKIPPED (fd not found)")
end

print("All sources tests passed")

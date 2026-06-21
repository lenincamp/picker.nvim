local grep_core = require("picker.grep.core")
local picker = require("picker")

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

local tmp = vim.fn.tempname()
vim.fn.writefile({ "hello world", "TODO fix this", "goodbye" }, tmp)

local items, query = grep_core.collect_file_items(tmp, "TODO", { regex = false })
assert_eq(query, "TODO", "collect_file_items query")
assert_eq(#items, 1, "collect_file_items count")
assert_eq(items[1].text, "TODO fix this", "collect_file_items text")
assert_true(items[1].lnum == 2, "collect_file_items line")

local items2 = grep_core.collect_file_items(tmp, "missing", { regex = false })
assert_eq(#items2, 0, "collect_file_items no match")

assert_true(type(picker.grep_buffer) == "function", "grep_buffer exported")

vim.fn.delete(tmp)
print("grep_buffer: ok")

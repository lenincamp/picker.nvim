local todo_core = require("picker.todos.core")
local todos = require("picker.builtins.todos")
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

local keywords = todo_core.keywords({})
assert_eq(#keywords, 8, "default keywords count")
assert_true(vim.tbl_contains(keywords, "TODO"), "includes TODO")

local urgent = todo_core.keywords({ urgent = true })
assert_eq(#urgent, 3, "urgent keywords count")

local pattern = todo_core.highlight_pattern()
assert_true(pattern:find("TODO", 1, true) ~= nil, "highlight pattern")
print("keywords: ok")

assert_true(type(todos.todos) == "function", "todos builtin")
assert_true(type(todos.todos_urgent) == "function", "todos_urgent builtin")
picker.setup({})
assert_true(type(picker.todos) == "function", "picker.todos exported")
assert_true(type(picker.todos_urgent) == "function", "picker.todos_urgent exported")
print("exports: ok")

if vim.fn.executable("rg") ~= 1 then
  print("todos collect: SKIPPED (rg not found)")
  print("todos: ok")
  return
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local file = tmp .. "/sample.lua"
vim.fn.writefile({ "-- TODO: fix this", "local ok = true" }, file)

local items = todo_core.collect_items(tmp)
assert_true(#items >= 1, "collect finds TODO")
assert_true(items[1].text:find("TODO", 1, true) ~= nil, "match text")

local urgent_items = todo_core.collect_items(tmp, urgent)
assert_true(#urgent_items >= 1, "urgent collect")

vim.fn.delete(tmp, "rf")
print("todos collect: ok")
print("todos: ok")

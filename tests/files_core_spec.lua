local files_core = require("picker.files.core")
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
local file_a = tmp .. "/src/a.lua"
local file_b = tmp .. "/src/b.txt"
vim.fn.mkdir(vim.fn.fnamemodify(file_a, ":p:h"), "p")
vim.fn.writefile({ "a" }, file_a)
vim.fn.writefile({ "b" }, file_b)

local items = files_core.collect_items(tmp)
assert_true(items ~= nil, "collect_items returns table")
assert_eq(#items, 2, "collects project files")

local paths = {}
for _, item in ipairs(items) do
  paths[item.label] = item.path
end
assert_true(paths["src/a.lua"] ~= nil, "includes lua file")
assert_eq(paths["src/a.lua"], vim.fs.normalize(file_a), "normalizes path")

local filtered = files_core.collect_items(tmp, { glob = "*.lua" })
assert_eq(#filtered, 1, "glob filter")
assert_eq(filtered[1].label, "src/a.lua", "glob keeps lua file")

local item = files_core.make_item(tmp, "src/a.lua")
assert_eq(item.path, vim.fs.normalize(file_a), "make_item path")

vim.fn.delete(tmp, "rf")

picker.setup({})
assert_true(type(picker.find_files) == "function", "find_files exported")
assert_true(type(picker.open_terminal) == "function", "open_terminal exported")

print("files/core: ok")

local grep_core = require("picker.grep.core")
local config = require("picker.config")

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

assert_eq(grep_core.normalize_query('"hello"'), "hello", "strips double quotes")
assert_eq(grep_core.normalize_query("'world'"), "world", "strips single quotes")
assert_eq(grep_core.normalize_query("  foo  "), "foo", "trims whitespace")
assert_eq(grep_core.normalize_query(nil), "", "nil becomes empty")
print("normalize_query: ok")

assert_eq(grep_core.fuzzy_pattern("ab"), "a.*b", "fuzzy pattern joins chars")
assert_eq(grep_core.fuzzy_pattern("a"), nil, "single char has no fuzzy pattern")
print("fuzzy_pattern: ok")

local score = grep_core.fuzzy_score("assert_true helper", "at")
assert_true(score ~= nil and score > 0, "fuzzy_score matches subsequence")
assert_eq(grep_core.fuzzy_score("xyz", "abc"), nil, "fuzzy_score nil when no match")
print("fuzzy_score: ok")

config.apply({})
local args = grep_core.rg_args({ hidden = true, ignored = true, glob = "*.lua" }, "needle", true)
assert_true(vim.tbl_contains(args, "--hidden"), "rg_args hidden")
assert_true(vim.tbl_contains(args, "--no-ignore"), "rg_args ignored")
assert_true(vim.tbl_contains(args, "-F"), "rg_args fixed strings")
assert_true(vim.tbl_contains(args, "needle"), "rg_args pattern")
assert_true(vim.tbl_contains(args, "!.git"), "rg_args excludes git")
local word_args = grep_core.rg_args({ word = true }, "needle", true)
assert_true(vim.tbl_contains(word_args, "-w"), "rg_args word")
assert_true(vim.tbl_contains(word_args, "-F"), "rg_args word fixed")
local has_lua_glob = false
for _, arg in ipairs(args) do
  if arg == "*.lua" then
    has_lua_glob = true
  end
end
assert_true(has_lua_glob, "rg_args includes glob")
print("rg_args: ok")

local item = grep_core.make_item("/tmp/proj", "src/a.lua", 12, 3, "local x = 1", "x")
assert_eq(item.filename, "/tmp/proj/src/a.lua", "make_item filename")
assert_eq(item.lnum, 12, "make_item lnum")
assert_eq(item.col, 3, "make_item col")
assert_eq(item.text, "local x = 1", "make_item text")
assert_eq(item.label, "src/a.lua:12:3  local x = 1", "make_item cheap label uses relative file")
print("make_item label: ok")

print("grep/core: ok")

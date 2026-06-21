local recent = require("picker.builtins.recent")
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
local file_a = tmp .. "/project/a.txt"
local file_b = tmp .. "/other/b.txt"
vim.fn.mkdir(vim.fn.fnamemodify(file_a, ":p:h"), "p")
vim.fn.mkdir(vim.fn.fnamemodify(file_b, ":p:h"), "p")
vim.fn.writefile({ "a" }, file_a)
vim.fn.writefile({ "b" }, file_b)

local old_oldfiles = vim.v.oldfiles
vim.v.oldfiles = { file_a, file_b }

local global_items = recent.collect_items({ global = true })
assert_true(#global_items >= 2, "global collects readable oldfiles")

local cwd_items, cwd = recent.collect_items({ cwd = tmp .. "/project" })
assert_eq(cwd, vim.fs.normalize(tmp .. "/project"), "cwd normalized")
assert_true(#cwd_items >= 1, "cwd filters to project files")
for _, item in ipairs(cwd_items) do
  assert_true(item.path:find("/project/", 1, true) ~= nil, "item under project cwd")
end

vim.v.oldfiles = old_oldfiles
vim.fn.delete(tmp, "rf")

picker.setup({})
assert_true(type(picker.recent_files) == "function", "recent_files exported")

print("builtins/recent: ok")

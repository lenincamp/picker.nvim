local git_status = require("picker.git.status")
local git_core = require("picker.git.core")
local config = require("picker.config")
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

assert_true(type(git_status.collect_status_grep_items) == "function", "collect_status_grep_items")
assert_true(type(picker.git_status_grep) == "function", "git_status_grep exported")
assert_true(type(picker.git_line_history) == "function", "git_line_history exported")

if vim.fn.executable("git") ~= 1 or vim.fn.executable("rg") ~= 1 then
  print("git status integration: SKIPPED")
  print("git/status: ok")
  return
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local repo = tmp .. "/repo"
vim.fn.mkdir(repo, "p")

local env = vim.tbl_extend("force", vim.fn.environ(), {
  GIT_AUTHOR_DATE = "2000-01-01T00:00:00",
  GIT_COMMITTER_DATE = "2000-01-01T00:00:00",
})

assert_true(vim.system({ "git", "init" }, { cwd = repo }):wait().code == 0, "git init")
vim.fn.writefile({ "findme here" }, repo .. "/tracked.txt")
vim.system({ "git", "add", "tracked.txt" }, { cwd = repo }):wait()
vim.system({ "git", "commit", "-m", "init", "--author", "test <test@test.com>" }, { cwd = repo, env = env }):wait()

local root = git_core.root(repo)
vim.fn.writefile({ "findme changed" }, repo .. "/tracked.txt")
vim.fn.writefile({ "findme new" }, repo .. "/new.txt")

local items, err = git_status.collect_status_grep_items(root, "findme")
assert_true(items ~= nil, "status grep items: " .. tostring(err))
assert_true(#items >= 2, "matches changed and untracked files")

config.apply({ git = { commands = true } })
picker.setup({ git = { commands = true } })
assert_true(vim.fn.exists(":GitStatusGrep") == 2, "GitStatusGrep command")
assert_true(vim.fn.exists(":GitLineHistory") == 2, "GitLineHistory command")
config.apply({})

vim.fn.delete(tmp, "rf")
print("git status integration: ok")
print("git/status: ok")

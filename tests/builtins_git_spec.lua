local git = require("picker.builtins.git")
local git_core = require("picker.git.core")
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

assert_true(type(git.git_files) == "function", "git_files exported from builtins")
assert_true(type(git.git_log) == "function", "git_log exported from builtins")
assert_true(type(git.git_blame_line) == "function", "git_blame_line exported from builtins")
assert_true(type(git.git_file_history) == "function", "git_file_history exported from builtins")

picker.setup({})
assert_true(type(picker.git_files) == "function", "git_files exported from picker")
assert_true(type(picker.git_log) == "function", "git_log exported from picker")
assert_true(type(picker.git_blame_line) == "function", "git_blame_line exported from picker")
assert_true(type(picker.git_file_history) == "function", "git_file_history exported from picker")
assert_true(type(picker.git_browse) == "function", "git_browse exported from picker")
assert_true(type(picker.lazygit) == "function", "lazygit exported from picker")

if vim.fn.executable("git") ~= 1 then
  print("git_files collect: SKIPPED (git not found)")
  print("builtins/git: ok")
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
vim.fn.writefile({ "tracked" }, repo .. "/a.txt")
vim.fn.writefile({ "other" }, repo .. "/b.txt")
vim.system({ "git", "add", "a.txt" }, { cwd = repo }):wait()
vim.system({ "git", "commit", "-m", "init", "--author", "test <test@test.com>" }, { cwd = repo, env = env }):wait()

local root = git_core.root(repo)
local lines = git_core.ls_files(root)
assert_eq(#lines, 1, "ls_files one tracked file")
assert_eq(lines[1], "a.txt", "tracked path")

local item = git_core.make_file_item(root, lines[1])
assert_true(item.path:find("/a.txt", 1, true) ~= nil, "file item path")

vim.fn.delete(tmp, "rf")
print("git_files collect: ok")
print("builtins/git: ok")

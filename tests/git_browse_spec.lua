local browse = require("picker.git.browse")
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

assert_true(type(picker.git_browse) == "function", "git_browse exported")

if vim.fn.executable("git") ~= 1 then
  print("git browse integration: SKIPPED (git not found)")
  print("git/browse: ok")
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
vim.system({ "git", "remote", "add", "origin", "git@github.com:owner/repo.git" }, { cwd = repo }):wait()
vim.fn.mkdir(repo .. "/src", "p")
vim.fn.writefile({ "hello" }, repo .. "/src/a.lua")
vim.system({ "git", "add", "src/a.lua" }, { cwd = repo }):wait()
vim.system({ "git", "commit", "-m", "init", "--author", "test <test@test.com>" }, { cwd = repo, env = env }):wait()
vim.system({ "git", "branch", "-M", "main" }, { cwd = repo }):wait()

local root = git_core.root(repo)
local file = root .. "/src/a.lua"
local url, err = browse.github_url(file, 10, 10, { root = root })
assert_true(url ~= nil, "github_url: " .. tostring(err))
assert_eq(url, "https://github.com/owner/repo/blob/main/src/a.lua#L10", "github ssh remote url")

local https_url = browse.github_url(file, 3, 5, {
  root = root,
})
vim.system({ "git", "remote", "set-url", "origin", "https://github.com/acme/demo.git" }, { cwd = repo }):wait()
https_url = browse.github_url(file, 3, 5, { root = root })
assert_eq(https_url, "https://github.com/acme/demo/blob/main/src/a.lua#L3-L5", "https remote range")

config.apply({
  git = {
    browse_url = function(path, line1, line2)
      return "custom://" .. vim.fn.fnamemodify(path, ":t") .. ":" .. line1
    end,
  },
})
local custom = browse.resolve_url(file, 7, 7)
assert_eq(custom, "custom://a.lua:7", "custom browse_url hook")
config.apply({})

vim.fn.delete(tmp, "rf")
print("git browse integration: ok")
print("git/browse: ok")

local git_core = require("picker.git.core")
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

local function normalize_path(path)
  if path and vim.uv.fs_realpath then
    local ok, real = pcall(vim.uv.fs_realpath, path)
    if ok and real then
      return vim.fs.normalize(real)
    end
  end
  return vim.fs.normalize(path)
end

local item = git_core.make_file_item("/repo", "src/a.lua")
assert_eq(item.label, "src/a.lua", "make_file_item label")
assert_eq(item.path, vim.fs.normalize("/repo/src/a.lua"), "make_file_item path")
print("make_file_item: ok")

assert_eq(git_core.relpath("/repo", "/repo/src/a.lua"), "src/a.lua", "relpath")
print("relpath: ok")

config.apply({ git = { max_log_count = 42 } })
assert_eq(git_core.max_log_count(), 42, "max_log_count from config")
config.apply({})
assert_eq(git_core.max_log_count(), 300, "max_log_count default")
print("max_log_count: ok")

if vim.fn.executable("git") ~= 1 then
  print("git integration: SKIPPED (git not found)")
  print("git/core: ok")
  return
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local repo = tmp .. "/repo"
vim.fn.mkdir(repo, "p")

local init = vim.system({ "git", "init" }, { cwd = repo, text = true }):wait()
assert_true(init and init.code == 0, "git init")

local tracked = repo .. "/tracked.txt"
vim.fn.writefile({ "hello" }, tracked)
vim.system({ "git", "add", "tracked.txt" }, { cwd = repo }):wait()
vim.system({ "git", "commit", "-m", "init", "--author", "test <test@test.com>" }, {
  cwd = repo,
  env = vim.tbl_extend("force", vim.fn.environ(), {
    GIT_AUTHOR_DATE = "2000-01-01T00:00:00",
    GIT_COMMITTER_DATE = "2000-01-01T00:00:00",
  }),
}):wait()

local root = git_core.root(repo)
assert_eq(root, normalize_path(repo), "root resolves repo")

local files = git_core.ls_files(root)
assert_true(files ~= nil, "ls_files returns table")
assert_eq(#files, 1, "ls_files one tracked file")
assert_eq(files[1], "tracked.txt", "ls_files path")

local untracked = repo .. "/new.txt"
vim.fn.writefile({ "new" }, untracked)
local changed = git_core.changed_files(root)
assert_true(vim.tbl_contains(changed, "new.txt"), "changed_files includes untracked")

vim.fn.writefile({ "changed" }, tracked)
local changed2 = git_core.changed_files(root)
assert_true(vim.tbl_contains(changed2, "tracked.txt"), "changed_files includes modified")
assert_true(vim.tbl_contains(changed2, "new.txt"), "changed_files still includes untracked")

vim.fn.delete(tmp, "rf")
print("git integration: ok")
print("git/core: ok")

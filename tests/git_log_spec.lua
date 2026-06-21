local git_log = require("picker.git.log")
local git_core = require("picker.git.core")

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

local line = "abc123def4567890123456789012345678901234\x1fabc123d\x1f2024-01-02\x1fAuthor Name\x1fFix bug"
local item = git_log.parse_commit_line(line)
assert_true(item ~= nil, "parse_commit_line returns item")
assert_eq(item.hash, "abc123def4567890123456789012345678901234", "hash")
assert_eq(item.short_hash, "abc123d", "short_hash")
assert_eq(item.date, "2024-01-02", "date")
assert_eq(item.author, "Author Name", "author")
assert_eq(item.subject, "Fix bug", "subject")
assert_eq(item.label, "abc123d  2024-01-02  Author Name  Fix bug", "label")
assert_eq(git_log.parse_commit_line("invalid"), nil, "invalid line")
print("parse_commit_line: ok")

if vim.fn.executable("git") ~= 1 then
  print("git log integration: SKIPPED (git not found)")
  print("git/log: ok")
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
local tracked = repo .. "/tracked.txt"
vim.fn.writefile({ "hello" }, tracked)
vim.system({ "git", "add", "tracked.txt" }, { cwd = repo }):wait()
vim.system({ "git", "commit", "-m", "init commit", "--author", "test <test@test.com>" }, {
  cwd = repo,
  env = env,
}):wait()

local root = git_core.root(repo)
assert_true(root ~= nil, "repo root")

local items, err = git_log.commit_items(root, { "--max-count=5" })
assert_true(items ~= nil, "commit_items: " .. tostring(err))
assert_eq(#items, 1, "one commit")
assert_eq(items[1].subject, "init commit", "commit subject")

local result_lines = { git_log.show_commit(root, items[1].hash, nil, 120) }
assert_true(type(result_lines[1]) == "table" and #result_lines[1] > 0, "show_commit returns lines")
local output = table.concat(result_lines[1], "\n")
assert_true(
  output:find("init commit", 1, true) ~= nil or output:find(items[1].short_hash, 1, true) ~= nil,
  "show_commit contains commit info"
)

vim.fn.delete(tmp, "rf")
print("git log integration: ok")
print("git/log: ok")

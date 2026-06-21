local git_core = require("picker.git.core")
local config = require("picker.config")

local M = {}

function M.github_url(file_path, line1, line2, ctx)
  ctx = ctx or {}
  local root = ctx.root or git_core.root(vim.fn.getcwd())
  if not root then
    return nil, "Not inside a git repository"
  end

  local remotes, remote_code = git_core.run({ "git", "-C", root, "remote", "get-url", "origin" })
  if remote_code ~= 0 or not remotes[1] then
    return nil, "No origin remote"
  end

  local branch_lines, branch_code = git_core.run({ "git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD" })
  local branch = branch_code == 0 and branch_lines[1] or "HEAD"
  local remote = remotes[1]:gsub("%.git$", "")
  local host, owner, repo = remote:match("git@([^:]+):([^/]+)/(.+)$")
  if not host then
    host, owner, repo = remote:match("https?://([^/]+)/([^/]+)/(.+)$")
  end
  if not host or not owner or not repo then
    return nil, "Unsupported git remote: " .. remote
  end

  local rel = vim.fs.relpath(root, file_path)
  if not rel then
    return nil, "File is outside git root"
  end

  local line_suffix = ""
  if line1 and line1 > 0 then
    line_suffix = "#L" .. line1
    if line2 and line2 > line1 then
      line_suffix = line_suffix .. "-L" .. line2
    end
  end

  return string.format("https://%s/%s/%s/blob/%s/%s%s", host, owner, repo, branch, rel, line_suffix)
end

function M.resolve_url(file_path, line1, line2)
  local root = git_core.root(vim.fn.getcwd())
  local ctx = {
    root = root,
    cwd = vim.fn.getcwd(),
  }

  local custom = (config.current.git or {}).browse_url
  if type(custom) == "function" then
    local ok, url, err = pcall(custom, file_path, line1, line2, ctx)
    if not ok then
      return nil, url
    end
    if url then
      return url
    end
    if err then
      return nil, err
    end
  end

  return M.github_url(file_path, line1, line2, ctx)
end

return M

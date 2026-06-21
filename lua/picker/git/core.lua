local config = require("picker.config")

local M = {}

local function normalize_path(path)
  if path and vim.uv.fs_realpath then
    local ok, real = pcall(vim.uv.fs_realpath, path)
    if ok and real then
      return vim.fs.normalize(real)
    end
  end
  return vim.fs.normalize(path)
end

function M.run(command, opts)
  opts = opts or {}
  local result = vim.system(command, { cwd = opts.cwd, text = true }):wait()
  local stdout = result and result.stdout or ""
  local stderr = result and result.stderr or ""
  local lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
  return lines, result and result.code or 1, stderr
end

function M.root(cwd)
  cwd = cwd or vim.fn.getcwd()
  local lines, code = M.run({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
  if code ~= 0 or not lines[1] then
    return nil
  end
  return normalize_path(lines[1])
end

function M.relpath(root, path)
  return vim.fs.relpath(root, path) or path
end

function M.make_file_item(root, path)
  root = normalize_path(root)
  return {
    label = path,
    path = normalize_path(root .. "/" .. path),
  }
end

function M.ls_files(root)
  local lines, code = M.run({ "git", "-C", root, "ls-files" })
  if code ~= 0 then
    return nil, "git ls-files failed"
  end
  return lines
end

function M.changed_files(root)
  local changed, changed_code = M.run({
    "git", "-C", root,
    "diff", "--name-only", "--diff-filter=ACMRTUXB", "HEAD",
  })
  local untracked, untracked_code = M.run({
    "git", "-C", root,
    "ls-files", "--others", "--exclude-standard",
  })

  local files = {}
  if changed_code == 0 then
    vim.list_extend(files, changed)
  end
  if untracked_code == 0 then
    vim.list_extend(files, untracked)
  end

  return files
end

function M.max_log_count()
  return (config.current.git or {}).max_log_count or 300
end

return M

local git_core = require("picker.git.core")
local git_log = require("picker.git.log")
local util = require("picker.util")

local M = {}

local function open_item(item)
  if item then
    util.open_file(item.path)
  end
end

local function require_root(cwd)
  local root = git_core.root(cwd or vim.fn.getcwd())
  if not root then
    util.notify("Not inside a git repository", vim.log.levels.WARN)
  end
  return root
end

local function require_file_buffer(message)
  if vim.bo.buftype ~= "" then
    util.notify(message, vim.log.levels.WARN)
    return nil
  end
  local file = vim.fn.expand("%:p")
  if file == "" then
    return nil
  end
  return file
end

function M.git_files(opts)
  opts = opts or {}
  if opts.title and not opts.prompt then
    opts.prompt = opts.title
  end

  local cwd = opts.cwd or vim.fn.getcwd()
  local root = git_core.root(cwd)
  if not root then
    util.notify("Not inside a git repository", vim.log.levels.WARN)
    return
  end

  local lines, err = git_core.ls_files(root)
  if not lines then
    util.notify(err or "git ls-files failed", vim.log.levels.WARN)
    return
  end

  local items = vim.tbl_map(function(path)
    return git_core.make_file_item(root, path)
  end, lines)

  local picker = require("picker")
  picker.select_items(items, {
    prompt = opts.prompt or "Git files",
    scope = "project",
    query = opts.query,
    input_mode = opts.input_mode ~= false,
    search_threshold = 0,
    filters = opts.filters or util.filters(),
    preview = function(item)
      return item.path
    end,
    format_item = function(item)
      return item.label
    end,
  }, open_item)
end

function M.git_log(cwd)
  local root = require_root(cwd)
  if not root then
    return
  end

  git_log.select_commits({
    root = root,
    log_args = { "--all", "--max-count=" .. git_core.max_log_count() },
    title = "Git log: " .. vim.fn.fnamemodify(root, ":t"),
  })
end

function M.git_blame_line()
  local file = require_file_buffer("Git blame needs a file buffer")
  if not file then
    return
  end

  local root = require_root(vim.fs.dirname(file))
  if not root then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local rel = git_core.relpath(root, file)
  local lines, code, stderr = git_core.run({ "git", "-C", root, "blame", "-L", line .. "," .. line, "--", rel })
  if code ~= 0 then
    util.notify(vim.trim(stderr) ~= "" and vim.trim(stderr) or "git blame failed", vim.log.levels.WARN)
    return
  end

  local hash = lines[1] and lines[1]:match("^(%x+)") or nil
  if not hash then
    util.notify("No blame commit found for current line", vim.log.levels.WARN)
    return
  end

  git_log.select_commits({
    root = root,
    path = file,
    log_args = { "--max-count=1", hash },
    title = "Git blame line: " .. vim.fn.fnamemodify(file, ":~:.") .. ":" .. line,
  })
end

function M.git_file_history()
  local file = require_file_buffer("Git file history needs a file buffer")
  if not file then
    return
  end

  local root = require_root(vim.fs.dirname(file))
  if not root then
    return
  end

  git_log.select_commits({
    root = root,
    path = file,
    log_args = {
      "--follow",
      "--max-count=" .. git_core.max_log_count(),
      "--",
      git_core.relpath(root, file),
    },
    title = "Git file history: " .. vim.fn.fnamemodify(file, ":~:."),
  })
end

local function selection_lines()
  local line1 = vim.fn.line("v")
  local line2 = vim.fn.line(".")
  if vim.fn.mode() == "n" then
    line1 = vim.api.nvim_win_get_cursor(0)[1]
    line2 = line1
  elseif line1 > line2 then
    line1, line2 = line2, line1
  end
  return line1, line2
end

function M.git_browse(copy_only)
  local file = vim.fn.expand("%:p")
  if file == "" then
    util.notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  local line1, line2 = selection_lines()
  local url, err = require("picker.git.browse").resolve_url(file, line1, line2)
  if not url then
    util.notify(err or "Could not build browse URL", vim.log.levels.WARN)
    return
  end

  if copy_only then
    vim.fn.setreg("+", url)
    util.notify("Copied: " .. url)
    return
  end

  vim.ui.open(url)
end

function M.lazygit(cwd)
  require("picker.git.lazygit").open(cwd)
end

function M.git_status_grep(text)
  require("picker.git.status").git_status_grep(text)
end

function M.git_line_history(line1, line2)
  require("picker.git.status").git_line_history(line1, line2)
end

return M

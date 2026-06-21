local git_core = require("picker.git.core")
local util = require("picker.util")

local M = {}

local function preview()
  return require("preview")
end

function M.parse_commit_line(line)
  local hash, short_hash, date, author, subject = line:match(
    "^([^\31]+)\31([^\31]+)\31([^\31]+)\31([^\31]+)\31(.*)$"
  )
  if not hash then
    return nil
  end
  return {
    hash = hash,
    short_hash = short_hash,
    date = date,
    author = author,
    subject = subject,
    label = string.format("%s  %s  %s  %s", short_hash, date, author, subject),
  }
end

function M.commit_items(root, log_args)
  local command = {
    "git", "-C", root,
    "log",
    "--date=short",
    "--format=%H%x1f%h%x1f%ad%x1f%an%x1f%s",
  }
  vim.list_extend(command, log_args or {})

  local lines, code, stderr = git_core.run(command)
  if code ~= 0 then
    return nil, vim.trim(stderr) ~= "" and vim.trim(stderr) or "git log failed"
  end

  local items = {}
  for _, line in ipairs(lines) do
    local item = M.parse_commit_line(line)
    if item then
      items[#items + 1] = item
    end
  end
  return items
end

function M.show_commit(root, hash, path, render_width)
  local command = {
    "git", "-C", root,
    "show",
    "--stat",
    "--patch",
    "--find-renames",
    "--color=never",
    "--format=fuller",
    hash,
  }
  if path then
    vim.list_extend(command, { "--", git_core.relpath(root, path) })
  end

  local lines, code, stderr = git_core.run(command)
  if code ~= 0 then
    return { vim.trim(stderr) ~= "" and vim.trim(stderr) or "git show failed" }
  end
  if #lines == 0 then
    return { "No changes for this selection" }
  end

  if vim.fn.executable("delta") ~= 1 then
    return lines, nil, "diff"
  end

  local delta_command = { "delta", "--paging=never" }
  if tonumber(render_width) and tonumber(render_width) > 20 then
    vim.list_extend(delta_command, { "--width", tostring(math.floor(render_width)) })
  end

  local delta = vim.system(delta_command, {
    text = true,
    stdin = table.concat(lines, "\n") .. "\n",
  }):wait()
  if delta and delta.code == 0 and delta.stdout and delta.stdout ~= "" then
    local rendered, highlights = preview().ansi_to_lines(delta.stdout)
    return rendered, highlights, nil
  end

  return lines, nil, "diff"
end

function M.select_commits(opts)
  opts = opts or {}
  local root = opts.root
  if not root then
    util.notify("Git root is required", vim.log.levels.WARN)
    return
  end

  local items, err = M.commit_items(root, opts.log_args)
  if not items then
    util.notify(err, vim.log.levels.WARN)
    return
  end

  local picker = require("picker")
  picker.select_items(items, {
    prompt = opts.title or "Git log",
    scope = "project",
    search_threshold = 0,
    preview_open = true,
    auto_select_single = false,
    preview_lines = function(item, render_width)
      local lines, highlights, syntax = M.show_commit(root, item.hash, opts.path, render_width)
      return { lines = lines, highlights = highlights, syntax = syntax }
    end,
    format_item = function(item)
      return item.label
    end,
    quickfix_item = function(item)
      return { text = item.label, filename = opts.path or root, lnum = 1, col = 1 }
    end,
  }, function(item)
    if not item then
      return
    end
    local lines, highlights, syntax = M.show_commit(root, item.hash, opts.path, math.max(80, vim.o.columns))
    preview().open_output_buffer({
      name = "picker://git-show/" .. item.hash .. (opts.path and (":" .. opts.path) or ""),
      lines = lines,
      highlights = highlights,
      height = 22,
      syntax = syntax or "diff",
    })
  end)
end

return M

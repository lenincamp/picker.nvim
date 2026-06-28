local config = require("picker.config")
local git_core = require("picker.git.core")
local grep_core = require("picker.grep.core")
local util = require("picker.util")

local M = {}

local commands_ready = false

local function open_grep_item(item)
  local path = item.filename or item.path
  if not path then
    return
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  if item.lnum then
    vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
  end
end

local function format_grep_item(item)
  return string.format(
    "%s:%d:%d  %s",
    vim.fn.fnamemodify(item.filename or item.path or "", ":~:."),
    item.lnum or 0,
    item.col or 0,
    item.text or ""
  )
end

function M.collect_status_grep_items(root, text)
  text = vim.trim(text or "")
  if text == "" then
    return nil, "empty query"
  end

  local files = git_core.changed_files(root)
  if #files == 0 then
    return nil, "no changed files"
  end

  local command = { "rg", "--vimgrep", "--smart-case", "--hidden", "-F", "--", text }
  vim.list_extend(command, files)

  local lines, code, stderr = git_core.run(command, { cwd = root })
  if code ~= 0 and #lines == 0 then
    return nil, vim.trim(stderr) ~= "" and vim.trim(stderr) or "no matches"
  end

  local items = {}
  grep_core.parse_vimgrep_lines(root, lines, items, text)
  if #items == 0 then
    return nil, "no matches"
  end
  return items
end

function M.git_status_grep(text)
  text = vim.trim(text or "")
  if text == "" then
    vim.ui.input({ prompt = "SearchText > ", scope = "project" }, function(input)
      M.git_status_grep(input)
    end)
    return
  end

  local root = git_core.root()
  if not root then
    util.notify("Not inside a git repository", vim.log.levels.WARN)
    return
  end

  local items, err = M.collect_status_grep_items(root, text)
  if not items then
    local level = err == "no changed files" and vim.log.levels.INFO or vim.log.levels.INFO
    util.notify(
      err == "no changed files" and "No staged or unstaged git files with content"
        or err == "no matches" and "No text matches found"
        or err,
      level
    )
    return
  end

  vim.fn.setqflist({}, " ", { title = "Git status grep: " .. text, items = items })

  require("picker").select_items(items, {
    prompt = "Git status grep: " .. text,
    scope = "project",
    search_threshold = 0,
    preview_open = true,
    preview = function(item)
      return item.filename or item.path
    end,
    preview_lnum = function(item)
      return item.lnum
    end,
    preview_match = function(item)
      return { lnum = item.lnum, col = item.col, length = #text }
    end,
    format_item = format_grep_item,
  }, open_grep_item)
end

function M.git_line_history(line1, line2)
  if vim.bo.buftype ~= "" then
    util.notify("Git line history needs a file buffer", vim.log.levels.WARN)
    return
  end

  local file = vim.fn.expand("%:p")
  if file == "" then
    util.notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  line1 = line1 or vim.api.nvim_win_get_cursor(0)[1]
  line2 = line2 or line1
  local spec = string.format("%d,%d:%s", line1, line2, file)
  local lines, code, stderr = git_core.run({
    "git", "--no-pager", "log", "--no-color", "-p", "-L", spec,
  })
  if code ~= 0 then
    util.notify(
      #lines > 0 and table.concat(lines, "\n") or vim.trim(stderr) ~= "" and vim.trim(stderr) or "git line history failed",
      vim.log.levels.WARN
    )
    return
  end

  local ok, preview = pcall(require, "preview")
  if ok then
    preview.open_output_buffer({
      name = "picker://git-line-history/" .. spec,
      lines = lines,
      height = 20,
      syntax = "diff",
    })
    return
  end

  vim.cmd("botright 20new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "diff"
  vim.bo[buf].modifiable = false
end

function M.setup_commands()
  if commands_ready or not (config.current.git or {}).commands then
    return
  end
  commands_ready = true

  vim.api.nvim_create_user_command("GitStatusGrep", function(opts)
    if opts.args ~= "" then
      M.git_status_grep(opts.args)
      return
    end
    M.git_status_grep("")
  end, {
    nargs = "*",
    desc = "Grep in git changed files",
  })

  vim.api.nvim_create_user_command("GitLineHistory", function(opts)
    M.git_line_history(opts.line1, opts.line2)
  end, {
    range = true,
    desc = "Git line history",
  })
end

return M

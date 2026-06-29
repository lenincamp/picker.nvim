local todo_core = require("picker.todos.core")
local util = require("picker.util")

local M = {}

local function open_item(item)
  local path = item.filename or item.path
  if not path then
    return
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  if item.lnum then
    vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
  end
end

local function format_item(item)
  return string.format(
    "%s:%d:%d  %s",
    vim.fn.fnamemodify(item.filename or item.path or "", ":~:."),
    item.lnum or 0,
    item.col or 0,
    item.text or ""
  )
end

function M.todos(opts)
  opts = opts or {}
  if opts.title and not opts.prompt then
    opts.prompt = opts.title
  end

  local urgent = opts.urgent == true
  local keywords = todo_core.keywords({ urgent = urgent, keywords = opts.keywords })
  local cwd = opts.cwd or util.root() or vim.fn.getcwd()
  local title = opts.prompt or opts.title or (urgent and "TODO/FIX/FIXME comments" or "TODO comments")

  local items = todo_core.collect_items(cwd, keywords)
  if #items == 0 then
    util.notify(title .. ": no results", vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, " ", { title = title, items = items })

  require("picker").select_items(items, {
    prompt = title,
    scope = "project",
    search_threshold = 0,
    preview = function(item)
      return item.filename or item.path
    end,
    preview_lnum = function(item)
      return item.lnum
    end,
    format_item = format_item,
  }, open_item)
end

function M.todos_urgent(opts)
  return M.todos(vim.tbl_extend("force", opts or {}, { urgent = true }))
end

return M

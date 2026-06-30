local util = require("picker.util")

local M = {}

function M.collect_items(opts)
  opts = opts or {}
  local cwd = not opts.global and vim.fs.normalize(opts.cwd or vim.fn.getcwd()) or nil
  local items = {}

  for _, path in ipairs(vim.v.oldfiles or {}) do
    local normalized = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
    local in_cwd = not cwd or normalized == cwd or normalized:sub(1, #cwd + 1) == (cwd .. "/")
    if vim.fn.filereadable(normalized) == 1 and in_cwd then
      items[#items + 1] = {
        label = cwd and vim.fn.fnamemodify(normalized, ":.") or vim.fn.fnamemodify(normalized, ":~:."),
        path = normalized,
      }
    end
  end

  return items, cwd
end

function M.recent_files(opts)
  opts = vim.tbl_extend("force", {
    prompt = "Recent files",
    input_mode = true,
  }, opts or {})

  if opts.title and not opts.prompt then
    opts.prompt = opts.title
  end

  local items, cwd = M.collect_items(opts)

  require("picker").select_items(items, {
    prompt = opts.prompt,
    scope = cwd and "project" or "global",
    search_threshold = 0,
    query = opts.query,
    input_mode = opts.input_mode,
    layout = opts.layout,
    filters = opts.filters or util.filters(),
    preview = function(item)
      return item.path
    end,
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if item then
      util.open_file(item.path)
    end
  end)
end

return M

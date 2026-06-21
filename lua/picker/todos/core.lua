local config = require("picker.config")
local grep_core = require("picker.grep.core")

local M = {}

function M.keywords(opts)
  opts = opts or {}
  local cfg = config.current.todos or {}
  if opts.urgent then
    return opts.keywords or cfg.urgent_keywords or M.defaults.urgent_keywords
  end
  return opts.keywords or cfg.keywords or M.defaults.keywords
end

function M.rg_pattern(keywords)
  return table.concat(keywords, "|")
end

function M.highlight_pattern(keywords)
  keywords = keywords or M.keywords({})
  return [[\v<(]] .. table.concat(keywords, "|") .. [[)>]]
end

function M.collect_items(cwd, keywords)
  cwd = cwd or vim.fn.getcwd()
  keywords = keywords or M.keywords({})
  local pattern = M.rg_pattern(keywords)
  local command = {
    "rg", "--vimgrep", "--hidden",
    "--glob", "!.git",
    "--glob", "!nvim.log",
    pattern,
  }

  local result = vim.system(command, { cwd = cwd, text = true }):wait()
  local stdout = result and result.stdout or ""
  local lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
  if (result and result.code or 1) ~= 0 and #lines == 0 then
    return {}
  end

  local items = {}
  grep_core.parse_vimgrep_lines(cwd, lines, items, pattern)
  return items
end

M.defaults = {
  keywords = { "TODO", "FIX", "FIXME", "HACK", "WARN", "PERF", "NOTE", "TEST" },
  urgent_keywords = { "TODO", "FIX", "FIXME" },
}

return M

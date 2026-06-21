local M = {}

local picker_proc = require("picker.proc")
local grep_core = require("picker.grep.core")
local util = require("picker.util")

local function glob_values(glob)
  if type(glob) == "string" then
    return { glob }
  end
  if type(glob) ~= "table" then
    return {}
  end
  return glob
end

local function normalize_query(query)
  query = vim.trim(tostring(query or ""))
  local first = query:sub(1, 1)
  local last = query:sub(-1)
  if #query >= 2 and (first == '"' or first == "'") and first == last then
    query = query:sub(2, -2)
  end
  return vim.trim(query)
end

--- Default ripgrep arguments for grep search.
local function rg_base_args()
  return {
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--smart-case",
    "--max-columns=500",
    "--max-columns-preview",
  }
end

--- Parse a ripgrep output line into a picker item.
--- Format: file:lnum:col:text
--- @param line string
--- @return table|nil
local function parse_rg_line(line)
  -- rg with --column outputs: file:lnum:col:text
  -- Use anchored pattern to find lnum:col: after the last path-like separator
  local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
  if not file or file == "" then return nil end
  lnum = tonumber(lnum)
  col = tonumber(col)
  if not lnum then return nil end
  local short = file
  local cwd = vim.uv.cwd() or ""
  if cwd ~= "" and file:sub(1, #cwd + 1) == cwd .. "/" then
    short = file:sub(#cwd + 2)
  end
  -- Also strip leading ./ from relative paths
  if short:sub(1, 2) == "./" then
    short = short:sub(3)
  end
  return {
    label = short .. ":" .. lnum .. ":" .. (text or ""),
    path = file,
    filename = file,
    lnum = lnum,
    col = col or 1,
    text = text or "",
  }
end

--- Create a dynamic_items function for live grep.
---
--- Usage:
---   picker.select_items({}, {
---     prompt = "Grep",
---     input_mode = true,
---     dynamic_items = require("picker.sources").grep({ cwd = vim.uv.cwd() }),
---   }, on_choice)
---
--- @param source_opts table|nil
---   - cwd: string (working directory, default vim.uv.cwd())
---   - cmd: string (executable, default "rg")
---   - extra_args: string[] (additional rg args)
---   - limit: number (max results, default 5000)
---   - min_chars: number (min query length to trigger search, default 2)
---   - glob: string|nil (file glob filter, e.g. "*.lua")
--- @return function(state, callback) -> handle
function M.grep(source_opts)
  source_opts = source_opts or {}
  local min_chars = source_opts.min_chars or 3
  local dynamic = grep_core.dynamic_items(source_opts)

  --- @param state table { query: string }
  --- @param callback function(items)
  --- @return picker.ProcHandle|nil
  return function(state, callback)
    local query = grep_core.normalize_query(state.query)
    if #query < min_chars then
      callback({})
      return nil
    end
    return dynamic(state, callback)
  end
end

--- Default fd/find arguments for file search.
local function fd_base_args()
  return {
    "--color=never",
    "--type=f",
    "--strip-cwd-prefix",
  }
end

--- Create a dynamic_items function for file search.
---
--- Usage:
---   picker.select_items({}, {
---     prompt = "Files",
---     input_mode = true,
---     dynamic_items = require("picker.sources").files({ cwd = vim.uv.cwd() }),
---   }, on_choice)
---
--- @param source_opts table|nil
---   - cwd: string (working directory, default vim.uv.cwd())
---   - cmd: string (executable, default "fd" or "fdfind")
---   - extra_args: string[] (additional fd args)
---   - limit: number (max results, default 5000)
---   - hidden: boolean (include hidden files, default false)
--- @return function(state, callback) -> handle
function M.files(source_opts)
  source_opts = source_opts or {}
  local cmd = source_opts.cmd or (vim.fn.executable("fd") == 1 and "fd" or "fdfind")
  local cwd = source_opts.cwd
  local extra_args = source_opts.extra_args or {}
  local limit = source_opts.limit or 1000
  local hidden = source_opts.hidden == true or source_opts.all_files == true
  local ignored = source_opts.ignored == true or source_opts.all_files == true

  --- @param state table { query: string }
  --- @param callback function(items)
  --- @return picker.ProcHandle|nil
  return function(state, callback)
    local query = normalize_query(state.query)

    local args = fd_base_args()
    -- Limit results at the fd level to avoid flooding stdout
    args[#args + 1] = "--max-results=1000"
    if hidden or state.all_files then
      args[#args + 1] = "--hidden"
    end
    if ignored or state.all_files then
      args[#args + 1] = "--no-ignore"
    end
    for _, arg in ipairs(extra_args) do
      args[#args + 1] = arg
    end

    -- Apply quick_filter glob/extension
    if state.quick_filter and state.quick_filter.glob then
      for _, glob in ipairs(glob_values(state.quick_filter.glob)) do
        for ext in tostring(glob):gmatch("%*%.([%w_%-]+)") do
          args[#args + 1] = "--extension"
          args[#args + 1] = ext
        end
      end
    end

    if query ~= "" then
      args[#args + 1] = "--"
      args[#args + 1] = query
    end

    return picker_proc.spawn({
      cmd = cmd,
      args = args,
      cwd = cwd or vim.uv.cwd(),
      limit = limit,
      transform = function(line)
        if line == "" then return nil end
        return {
          label = line,
          path = line,
          filename = line,
        }
      end,
      on_items = callback,
    })
  end
end

return M

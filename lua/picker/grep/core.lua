local config = require("picker.config")
local util = require("picker.util")
local picker_proc = require("picker.proc")

local M = {}

function M.normalize_query(query)
  query = vim.trim(tostring(query or ""))
  local first = query:sub(1, 1)
  local last = query:sub(-1)
  if #query >= 2 and (first == '"' or first == "'") and first == last then
    query = query:sub(2, -2)
  end
  return vim.trim(query)
end

local function has_regex_syntax(query)
  for char in ("\\^$.*+?(){}|[]"):gmatch(".") do
    if query:find(char, 1, true) then
      return true
    end
  end
  return false
end

function M.fuzzy_pattern(query)
  local chars = {}
  for char in query:gmatch("%S") do
    chars[#chars + 1] = util.regex_escape(char)
  end
  return #chars > 1 and table.concat(chars, ".*") or nil
end

function M.fuzzy_score(text, query)
  local needle = query:gsub("%s+", ""):lower()
  if needle == "" then
    return nil
  end

  local boundaries = {}
  local previous = ""
  for index = 1, #text do
    local char = text:sub(index, index)
    if index == 1 or previous:match("[%W_]") or char:match("%u") then
      boundaries[#boundaries + 1] = char:lower()
    end
    previous = char
  end
  local boundary_text = table.concat(boundaries)
  local boundary_cursor = 1
  local boundary_bonus = boundary_text:find(needle, 1, true) and 20000 or 0
  for index = 1, #needle do
    local found = boundary_text:find(needle:sub(index, index), boundary_cursor, true)
    if not found then
      boundary_bonus = 0
      break
    end
    boundary_bonus = boundary_bonus + 300
    boundary_cursor = found + 1
  end

  local lower = text:lower()
  local exact_query = vim.trim(query):lower()
  local cursor = 1
  local first = nil
  local prev = nil
  local score = 0

  for index = 1, #needle do
    local found = lower:find(needle:sub(index, index), cursor, true)
    if not found then
      return nil
    end

    first = first or found
    if prev and found == prev + 1 then
      score = score + 20
    elseif prev then
      score = score - math.min(found - prev, 20)
    end

    local original = text:sub(found, found)
    local before = found > 1 and text:sub(found - 1, found - 1) or ""
    if found == 1 or before:match("[%W_]") or original:match("%u") then
      score = score + 8
    end

    prev = found
    cursor = found + 1
  end

  local exact_bonus = exact_query ~= "" and lower:find(exact_query, 1, true) and 10000 or 0
  return exact_bonus + boundary_bonus + score + math.max(0, 200 - (first or 200))
end

function M.rank_fuzzy_items(items, query)
  for _, item in ipairs(items) do
    item._grep_fuzzy_score = M.fuzzy_score((item.text or "") .. " " .. (item.filename or ""), query) or 0
  end
  table.sort(items, function(a, b)
    if a._grep_fuzzy_score ~= b._grep_fuzzy_score then
      return a._grep_fuzzy_score > b._grep_fuzzy_score
    end
    return (a.filename or "") < (b.filename or "")
  end)
  for _, item in ipairs(items) do
    item._grep_fuzzy_score = nil
  end
end

function M.make_item(dir, file, lnum, col, text, query)
  local filename = vim.fs.normalize(dir .. "/" .. file)
  -- `file` is already relative to the search dir (rg runs with cwd=dir), so use
  -- it directly for the label instead of a per-item vim.fn.fnamemodify, which
  -- was the main cost when building thousands of results. The grep picker still
  -- overrides display via format_item; this label serves generic `sources.grep`
  -- consumers that have no format_item.
  return {
    label = string.format("%s:%d:%d  %s", file, lnum, col, text or ""),
    path = filename,
    filename = filename,
    lnum = lnum,
    col = col,
    text = text or "",
    query = query,
  }
end

function M.parse_vimgrep_lines(dir, lines, items, query)
  for _, line in ipairs(lines) do
    local file, lnum, col, text = line:match("^([^:]+):(%d+):(%d+):(.*)$")
    if file then
      items[#items + 1] = M.make_item(dir, file, tonumber(lnum), tonumber(col), text, query)
    end
  end
end

function M.append_unique(target, source)
  local seen = {}
  for _, item in ipairs(target) do
    seen[table.concat({ item.filename or "", item.lnum or 0, item.col or 0 }, "\0")] = true
  end
  for _, item in ipairs(source) do
    local key = table.concat({ item.filename or "", item.lnum or 0, item.col or 0 }, "\0")
    if not seen[key] then
      seen[key] = true
      target[#target + 1] = item
    end
  end
end

function M.rg_args(opts, pattern, fixed)
  local args = { "--vimgrep", "--smart-case", "--glob", "!.git" }
  if opts.hidden or opts.all_files then
    args[#args + 1] = "--hidden"
  end
  if opts.ignored or opts.all_files then
    args[#args + 1] = "--no-ignore"
  end
  if fixed then
    args[#args + 1] = "-F"
  end
  if opts.word then
    args[#args + 1] = "-w"
  end
  vim.list_extend(args, util.file_glob_args(config.current.grep_exclude_globs))
  vim.list_extend(args, util.file_glob_args(opts.glob))
  args[#args + 1] = pattern
  return args
end

local function run_rg(dir, opts, pattern, fixed)
  local command = { "rg" }
  vim.list_extend(command, M.rg_args(opts, pattern, fixed))
  local result = vim.system(command, { cwd = dir, text = true }):wait()
  local stdout = result and result.stdout or ""
  return vim.split(stdout, "\n", { plain = true, trimempty = true })
end

local function parse_rg_line(dir, query)
  return function(line)
    local file, lnum, col, text = line:match("^([^:]+):(%d+):(%d+):(.*)$")
    if not file then
      return nil
    end
    return M.make_item(dir, file, tonumber(lnum), tonumber(col), text, query)
  end
end

local function spawn_rg(dir, opts, pattern, fixed, on_done, query)
  return picker_proc.spawn({
    cmd = "rg",
    args = M.rg_args(opts, pattern, fixed),
    cwd = dir,
    transform = parse_rg_line(dir, query or pattern),
    on_done = on_done,
  })
end

local function search_pattern(_opts, query)
  return query
end

local function allow_fuzzy(opts, query)
  return (opts.fuzzy == true or (opts.regex and opts.fuzzy ~= false))
    and not opts.word
    and not has_regex_syntax(query)
end

function M.collect_items(opts, query)
  local cwd = opts.cwd or util.root()
  query = M.normalize_query(query)
  if query == "" then
    return {}, query
  end

  local dirs = opts.dirs or { cwd }
  local items = {}
  local pattern = search_pattern(opts, query)
  local fixed = not opts.regex
  local fuzzy_allowed = allow_fuzzy(opts, query)

  for _, dir in ipairs(dirs) do
    M.parse_vimgrep_lines(dir, run_rg(dir, opts, pattern, fixed), items, query)
  end

  if fuzzy_allowed and #items == 0 then
    local fuzzy = M.fuzzy_pattern(query)
    if fuzzy then
      local fuzzy_items = {}
      for _, dir in ipairs(dirs) do
        M.parse_vimgrep_lines(dir, run_rg(dir, opts, fuzzy, false), fuzzy_items, query)
      end
      M.append_unique(items, fuzzy_items)
      M.rank_fuzzy_items(items, query)
    end
  end

  return items, query
end

function M.collect_file_items(file, query, opts)
  opts = opts or {}
  query = M.normalize_query(query)
  if query == "" then
    return {}, query
  end

  file = vim.fs.normalize(file)
  local dir = vim.fn.fnamemodify(file, ":h")
  local fixed = not opts.regex

  local function run(use_fixed)
    local command = { "rg", "--vimgrep", "--smart-case" }
    if use_fixed then
      command[#command + 1] = "-F"
    end
    if opts.word then
      command[#command + 1] = "-w"
    end
    command[#command + 1] = "--"
    command[#command + 1] = query
    command[#command + 1] = file
    local result = vim.system(command, { text = true }):wait()
    local stdout = result and result.stdout or ""
    local code = result and result.code or 1
    local lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
    return lines, code
  end

  local lines, code = run(fixed)
  if code == 2 and not fixed then
    lines = run(true)
  end

  local items = {}
  local basename = vim.fn.fnamemodify(file, ":t")
  for _, line in ipairs(lines) do
    local matched_file, lnum, col, text = line:match("^([^:]+):(%d+):(%d+):(.*)$")
    if matched_file and lnum then
      items[#items + 1] = M.make_item(dir, basename, tonumber(lnum), tonumber(col), text, query)
    end
  end
  return items, query
end

function M.collect_items_async(opts, query, callback)
  local cwd = opts.cwd or util.root()
  query = M.normalize_query(query)
  if query == "" then
    callback({})
    return nil
  end

  local dirs = opts.dirs or { cwd }
  local pattern = search_pattern(opts, query)
  local fixed = not opts.regex
  local fuzzy_allowed = allow_fuzzy(opts, query)

  local pending = #dirs
  local items = {}
  local procs = {}

  local function finish_primary()
    if fuzzy_allowed and #items == 0 then
      local fuzzy = M.fuzzy_pattern(query)
      if fuzzy then
        local fuzzy_pending = #dirs
        local fuzzy_items = {}
        for _, dir in ipairs(dirs) do
          spawn_rg(dir, opts, fuzzy, false, function(dir_items)
            if procs[1] and procs[1].aborted then
              return
            end
            M.append_unique(fuzzy_items, dir_items)
            fuzzy_pending = fuzzy_pending - 1
            if fuzzy_pending == 0 then
              M.rank_fuzzy_items(fuzzy_items, query)
              callback(fuzzy_items)
            end
          end, query)
        end
        return
      end
    end
    callback(items)
  end

  for _, dir in ipairs(dirs) do
    local proc = spawn_rg(dir, opts, pattern, fixed, function(dir_items)
      if procs[1] and procs[1].aborted then
        return
      end
      M.append_unique(items, dir_items)
      pending = pending - 1
      if pending == 0 then
        finish_primary()
      end
    end, query)
    procs[#procs + 1] = proc
  end

  return procs[1]
end

function M.dynamic_items(source_opts)
  source_opts = source_opts or {}
  return function(state, callback)
    local query = M.normalize_query(state.query)
    if query == "" then
      callback({})
      return nil
    end

    -- Keep the full result set (picker.proc caps at 5000 as a safety net) so
    -- cursor navigation flows over everything. Items are cheap now (no eager
    -- label), so building them no longer janks the main thread.
    local opts = vim.tbl_extend("force", source_opts, {
      all_files = state.all_files == true,
      cwd = source_opts.cwd or util.root(),
    })
    if state.quick_filter and state.quick_filter.glob then
      opts.glob = state.quick_filter.glob
    end

    return M.collect_items_async(opts, query, callback)
  end
end

return M

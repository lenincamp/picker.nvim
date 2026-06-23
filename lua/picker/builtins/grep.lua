local grep_core = require("picker.grep.core")
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

local function preview_match(opts, item)
  local query = grep_core.normalize_query(item and item.query or opts.query)
  return {
    lnum = item.lnum,
    col = item.col,
    length = (opts.regex and not opts.word) and nil or #query,
  }
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

local function base_picker_opts(opts)
  opts = opts or {}
  return {
    scope = opts.scope or "project",
    search_threshold = 0,
    input_spacing = opts.input_spacing,
    filters = opts.filters or util.filters(),
    preview = function(item)
      return item.filename or item.path
    end,
    preview_lnum = function(item)
      return item.lnum
    end,
    preview_match = function(item)
      return preview_match(opts, item)
    end,
    format_item = format_item,
  }
end

function M.grep(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local query = grep_core.normalize_query(opts.query)
  if query == "" then
    return M.grep_picker(opts)
  end

  local items
  items, query = grep_core.collect_items(opts, query)

  local title = opts.title and (opts.title .. ": " .. query) or opts.prompt and (opts.prompt .. ": " .. query) or ("Grep: " .. query)
  vim.fn.setqflist({}, " ", { title = title, items = items })
  if #items == 0 then
    util.notify(title .. ": no results", vim.log.levels.WARN)
    return
  end

  local picker = require("picker")
  local picker_opts = vim.tbl_extend("force", base_picker_opts(opts), {
    prompt = title,
    input_mode = true,
    layout = opts.layout,
    auto_select_single = false,
    preview_open = opts.preview_open == true,
  })

  picker.select_items(items, picker.with_layout(picker_opts), open_item)
end

function M.grep_picker(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local picker = require("picker")

  local source_opts = vim.tbl_extend("force", opts, {
    cwd = cwd,
    fuzzy = opts.fuzzy ~= false,
    regex = opts.regex ~= false,
  })

  local picker_opts = vim.tbl_extend("force", base_picker_opts(opts), {
    prompt = opts.title or opts.prompt or "Grep",
    input_mode = true,
    input_only = true,
    auto_select_single = false,
    debounce_ms = opts.debounce_ms or 140,
    layout = opts.layout or "intellij_grep",
    preview_open = opts.preview_open == true,
    dynamic_items = grep_core.dynamic_items(source_opts),
    submit_query = function(query, state)
      local next_opts = vim.tbl_extend("force", opts, {
        all_files = state and state.all_files == true,
        cwd = cwd,
        fuzzy = opts.fuzzy ~= false,
        query = query,
        regex = opts.regex ~= false,
        preview = true,
        preview_open = true,
        layout = "intellij_grep",
      })
      if state and state.quick_filter and state.quick_filter.glob then
        next_opts.glob = state.quick_filter.glob
      end
      M.grep(next_opts)
    end,
  })

  picker.select_items({}, picker.with_layout(picker_opts), open_item)
end

function M.grep_word(opts)
  opts = opts or {}
  opts.query = util.selected_text_or_word()
  opts.regex = true
  opts.word = true
  M.grep(opts)
end

function M.grep_buffer(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local file = opts.file or vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    util.notify("Buffer has no file on disk", vim.log.levels.WARN)
    return
  end

  local function run(query)
    query = grep_core.normalize_query(query)
    if query == "" then
      return
    end

    local search_opts = vim.tbl_extend("force", { regex = false }, opts)
    local items
    items, query = grep_core.collect_file_items(file, query, search_opts)
    if #items == 0 then
      util.notify("No text matches found", vim.log.levels.INFO)
      return
    end

    local title = string.format("Search current file: %s", query)
    vim.fn.setqflist({}, " ", { title = title, items = items })

    local picker = require("picker")
    local picker_opts = vim.tbl_extend("force", base_picker_opts(vim.tbl_extend("force", opts, { query = query })), {
      prompt = title,
      scope = "buffer",
      preview_open = opts.preview_open ~= false,
    })
    picker.select_items(items, picker.with_layout(picker_opts), open_item)
  end

  local query = grep_core.normalize_query(opts.query)
  if query ~= "" then
    run(query)
    return
  end

  vim.ui.input({ prompt = "Search text > ", scope = "buffer" }, function(input)
    if input then
      run(input)
    end
  end)
end

return M

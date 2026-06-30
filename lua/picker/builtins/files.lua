local files_core = require("picker.files.core")
local util = require("picker.util")

local M = {}

local function open_item(item)
  if item then
    util.open_file(item.path)
  end
end

function M.find_files(opts)
  opts = opts or {}
  if opts.title and not opts.prompt then
    opts.prompt = opts.title
  end

  local cwd = opts.cwd or vim.fn.getcwd()
  local items, err = files_core.collect_items(cwd, opts)
  if not items then
    util.notify(err, vim.log.levels.WARN)
    return
  end

  if opts.regex_query then
    local filtered = {}
    for _, item in ipairs(items) do
      local ok, matched = pcall(function()
        return item.label:find(opts.regex_query) ~= nil
      end)
      if ok and matched then
        filtered[#filtered + 1] = item
      end
    end
    items = filtered
    if #items == 0 then
      util.notify((opts.prompt or "Find files") .. ": no regex results for " .. opts.regex_query, vim.log.levels.WARN)
      return
    end
  end

  local picker = require("picker")
  local select_opts = {
    prompt = opts.prompt or "Find files",
    scope = "project",
    search_threshold = 0,
    query = opts.query,
    input_mode = opts.input_mode ~= false,
    auto_select_single = opts.auto_select_single,
    layout = opts.layout,
    preview_open = opts.preview_open,
    filters = opts.filters or util.filters(),
  }

  if select_opts.input_mode then
    select_opts.dynamic_items = function(state, callback)
      local next_opts = vim.tbl_extend("force", opts, {
        all_files = state and state.all_files == true,
        cwd = cwd,
      })
      if state and state.quick_filter and state.quick_filter.glob then
        next_opts.glob = state.quick_filter.glob
      end
      local next_items = files_core.collect_items(cwd, next_opts) or {}
      local query = vim.trim((state and state.query) or "")
      if query ~= "" then
        next_items = require("picker.filter").items(next_items, select_opts, query)
      end
      callback(next_items)
      return nil
    end
    select_opts.submit_query = function(query, state)
      local next_opts = vim.tbl_extend("force", opts, {
        all_files = state and state.all_files == true,
        cwd = cwd,
        query = query,
        input_mode = true,
        preview = true,
        auto_select_single = false,
        layout = "intellij_grep",
      })
      if state and state.quick_filter and state.quick_filter.glob then
        next_opts.glob = state.quick_filter.glob
      end
      if state and state.regex_pattern then
        next_opts.regex_query = state.regex_pattern
      end
      M.find_files(next_opts)
    end
  end

  if opts.preview ~= false then
    select_opts.preview = function(item)
      return item.path
    end
  end

  picker.select_items(items, picker.with_layout(select_opts), open_item)
end

function M.open_terminal(cwd)
  vim.cmd("botright 15split")
  local buffer = vim.api.nvim_get_current_buf()
  vim.fn.termopen(vim.o.shell, { cwd = cwd or vim.fn.getcwd() })
  vim.bo[buffer].buflisted = false
  vim.cmd("startinsert")
end

return M

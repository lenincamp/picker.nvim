local M = {}

local picker_display = require("picker.display")
local picker_filter = require("picker.filter")
local picker_selection = require("picker.selection")
local picker_status = require("picker.status")

local function single_line(value)
  return tostring(value or ""):gsub("[\r\n]+", " ")
end

local function item_description(item, opts)
  if opts and type(opts.describe_item) == "function" then
    local ok, description = pcall(opts.describe_item, item)
    if ok and type(description) == "string" and description ~= "" then
      return description
    end
  end
  if type(item) == "table" and type(item.description) == "string" and item.description ~= "" then
    return item.description
  end
  return nil
end

function M.lines(opts, state)
  local total = #state.current_candidates
  local page_start = state.page_start
  if page_start > total then
    page_start = math.max(1, total - state.max_results + 1)
  end

  local filters = opts.filters or opts.quick_filters
  local status_line = picker_status.segments(opts, {
    choosing_quick_filter = state.choosing_quick_filter,
    all_files = state.all_files,
    filters = filters,
    has_preview = state.has_preview,
    picker_layout = state.picker_layout,
    show_descriptions = state.show_descriptions,
    group_help = opts.group_item and "  [g/]g=group" or "",
    total = total,
    filter_history = state.filter_history,
  })
  local header_lines = opts.input_mode and 1 or 2
  local visible_limit = math.max(1, state.height - header_lines - 1)
  local page_end = math.min(total, page_start + visible_limit - 1)
  local lines = {}
  local item_line_highlights = {}
  if not opts.input_mode then
    local title = single_line(state.prompt)
      .. (state.current_query ~= "" and (" /" .. single_line(state.current_query)) or "")
      .. (state.current_filter_label and (" [" .. single_line(state.current_filter_label) .. "]") or "")
    lines[#lines + 1] = picker_display.padded_line(title, state.width)
  end
  lines[#lines + 1] = picker_display.padded_line(single_line(status_line), state.width)
  local item_highlights = {}

  for index = page_start, page_end do
    local item = state.current_candidates[index]
    local visible_index = index - page_start + 1
    local shortcut = visible_index <= 9 and string.format("[%d]", visible_index) or "   "
    local marker = opts.multi_select and (state.selected[picker_selection.item_key(opts, item)] and "●" or "○") or " "
    local label = single_line(picker_filter.item_label(item, opts))
    local description = state.show_descriptions and item_description(item, opts) or nil
    if description then
      description = single_line(description)
      label = label .. "  " .. description
    end
    local prefix = string.format("%4d %s %s ", index, shortcut, marker)
    local line = prefix .. label
    lines[#lines + 1] = line
    item_line_highlights[#item_line_highlights + 1] = #lines
    if state.current_query ~= "" then
      for _, range in ipairs(picker_filter.match_ranges(label, state.current_query)) do
        item_highlights[#item_highlights + 1] = {
          line = #lines,
          from = #prefix + range.from - 1,
          to = #prefix + range.to,
        }
      end
    end
  end

  if total > visible_limit then
    lines[#lines + 1] = string.format("... showing %d-%d of %d", page_start, page_end, total)
  end

  return {
    lines = lines,
    item_highlights = item_highlights,
    item_line_highlights = item_line_highlights,
    status_line = status_line,
    page_start = page_start,
  }
end

function M.highlight(bufnr, namespace, rendered, opts)
  picker_status.highlight(bufnr, namespace, rendered.status_line, opts)
  for _, line_num in ipairs(rendered.item_line_highlights or {}) do
    vim.api.nvim_buf_add_highlight(bufnr, namespace, "NativePickerItem", line_num - 1, 0, -1)
  end
  for _, range in ipairs(rendered.item_highlights or {}) do
    vim.api.nvim_buf_add_highlight(bufnr, namespace, "NativePickerMatch", range.line - 1, range.from, range.to)
  end
end

return M

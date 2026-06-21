local M = {}

local picker_display = require("picker.display")
local picker_filter = require("picker.filter")

local function action_parts(actions, with_description)
  local parts = {}
  for lhs, action in pairs(actions or {}) do
    if type(action) == "table" then
      if with_description and action.desc then
        parts[#parts + 1] = lhs .. "=" .. action.desc
      else
        parts[#parts + 1] = lhs
      end
    end
  end
  table.sort(parts)
  return parts
end

function M.segments(opts, state)
  if state.choosing_quick_filter then
    return "FileType " .. picker_filter.quick_filter_menu(state.filters) .. "  Esc=cancel"
  end

  local layout_label = state.picker_layout == "intellij_grep" and "intellij" or (state.has_preview and "side" or "list")
  local mode_label = opts.input_mode and (state.input_insert_mode and "INS" or "NORMAL") or nil
  local enter_label = type(opts.dynamic_items) == "function" and "open" or (opts.submit_query and "run" or "open")
  if state.show_descriptions then
    local filter_help = picker_filter.has_filters(state.filters) and "  F=types  C=clear-type  R=regex" or ""
    local input_help = opts.input_mode and (state.input_insert_mode and "  type=filter  BS=back" or "  i/a=insert") or "  /=filter"
    local multi_help = opts.multi_select and "  Space/m=mark" or ""
    local description_help = (opts.describe_item or opts.item_descriptions) and "  items=descriptions" or ""
    local actions = action_parts(opts.actions, true)
    local action_help = #actions > 0 and ("  " .. table.concat(actions, "  ")) or ""
    local close_help = opts.input_mode and (state.input_insert_mode and "Esc=normal" or "Esc/q=close") or "q=close"
    local zoom_help = opts.input_mode and "A-z=zoom" or "z=zoom"
    if opts.input_mode then
      zoom_help = state.input_insert_mode and "z=text" or "z=zoom"
    end
    return string.format("%s%sEnter=%s  C-q=qf%s%s%s%s%s  1-9=open  Tab=preview  C-o=focus  A-l=layout:%s  %s  C-u/C-d=page  C-f/C-b=scroll%s  ?=keys  %s  (%d total)", mode_label and (mode_label .. "  ") or "", "", enter_label, input_help, filter_help, multi_help, description_help, action_help, layout_label, zoom_help, state.group_help, close_help, state.total)
  end

  local parts = {}
  if mode_label then parts[#parts + 1] = mode_label end
  vim.list_extend(parts, { "Enter", "C-q", opts.input_mode and (state.input_insert_mode and "type" or "NORMAL") or "/" })
  if picker_filter.has_filters(state.filters) then
    vim.list_extend(parts, { "F", "C", "R" })
  end
  if opts.multi_select then
    vim.list_extend(parts, { "Space/m" })
  end
  vim.list_extend(parts, action_parts(opts.actions, false))
  vim.list_extend(parts, { "1-9", "Tab", "C-o", "A-l:" .. layout_label, opts.input_mode and (state.input_insert_mode and "z" or "z") or "z", "C-u/d", "C-f/b" })
  if opts.group_item then
    vim.list_extend(parts, { "[g", "]g" })
  end
  vim.list_extend(parts, { "?", opts.input_mode and (state.input_insert_mode and "Esc" or "i/a Esc/q") or "q", string.format("%d total", state.total) })

  return table.concat(parts, "  ")
end

function M.highlight(bufnr, namespace, line)
  picker_display.define_highlights()
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, 2)
  vim.api.nvim_buf_add_highlight(bufnr, namespace, "NativePickerTitle", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(bufnr, namespace, "NativePickerStatus", 1, 0, -1)
  for key in line:gmatch("[%w%-%[%]/?<:]+") do
    local start = 1
    while true do
      local from, to = line:find(vim.pesc(key), start)
      if not from then
        break
      end
      vim.api.nvim_buf_add_highlight(bufnr, namespace, "NativePickerKey", 1, from - 1, to)
      start = to + 1
    end
  end
end

return M

local M = {}

local input_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.*/:@#$%^&+=,[]{}()\\!?|~'\""
local reserved_filter_keys = { j = true, k = true, q = true, ["/"] = true, R = true, F = true, C = true }

local function set(lhs, rhs, opts, extra)
  vim.keymap.set("n", lhs, rhs, vim.tbl_extend("force", opts, extra or {}))
end

function M.setup(args)
  local opts = args.opts or {}
  local map_opts = { buffer = args.buffer, silent = true }
  local custom_actions = opts.actions or {}

  set("<CR>", args.select_cursor, map_opts)
  set("<C-q>", args.open_quickfix, map_opts)
  set("<C-v>", function()
    if opts.input_mode then return args.paste_query() end
    args.open_split("vsplit")
  end, map_opts, { nowait = true })
  set("<D-v>", function()
    if opts.input_mode then args.paste_query() end
  end, map_opts, { nowait = true })
  set("<C-r>", function()
    if opts.input_mode then args.paste_query() end
  end, map_opts, { nowait = true })
  set("<C-x>", custom_actions["<C-x>"] and args.run_action(custom_actions["<C-x>"]) or function() args.open_split("split") end, map_opts)
  set("/", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("/")() end
    args.run_or_select_quick_filter("/", args.ask_filter)()
  end, map_opts)
  set("F", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("F")() end
    args.ask_quick_filter()
  end, map_opts)
  set("C", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("C")() end
    args.run_or_select_quick_filter("C", args.clear_active_filters)()
  end, map_opts)
  set("R", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("R")() end
    args.run_or_select_quick_filter("R", args.ask_regex_filter)()
  end, map_opts)
  set("<Tab>", args.toggle_preview, map_opts)
  set("<C-o>", args.focus_preview, map_opts)
  set("<A-l>", args.toggle_picker_layout, map_opts)
  set("?", args.toggle_descriptions, map_opts)
  set("z", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("z")() end
    args.toggle_preview_zoom()
  end, map_opts, { nowait = true })
  set("j", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("j")() end
    args.run_or_select_quick_filter("j", function() args.move_cursor(1) end)()
  end, map_opts)
  set("k", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("k")() end
    args.run_or_select_quick_filter("k", function() args.move_cursor(-1) end)()
  end, map_opts)
  set("<C-n>", function() args.move_cursor(1) end, map_opts)
  set("<C-p>", function() args.move_cursor(-1) end, map_opts)
  set("<C-u>", args.page_up_or_top, map_opts)
  set("<C-d>", function() args.page(1) end, map_opts)
  set("<C-f>", args.scroll_preview_down, map_opts)
  set("<C-b>", args.scroll_preview_up, map_opts)
  set("]g", function() args.jump_group(1) end, map_opts)
  set("[g", function() args.jump_group(-1) end, map_opts)
  set("q", function()
    if opts.input_mode and args.is_insert_mode() then return args.append_query("q")() end
    args.cancel_or_close()
  end, map_opts)
  set("p", function()
    if opts.input_mode and not args.is_insert_mode() then return args.paste_query() end
    if opts.input_mode then return args.append_query("p")() end
  end, map_opts, { nowait = opts.input_mode })
  set("<Esc>", args.cancel_or_close, map_opts)

  if opts.input_mode then
    set("<BS>", args.backspace_query, map_opts)
    set("<C-h>", args.backspace_query, map_opts)
    set("<C-w>", args.clear_query, map_opts)
    set("i", function()
      if args.is_insert_mode() then return args.append_query("i")() end
      args.enter_insert_mode()
    end, map_opts)
    set("a", function()
      if args.is_insert_mode() then return args.append_query("a")() end
      args.enter_insert_mode()
    end, map_opts)
    for _, char in ipairs(vim.split(input_chars, "", { plain = true, trimempty = true })) do
      if not ({ ["/"] = true, F = true, C = true, R = true, z = true, j = true, k = true, q = true, p = true, i = true, a = true, ["?"] = true })[char] then
        set(char, args.append_query(char), map_opts)
      end
    end
    if not opts.multi_select then
      set("<Space>", args.append_query(" "), map_opts, { nowait = true })
      set("<Space><Space>", args.append_query("  "), map_opts, { nowait = true })
      for _, char in ipairs(vim.split(input_chars, "", { plain = true, trimempty = true })) do
        pcall(set, "<Space>" .. char, args.append_query(" " .. char), map_opts, { nowait = true })
      end
    end
  end

  if opts.multi_select then
    set("<Space>", args.toggle_selected, map_opts, { nowait = true })
    set("m", args.toggle_selected, map_opts)
  end

  for lhs, action in pairs(custom_actions) do
    if lhs ~= "<C-x>" and type(action) == "table" and type(action.fn) == "function" then
      set(lhs, args.run_action(action), map_opts)
    end
  end

  for _, filter in ipairs(opts.filters or opts.quick_filters or {}) do
    if filter.key and not reserved_filter_keys[filter.key] then
      set(filter.key, function()
        if args.is_choosing_quick_filter() then
          args.select_quick_filter_key(filter.key)
          return
        end
        if opts.input_mode and args.is_insert_mode() then
          return args.append_query(filter.key)()
        end
        args.apply_quick_filter(filter)
      end, map_opts)
    end
  end

  for index = 1, 9 do
    set(tostring(index), function()
      if opts.input_mode and args.is_insert_mode() then
        return args.append_query(tostring(index))()
      end
      args.select_index(index)
    end, map_opts, { nowait = opts.input_mode })
  end
end

return M

local M = {}
local config = require("picker.config")
local picker_filter = require("picker.filter")
local picker_filter_state = require("picker.filter_state")
local picker_input = require("picker.input")
local picker_keymaps = require("picker.keymaps")
local picker_layout_mod = require("picker.layout")
local picker_navigation = require("picker.navigation")
local picker_preview = require("picker.preview")
local picker_preview_window = require("picker.preview_window")
local picker_proc = require("picker.proc")
local picker_quickfix = require("picker.quickfix")
local picker_render = require("picker.render")
local picker_selection = require("picker.selection")
local picker_windows = require("picker.windows")

local uv = vim.uv or vim.loop
local intellij_grep = true
local last_qf_title = nil
local preview_namespace = vim.api.nvim_create_namespace("native_picker_preview")
local picker_namespace = vim.api.nvim_create_namespace("native_picker")

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO)
end

function M.select_items(items, opts, on_choice)
  opts = opts or {}
  if #items == 0 and not opts.input_only then
    notify((opts and opts.prompt or "Select") .. ": no results", vim.log.levels.WARN)
    return
  end

  local prompt = opts.prompt or "Select"
  local max_results = opts.max_results or 40
  local supports_filter = opts.search ~= false
  if opts.input_mode then
    supports_filter = true
  end
  local has_initial_query = opts.query and opts.query ~= ""
  local candidates_win = nil
  local candidates_buf = nil
  local preview_win = nil
  local preview_buf = nil

  local function close_candidates_window()
    local window_state = {
      candidates_buf = candidates_buf,
      candidates_win = candidates_win,
      preview_buf = preview_buf,
      preview_win = preview_win,
    }
    picker_windows.close(window_state)
    candidates_win = window_state.candidates_win
    candidates_buf = window_state.candidates_buf
    preview_win = window_state.preview_win
    preview_buf = window_state.preview_buf
  end

  local function open_candidates_picker(candidates, query)
    close_candidates_window()

    local current_query = vim.trim(query or "")
    local current_candidates = opts.input_only and {} or candidates
    local current_filter_label = nil
    local current_quick_filter = nil
    local current_regex_pattern = nil
    local current_all_files = opts.all_files == true
    local choosing_quick_filter = false
    local filter_generation = 0
    local selected = {}
    local page_start = 1
    local item_row = opts.input_mode and 2 or 3
    local cursor_row = item_row -- tracks selected row in candidates (1-indexed buffer line)
    local has_preview = type(opts.preview) == "function" or type(opts.preview_lines) == "function"
    local preview_enabled = has_preview and opts.preview_open == true
    local preview_maximized = false
    local show_descriptions = false
    local picker_layout = opts.layout or (intellij_grep and "intellij_grep" or "default")
    local layout
    local width, height
    local cursor_namespace = vim.api.nvim_create_namespace("native_picker_cursor")

    local function calculate_layout()
      layout = picker_layout_mod.calculate({
        has_preview = has_preview,
        layout = picker_layout,
        input_mode = opts.input_mode,
        input_spacing = opts.input_spacing or config.current.input_spacing,
        max_results = max_results,
        position = opts.position,
      })
      width = layout.width
      height = layout.height
    end

    calculate_layout()

    local function preview_config()
      return picker_layout_mod.preview_config(layout, preview_maximized)
    end

    local function highlight_cursor_line()
      if not candidates_buf or not vim.api.nvim_buf_is_valid(candidates_buf) then return end
      vim.api.nvim_buf_clear_namespace(candidates_buf, cursor_namespace, 0, -1)
      local line_count = vim.api.nvim_buf_line_count(candidates_buf)
      if cursor_row >= item_row and cursor_row <= line_count then
        vim.api.nvim_buf_set_extmark(candidates_buf, cursor_namespace, cursor_row - 1, 0, {
          line_hl_group = "CursorLine",
          hl_eol = true,
        })
      end
    end

    candidates_win, candidates_buf = picker_windows.open_candidates(picker_layout_mod.candidates_config(layout))
    if not candidates_win then
      close_candidates_window()
      vim.ui.select(candidates, opts, on_choice)
      return
    end

    local function render()
      local rendered = picker_render.lines(opts, {
        current_candidates = current_candidates,
        current_filter_label = current_filter_label,
        current_query = current_query,
        all_files = current_all_files,
        choosing_quick_filter = choosing_quick_filter,
        has_preview = has_preview,
        height = height,
        max_results = max_results,
        page_start = page_start,
        picker_layout = picker_layout,
        prompt = prompt,
        selected = selected,
        show_descriptions = show_descriptions,
        width = width,
      })
      page_start = rendered.page_start

      vim.bo[candidates_buf].modifiable = true
      vim.api.nvim_buf_set_lines(candidates_buf, 0, -1, false, rendered.lines)
      vim.bo[candidates_buf].modifiable = false
      picker_render.highlight(candidates_buf, picker_namespace, rendered, opts)

      -- Clamp cursor_row to valid range after content changes
      local last_line = #rendered.lines
      if last_line < item_row then
        cursor_row = math.max(1, last_line)
      else
        cursor_row = math.max(item_row, math.min(cursor_row, last_line))
      end

      if vim.api.nvim_win_is_valid(candidates_win) then
        vim.api.nvim_win_set_cursor(candidates_win, { cursor_row, 0 })
      end
      highlight_cursor_line()
    end

    local function current_item()
      if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then return nil end
      local row = vim.api.nvim_win_get_cursor(candidates_win)[1]
      return current_candidates[page_start + row - item_row]
    end

    local function close_preview()
      preview_win, preview_buf = picker_preview_window.close(preview_win, preview_buf)
    end

    local input_state = nil

    local function sync_input_window()
      if not opts.input_mode or not input_state or not input_state.win then
        return
      end
      if not vim.api.nvim_win_is_valid(input_state.win) then
        return
      end
      pcall(vim.api.nvim_win_set_config, input_state.win, {
        zindex = picker_layout_mod.INPUT_ZINDEX,
        row = picker_layout_mod.input_row(layout.row, opts.input_spacing or config.current.input_spacing),
        col = layout.col,
        width = layout.width,
      })
    end

    local function update_preview()
      if not preview_enabled then return end
      preview_win, preview_buf = picker_preview_window.update(preview_win, preview_buf, {
        config = preview_config(),
        item = current_item(),
        namespace = preview_namespace,
        picker_opts = opts,
      })
      sync_input_window()
    end

    local async_proc = nil
    local debounce_timer = uv.new_timer()

    local function abort_async()
      picker_proc.abort(async_proc)
      async_proc = nil
    end

    -- Wrap close to also clean up async resources
    local _base_close = close_candidates_window
    local function close_candidates_window() -- luacheck: ignore 431
      abort_async()
      if not debounce_timer:is_closing() then
        debounce_timer:stop()
        debounce_timer:close()
      end
      if input_state then
        picker_input.close(input_state)
        input_state = nil
      end
      _base_close()
      vim.cmd("stopinsert")
    end

    local function select_index(index)
      local actual_index = index and (page_start + index - 1) or nil
      if actual_index and current_candidates[actual_index] then
        local choice = current_candidates[actual_index]
        close_candidates_window()
        on_choice(choice)
      end
    end

    local function select_cursor()
      if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then
        return
      end
      if opts.multi_select then
        local chosen = picker_selection.selected_items(items, opts, selected)
        if #chosen > 0 then
          close_candidates_window()
          on_choice(chosen)
          return
        end
      end
      if type(opts.submit_query) == "function" and vim.trim(current_query) ~= "" and not (type(opts.dynamic_items) == "function" and #current_candidates > 0) then
        local query = vim.trim(current_query)
        local filter = current_quick_filter
        local regex_pattern = current_regex_pattern
        close_candidates_window()
        opts.submit_query(query, { filter = filter, regex_pattern = regex_pattern })
        return
      end
      local row = vim.api.nvim_win_get_cursor(candidates_win)[1]
      select_index(row - item_row + 1)
    end

    local function open_split(command)
      local item = current_item()
      local path = picker_preview.path(opts, item)
      if path then
        close_candidates_window()
        vim.cmd(command .. " " .. vim.fn.fnameescape(path))
        if item and item.lnum then
          vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
        end
      end
    end

    local function open_quickfix()
      local qf_items = picker_quickfix.items(current_candidates, opts)

      if #qf_items == 0 then
        notify(prompt .. ": no quickfix-compatible results", vim.log.levels.WARN)
        return
      end

      close_candidates_window()
      local title = (opts.quickfix_title or prompt) .. (current_query ~= "" and (" /" .. current_query) or "")
      vim.fn.setqflist({}, " ", { title = title, items = qf_items })
      last_qf_title = title
      vim.cmd("copen")
    end

    local function scroll_preview(delta)
      picker_navigation.scroll_preview(preview_win, delta)
    end

    local function move_cursor(delta)
      if picker_navigation.move_cursor(candidates_win, current_candidates, page_start, height, delta, item_row) then
        cursor_row = vim.api.nvim_win_get_cursor(candidates_win)[1]
        highlight_cursor_line()
        update_preview()
      end
    end

    local function apply_filter_state(empty_message)
      local filter_state = {
        all_files = current_all_files,
        query = current_query,
        quick_filter = current_quick_filter,
        regex_pattern = current_regex_pattern,
      }

      if type(opts.dynamic_items) == "function" then
        abort_async()
        filter_generation = filter_generation + 1
        local generation = filter_generation
        local render_scheduled = false

        local function receive_items(next_candidates)
          if generation ~= filter_generation then return end
          if not candidates_buf or not vim.api.nvim_buf_is_valid(candidates_buf) then return end
          if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then return end
          current_filter_label = picker_filter_state.label(filter_state)
          current_candidates = next_candidates or {}
          choosing_quick_filter = false
          page_start = 1
          -- Throttle render: only one pending render per event loop cycle
          if not render_scheduled then
            render_scheduled = true
            vim.schedule(function()
              render_scheduled = false
              if generation ~= filter_generation then return end
              if not candidates_buf or not vim.api.nvim_buf_is_valid(candidates_buf) then return end
              render()
              update_preview()
            end)
          end
        end

        local arity = debug.getinfo(opts.dynamic_items, "u").nparams
        if arity >= 2 then
          -- Async form: dynamic_items(state, callback)
          local ok, handle = pcall(opts.dynamic_items, filter_state, function(items)
            if generation ~= filter_generation then return end
            -- Schedule to ensure we're on the main thread regardless of caller context
            vim.schedule(function()
              if generation ~= filter_generation then return end
              receive_items(items)
            end)
          end)
          if ok and type(handle) == "table" then
            async_proc = handle
          end
          return true
        else
          -- Sync form: dynamic_items(state) -> items
          -- Defer blocking callbacks (e.g. vim.system():wait()) — never run in fast events.
          vim.schedule(function()
            if generation ~= filter_generation then return end
            if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then
              return
            end
            local ok, dynamic = pcall(opts.dynamic_items, filter_state)
            if generation ~= filter_generation then return end
            if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then
              return
            end
            local next_candidates = ok and type(dynamic) == "table" and dynamic or {}
            if #next_candidates == 0 and not opts.input_mode then
              notify(empty_message or (prompt .. ": no results"), vim.log.levels.WARN)
              return
            end
            receive_items(next_candidates)
          end)
          return true
        end
      end

      filter_generation = filter_generation + 1
      local generation = filter_generation
      picker_filter_state.items_async(
        opts.input_only and {} or items,
        opts,
        filter_state,
        function(next_candidates)
          if generation ~= filter_generation then return end
          if not candidates_buf or not vim.api.nvim_buf_is_valid(candidates_buf) then return end
          if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then return end
          if #next_candidates == 0 and not opts.input_mode then
            notify(empty_message or (prompt .. ": no results"), vim.log.levels.WARN)
            return
          end

          current_filter_label = picker_filter_state.label(filter_state)
          current_candidates = next_candidates
          choosing_quick_filter = false
          page_start = 1
          cursor_row = item_row
          if not opts.input_mode then
            vim.api.nvim_set_current_win(candidates_win)
          end
          render()
          update_preview()
        end,
        function()
          return generation ~= filter_generation
        end
      )
      return true
    end

    local function ask_filter()
      vim.ui.input({
        prompt = prompt .. " / ",
        default = current_query,
        scope = opts.scope or "project",
      }, function(input)
        if input == nil then
          return
        end

        local next_query = vim.trim(input)
        local previous_query = current_query
        current_query = next_query
        if not apply_filter_state(prompt .. ": no results for " .. next_query) then
          current_query = previous_query
          return
        end
      end)
    end

    local function apply_quick_filter(filter)
      if type(filter) ~= "table" or type(filter.predicate) ~= "function" then
        return
      end

      local previous_filter = current_quick_filter
      current_quick_filter = filter
      if not apply_filter_state(prompt .. ": no " .. (filter.label or "filtered") .. " results") then
        current_quick_filter = previous_filter
        return
      end
    end

    local function clear_active_filters()
      if not current_quick_filter then
        return
      end
      current_quick_filter = nil
      apply_filter_state()
    end

    local function toggle_all_files()
      current_all_files = not current_all_files
      apply_filter_state()
    end

    local function select_quick_filter_key(key)
      local filters = opts.filters or opts.quick_filters or {}
      for _, filter in ipairs(filters) do
        if filter.key == key then
          apply_quick_filter(filter)
          return true
        end
      end
      notify("Unknown filter: " .. key .. " (" .. picker_filter.quick_filter_menu(filters) .. ")", vim.log.levels.WARN)
      choosing_quick_filter = false
      render()
      return true
    end

    local function ask_quick_filter()
      local filters = opts.filters or opts.quick_filters or {}
      if vim.tbl_isempty(filters) then
        return
      end
      choosing_quick_filter = true
      render()
    end

    local function ask_regex_filter()
      vim.ui.input({
        prompt = prompt .. " regex / ",
        scope = opts.scope or "project",
      }, function(pattern)
        pattern = vim.trim(pattern or "")
        if pattern == "" then
          return
        end

        local previous_pattern = current_regex_pattern
        current_regex_pattern = pattern
        if not apply_filter_state(prompt .. ": no regex results for " .. pattern) then
          current_regex_pattern = previous_pattern
          return
        end
      end)
    end

    local function page(delta)
      local next_start, changed = picker_navigation.page(current_candidates, page_start, height, delta, item_row)
      if changed then
        page_start = next_start
        cursor_row = item_row
        render()
        update_preview()
      end
    end

    local function page_up_or_top()
      local next_start, changed = picker_navigation.page_up_or_top(candidates_win, current_candidates, page_start, height, item_row)
      if changed then
        page_start = next_start
        cursor_row = vim.api.nvim_win_get_cursor(candidates_win)[1]
        highlight_cursor_line()
        update_preview()
      end
    end

    local function jump_group(delta)
      local next_start, group_row = picker_navigation.jump_group(opts, candidates_win, current_candidates, page_start, height, delta, item_row)
      if group_row then
        page_start = next_start
        cursor_row = group_row
        render()
        vim.api.nvim_win_set_cursor(candidates_win, { cursor_row, 0 })
        highlight_cursor_line()
        update_preview()
      end
    end

    local function toggle_preview()
      if not has_preview then return end
      preview_enabled = not preview_enabled
      if preview_enabled then
        update_preview()
      else
        preview_maximized = false
        close_preview()
        sync_input_window()
      end
    end

    local function toggle_preview_zoom()
      if not has_preview then return end
      if not preview_enabled then
        preview_enabled = true
      end
      preview_maximized = not preview_maximized
      update_preview()
    end

    local function focus_preview()
      if not has_preview then return end
      if not preview_enabled then
        preview_enabled = true
        update_preview()
      end
      if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then return end
      vim.api.nvim_win_set_config(preview_win, vim.tbl_extend("force", vim.api.nvim_win_get_config(preview_win), {
        focusable = true,
      }))
      vim.api.nvim_set_current_win(preview_win)

      local preview_map_opts = { buffer = preview_buf, silent = true }
      local function return_to_input()
        if input_state then
          picker_input.focus(input_state)
        elseif candidates_win and vim.api.nvim_win_is_valid(candidates_win) then
          vim.api.nvim_set_current_win(candidates_win)
        end
      end
      vim.keymap.set("n", "<C-o>", return_to_input, preview_map_opts)
      vim.keymap.set("n", "q", return_to_input, preview_map_opts)
      vim.keymap.set("n", "<Esc>", return_to_input, preview_map_opts)
    end

    local function toggle_picker_layout()
      if not has_preview then return end
      picker_layout = picker_layout == "intellij_grep" and "default" or "intellij_grep"
      intellij_grep = picker_layout == "intellij_grep"
      preview_maximized = false
      calculate_layout()

      if candidates_win and vim.api.nvim_win_is_valid(candidates_win) then
        pcall(vim.api.nvim_win_set_config, candidates_win, picker_layout_mod.candidates_config(layout))
      end

      render()
      update_preview()
      sync_input_window()
    end

    local function toggle_descriptions()
      show_descriptions = not show_descriptions
      render()
    end

    local function cancel_or_close()
      if choosing_quick_filter then
        choosing_quick_filter = false
        render()
        return
      end
      close_candidates_window()
    end

    local function update_inline_query(next_query)
      current_query = next_query or ""
      cursor_row = item_row
      filter_generation = filter_generation + 1
      local generation = filter_generation
      local ms = type(opts.dynamic_items) == "function" and math.max(tonumber(opts.debounce_ms) or 200, 50) or math.max(tonumber(opts.debounce_ms) or 25, 5)

      local function refresh()
        debounce_timer:stop()
        debounce_timer:start(ms, 0, vim.schedule_wrap(function()
          if generation ~= filter_generation then return end
          if not candidates_buf or not vim.api.nvim_buf_is_valid(candidates_buf) then return end
          if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then return end
          apply_filter_state(prompt .. ": no results for " .. current_query)
        end))
      end

      if vim.in_fast_event() then
        vim.schedule(refresh)
      else
        refresh()
      end
    end

    local function toggle_selected()
      if not opts.multi_select then return end
      local item = current_item()
      if not item then return end
      local key = picker_selection.item_key(opts, item)
      selected[key] = not selected[key] or nil
      render()
    end

    local function run_action(action)
      return function()
        local item = current_item()
        local chosen = picker_selection.selected_items(items, opts, selected)
        if #chosen == 0 and item then
          chosen = { item }
        end
        action.fn(chosen, item, {
          close = close_candidates_window,
          render = render,
          selected = selected,
        })
      end
    end

    -- Normal-mode key handler for the input buffer (dispatches picker actions)
    local function handle_normal_key(key)
      -- Quick filter menu intercepts all keys
      if choosing_quick_filter then
        if key == "<Esc>" or key == "q" then
          choosing_quick_filter = false
          render()
        else
          -- Extract printable char from key notation
          local char = key:match("^(.)$")
          if char then select_quick_filter_key(char) end
        end
        return
      end

      if key == "j" or key == "<C-n>" or key == "<C-j>" then
        move_cursor(1)
      elseif key == "k" or key == "<C-p>" or key == "<C-k>" then
        move_cursor(-1)
      elseif key == "<CR>" then
        select_cursor()
      elseif key == "<Esc>" or key == "q" then
        cancel_or_close()
      elseif key == "<C-q>" then
        open_quickfix()
      elseif key == "<C-r>" then
        if input_state then picker_input.refresh(input_state) end
      elseif key == "<C-v>" then
        open_split("vsplit")
      elseif key == "<C-x>" then
        local custom = (opts.actions or {})["<C-x>"]
        if custom and type(custom) == "table" and type(custom.fn) == "function" then
          run_action(custom)()
        else
          open_split("split")
        end
      elseif key == "<Tab>" then
        toggle_preview()
      elseif key == "<C-o>" then
        focus_preview()
      elseif key == "<C-u>" then
        page_up_or_top()
      elseif key == "<C-d>" then
        page(1)
      elseif key == "<C-f>" then
        scroll_preview(height)
      elseif key == "<C-b>" then
        scroll_preview(-height)
      elseif key == "<A-l>" then
        toggle_picker_layout()
      elseif key == "z" then
        toggle_preview_zoom()
      elseif key == "?" then
        toggle_descriptions()
      elseif key == "<Space>" or key == "m" then
        toggle_selected()
      elseif key == "]g" then
        jump_group(1)
      elseif key == "[g" then
        jump_group(-1)
      elseif key == "F" then
        ask_quick_filter()
      elseif key == "C" then
        clear_active_filters()
      elseif key == "R" then
        ask_regex_filter()
      elseif key == "I" then
        toggle_all_files()
      elseif key == "p" then
        if input_state then picker_input.paste(input_state) end
      elseif key:match("^%d$") then
        select_index(tonumber(key))
      end
    end

    if opts.input_mode then
      -- Make candidates window non-focusable so user stays in input
      if candidates_win and vim.api.nvim_win_is_valid(candidates_win) then
        pcall(vim.api.nvim_win_set_config, candidates_win, { focusable = false })
      end

      render()
      update_preview()

      -- Open real input buffer
      local input_row = picker_layout_mod.input_row(layout.row, opts.input_spacing or config.current.input_spacing)
      input_state = picker_input.open({
        prompt = prompt,
        row = input_row,
        col = layout.col,
        width = layout.width,
        zindex = picker_layout_mod.INPUT_ZINDEX,
        initial = current_query,
        debounce_ms = tonumber(opts.input_debounce_ms) or 35,
        on_change = function(text)
          update_inline_query(text)
        end,
        on_submit = function(_text)
          select_cursor()
        end,
        on_close = function()
          close_candidates_window()
        end,
        on_normal_key = handle_normal_key,
      })
    else
      -- Non-input_mode: keymaps on candidates buffer (old behavior)
      picker_keymaps.setup({
        buffer = candidates_buf,
        cancel_or_close = cancel_or_close,
        move_cursor = move_cursor,
        open_quickfix = open_quickfix,
        open_split = open_split,
        opts = opts,
        page = page,
        page_up_or_top = page_up_or_top,
        run_action = run_action,
        scroll_preview_down = function() scroll_preview(height) end,
        scroll_preview_up = function() scroll_preview(-height) end,
        select_cursor = select_cursor,
        select_index = select_index,
        toggle_descriptions = toggle_descriptions,
        toggle_picker_layout = toggle_picker_layout,
        toggle_preview = toggle_preview,
        toggle_preview_zoom = toggle_preview_zoom,
        toggle_selected = toggle_selected,
        focus_preview = focus_preview,
        ask_quick_filter = ask_quick_filter,
        ask_filter = ask_filter,
        ask_regex_filter = ask_regex_filter,
        apply_quick_filter = apply_quick_filter,
        clear_active_filters = clear_active_filters,
        toggle_all_files = toggle_all_files,
        select_quick_filter_key = select_quick_filter_key,
        jump_group = jump_group,
      })
      render()
      update_preview()
    end
  end

  local function choose(candidates, query)
    query = vim.trim(query or "")
    if #candidates == 0 then
      if opts.input_only then
        open_candidates_picker(candidates, query)
        return
      end
      notify(prompt .. ": no results", vim.log.levels.WARN)
      return
    end

    if (not supports_filter or has_initial_query) and #candidates == 1 and opts.auto_select_single ~= false then
      on_choice(candidates[1])
      return
    end

    if supports_filter then
      open_candidates_picker(candidates, query)
      return
    end

    vim.ui.select(candidates, opts, on_choice)
  end

  if has_initial_query then
    choose(picker_filter.items(items, opts, opts.query), opts.query)
    return
  end

  choose(items, "")
end

function M.with_layout(opts)
  if intellij_grep then
    return vim.tbl_extend("force", opts, { layout = "intellij_grep" })
  end
  return opts
end

function M.is_intellij_grep_enabled()
  return intellij_grep
end

function M.set_intellij_grep(v)
  intellij_grep = v and true or false
end

function M.toggle_intellij_grep()
  M.set_intellij_grep(not M.is_intellij_grep_enabled())
  return M.is_intellij_grep_enabled()
end

function M.resume()
  if last_qf_title then
    vim.cmd("copen")
  else
    notify("No native search to resume", vim.log.levels.WARN)
  end
end

function M.setup(opts)
  opts = opts or {}
  local dashboard_opts = opts.dashboard
  local keymaps_opts = opts.keymaps
  local picker_opts = vim.deepcopy(opts)
  picker_opts.dashboard = nil
  picker_opts.keymaps = nil

  config.apply(picker_opts)
  if picker_opts.layout == "intellij_grep" then
    intellij_grep = true
  elseif picker_opts.layout then
    intellij_grep = false
  end

  require("picker.dashboard").setup(dashboard_opts)
  require("picker.git.status").setup_commands()

  if keymaps_opts == false or (type(keymaps_opts) == "table" and keymaps_opts.enabled == false) then
    return
  end
  require("picker.user_keymaps").apply(type(keymaps_opts) == "table" and keymaps_opts or {})
end

local util = require("picker.util")
local misc = require("picker.builtins.misc")
local buffers = require("picker.builtins.buffers")
local recent = require("picker.builtins.recent")
local grep = require("picker.builtins.grep")
local files = require("picker.builtins.files")
local git = require("picker.builtins.git")
local todos = require("picker.builtins.todos")

M.root = util.root
M.filters = util.filters
M.registers = misc.registers
M.command_history = misc.command_history
M.commands = misc.commands
M.diagnostics = misc.diagnostics
M.help = misc.help
M.keymaps = misc.keymaps
M.loclist = misc.loclist
M.qflist = misc.qflist
M.marks = misc.marks
M.notifications = misc.notifications
M.undo_history = misc.undo_history
M.buffers = buffers.buffers
M.delete_buffer = buffers.delete_buffer
M.delete_other_buffers = buffers.delete_other_buffers
M.recent_files = recent.recent_files
M.find_files = files.find_files
M.open_terminal = files.open_terminal
M.grep = grep.grep
M.grep_picker = grep.grep_picker
M.grep_word = grep.grep_word
M.grep_buffer = grep.grep_buffer
M.git_files = git.git_files
M.git_log = git.git_log
M.git_blame_line = git.git_blame_line
M.git_file_history = git.git_file_history
M.git_browse = git.git_browse
M.lazygit = git.lazygit
M.git_status_grep = git.git_status_grep
M.git_line_history = git.git_line_history
M.todos = todos.todos
M.todos_urgent = todos.todos_urgent

M.dashboard = require("picker.dashboard")
M.gutter = require("picker.gutter")

return M

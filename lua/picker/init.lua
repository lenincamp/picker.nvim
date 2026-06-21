local M = {}
local picker_config = require("picker.config")
local picker_filter = require("picker.filter")
local picker_filter_state = require("picker.filter_state")
local picker_keymaps = require("picker.keymaps")
local picker_layout_mod = require("picker.layout")
local picker_navigation = require("picker.navigation")
local picker_preview = require("picker.preview")
local picker_preview_window = require("picker.preview_window")
local picker_quickfix = require("picker.quickfix")
local picker_render = require("picker.render")
local picker_selection = require("picker.selection")
local picker_windows = require("picker.windows")

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
    local choosing_quick_filter = false
    local input_insert_mode = opts.input_mode == true
    local filter_generation = 0
    local selected = {}
    local page_start = 1
    local has_preview = type(opts.preview) == "function" or type(opts.preview_lines) == "function"
    local preview_enabled = has_preview and opts.preview_open == true
    local preview_maximized = false
    local show_descriptions = false
    local picker_layout = opts.layout or (intellij_grep and "intellij_grep" or "default")
    local layout
    local width, height

    local function calculate_layout()
      layout = picker_layout_mod.calculate({
        has_preview = has_preview,
        layout = picker_layout,
        input_mode = opts.input_mode,
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
        choosing_quick_filter = choosing_quick_filter,
        has_preview = has_preview,
        height = height,
        max_results = max_results,
        page_start = page_start,
        picker_layout = picker_layout,
        prompt = prompt,
        selected = selected,
        show_descriptions = show_descriptions,
        input_insert_mode = input_insert_mode,
        width = width,
      })
      page_start = rendered.page_start

      vim.bo[candidates_buf].modifiable = true
      vim.api.nvim_buf_set_lines(candidates_buf, 0, -1, false, rendered.lines)
      vim.bo[candidates_buf].modifiable = false
      picker_render.highlight(candidates_buf, picker_namespace, rendered)

      if vim.api.nvim_win_is_valid(candidates_win) then
        vim.api.nvim_win_set_cursor(candidates_win, { math.min(3, #rendered.lines), 0 })
      end
    end

    local function current_item()
      if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then return nil end
      local row = vim.api.nvim_win_get_cursor(candidates_win)[1]
      return current_candidates[page_start + row - 3]
    end

    local function close_preview()
      preview_win, preview_buf = picker_preview_window.close(preview_win, preview_buf)
    end

    local function update_preview()
      if not preview_enabled then return end
      preview_win, preview_buf = picker_preview_window.update(preview_win, preview_buf, {
        config = preview_config(),
        item = current_item(),
        namespace = preview_namespace,
        picker_opts = opts,
      })
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
      select_index(row - 2)
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
      if picker_navigation.move_cursor(candidates_win, current_candidates, page_start, height, delta) then
        update_preview()
      end
    end

    local function apply_filter_state(empty_message)
      local filter_state = {
        query = current_query,
        quick_filter = current_quick_filter,
        regex_pattern = current_regex_pattern,
      }
      local next_candidates
      if type(opts.dynamic_items) == "function" then
        local ok, dynamic = pcall(opts.dynamic_items, filter_state)
        next_candidates = ok and type(dynamic) == "table" and dynamic or {}
      else
        next_candidates = opts.input_only and {} or picker_filter_state.items(items, opts, filter_state)
      end
      if #next_candidates == 0 and not opts.input_mode then
        notify(empty_message or (prompt .. ": no results"), vim.log.levels.WARN)
        return false
      end

      current_filter_label = picker_filter_state.label(filter_state)
      current_candidates = next_candidates
      choosing_quick_filter = false
      page_start = 1
      if candidates_win and vim.api.nvim_win_is_valid(candidates_win) then
        vim.api.nvim_set_current_win(candidates_win)
      end
      render()
      update_preview()
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
      local next_start, changed = picker_navigation.page(current_candidates, page_start, height, delta)
      if changed then
        page_start = next_start
        render()
        update_preview()
        vim.cmd("normal! zz")
      end
    end

    local function page_up_or_top()
      local next_start, changed = picker_navigation.page_up_or_top(candidates_win, current_candidates, page_start, height)
      if changed then
        page_start = next_start
        update_preview()
        vim.cmd("normal! zz")
      end
    end

    local function jump_group(delta)
      local next_start, cursor_row = picker_navigation.jump_group(opts, candidates_win, current_candidates, page_start, height, delta)
      if cursor_row then
        page_start = next_start
        render()
        vim.api.nvim_win_set_cursor(candidates_win, { cursor_row, 0 })
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

    local function enter_insert_mode()
      if opts.input_mode then
        input_insert_mode = true
        render()
      end
    end

    local function exit_insert_mode()
      if opts.input_mode and input_insert_mode then
        input_insert_mode = false
        render()
        return true
      end
      return false
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
      vim.keymap.set("n", "<C-o>", function()
        if candidates_win and vim.api.nvim_win_is_valid(candidates_win) then
          vim.api.nvim_set_current_win(candidates_win)
        end
      end, preview_map_opts)
      vim.keymap.set("n", "q", function()
        if candidates_win and vim.api.nvim_win_is_valid(candidates_win) then
          vim.api.nvim_set_current_win(candidates_win)
        end
      end, preview_map_opts)
      vim.keymap.set("n", "<Esc>", function()
        if candidates_win and vim.api.nvim_win_is_valid(candidates_win) then
          vim.api.nvim_set_current_win(candidates_win)
        end
      end, preview_map_opts)
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
    end

    local function toggle_descriptions()
      show_descriptions = not show_descriptions
      render()
    end

    local function cancel_or_close()
      if exit_insert_mode() then
        return
      end
      if choosing_quick_filter then
        choosing_quick_filter = false
        render()
        return
      end
      close_candidates_window()
    end

    local function run_or_select_quick_filter(key, action)
      return function()
        if choosing_quick_filter then
          select_quick_filter_key(key)
          return
        end
        action()
      end
    end

    local function update_inline_query(next_query)
      local previous_query = current_query
      current_query = next_query or ""
      if opts.input_mode then
        filter_generation = filter_generation + 1
        local generation = filter_generation
        render()
        vim.defer_fn(function()
          if generation ~= filter_generation then
            return
          end
          if not candidates_buf or not vim.api.nvim_buf_is_valid(candidates_buf) then
            return
          end
          if not candidates_win or not vim.api.nvim_win_is_valid(candidates_win) then
            return
          end
          apply_filter_state(prompt .. ": no results for " .. current_query)
        end, tonumber(opts.debounce_ms) or 25)
        return
      end
      if not apply_filter_state(prompt .. ": no results for " .. current_query) then
        current_query = previous_query
      end
    end

    local function append_query(text)
      return function()
        if opts.input_mode and not input_insert_mode then
          return
        end
        if choosing_quick_filter then
          select_quick_filter_key(text)
          return
        end
        update_inline_query(current_query .. text)
      end
    end

    local function paste_query()
      local text = vim.fn.getreg("+")
      if text == "" then
        text = vim.fn.getreg("*")
      end
      if text == "" then
        text = vim.fn.getreg('"')
      end
      text = tostring(text or ""):gsub("[\r\n]+", " ")
      if text == "" then
        return
      end
      update_inline_query(current_query .. text)
    end

    local function backspace_query()
      if current_query == "" then
        return
      end
      update_inline_query(current_query:sub(1, -2))
    end

    local function clear_query()
      update_inline_query("")
    end

    local function toggle_selected()
      if not opts.multi_select then
        return
      end
      local item = current_item()
      if not item then
        return
      end
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

    picker_keymaps.setup({
      append_query = append_query,
      apply_quick_filter = apply_quick_filter,
      ask_filter = ask_filter,
      ask_quick_filter = ask_quick_filter,
      ask_regex_filter = ask_regex_filter,
      backspace_query = backspace_query,
      buffer = candidates_buf,
      cancel_or_close = cancel_or_close,
      clear_active_filters = clear_active_filters,
      clear_query = clear_query,
      enter_insert_mode = enter_insert_mode,
      exit_insert_mode = exit_insert_mode,
      focus_preview = focus_preview,
      is_insert_mode = function() return input_insert_mode end,
      is_choosing_quick_filter = function() return choosing_quick_filter end,
      jump_group = jump_group,
      move_cursor = move_cursor,
      open_quickfix = open_quickfix,
      open_split = open_split,
      opts = opts,
      page = page,
      page_up_or_top = page_up_or_top,
      paste_query = paste_query,
      run_action = run_action,
      run_or_select_quick_filter = run_or_select_quick_filter,
      scroll_preview_down = function() scroll_preview(height) end,
      scroll_preview_up = function() scroll_preview(-height) end,
      select_cursor = select_cursor,
      select_index = select_index,
      select_quick_filter_key = select_quick_filter_key,
      toggle_descriptions = toggle_descriptions,
      toggle_picker_layout = toggle_picker_layout,
      toggle_preview = toggle_preview,
      toggle_preview_zoom = toggle_preview_zoom,
      toggle_selected = toggle_selected,
    })

    render()
    update_preview()
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

function M.setup(opts)
  picker_config.apply(opts or {})
  if picker_config.current.layout then
    intellij_grep = picker_config.current.layout == "intellij_grep"
  end
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

function M.resume()
  if last_qf_title then
    vim.cmd("copen")
  else
    notify("No native search to resume", vim.log.levels.WARN)
  end
end

return M

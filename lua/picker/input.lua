local M = {}

local uv = vim.uv or vim.loop

local function single_line(value)
  return tostring(value or ""):gsub("[\r\n]+", " ")
end

local function input_text(buf)
  return single_line(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), " "))
end

local function schedule_change(state, opts, text, force)
  if state.closed then return end
  if not force and text == state.last_text then return end
  state.last_text = text
  state.timer:stop()
  local delay = state.debounce_ms > 0 and state.debounce_ms or 0
  state.timer:start(delay, 0, vim.schedule_wrap(function()
    if state.closed then return end
    if opts.on_change then opts.on_change(text) end
  end))
end

--- @class picker.InputState
--- @field buf number|nil
--- @field win number|nil
--- @field timer uv.uv_timer_t
--- @field autocmd_id number|nil
--- @field closed boolean

--- Create a 1-line input float.
--- @param opts table
---   - prompt: string
---   - row: number
---   - col: number
---   - width: number
---   - initial: string|nil
---   - debounce_ms: number (default 0; the caller debounces via update_inline_query)
---   - on_change: function(text)
---   - on_submit: function(text)
---   - on_close: function()
---   - on_normal_key: function(key) — dispatches normal-mode keys to picker actions
--- @return picker.InputState
function M.open(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local title = " " .. (opts.prompt or "Search") .. " "
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = opts.row,
    col = opts.col,
    width = opts.width,
    height = 1,
    style = "minimal",
    border = "single",
    title = title,
    title_pos = "left",
    zindex = opts.zindex or 65,
    focusable = true,
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  local state = {
    buf = buf,
    win = win,
    timer = uv.new_timer(),
    autocmd_id = nil,
    closed = false,
    debounce_ms = opts.debounce_ms or 0,
    last_text = opts.initial or "",
  }

  -- Set initial text and enter insert mode
  if opts.initial and opts.initial ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.initial })
    vim.api.nvim_win_set_cursor(win, { 1, #opts.initial })
  end
  vim.cmd("startinsert!")

  state.autocmd_id = vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged", "TextChangedP" }, {
    buffer = buf,
    callback = function()
      if state.closed then return end
      local text = input_text(buf)
      if vim.api.nvim_buf_line_count(buf) > 1 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
        if state.win and vim.api.nvim_win_is_valid(state.win) then
          vim.api.nvim_win_set_cursor(state.win, { 1, #text })
        end
      end
      schedule_change(state, opts, text, false)
    end,
  })

  local map_opts = { buffer = buf, silent = true, nowait = true }
  local function refresh()
    schedule_change(state, opts, input_text(buf), true)
  end

  local function paste_register()
    if not (state.win and vim.api.nvim_win_is_valid(state.win) and state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
      return
    end
    local regname = vim.v.register ~= "" and vim.v.register or '"'
    local text = single_line(vim.fn.getreg(regname))
    if text == "" and regname ~= "+" then
      text = single_line(vim.fn.getreg("+"))
    end
    if text == "" then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local line = input_text(state.buf)
    local col = math.max(0, math.min(cursor[2], #line))
    local next_text = line:sub(1, col) .. text .. line:sub(col + 1)
    vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, { next_text })
    vim.api.nvim_win_set_cursor(state.win, { 1, math.min(#next_text, col + #text) })
    schedule_change(state, opts, next_text, true)
    vim.cmd("startinsert!")
  end
  state.paste = paste_register
  state.refresh = refresh

  -- Insert-mode: CR submits, Esc goes to normal, ctrl keys navigate
  vim.keymap.set("i", "<CR>", function()
    if opts.on_submit then opts.on_submit(input_text(buf)) end
  end, map_opts)
  vim.keymap.set("i", "<Esc>", "<Esc>", map_opts)
  vim.keymap.set("i", "<C-r>", refresh, map_opts)
  vim.keymap.set("n", "p", paste_register, map_opts)
  vim.keymap.set("n", "P", paste_register, map_opts)
  vim.keymap.set("n", "<C-r>", refresh, map_opts)

  local insert_nav = { "<C-n>", "<C-p>", "<C-j>", "<C-k>", "<C-u>", "<C-d>", "<C-q>", "<Tab>", "<C-o>", "<C-f>", "<C-b>" }
  for _, key in ipairs(insert_nav) do
    vim.keymap.set("i", key, function()
      if opts.on_normal_key then opts.on_normal_key(key) end
    end, map_opts)
  end

  -- Normal-mode: delegate everything to picker via on_normal_key
  -- Only keep i/a/I/A for re-entering insert (native behavior)
  local normal_passthrough = {
    "<CR>", "<Esc>", "q", "j", "k", "J", "K",
    "<C-n>", "<C-p>", "<C-u>", "<C-d>", "<C-q>", "<C-r>", "<C-f>", "<C-b>",
    "<Tab>", "<C-o>", "<C-v>", "<C-x>", "<A-l>",
    "z", "F", "C", "R", "I", "/", "?",
    "]g", "[g",
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "<Space>", "m",
  }
  for _, key in ipairs(normal_passthrough) do
    vim.keymap.set("n", key, function()
      if opts.on_normal_key then opts.on_normal_key(key) end
    end, map_opts)
  end

  return state
end

--- Paste the active register into the input buffer and notify listeners.
--- @param state picker.InputState
function M.paste(state)
  if state and type(state.paste) == "function" then
    state.paste()
  end
end

--- Force the current input text through on_change.
--- @param state picker.InputState
function M.refresh(state)
  if state and type(state.refresh) == "function" then
    state.refresh()
  end
end

--- Close the input window and clean up.
--- @param state picker.InputState
function M.close(state)
  if state.closed then return end
  state.closed = true
  if not state.timer:is_closing() then
    state.timer:stop()
    state.timer:close()
  end
  if state.autocmd_id then
    pcall(vim.api.nvim_del_autocmd, state.autocmd_id)
    state.autocmd_id = nil
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state.win = nil
  state.buf = nil
end

--- Replace input text without triggering debounced on_change.
--- @param state picker.InputState
--- @param text string
function M.set_text(state, text)
  if state.closed or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  text = single_line(text or "")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { text })
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_cursor(state.win, { 1, #text })
  end
  state.last_text = text
end

--- Focus the input window in insert mode.
--- @param state picker.InputState
function M.focus(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    vim.cmd("startinsert!")
  end
end

return M

local M = {}

local function display_width(text)
  return vim.fn.strdisplaywidth(text)
end

function M.max_display_width(lines)
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, display_width(line))
  end
  return max_width
end

function M.menu_lines(buttons, icons)
  local rows = {}
  local max_prefix = 0

  for _, btn in ipairs(buttons) do
    local icon = (icons or {})[btn.key] or "•"
    local prefix = string.format("%s  [%s]", icon, btn.key)
    max_prefix = math.max(max_prefix, display_width(prefix))
    rows[#rows + 1] = { prefix = prefix, desc = btn.desc }
  end

  local lines = {}
  local max_width = 0
  for _, row in ipairs(rows) do
    local pad = math.max(1, max_prefix - display_width(row.prefix) + 2)
    local line = row.prefix .. string.rep(" ", pad) .. row.desc
    lines[#lines + 1] = line
    max_width = math.max(max_width, display_width(line))
  end

  for i, line in ipairs(lines) do
    local trailing = max_width - display_width(line)
    if trailing > 0 then
      lines[i] = line .. string.rep(" ", trailing)
    end
  end

  return lines
end

local function window_height()
  local ok_win, win = pcall(vim.api.nvim_get_current_win)
  if ok_win and win and vim.api.nvim_win_is_valid(win) then
    local ok_h, height = pcall(vim.api.nvim_win_get_height, win)
    if ok_h and type(height) == "number" and height > 0 then
      return height
    end
  end
  return vim.o.lines
end

local function window_width()
  local ok_win, win = pcall(vim.api.nvim_get_current_win)
  if ok_win and win and vim.api.nvim_win_is_valid(win) then
    local ok_w, width = pcall(vim.api.nvim_win_get_width, win)
    if ok_w and type(width) == "number" and width > 0 then
      return width
    end
  end
  return vim.o.columns
end

function M.content_lines(header, buttons, icons)
  local menu = M.menu_lines(buttons, icons)
  local max_height = window_height()
  local full_height = #header + 1 + #menu

  local hdr = header
  if full_height > max_height then
    local header_room = math.max(0, max_height - #menu - 1)
    local start = math.max(1, #header - header_room + 1)
    hdr = {}
    for i = start, #header do
      hdr[#hdr + 1] = header[i]
    end
  end

  local lines = vim.deepcopy(hdr)
  if #lines > 0 then
    lines[#lines + 1] = ""
  end

  for _, line in ipairs(menu) do
    lines[#lines + 1] = line
  end

  return lines
end

local function top_padding_lines(line_count)
  return math.max(0, math.floor((window_height() - line_count) / 2))
end

function M.centered_lines(header, buttons, icons)
  local lines = M.content_lines(header, buttons, icons)
  local centered = {}
  local content_width = M.max_display_width(lines)
  local block_pad = math.max(0, math.floor((window_width() - content_width) / 2))

  for _ = 1, top_padding_lines(#lines) do
    centered[#centered + 1] = ""
  end

  for _, line in ipairs(lines) do
    local inner_pad = math.max(0, math.floor((content_width - display_width(line)) / 2))
    centered[#centered + 1] = string.rep(" ", block_pad + inner_pad) .. line
  end

  return centered
end

function M.effective_width(header, buttons, icons)
  local content_width = math.max(40, M.max_display_width(M.content_lines(header, buttons, icons)) + 4)
  local max_for_screen = math.max(40, vim.o.columns - 2)
  return math.min(content_width, max_for_screen)
end

return M

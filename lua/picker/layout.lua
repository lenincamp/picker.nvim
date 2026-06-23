local M = {}

M.INPUT_OUTER_ROWS = 2
M.INPUT_ZINDEX = 65
M.PREVIEW_ZINDEX = 60

local function screen_size()
  return math.max(vim.o.columns, 20), math.max(vim.o.lines - vim.o.cmdheight - 2, 5)
end

function M.calculate(opts)
  opts = opts or {}
  local columns, rows = screen_size()
  local has_preview = opts.has_preview == true
  local input_mode = opts.input_mode == true
  local max_results = opts.max_results or 40
  local picker_layout = opts.layout or "default"

  local result = {
    columns = columns,
    rows = rows,
  }

  if input_mode and not has_preview then
    local intellij_input = picker_layout == "intellij_grep"
    result.width = intellij_input and math.max(40, columns - 4) or math.min(math.max(52, math.floor(columns * 0.5)), columns - 4)
    result.height = math.min(max_results + 3, math.max(6, math.min(10, rows - 2)))
    result.row = math.max(1, rows - result.height)
    result.col = intellij_input and 2 or math.max(2, math.floor((columns - result.width) / 2))
    result.preview_width = 0
    result.preview_height = 0
    result.preview_row = result.row
    result.preview_col = result.col
    return result
  end

  if has_preview and picker_layout == "intellij_grep" then
    result.width = math.max(40, columns - 4)
    result.height = math.min(max_results + 3, math.max(8, math.floor(rows * 0.34)))
    result.row = math.max(1, rows - result.height)
    result.col = 2
    result.preview_width = result.width
    result.preview_row = 1
    result.preview_col = result.col
    if input_mode then
      local s = opts.input_spacing or 0
      local input_row = math.max(0, result.row - M.INPUT_OUTER_ROWS - s)
      result.preview_height = math.max(5, input_row - result.preview_row - 1 - s)
    else
      result.preview_height = math.max(5, result.row - 2)
    end
    return result
  end

  local total_width = has_preview and math.min(math.max(90, math.floor(columns * 0.9)), columns - 4) or nil
  result.width = has_preview and math.min(math.max(50, math.floor(total_width * 0.55)), total_width - 32)
    or math.min(math.max(60, math.floor(columns * 0.72)), columns - 4)
  result.preview_width = has_preview and math.max(30, total_width - result.width - 2) or 0
  result.height = math.min(max_results + 3, rows - 2)
  result.row = math.max(1, math.floor((rows - result.height) / 2))
  result.col = math.max(2, math.floor((columns - (has_preview and total_width or result.width)) / 2))
  result.preview_height = result.height
  result.preview_row = result.row
  result.preview_col = result.col + result.width + 2

  if opts.position == "top" then
    result.row = 1
    result.col = 2
    result.preview_row = result.row
    result.preview_col = result.col + result.width + 2
  end

  return result
end

function M.input_row(candidates_row, spacing)
  local s = spacing or 0
  return math.max(0, candidates_row - M.INPUT_OUTER_ROWS - s)
end

function M.candidates_config(layout)
  return {
    relative = "editor",
    row = layout.row,
    col = layout.col,
    width = layout.width,
    height = layout.height,
    style = "minimal",
    border = "single",
    zindex = 50,
    focusable = true,
    noautocmd = true,
  }
end

function M.preview_config(layout, maximized)
  if maximized then
    return {
      relative = "editor",
      row = 1,
      col = 2,
      width = math.max(20, layout.columns - 4),
      height = math.max(5, layout.rows - 2),
      style = "minimal",
      border = "single",
      zindex = 80,
      focusable = false,
      noautocmd = true,
    }
  end

  return {
    relative = "editor",
    row = layout.preview_row,
    col = layout.preview_col,
    width = layout.preview_width,
    height = layout.preview_height,
    style = "minimal",
    border = "single",
    zindex = M.PREVIEW_ZINDEX,
    focusable = false,
    noautocmd = true,
  }
end

return M

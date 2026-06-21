local M = {}

local picker_filter = require("picker.filter")

function M.scroll_preview(preview_win, delta)
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    vim.api.nvim_win_call(preview_win, function()
      vim.cmd("normal! " .. math.abs(delta) .. (delta > 0 and "\5" or "\25"))
    end)
  end
end

function M.move_cursor(win, candidates, page_start, height, delta)
  if #candidates == 0 then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local last = math.min(#candidates - page_start + 3, math.max(3, height - 1))
  vim.api.nvim_win_set_cursor(win, { math.max(3, math.min(cursor[1] + delta, last)), 0 })
  return true
end

function M.page(candidates, page_start, height, delta)
  local total = #candidates
  local visible_limit = math.max(1, height - 3)
  if total <= visible_limit then
    return page_start, false
  end
  local max_start = math.floor((total - 1) / visible_limit) * visible_limit + 1
  return math.max(1, math.min(page_start + delta * visible_limit, max_start)), true
end

function M.page_up_or_top(win, candidates, page_start, height)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return page_start, false
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  if cursor[1] > 3 then
    vim.api.nvim_win_set_cursor(win, { 3, 0 })
    return page_start, true
  end
  return M.page(candidates, page_start, height, -1)
end

function M.jump_group(opts, win, candidates, page_start, height, delta)
  if type(opts.group_item) ~= "function" then return page_start, nil end
  local current_index = page_start + (vim.api.nvim_win_get_cursor(win)[1] - 3)
  local current_group = picker_filter.item_group(candidates[current_index], opts)
  local index = current_index
  while index >= 1 and index <= #candidates do
    index = index + delta
    local group = picker_filter.item_group(candidates[index], opts)
    if group and group ~= current_group then
      local visible_limit = math.max(1, height - 3)
      local next_start = math.floor((index - 1) / visible_limit) * visible_limit + 1
      return next_start, index - next_start + 3
    end
  end
  return page_start, nil
end

return M

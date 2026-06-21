local M = {}

function M.close(state)
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    pcall(vim.api.nvim_win_close, state.preview_win, true)
  end
  if state.preview_buf and vim.api.nvim_buf_is_valid(state.preview_buf) then
    pcall(vim.api.nvim_buf_delete, state.preview_buf, { force = true })
  end
  if state.candidates_win and vim.api.nvim_win_is_valid(state.candidates_win) then
    pcall(vim.api.nvim_win_close, state.candidates_win, true)
  end
  if state.candidates_buf and vim.api.nvim_buf_is_valid(state.candidates_buf) then
    pcall(vim.api.nvim_buf_delete, state.candidates_buf, { force = true })
  end
  state.candidates_win = nil
  state.candidates_buf = nil
  state.preview_win = nil
  state.preview_buf = nil
end

function M.open_candidates(layout_config)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"

  local ok, win = pcall(vim.api.nvim_open_win, bufnr, true, layout_config)
  if not ok then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    return nil, nil
  end

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  return win, bufnr
end

return M

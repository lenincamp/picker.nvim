local M = {}

M.defaults = {
  layout = "intellij_grep",
  max_results = 40,
  debounce_ms = 25,
  preview_max_bytes = 300000,
  preview_lines = 120,
}

M.current = vim.deepcopy(M.defaults)

function M.apply(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M

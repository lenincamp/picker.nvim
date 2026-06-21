local M = {}

function M.item_key(opts, item)
  if type(opts.item_key) == "function" then
    local ok, key = pcall(opts.item_key, item)
    if ok and key ~= nil then
      return tostring(key)
    end
  end
  if type(item) == "table" then
    return tostring(item.bufnr or item.path or item.filename or item.label or item.name or item)
  end
  return tostring(item)
end

function M.selected_items(items, opts, selected)
  local result = {}
  for _, item in ipairs(items) do
    if selected[M.item_key(opts, item)] then
      result[#result + 1] = item
    end
  end
  return result
end

return M

local M = {}

function M.item(item, opts)
  if opts and type(opts.quickfix_item) == "function" then
    local ok, qf = pcall(opts.quickfix_item, item)
    if ok and type(qf) == "table" then
      return qf
    end
  end

  if type(item) ~= "table" then
    return nil
  end

  local filename = item.filename or item.path
  if not filename then
    return nil
  end

  return {
    filename = filename,
    lnum = item.lnum or 1,
    col = item.col or 1,
    text = item.text or item.label or vim.fn.fnamemodify(filename, ":~:."),
  }
end

function M.items(items, opts)
  local qf_items = {}
  for _, item in ipairs(items) do
    local qf = M.item(item, opts)
    if qf then
      qf_items[#qf_items + 1] = qf
    end
  end
  return qf_items
end

return M

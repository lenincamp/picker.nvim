local M = {}

local function single_line(value)
  return tostring(value or ""):gsub("[\r\n]+", " ")
end

local function normalize_lines(value)
  if type(value) == "string" then
    local lines = vim.split(value, "\n", { plain = true })
    if #lines > 1 and lines[#lines] == "" then
      table.remove(lines)
    end
    return #lines > 0 and lines or { "" }
  end

  if type(value) ~= "table" then
    return { tostring(value or "") }
  end

  local lines = {}
  for _, line in ipairs(value) do
    if type(line) == "string" then
      lines[#lines + 1] = line
    elseif type(line) == "table" then
      for _, nested in ipairs(line) do
        lines[#lines + 1] = tostring(nested or "")
      end
    else
      lines[#lines + 1] = tostring(line or "")
    end
  end
  return #lines > 0 and lines or { "" }
end

function M.path(opts, item)
  if type(opts.preview) ~= "function" then return nil end
  local ok, path = pcall(opts.preview, item)
  return ok and type(path) == "string" and path or nil
end

function M.content(opts, item, render_width)
  if type(opts.preview_lines) ~= "function" then return nil end
  local ok, result = pcall(opts.preview_lines, item, render_width)
  if not ok then return false, { "Preview failed: " .. single_line(result) }, nil end

  if type(result) == "string" then
    return true, normalize_lines(result), nil
  end

  if type(result) == "table" and result.lines then
    return true, normalize_lines(result.lines), result.syntax, result.highlights
  end

  if type(result) == "table" then
    return true, normalize_lines(result), nil
  end

  return false, { "No preview available" }, nil
end

function M.target_lnum(opts, item)
  if type(opts.preview_lnum) ~= "function" then return nil end
  local ok, lnum = pcall(opts.preview_lnum, item)
  lnum = ok and tonumber(lnum) or nil
  return lnum and math.max(1, lnum) or nil
end

function M.allowed(opts, path, item)
  if not path or vim.fn.filereadable(path) ~= 1 then return false, "No readable preview" end
  local size = vim.fn.getfsize(path)
  if size < 0 or size > (opts.preview_max_bytes or 300000) then return false, "Preview skipped: file is too large" end
  local target_lnum = M.target_lnum(opts, item)
  local line_limit = math.max(opts.preview_lines or 120, target_lnum and (target_lnum + 60) or 0)
  local ok, lines = pcall(vim.fn.readfile, path, "", line_limit)
  if not ok then return false, "Preview failed: unable to read file" end
  for _, line in ipairs(lines) do
    if line:find("%z") then return false, "Preview skipped: binary file" end
  end
  return true, lines
end

function M.match(opts, item, lines)
  if type(opts.preview_match) ~= "function" then return nil end
  local ok, match = pcall(opts.preview_match, item, lines)
  return ok and type(match) == "table" and match or nil
end

function M.apply_match(bufnr, namespace, match, lines)
  if not (match and match.lnum and match.lnum >= 1 and match.lnum <= #lines) then
    return
  end

  vim.api.nvim_set_hl(0, "NativePickerPreviewLine", { link = "CursorLine", default = true })
  vim.api.nvim_set_hl(0, "NativePickerPreviewMatch", { link = "Search", default = true })
  vim.api.nvim_buf_set_extmark(bufnr, namespace, match.lnum - 1, 0, {
    line_hl_group = "NativePickerPreviewLine",
    hl_eol = true,
  })
  if match.col and match.length and match.length > 0 then
    local preview_line = lines[match.lnum] or ""
    local start_col = math.min(math.max(match.col - 1, 0), #preview_line)
    local end_col = math.min(start_col + match.length, #preview_line)
    if end_col > start_col then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, match.lnum - 1, start_col, {
        end_col = end_col,
        hl_group = "NativePickerPreviewMatch",
      })
    end
  end
end

return M

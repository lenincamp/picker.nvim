local util = require("picker.util")

local M = {}

function M.make_item(cwd, path)
  return {
    label = path,
    path = vim.fs.normalize(cwd .. "/" .. path),
  }
end

function M.collect_items(cwd, opts)
  opts = opts or {}
  local command = { "rg", "--files", "--glob", "!.git" }
  if opts.hidden or opts.all_files then
    command[#command + 1] = "--hidden"
  end
  if opts.ignored or opts.all_files then
    command[#command + 1] = "--no-ignore"
  end
  vim.list_extend(command, util.file_glob_args(opts.glob))

  local result = vim.system(command, { cwd = cwd, text = true }):wait()
  local stdout = result and result.stdout or ""
  local stderr = result and result.stderr or ""
  local lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
  if (result and result.code or 1) ~= 0 and #lines == 0 then
    return nil, vim.trim(stderr) ~= "" and vim.trim(stderr) or "No files found"
  end

  return vim.tbl_map(function(path)
    return M.make_item(cwd, path)
  end, lines)
end

return M

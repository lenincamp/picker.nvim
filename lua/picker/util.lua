local config = require("picker.config")

local M = {}

local root_cache = {}
local root_cache_ready = false

function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO)
end

function M.item_path(item)
  return type(item) == "table" and (item.path or item.filename or item.label or "") or tostring(item or "")
end

function M.path_has_extension(path, extensions)
  path = path:lower()
  for _, extension in ipairs(extensions) do
    if path:sub(-#extension) == extension then
      return true
    end
  end
  return false
end

local function ensure_root_cache_autocmd()
  if root_cache_ready then
    return
  end
  root_cache_ready = true

  vim.api.nvim_create_autocmd("BufFilePost", {
    group = vim.api.nvim_create_augroup("PickerRootCache", { clear = true }),
    callback = function(args)
      root_cache[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("PickerRootCacheCwd", { clear = true }),
    callback = function()
      root_cache = {}
    end,
  })
end

function M.root()
  ensure_root_cache_autocmd()
  local buf = vim.api.nvim_get_current_buf()
  if not root_cache[buf] then
    root_cache[buf] = vim.fs.root(buf, config.current.root_markers) or vim.fn.getcwd()
  end
  return root_cache[buf]
end

function M.filters()
  return config.current.filters or {}
end

function M.file_glob_args(globs)
  if type(globs) == "string" then
    globs = { globs }
  elseif type(globs) ~= "table" then
    globs = {}
  end
  local args = {}
  for _, glob in ipairs(globs) do
    args[#args + 1] = "--glob"
    args[#args + 1] = glob
  end
  return args
end

function M.regex_escape(text)
  return (text:gsub("([\\%^%$%(%)%%%.%[%]%*%+%-%?%|{}])", "\\%1"))
end

function M.selected_text_or_word()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local saved = vim.fn.getreg("z")
    local saved_type = vim.fn.getregtype("z")
    vim.cmd([[silent normal! "zy]])
    local text = vim.fn.getreg("z")
    vim.fn.setreg("z", saved, saved_type)
    return vim.trim(text)
  end
  return vim.fn.expand("<cword>")
end

return M

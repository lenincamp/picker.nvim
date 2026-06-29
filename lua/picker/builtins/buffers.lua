local config = require("picker.config")

local M = {}

local function buffer_path(info)
  return info and info.name ~= "" and info.name or nil
end

local function target_buffers(selected)
  local result = {}
  for _, info in ipairs(selected or {}) do
    if info and info.bufnr and vim.api.nvim_buf_is_valid(info.bufnr) then
      result[#result + 1] = info
    end
  end
  return result
end

local function default_delete_action()
  return {
    desc = "delete",
    fn = function(selected, _, ctx)
      for _, info in ipairs(target_buffers(selected)) do
        pcall(vim.cmd, "bdelete " .. info.bufnr)
      end
      if ctx and ctx.close then
        ctx.close()
      end
    end,
  }
end

function M.build_actions(opts)
  opts = opts or {}
  local actions = {
    ["<C-x>"] = default_delete_action(),
  }

  for lhs, action in pairs(config.current.buffer_actions or {}) do
    actions[lhs] = action
  end

  for lhs, action in pairs(opts.actions or {}) do
    actions[lhs] = action
  end

  return actions
end

function M.buffers(opts)
  opts = vim.tbl_extend("force", {
    prompt = "Buffers",
    scope = "session",
    multi_select = true,
  }, opts or {})

  local infos = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(infos, function(a, b)
    return a.bufnr < b.bufnr
  end)

  require("picker").select_items(infos, {
    prompt = opts.prompt,
    scope = opts.scope,
    search_threshold = 0,
    multi_select = opts.multi_select,
    item_key = function(info)
      return info.bufnr
    end,
    preview_open = opts.preview_open,
    preview = buffer_path,
    describe_item = function(info)
      local parts = {}
      if info.name == "" then
        parts[#parts + 1] = "scratch"
      else
        parts[#parts + 1] = vim.fn.fnamemodify(info.name, ":p:h")
      end
      if info.changed == 1 then
        parts[#parts + 1] = "modified"
      end
      if info.hidden == 1 then
        parts[#parts + 1] = "hidden"
      end
      return table.concat(parts, "  ")
    end,
    actions = M.build_actions(opts),
    format_item = function(info)
      local name = info.name ~= "" and vim.fn.fnamemodify(info.name, ":~:.") or "[No Name]"
      return string.format("%d %s%s", info.bufnr, name, info.changed == 1 and " [+]" or "")
    end,
  }, function(info)
    if info then
      vim.cmd("buffer " .. info.bufnr)
    end
  end)
end

function M.delete_buffer()
  vim.cmd("bdelete")
end

function M.delete_other_buffers()
  local current = vim.api.nvim_get_current_buf()
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.bufnr ~= current then
      pcall(vim.cmd, "bdelete " .. info.bufnr)
    end
  end
end

return M

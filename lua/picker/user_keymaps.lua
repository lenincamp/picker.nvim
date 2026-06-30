local M = {}

local function picker()
  return require("picker")
end

---@type table[]
local specs = {
  {
    mode = "n",
    lhs = "<leader>fF",
    desc = "Find Files (root)",
    action = function()
      local p = picker()
      p.find_files({ cwd = p.root(), title = "Find Files (root)", input_mode = true, layout = "intellij_grep" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>fc",
    desc = "Config Files",
    action = function()
      picker().find_files({ cwd = vim.fn.stdpath("config"), title = "Config Files" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>ff",
    desc = "Find Files (cwd)",
    action = function()
      picker().find_files({ title = "Find Files (cwd)", input_mode = true, layout = "intellij_grep" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>fi",
    desc = "Find Ignored Files (cwd)",
    action = function()
      picker().find_files({ ignored = true, title = "Find Ignored Files (cwd)" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>fI",
    desc = "Find Ignored Files (root)",
    action = function()
      local p = picker()
      p.find_files({ cwd = p.root(), ignored = true, title = "Find Ignored Files (root)" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>fg",
    desc = "Find Git Files",
    action = function()
      picker().git_files({ title = "Find Git Files" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>fR",
    desc = "Recent Files (cwd)",
    action = function()
      picker().recent_files({ title = "Recent Files (cwd)" })
    end
  },
  { mode = "n",               lhs = "<leader>fn", desc = "New File",              rhs = "<cmd>enew<cr>" },
  { mode = "n",               lhs = "<leader>sb", desc = "Search Buffers",        action = function() picker().buffers() end },
  { mode = { "n", "i", "x" }, lhs = "<leader>sy", desc = "Registers / Clipboard", action = function() picker().registers() end },
  { mode = "n",               lhs = "<leader>sc", desc = "Command History",       action = function() picker()
        .command_history() end },
  { mode = "n",               lhs = "<leader>sC", desc = "Commands",              action = function() picker().commands() end },
  { mode = "n",               lhs = "<leader>sd", desc = "Document Diagnostics",  action = function() picker()
        .diagnostics({ buffer = true }) end },
  { mode = "n",               lhs = "<leader>sD", desc = "Workspace Diagnostics", action = function() picker()
        .diagnostics() end },
  {
    mode = "n",
    lhs = "<leader>sG",
    desc = "Grep (root)",
    action = function()
      local p = picker()
      p.grep_picker({ cwd = p.root(), title = "Grep (root)" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>sg",
    desc = "Grep (cwd)",
    action = function()
      picker().grep_picker({ title = "Grep (cwd)" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>s/",
    desc = "Grep (root)",
    action = function()
      local p = picker()
      p.grep({ cwd = p.root(), title = "Grep (root)" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>si",
    desc = "Grep Ignored (cwd)",
    action = function()
      picker().grep({ ignored = true, title = "Grep Ignored (cwd)" })
    end
  },
  {
    mode = "n",
    lhs = "<leader>sI",
    desc = "Grep Ignored (root)",
    action = function()
      local p = picker()
      p.grep({ cwd = p.root(), ignored = true, title = "Grep Ignored (root)" })
    end
  },
  { mode = "n", lhs = "<leader>sh", desc = "Help",                  action = function() picker().help() end },
  { mode = "n", lhs = "<leader>sk", desc = "Keymaps",               action = function() picker().keymaps() end },
  { mode = "n", lhs = "<leader>sl", desc = "Location List",         action = function() picker().loclist() end },
  { mode = "n", lhs = "<leader>sm", desc = "Marks",                 action = function() picker().marks() end },
  { mode = "n", lhs = "<leader>sn", desc = "Notifications",         action = function() picker().notifications() end },
  { mode = "n", lhs = "<leader>sq", desc = "Quickfix List",         action = function() picker().qflist() end },
  { mode = "n", lhs = "<leader>sr", desc = "Resume Last Search",    action = function() picker().resume() end },
  { mode = "n", lhs = "<leader>su", desc = "Undo History",          action = function() picker().undo_history() end },
  {
    mode = { "n", "x" },
    lhs = "<leader>sW",
    desc = "Search Word (root)",
    action = function()
      local p = picker()
      p.grep_word({ cwd = p.root() })
    end
  },
  { mode = { "n", "x" }, lhs = "<leader>sw", desc = "Search Word (cwd)",                     action = function() picker()
        .grep_word({}) end },
  { mode = "n",          lhs = "<leader>/",  desc = "Fast search text in current file (rg)", action = function() picker()
        .grep_buffer() end },
  { mode = "n",          lhs = "<leader>bd", desc = "Delete Buffer",                         action = function() picker()
        .delete_buffer() end },
  { mode = "n",          lhs = "<leader>bo", desc = "Delete Other Buffers",                  action = function() picker()
        .delete_other_buffers() end },
  {
    mode = "n",
    lhs = "<leader>gG",
    desc = "Lazygit (root)",
    condition = function() return vim.fn.executable("lazygit") == 1 end,
    action = function()
      local p = picker()
      p.lazygit(p.root())
    end
  },
  {
    mode = "n",
    lhs = "<leader>gg",
    desc = "Lazygit (cwd)",
    condition = function() return vim.fn.executable("lazygit") == 1 end,
    action = function()
      picker().lazygit(vim.fn.getcwd())
    end
  },
  { mode = "n",          lhs = "<leader>gl", desc = "Git Log (cwd)",         action = function() picker().git_log(vim.fn
    .getcwd()) end },
  { mode = "n",          lhs = "<leader>gb", desc = "Git Blame Line",        action = function() picker().git_blame_line() end },
  { mode = "n",          lhs = "<leader>gf", desc = "Git File History",      action = function() picker()
        .git_file_history() end },
  { mode = "n",          lhs = "<leader>gL", desc = "Git Log (root)",        action = function() picker().git_log(picker()
    .root()) end },
  { mode = { "n", "x" }, lhs = "<leader>gB", desc = "Git Browse (open)",     action = function() picker().git_browse(false) end },
  { mode = { "n", "x" }, lhs = "<leader>gY", desc = "Git Browse (copy URL)", action = function() picker().git_browse(true) end },
}

function M.specs()
  return specs
end

function M.lazy_keys()
  local keys = {}
  for _, spec in ipairs(specs) do
    keys[#keys + 1] = { spec.lhs, mode = spec.mode, desc = spec.desc }
  end
  return keys
end

function M.apply(opts)
  opts = opts or {}
  local disabled = {}
  for _, lhs in ipairs(opts.disable or {}) do
    disabled[lhs] = true
  end

  for _, spec in ipairs(specs) do
    if disabled[spec.lhs] then
      goto continue
    end
    if spec.condition == nil or spec.condition() then
      vim.keymap.set(spec.mode, spec.lhs, spec.rhs or spec.action, { desc = spec.desc, silent = true })
    end
    ::continue::
  end
end

return M

local picker_config = require("picker.config")
local util = require("picker.util")

local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO)
end

function M.project_roots()
  local roots = {}
  local seen = {}
  local home = vim.fs.normalize(vim.loop.os_homedir())
  local markers = picker_config.current.project_markers
  for _, path in ipairs(vim.v.oldfiles or {}) do
    local dir = vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(path, ":p")))
    local root = dir and vim.fs.root(dir, markers) or nil
    root = root or dir
    root = root and vim.fs.normalize(root) or nil
    if root and root ~= "" and root ~= home and not seen[root] and vim.fn.isdirectory(root) == 1 then
      seen[root] = true
      roots[#roots + 1] = { label = vim.fn.fnamemodify(root, ":~"), path = root }
    end
  end
  table.sort(roots, function(a, b)
    return a.label < b.label
  end)
  return roots
end

local function select_recent_project()
  local picker = require("picker")
  local projects = M.project_roots()
  if #projects == 0 then
    notify("No recent projects", vim.log.levels.INFO)
    return
  end

  picker.select_items(projects, {
    prompt = "Recent Projects",
    scope = "global",
    search_threshold = 0,
    input_mode = true,
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if not item then
      return
    end
    vim.cmd("cd " .. vim.fn.fnameescape(item.path))
    picker.find_files({ prompt = "Find Files: " .. item.label, cwd = item.path, input_mode = true })
  end)
end

local builtin = {
  files = function()
    require("picker").find_files({ prompt = "Find File", input_mode = true })
  end,
  grep = function()
    require("picker").grep({ prompt = "Search in Files", cwd = util.root(), input_mode = true })
  end,
  recent = function()
    require("picker").recent_files({ prompt = "Recent Files", global = true })
  end,
  projects = select_recent_project,
  config = function()
    require("picker").find_files({
      prompt = "Config Files",
      cwd = vim.fn.stdpath("config"),
      input_mode = true,
    })
  end,
  session = function()
    notify("Dashboard session action is not configured", vim.log.levels.INFO)
  end,
  new = function()
    vim.cmd("enew")
  end,
  quit = function()
    vim.cmd("qa")
  end,
}

function M.run(action)
  if type(action) == "function" then
    action()
    return
  end
  if type(action) ~= "string" or action == "" then
    return
  end

  local custom = require("picker.dashboard.config").current.actions[action]
  if type(custom) == "function" then
    custom()
    return
  end

  local handler = builtin[action]
  if handler then
    handler()
    return
  end

  notify("Unknown dashboard action: " .. action, vim.log.levels.WARN)
end

return M

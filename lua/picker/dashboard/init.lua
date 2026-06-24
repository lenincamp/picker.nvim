local config_mod = require("picker.dashboard.config")
local content = require("picker.dashboard.content")
local view = require("picker.dashboard.view")
local window = require("picker.dashboard.window")
local actions = require("picker.dashboard.actions")

local M = {}

M._setup_done = false

local function dashboard_keymap_opts(bufnr, desc)
  return {
    buffer = bufnr,
    silent = true,
    nowait = true,
    noremap = true,
    desc = desc,
  }
end

local function cleanup_shadow_buffers()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local bt = vim.bo[buf].buftype
      local modified = vim.bo[buf].modified
      if name == "" and bt == "" and not modified then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

local function apply_keymaps(bufnr)
  if vim.b[bufnr].picker_dashboard_keymaps_applied then
    return
  end

  for _, btn in ipairs(config_mod.current.buttons) do
    vim.keymap.set("n", btn.key, function()
      actions.run(btn.action)
    end, dashboard_keymap_opts(bufnr, "Dashboard: " .. btn.desc))
  end

  vim.b[bufnr].picker_dashboard_keymaps_applied = true
end

local function disable_miniclue(bufnr)
  vim.b[bufnr].miniclue_disable = true
  pcall(function()
    require("mini.clue").disable_buf_triggers(bufnr)
  end)
end

local function refresh_keymaps_after_lazyload()
  -- Run after other LazyLoad handlers (e.g. mini.clue ensure_buf_triggers).
  vim.schedule(function()
    vim.schedule(function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and window.is_dashboard_buffer(bufnr) then
          disable_miniclue(bufnr)
          vim.b[bufnr].picker_dashboard_keymaps_applied = nil
          apply_keymaps(bufnr)
        end
      end
    end)
  end)
end

local function setup_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not window.is_dashboard_buffer(bufnr) then
    return
  end

  disable_miniclue(bufnr)
  window.apply_options()
  apply_keymaps(bufnr)

  if not vim.b[bufnr].picker_dashboard_cleanup_done then
    vim.b[bufnr].picker_dashboard_cleanup_done = true
    vim.schedule(cleanup_shadow_buffers)
  end
end

function M.centered_header_lines()
  local cfg = config_mod.current
  return content.centered_lines(cfg.header, cfg.buttons, cfg.icons)
end

function M.effective_width()
  local cfg = config_mod.current
  return content.effective_width(cfg.header, cfg.buttons, cfg.icons)
end

function M.open()
  view.setup_highlights()
  local cfg = config_mod.current
  local bufnr = vim.api.nvim_get_current_buf()

  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = cfg.filetype
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, M.centered_header_lines())
  vim.bo[bufnr].modifiable = false
  view.apply_highlights(bufnr)

  window.save_restore_state()
  window.apply_options()
  setup_buffer(bufnr)
end

function M.setup(opts)
  config_mod.apply(opts)

  if M._setup_done then
    view.setup_highlights()
    return
  end
  M._setup_done = true

  view.setup_highlights()

  vim.api.nvim_create_user_command("Dashboard", M.open, { desc = "Open picker dashboard" })

  local legacy_patterns = vim.list_extend({ config_mod.current.filetype }, config_mod.current.legacy_filetypes or {})

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("PickerDashboardFileType", { clear = true }),
    pattern = legacy_patterns,
    callback = function(args)
      setup_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("PickerDashboardBufEnter", { clear = true }),
    callback = function(args)
      setup_buffer(args.buf)
      local win = vim.api.nvim_get_current_win()
      if not window.is_dashboard_buffer(args.buf) and window.has_pending_restore(win) then
        window.restore_options(win)
      end
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("PickerDashboardColorScheme", { clear = true }),
    callback = function()
      view.refresh_open_buffers()
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = vim.api.nvim_create_augroup("PickerDashboardBackground", { clear = true }),
    pattern = "background",
    callback = function()
      view.refresh_open_buffers()
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("PickerDashboardVimEnter", { clear = true }),
    callback = function()
      if window.should_open() then
        M.open()
      end
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("PickerDashboardLazyLoad", { clear = true }),
    pattern = "LazyLoad",
    callback = refresh_keymaps_after_lazyload,
  })
end

return M

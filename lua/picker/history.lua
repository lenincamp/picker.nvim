local config = require("picker.config")

local M = {}

local stores = {}
local flush_setup = false

local function safe_scope(scope)
  return (scope or "global"):gsub("[^%w%-_%.]", "_")
end

local function history_path(scope)
  return vim.fn.stdpath("data") .. "/picker/history/" .. safe_scope(scope) .. ".json"
end

local function normalize_entry(entry)
  entry = entry or {}
  return {
    query = vim.trim(entry.query or ""),
    filter_key = entry.filter_key,
    regex_pattern = entry.regex_pattern,
    all_files = entry.all_files == true,
  }
end

local function empty_entry(entry)
  entry = normalize_entry(entry)
  return entry.query == ""
    and entry.filter_key == nil
    and entry.regex_pattern == nil
    and not entry.all_files
end

local function load_entries(scope)
  local path = history_path(scope)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(decoded) ~= "table" then
    return {}
  end
  local entries = {}
  for _, entry in ipairs(decoded) do
    if type(entry) == "table" and not empty_entry(entry) then
      entries[#entries + 1] = normalize_entry(entry)
    end
  end
  return entries
end

local function persist(store)
  if not store.dirty then
    return
  end
  local path = history_path(store.scope)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode(store.entries) }, path)
  store.dirty = false
end

local function trim_store(store)
  while #store.entries > store.max do
    table.remove(store.entries, 1)
    store.idx = math.max(1, store.idx - 1)
    store.cursor = math.max(1, store.cursor - 1)
  end
end

local function get_store(scope)
  if stores[scope] then
    return stores[scope]
  end
  local store = {
    scope = scope,
    entries = load_entries(scope),
    idx = 1,
    cursor = 1,
    max = config.current.filter_history_max or 100,
    dirty = false,
  }
  store.idx = #store.entries + 1
  store.cursor = store.idx
  stores[scope] = store
  return store
end

local function ensure_flush_autocmd()
  if flush_setup then
    return
  end
  flush_setup = true
  vim.api.nvim_create_autocmd("ExitPre", {
    group = vim.api.nvim_create_augroup("PickerHistoryFlush", { clear = true }),
    callback = function()
      for _, store in pairs(stores) do
        persist(store)
      end
    end,
  })
end

--- @class picker.History
--- @field store table
local History = {}
History.__index = History

function M.new(scope)
  ensure_flush_autocmd()
  return setmetatable({ store = get_store(scope) }, History)
end

function History:at_tip()
  return self.store.cursor == self.store.idx
end

function History:stage(entry)
  entry = normalize_entry(entry)
  if empty_entry(entry) then
    return
  end

  local previous = self.store.entries[self.store.idx - 1]
  if previous and vim.deep_equal(previous, entry) then
    return
  end

  if self.store.cursor < self.store.idx then
    for i = self.store.cursor + 1, #self.store.entries do
      self.store.entries[i] = nil
    end
    self.store.idx = self.store.cursor
  end

  self.store.entries[self.store.idx] = entry
  for i = self.store.idx + 1, #self.store.entries do
    self.store.entries[i] = nil
  end
  self.store.dirty = true
end

function History:commit(entry)
  if not self:at_tip() then
    return
  end
  self:stage(entry)
  trim_store(self.store)
  self.store.idx = #self.store.entries + 1
  self.store.cursor = self.store.idx
end

function History:back(entry)
  if self:at_tip() then
    self:stage(entry)
  end
  if self.store.cursor <= 1 then
    return nil
  end
  self.store.cursor = self.store.cursor - 1
  return self.store.entries[self.store.cursor]
end

function History:forward()
  if self.store.cursor >= self.store.idx then
    return nil
  end
  self.store.cursor = self.store.cursor + 1
  return self.store.entries[self.store.cursor]
end

function History:flush()
  persist(self.store)
end

return M

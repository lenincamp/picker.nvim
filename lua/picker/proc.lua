local M = {}

local uv = vim.uv or vim.loop

--- @class picker.ProcHandle
--- @field handle uv.uv_process_t|nil
--- @field stdout uv.uv_pipe_t|nil
--- @field pid number|nil
--- @field aborted boolean

--- Kill a running process handle.
--- @param proc picker.ProcHandle
local function kill_proc(proc)
  if proc.aborted then return end
  proc.aborted = true
  if proc.stdout and not proc.stdout:is_closing() then
    proc.stdout:read_stop()
    proc.stdout:close()
  end
  if proc.handle and not proc.handle:is_closing() then
    proc.handle:kill("sigterm")
    local handle = proc.handle
    vim.defer_fn(function()
      if handle and not handle:is_closing() then
        handle:kill("sigkill")
      end
    end, 200)
  end
end

--- Spawn an async process and stream parsed lines to a callback.
---
--- @param opts table
---   - cmd: string (executable)
---   - args: string[] (arguments)
---   - cwd: string|nil (working directory)
---   - limit: number|nil (max items, default 5000)
---   - transform: function(line) -> item|nil (parse stdout line into picker item)
---   - on_items: function(items) (called on main thread with accumulated results)
---   - on_done: function(items)|nil (called on main thread when process exits)
--- @return picker.ProcHandle
function M.spawn(opts)
  local stdout = uv.new_pipe()
  local proc = { handle = nil, stdout = stdout, pid = nil, aborted = false }
  local limit = opts.limit or 5000
  local items = {}
  local remainder = ""
  local transform = opts.transform
  local on_items = opts.on_items
  local on_done = opts.on_done
  local flush_timer = uv.new_timer()
  local flush_scheduled = false
  local exit_code = nil
  local stdout_done = false
  local finished = false
  local pending_data = {}

  local function stop_at_limit()
    pending_data = {}
    remainder = ""
    stdout_done = true
    if proc.stdout and not proc.stdout:is_closing() then
      proc.stdout:read_stop()
    end
    if proc.handle and not proc.handle:is_closing() then
      proc.handle:kill("sigterm")
    end
  end

  local function add_line(line)
    if line:sub(-1) == "\r" then line = line:sub(1, -2) end
    if transform then
      local item = transform(line)
      if item then
        items[#items + 1] = item
      end
    else
      items[#items + 1] = line
    end
  end

  local function schedule_flush()
    if flush_scheduled or proc.aborted then return end
    flush_scheduled = true
    -- Flush at 50ms intervals to avoid overwhelming the UI event loop
    flush_timer:start(50, 0, function()
      flush_scheduled = false
      if proc.aborted then return end
      if #items == 0 then return end
      -- Pass the items table directly (no copy); receiver should not mutate
      local current = items
      vim.schedule(function()
        if not proc.aborted and on_items then
          on_items(current)
        end
      end)
    end)
  end

  -- Process at most BATCH_SIZE lines per event loop tick to avoid blocking the UI
  local BATCH_SIZE = 200
  local processing = false

  local function drain_pending()
    if processing or proc.aborted then return end
    processing = true
    local batch_count = 0
    while #pending_data > 0 and batch_count < BATCH_SIZE do
      if #items >= limit then
        pending_data = {}
        stop_at_limit()
        processing = false
        return
      end
      local chunk = table.remove(pending_data, 1)
      remainder = remainder .. chunk
      local from = 1
      while true do
        local nl = remainder:find("\n", from, true)
        if not nl then
          remainder = remainder:sub(from)
          break
        end
        local line = remainder:sub(from, nl - 1)
        from = nl + 1
        batch_count = batch_count + 1
        if #items >= limit then
          remainder = ""
          pending_data = {}
          stop_at_limit()
          processing = false
          return
        end
        add_line(line)
        if batch_count >= BATCH_SIZE then
          -- Save unprocessed part of this chunk
          local leftover = remainder:sub(from)
          remainder = ""
          if leftover ~= "" then
            table.insert(pending_data, 1, leftover)
          end
          schedule_flush()
          processing = false
          -- Yield: schedule next batch on next event loop tick
          vim.schedule(drain_pending)
          return
        end
      end
    end
    schedule_flush()
    processing = false
    -- If more data arrived while we were processing, continue
    if #pending_data > 0 and not proc.aborted then
      vim.schedule(drain_pending)
    end
  end

  local function drain_all_pending()
    if processing or proc.aborted then return end
    processing = true
    while #pending_data > 0 do
      if #items >= limit then
        pending_data = {}
        stop_at_limit()
        processing = false
        return
      end
      remainder = remainder .. table.remove(pending_data, 1)
      local from = 1
      while true do
        local nl = remainder:find("\n", from, true)
        if not nl then
          remainder = remainder:sub(from)
          break
        end
        if #items >= limit then
          remainder = ""
          pending_data = {}
          stop_at_limit()
          processing = false
          return
        end
        add_line(remainder:sub(from, nl - 1))
        from = nl + 1
      end
    end
    if remainder ~= "" and #items < limit then
      add_line(remainder)
      remainder = ""
    end
    processing = false
  end

  local function finish_if_done()
    if finished or proc.aborted or exit_code == nil or not stdout_done then
      return
    end
    finished = true
    if not flush_timer:is_closing() then
      flush_timer:stop()
      flush_timer:close()
    end
    if proc.stdout and not proc.stdout:is_closing() then
      proc.stdout:close()
    end
    vim.schedule(function()
      if not proc.aborted then
        if on_items and #items > 0 then
          on_items(items)
        end
        if on_done then
          on_done(items, exit_code)
        end
      end
    end)
  end

  local function on_stdout(err, data)
    if err or not data then
      drain_all_pending()
      stdout_done = true
      finish_if_done()
      return
    end
    if proc.aborted then return end
    pending_data[#pending_data + 1] = data
    drain_pending()
  end

  local handle, pid = uv.spawn(opts.cmd, {
    args = opts.args,
    cwd = opts.cwd,
    stdio = { nil, stdout, nil },
  }, function(code, _signal)
    exit_code = code
    proc.handle:close()
    proc.handle = nil
    finish_if_done()
  end)

  if not handle then
    if not flush_timer:is_closing() then flush_timer:close() end
    if not stdout:is_closing() then stdout:close() end
    vim.schedule(function()
      if on_done then on_done({}, -1) end
    end)
    return proc
  end

  proc.handle = handle
  proc.pid = pid
  stdout:read_start(on_stdout)
  return proc
end

--- Abort a running process.
--- @param proc picker.ProcHandle|nil
function M.abort(proc)
  if proc then
    kill_proc(proc)
  end
end

return M

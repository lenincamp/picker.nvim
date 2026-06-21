local M = {}

local function normalize_token(token)
  return (token or ""):gsub("^[\"']+", ""):gsub("[\"']+$", "")
end

local function query_tokens(query)
  local tokens = {}
  for token in vim.trim(query or ""):lower():gmatch("%S+") do
    token = normalize_token(token)
    if token ~= "" then
      tokens[#tokens + 1] = {
        glob = token:find("[*?]") ~= nil,
        text = token,
      }
    end
  end
  return tokens
end

local function is_separator(char)
  return char == "/" or char == "\\"
end

function M.item_label(item, opts)
  if opts and type(opts.format_item) == "function" then
    return opts.format_item(item)
  end
  if type(item) == "table" then
    return item.label or item.path or item.name or vim.inspect(item)
  end
  return tostring(item)
end

function M.item_group(item, opts)
  if opts and type(opts.group_item) == "function" then
    local ok, group = pcall(opts.group_item, item)
    return ok and group or nil
  end
  return type(item) == "table" and item.group or nil
end

function M.item_matches(label, query)
  query = vim.trim(query or "")
  if query == "" then
    return true
  end

  local function glob_pattern(token)
    local escaped = vim.pesc(token)
    return escaped:gsub("%%%*", ".*"):gsub("%%%?", ".")
  end

  label = label:lower()
  for token in query:lower():gmatch("%S+") do
    token = normalize_token(token)
    if token == "" then
      return true
    end
    if token:find("[*?]") then
      if not label:find(glob_pattern(token)) then
        return false
      end
    elseif not label:find(token, 1, true) then
      return false
    end
  end
  return true
end

local function fuzzy_positions(lower_label, token)
  local positions = {}
  local cursor = 1

  for index = 1, #token do
    local char = token:sub(index, index)
    local found = lower_label:find(char, cursor, true)
    if not found then
      return nil
    end
    positions[#positions + 1] = found
    cursor = found + 1
  end

  return positions
end

local function fuzzy_token_score(lower_label, token)
  local cursor = 1
  local first = nil
  local previous = nil
  local score = 0

  for index = 1, #token do
    local found = lower_label:find(token:sub(index, index), cursor, true)
    if not found then
      return nil
    end
    first = first or found
    if previous and found == previous + 1 then
      score = score + 12
    end
    previous = found
    cursor = found + 1
  end

  return score + 100 - first
end

local function basename_segment(lower_label)
  local start = 1
  for index = #lower_label, 1, -1 do
    if is_separator(lower_label:sub(index, index)) then
      start = index + 1
      break
    end
  end
  return lower_label:sub(start), start
end

local function basename_score(lower_label, token)
  local segment, offset = basename_segment(lower_label)
  if #token > #segment then
    return nil
  end
  if not segment:find(token:sub(1, 1), 1, true) or not segment:find(token:sub(-1), 1, true) then
    return nil
  end
  return fuzzy_token_score(segment, token), offset, segment
end

local function basename_positions(lower_label, token)
  local score, offset, segment = basename_score(lower_label, token)
  local positions = score and fuzzy_positions(segment, token) or nil
  if positions then
    for index, position in ipairs(positions) do
      positions[index] = offset + position - 1
    end
  end
  return positions
end

local function fuzzy_score(label, tokens)
  if #tokens == 0 then
    return 0
  end

  local score = 0
  local lower = label:lower()
  for _, token in ipairs(tokens) do
    if token.glob then
      if not M.item_matches(label, token.text) then
        return nil
      end
      score = score + 20
    else
      local exact_from = lower:find(token.text, 1, true)
      if exact_from then
        score = score + 180 - exact_from
      elseif #token.text >= 4 then
        local token_score = basename_score(lower, token.text)
        if not token_score then
          return nil
        end
        score = score + token_score
      else
        local token_score = fuzzy_token_score(lower, token.text)
        if not token_score then
          return nil
        end
        score = score + token_score
      end
    end
  end

  return score
end

local function better(a, b)
  if a.score ~= b.score then
    return a.score > b.score
  end
  return a.label < b.label
end

local function worse(a, b)
  return better(b, a)
end

local function heap_sift_up(heap, index)
  while index > 1 do
    local parent = math.floor(index / 2)
    if not worse(heap[index], heap[parent]) then
      break
    end
    heap[index], heap[parent] = heap[parent], heap[index]
    index = parent
  end
end

local function heap_sift_down(heap, index)
  local size = #heap
  while true do
    local left = index * 2
    local right = left + 1
    local smallest = index
    if left <= size and worse(heap[left], heap[smallest]) then
      smallest = left
    end
    if right <= size and worse(heap[right], heap[smallest]) then
      smallest = right
    end
    if smallest == index then
      break
    end
    heap[index], heap[smallest] = heap[smallest], heap[index]
    index = smallest
  end
end

local function heap_push(heap, entry, limit)
  if #heap < limit then
    heap[#heap + 1] = entry
    heap_sift_up(heap, #heap)
    return
  end
  if better(entry, heap[1]) then
    heap[1] = entry
    heap_sift_down(heap, 1)
  end
end

function M.match_positions(label, query)
  local all = {}
  query = vim.trim(query or "")
  if query == "" then
    return all
  end

  for token in query:gmatch("%S+") do
    token = normalize_token(token)
    if not token:find("[*?]") then
      local positions = fuzzy_positions(label:lower(), token:lower())
      if positions then
        vim.list_extend(all, positions)
      end
    end
  end
  return all
end

local function append_position_ranges(ranges, positions)
  if not positions or #positions == 0 then
    return
  end

  local from = positions[1]
  local previous = positions[1]
  for index = 2, #positions do
    local position = positions[index]
    if position ~= previous + 1 then
      ranges[#ranges + 1] = { from = from, to = previous }
      from = position
    end
    previous = position
  end
  ranges[#ranges + 1] = { from = from, to = previous }
end

function M.match_ranges(label, query)
  local ranges = {}
  query = vim.trim(query or "")
  if query == "" then
    return ranges
  end

  local lower_label = label:lower()
  for token in query:lower():gmatch("%S+") do
    token = normalize_token(token)
    if not token:find("[*?]") then
      local exact_from, exact_to = lower_label:find(token, 1, true)
      if exact_from then
        ranges[#ranges + 1] = { from = exact_from, to = exact_to }
      elseif #token >= 4 then
        append_position_ranges(ranges, basename_positions(lower_label, token))
      else
        append_position_ranges(ranges, fuzzy_positions(lower_label, token))
      end
    end
  end
  return ranges
end

function M.items(items, opts, query)
  opts = opts or {}
  local tokens = query_tokens(query)
  local use_limit = #tokens > 0 and opts.filter_limit ~= false
  local limit = tonumber(opts.filter_limit) or 5000
  local entries = {}

  for _, item in ipairs(items) do
    local label = M.item_label(item, opts)
    local score = fuzzy_score(label, tokens)
    if score then
      local entry = { item = item, label = label, score = score }
      if use_limit then
        heap_push(entries, entry, limit)
      else
        entries[#entries + 1] = entry
      end
    end
  end

  if #tokens > 0 then
    table.sort(entries, better)
  end

  local filtered = {}
  for index, entry in ipairs(entries) do
    filtered[index] = entry.item
  end
  return filtered
end

function M.by_predicate(items, predicate)
  local filtered = {}
  for _, item in ipairs(items) do
    local ok, keep = pcall(predicate, item)
    if ok and keep then
      filtered[#filtered + 1] = item
    end
  end
  return filtered
end

function M.by_regex(items, opts, pattern)
  local filtered = {}
  for _, item in ipairs(items) do
    local ok, matched = pcall(function()
      return M.item_label(item, opts):find(pattern) ~= nil
    end)
    if ok and matched then
      filtered[#filtered + 1] = item
    end
  end
  return filtered
end

function M.has_filters(filters)
  return type(filters) == "table" and not vim.tbl_isempty(filters)
end

function M.quick_filter_menu(filters)
  local menu = {}
  for _, filter in ipairs(filters or {}) do
    if filter.key and filter.label then
      menu[#menu + 1] = string.format("%s=%s", filter.key, filter.label)
    end
  end
  return table.concat(menu, "  ")
end

return M

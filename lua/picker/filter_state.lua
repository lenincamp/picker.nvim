local M = {}

local picker_filter = require("picker.filter")

function M.items(items, opts, state)
  local next_candidates = state.query == "" and items or picker_filter.items(items, opts, state.query)
  if state.quick_filter then
    next_candidates = picker_filter.by_predicate(next_candidates, state.quick_filter.predicate)
  end
  if state.regex_pattern then
    next_candidates = picker_filter.by_regex(next_candidates, opts, state.regex_pattern)
  end
  return next_candidates
end

function M.items_async(items, opts, state, done, is_stale)
  local function apply_secondary(next_candidates)
    if is_stale and is_stale() then
      return
    end
    if state.quick_filter then
      next_candidates = picker_filter.by_predicate(next_candidates, state.quick_filter.predicate)
    end
    if state.regex_pattern then
      next_candidates = picker_filter.by_regex(next_candidates, opts, state.regex_pattern)
    end
    done(next_candidates)
  end

  if state.query == "" then
    vim.schedule(function()
      apply_secondary(items)
    end)
    return
  end

  picker_filter.items_async(items, opts, state.query, apply_secondary, is_stale)
end

function M.label(state)
  local labels = {}
  if state.quick_filter then
    labels[#labels + 1] = state.quick_filter.label or state.quick_filter.key
  end
  if state.regex_pattern then
    labels[#labels + 1] = "regex:" .. state.regex_pattern
  end
  return #labels > 0 and table.concat(labels, " ") or nil
end

return M

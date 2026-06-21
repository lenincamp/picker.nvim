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

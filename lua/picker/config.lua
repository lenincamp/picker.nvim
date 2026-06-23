local M = {}

M.defaults = {
  layout = "intellij_grep",
  input_spacing = 0,
  max_results = 40,
  debounce_ms = 25,
  preview_max_bytes = 300000,
  preview_lines = 120,
  root_markers = { ".git", "pom.xml", "package.json", "build.gradle" },
  project_markers = {
    ".git",
    "pom.xml",
    "package.json",
    "sfdx-project.json",
    "build.gradle",
    "build.gradle.kts",
  },
  filters = {},
  buffer_actions = {},
  grep_exclude_globs = {
    "!**/*.min.js",
    "!**/*.chunk.js",
    "!**/*.chunk.jsx",
    "!**/*.chunk.ts",
    "!**/*.chunk.tsx",
    "!**/chunk-*.js",
    "!**/chunk-*.jsx",
    "!**/chunk-*.ts",
    "!**/chunk-*.tsx",
  },
  git = {
    max_log_count = 300,
    lazygit_cmd = { "lazygit" },
    commands = false,
    browse_url = nil,
  },
  todos = {
    keywords = { "TODO", "FIX", "FIXME", "HACK", "WARN", "PERF", "NOTE", "TEST" },
    urgent_keywords = { "TODO", "FIX", "FIXME" },
  },
}

M.current = vim.deepcopy(M.defaults)

function M.apply(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M

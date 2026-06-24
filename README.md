# picker.nvim

A fast, native Neovim fuzzy picker built entirely in Lua. No external dependencies besides Neovim 0.10+. Supports file search, live grep, preview, multi-select, quick filters, and IntelliJ-style layouts.

## Features

- **Zero external dependencies** — pure Lua, uses only Neovim built-in APIs
- **Fuzzy matching** — segment-aware scoring with acronym/camelCase support
- **Live filtering** — instant results as you type, with debounced dynamic items
- **Preview** — file preview with syntax highlighting and ANSI color support (via [preview.nvim](https://github.com/lenincamp/preview.nvim))
- **IntelliJ-style layout** — full-width bottom panel with stacked preview (or side-by-side)
- **Quick filters** — file type globs (e.g., `Fj` for `*.js,*.jsx,*.ts,*.tsx`)
- **Regex filter** — apply regex pattern on top of fuzzy results
- **Multi-select** — mark items with `Space` and batch-submit
- **Quickfix integration** — send results to quickfix list with `<C-q>`
- **Input mode** — search-first UX with insert/normal mode toggling
- **Preview zoom** — maximize preview with `z` in normal mode
- **Numeric shortcuts** — press `1`-`9` in normal mode to select by index
- **Resume** — reopen last quickfix search results

## Requirements

- Neovim >= 0.10.0
- [preview.nvim](https://github.com/lenincamp/preview.nvim) (optional, for ANSI/syntax preview highlighting)

## Installation

### lazy.nvim

```lua
{
  "lenincamp/picker.nvim",
  dependencies = {
    { "lenincamp/preview.nvim" },
  },
  opts = {},
  -- or configure manually:
  -- config = function(_, opts)
  --   require("picker").setup(opts)
  -- end,
}
```

### mini.deps / pack manager (manual)

```lua
-- Symlink or clone to pack/core/start/
-- ~/.local/share/nvim/site/pack/core/start/picker.nvim -> ~/workspace/plugins/picker.nvim
-- ~/.local/share/nvim/site/pack/core/start/preview.nvim -> ~/workspace/plugins/preview.nvim
```

### packer.nvim

```lua
use {
  "lenincamp/picker.nvim",
  requires = { "lenincamp/preview.nvim" },
  config = function()
    require("picker").setup()
  end,
}
```

## Configuration

```lua
require("picker").setup({
  -- Layout style: "intellij_grep" (full-width bottom) or "default" (centered side-by-side)
  layout = "intellij_grep",
  -- Max items shown per page
  max_results = 40,
  -- Debounce for dynamic_items callbacks (ms)
  debounce_ms = 25,
  -- Max file size for preview (bytes)
  preview_max_bytes = 300000,
  -- Max lines to render in preview
  preview_lines = 120,
  -- Extra screen rows between input and picker/preview borders (input_mode only).
  -- 0 = borders share a single line (compact), 1 = adjacent, 2+ = visible gap.
  input_spacing = 0,
  -- Max remembered filter queries per picker scope
  filter_history_max = 100,
})
```

All options are optional; defaults are shown above.

## API

### `require("picker").select_items(items, opts, on_choice)`

Open a picker with the given items.

```lua
local picker = require("picker")

picker.select_items({
  { label = "Open config", path = "~/.config/nvim/init.lua" },
  { label = "Open keymaps", path = "~/.config/nvim/lua/keymaps.lua" },
}, {
  prompt = "Quick Open",
  preview = function(item) return item.path end,
}, function(item)
  vim.cmd("edit " .. item.path)
end)
```

#### Item format

Each item can be a table with:

| Field       | Type     | Description                              |
|-------------|----------|------------------------------------------|
| `label`     | string   | Display text (required)                  |
| `path`      | string   | File path for preview/navigation         |
| `lnum`      | number   | Line number for jump                     |
| `col`       | number   | Column number for jump                   |
| `filename`  | string   | Alternative to `path`                    |
| `group`     | string   | Group header in results                  |
| `value`     | any      | Arbitrary data passed to `on_choice`     |

#### Options

| Option           | Type            | Description                                              |
|------------------|-----------------|----------------------------------------------------------|
| `prompt`         | string          | Title shown in the picker                                |
| `preview`        | function(item)  | Returns file path for file-based preview                 |
| `preview_lines`  | function(item, width) | Returns lines/table for custom preview content   |
| `preview_open`   | boolean         | Open preview immediately (default: false)                |
| `input_mode`     | boolean         | Start in search-first insert mode                        |
| `layout`         | string          | `"intellij_grep"` or `"default"`                         |
| `max_results`    | number          | Items per page                                           |
| `multi_select`   | boolean         | Allow marking multiple items                             |
| `submit_query`   | function(query, state) | Called on `<CR>` when no item is selected         |
| `dynamic_items`  | function(state) or function(state, cb) | Sync or async live-fetch items as user types. Async (2-arg) spawns return a proc handle for auto-cancellation |
| `actions`        | table           | Custom keymap actions `{ ["<C-x>"] = fn }`               |
| `query`          | string          | Initial query string                                     |
| `search`         | boolean         | Enable filtering (default: true)                         |
| `scope`          | string          | Scope identifier for filter persistence                  |
| `filter_history` | boolean         | Remember queries/filters per scope (default: true)       |
| `fuzzy`          | boolean         | Enable fuzzy matching (default: true)                    |
| `regex`          | boolean         | Treat query as regex pattern                             |
| `input_spacing`  | number          | Extra rows between input and picker/preview (0=compact)  |

### `require("picker").with_layout(opts)`

Merge the current layout preference into an options table:

```lua
local opts = picker.with_layout({ prompt = "Find Files" })
-- Returns { prompt = "Find Files", layout = "intellij_grep" }
```

### `require("picker").is_intellij_grep_enabled()`

Returns `true` if IntelliJ layout is the current default.

### `require("picker").set_intellij_grep(bool)`

Toggle the default layout between IntelliJ and side-by-side.

### `require("picker").resume()`

Reopen the last quickfix search (e.g., resume grep results).

### `require("picker").setup(opts)`

Apply configuration. Called automatically by lazy.nvim with `opts = {}`.

### Built-in Sources (`require("picker.sources")`)

Async process-backed sources for grep and file search. These return a 2-arg `dynamic_items` function that spawns `rg`/`fd` asynchronously via `vim.uv.spawn`, with automatic process cancellation on each keystroke.

#### `sources.grep(opts)`

Live ripgrep search. Returns a `dynamic_items(state, callback)` function.

```lua
local picker = require("picker")
local sources = require("picker.sources")

picker.select_items({}, picker.with_layout({
  prompt = "Grep",
  input_mode = true,
  preview_open = true,
  dynamic_items = sources.grep({ cwd = vim.uv.cwd() }),
  preview = function(item) return item and item.path end,
}), function(item)
  vim.cmd("edit " .. vim.fn.fnameescape(item.path))
  vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
end)
```

Options: `cwd`, `cmd` (default `"rg"`), `extra_args`, `limit` (default 5000), `min_chars` (default 2), `glob`.

#### `sources.files(opts)`

Live file search via `fd`. Returns a `dynamic_items(state, callback)` function.

```lua
picker.select_items({}, picker.with_layout({
  prompt = "Files",
  input_mode = true,
  dynamic_items = sources.files({ cwd = vim.uv.cwd() }),
  preview = function(item) return item and item.path end,
}), function(item)
  vim.cmd("edit " .. vim.fn.fnameescape(item.path))
end)
```

Options: `cwd`, `cmd` (default `"fd"`), `extra_args`, `limit` (default 5000), `hidden` (default false).

### Async Process Runner (`require("picker.proc")`)

Low-level async subprocess runner using `vim.uv.spawn`. Used internally by sources, but available for custom integrations.

```lua
local proc = require("picker.proc")
local handle = proc.spawn({
  cmd = "rg",
  args = { "--color=never", "--no-heading", "-n", "pattern", "." },
  cwd = vim.uv.cwd(),
  limit = 1000,
  transform = function(line) return { label = line } end,
  on_items = function(items) -- called incrementally end,
  on_done = function(items, exit_code) -- called when process exits end,
})
-- Cancel at any time:
proc.abort(handle)
```

## Keymaps (inside picker)

| Key         | Mode   | Action                                      |
|-------------|--------|---------------------------------------------|
| `C-j` / `C-k` | insert/normal (input mode) | Previous / next filter history |
| `j` / `k`  | normal | Navigate items                              |
| `<CR>`      | both   | Select item / submit query                  |
| `<Esc>`     | insert | Switch to normal mode                       |
| `<Esc>`/`q` | normal | Close picker                               |
| `i` / `a`  | normal | Enter insert mode                           |
| `1`-`9`    | normal | Select item by index                        |
| `<Space>`  | normal | Toggle multi-select mark                    |
| `<C-q>`    | normal | Send all results to quickfix                |
| `<C-v>`    | normal | Open in vsplit (or paste in input mode)     |
| `<C-x>`    | normal | Open in split                               |
| `<C-r>`    | normal | Paste from clipboard (input mode)           |
| `<Tab>`    | normal | Toggle preview panel                        |
| `<C-o>`    | normal | Focus/unfocus preview window                |
| `z`        | normal | Zoom/maximize preview                       |
| `<A-l>`    | normal | Toggle layout (IntelliJ ↔ side-by-side)     |
| `?`        | normal | Toggle keymap descriptions in status        |
| `F`        | normal | Quick filter by file type                   |
| `C`        | normal | Clear active quick filter                   |
| `R`        | normal | Apply regex filter                          |
| `/`        | normal | Enter filter mode                           |
| `<C-u>`    | normal | Scroll up half page                         |
| `<C-d>`    | normal | Scroll down half page                       |
| `<C-f>`    | normal | Scroll down full page                       |
| `<C-b>`    | normal | Scroll up full page                         |

## Modules

| Module               | Responsibility                              |
|----------------------|---------------------------------------------|
| `picker.init`        | Main entry point and `select_items` logic   |
| `picker.config`      | Default configuration and `setup()`         |
| `picker.filter`      | Fuzzy matching, scoring, and filtering      |
| `picker.filter_state`| Quick filter glob state management          |
| `picker.history`     | Per-scope filter query persistence          |
| `picker.keymaps`     | Buffer-local keymap setup                   |
| `picker.layout`      | Window geometry calculations                |
| `picker.navigation`  | Cursor movement, page scroll                |
| `picker.preview`     | Preview path/content resolution             |
| `picker.preview_window` | Preview float lifecycle and rendering    |
| `picker.proc`        | Async subprocess runner (`vim.uv.spawn`)    |
| `picker.quickfix`    | Quickfix list population                    |
| `picker.render`      | Line rendering and highlighting             |
| `picker.selection`   | Multi-select state                          |
| `picker.sources`     | Built-in grep/files async sources           |
| `picker.status`      | Status bar segments                         |
| `picker.display`     | Label formatting utilities                  |
| `picker.windows`     | Float window open/close                     |

## License

MIT

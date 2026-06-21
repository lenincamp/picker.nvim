local M = {}

M.defaults = {
  open_on_startup = true,
  filetype = "picker_dashboard",
  legacy_filetypes = { "snacks_dashboard", "pure_dashboard" },
  icons = {
    f = "",
    g = "󱎸",
    r = "󰄉",
    p = "󰉋",
    c = "",
    s = "",
    n = "󰝒",
    q = "󰈆",
  },
  highlights = {
    dark = {
      header = { fg = "#39FFB6", bold = true },
      special = { fg = "#19E3FF", bold = true },
      key = { fg = "#9AFBFF", bold = true },
    },
    light = {
      header = { fg = "#047857", bold = true },
      special = { fg = "#0369A1", bold = true },
      key = { fg = "#0E7490", bold = true },
    },
  },
  highlight_groups = {
    header = "PickerDashboardHeader",
    special = "PickerDashboardSpecial",
    key = "PickerDashboardKey",
  },
  header = {
    [[                        .,,cc,,,.]],
    [[                   ,c$$$$$$$$$$$$cc,]],
    [[                ,c$$$$$$$$$$??""??$?? ..]],
    [[             ,z$$$$$$$$$$$P xdMMbx  nMMMMMb]],
    [[            r")$$$$??$$$$" dMMMMMMb "MMMMMMb]],
    [[          r",d$$$$$>;$$$$ dMMMMMMMMb MMMMMMM.]],
    [[         d'z$$$$$$$>'"""" 4MMMMMMMMM MMMMMMM>]],
    [[        d'z$$$$$$$$h $$$$r`MMMMMMMMM "MMMMMM]],
    [[        P $$$$$$$$$$.`$$$$.'"MMMMMP',c,"""'..]],
    [[       d',$$$$$$$$$$$.`$$$$$c,`""_,c$$$$$$$$h]],
    [[       $ $$$$$$$$$$$$$.`$$$$$$$$$$$"     "$$$h]],
    [[      ,$ $$$$$$$$$$$$$$ $$$$$$$$$$%       `$$$L]],
    [[      d$c`?$$$$$$$$$$P'z$$$$$$$$$$c       ,$$$$.]],
    [[      $$$cc,"""""""".zd$$$$$$$$$$$$c,  .,c$$$$$F]],
    [[     ,$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$]],
    [[     d$$$$$$$$$$$$$$$$c`?$$$$$$$$$$$$$$$$$$$$$$$]],
    [[     ?$$$$$$$$$."$$$$$$c,`..`?$$$$$$$$$$$$$$$$$$.]],
    [[     <$$$$$$$$$$. ?$$$$$$$$$h $$$$$$$$$$$$$$$$$$>]],
    [[      $$$$$$$$$$$h."$$$$$$$$P $$$$$$$$$$$$$$$$$$>]],
    [[      `$$$$$$$$$$$$ $$$$$$$",d$$$$$$$$$$$$$$$$$$>]],
    [[       $$$$$$$$$$$$c`""""',c$$$$$$$$$$$$$$$$$$$$']],
    [[       "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$F]],
    [[        "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$']],
    [[        ."?$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P'  FOR FUCK'S SAKE!]],
    [[     ,c$$c,`?$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"  THE TIME HE WASTES]],
    [[   z$$$$$P"   ""??$$$$$$$$$$$$$$$$$$$$$$$"  IN RICING NVIM IS]],
    [[,c$$$$$P"          .`""????????$$$$$$$$$$c  DRIVING ME CRAZY.]],
    [[`"""              ,$$$L.        "?$$$$$$$$$.   WHAT'S THE MATTER]],
    [[               ,cd$$$$$$$$$hc,    ?$$$$$$$$$c    WITH HIM ??????]],
    [[              `$$$$$$$$$$$$$$$.    ?$$$$$$$$$h]],
    [[               `?$$$$$$$$$$$$P      ?$$$$$$$$$]],
    [[                 `?$$$$$$$$$P        ?$$$$$$$$$$$$hc]],
    [[                   "?$$$$$$"         <$$$$$$$$$$$$$$r   FUCKING]],
    [[                     `""""           <$$$$$$$$$$$$$$F   KILL IT]],
    [[                                      $$$$$$$$$$$$$F]],
    [[                                      `?$$$$$$$$P"]],
    [[                                        "????"]],
  },
  buttons = {
    { key = "f", desc = "Find File", action = "files" },
    { key = "g", desc = "Search in Files", action = "grep" },
    { key = "r", desc = "Recent Files", action = "recent" },
    { key = "p", desc = "Recent Projects", action = "projects" },
    { key = "c", desc = "Config Files", action = "config" },
    { key = "s", desc = "Restore Last Session", action = "session" },
    { key = "n", desc = "New File", action = "new" },
    { key = "q", desc = "Quit", action = "quit" },
  },
  actions = {},
  on_restore_window = nil,
}

M.current = vim.deepcopy(M.defaults)

function M.apply(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M

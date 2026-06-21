if vim.g.loaded_picker then
  return
end
vim.g.loaded_picker = true

vim.api.nvim_create_user_command("PickerSetup", function()
  require("picker").setup()
end, { desc = "Initialize picker.nvim with default config" })

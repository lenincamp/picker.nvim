local config = require("picker.config")
local lazygit = require("picker.git.lazygit")
local picker = require("picker")

local function assert_true(v, msg)
  if not v then
    error(msg or "assert_true failed")
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then
    error(string.format("%s: expected %s, got %s", msg or "assert_eq", vim.inspect(b), vim.inspect(a)))
  end
end

assert_true(type(lazygit.open) == "function", "lazygit.open exists")
assert_true(type(picker.lazygit) == "function", "picker.lazygit exported")

config.apply({ git = { lazygit_cmd = { "lazygit", "--version" } } })
assert_true(type(picker.lazygit) == "function", "lazygit still exported after config")
config.apply({ git = { lazygit_cmd = "lazygit" } })
assert_true(type(picker.lazygit) == "function", "lazygit accepts string cmd config")
config.apply({})

print("git/lazygit: ok")

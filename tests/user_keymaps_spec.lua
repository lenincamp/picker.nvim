local M = {}

local function assert_true(v, msg)
  if not v then
    error(msg or "assert_true failed")
  end
end

local user_keymaps = require("picker.user_keymaps")

assert_true(#user_keymaps.specs() >= 40, "user_keymaps specs count")
assert_true(#user_keymaps.lazy_keys() == #user_keymaps.specs(), "lazy_keys matches specs")

local seen = {}
for _, spec in ipairs(user_keymaps.specs()) do
  assert_true(type(spec.lhs) == "string", "spec has lhs")
  assert_true(spec.action or spec.rhs, "spec has action or rhs")
  assert_true(not seen[spec.lhs], "duplicate lhs: " .. spec.lhs)
  seen[spec.lhs] = true
end

assert_true(type(user_keymaps.apply) == "function", "apply exported")
print("user_keymaps: ok")

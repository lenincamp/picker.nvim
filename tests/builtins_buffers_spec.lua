local buffers = require("picker.builtins.buffers")
local picker = require("picker")

local function assert_true(v, msg)
  if not v then
    error(msg or "assert_true failed")
  end
end

picker.setup({
  buffer_actions = {
    ["<C-a>"] = { desc = "custom", fn = function() end },
  },
})

local actions = buffers.build_actions({})
assert_true(actions["<C-x>"] ~= nil, "default delete action")
assert_true(actions["<C-x>"].desc == "delete", "delete desc")
assert_true(actions["<C-a>"] ~= nil, "config buffer action merged")
assert_true(actions["<C-a>"].desc == "custom", "config action desc")

local override = buffers.build_actions({
  actions = {
    ["<C-z>"] = { desc = "zoom", fn = function() end },
  },
})
assert_true(override["<C-z>"] ~= nil, "opts action merged")
assert_true(override["<C-a>"] ~= nil, "config preserved with opts")

assert_true(type(picker.buffers) == "function", "buffers exported")
assert_true(type(picker.delete_buffer) == "function", "delete_buffer exported")
assert_true(type(picker.delete_other_buffers) == "function", "delete_other_buffers exported")

print("builtins/buffers: ok")

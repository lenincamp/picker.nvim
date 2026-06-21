local util = require("picker.util")

local function assert_true(v, msg)
  if not v then
    error(msg or "assert_true failed")
  end
end

assert_true(type(util.root()) == "string", "root returns string")
assert_true(type(util.filters()) == "table", "filters returns table")
assert_true(util.path_has_extension("foo.java", { ".java" }), "path_has_extension")

local picker = require("picker")
picker.setup({
  filters = {
    {
      key = "J",
      label = "Java",
      glob = { "*.java" },
      predicate = function(item)
        return util.path_has_extension(util.item_path(item), { ".java" })
      end,
    },
  },
})

assert_true(#picker.filters() == 1, "setup applies filters")
assert_true(picker.filters()[1].key == "J", "filter key preserved")
assert_true(type(picker.registers) == "function", "registers exported")
assert_true(type(picker.help) == "function", "help exported")
assert_true(type(picker.keymaps) == "function", "keymaps exported")

print("builtins/misc: ok")

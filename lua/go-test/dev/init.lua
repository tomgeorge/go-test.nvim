local reload = function()
  print("reloading...")
  package.loaded["go-test"] = nil
  package.loaded["go-test.commands"] = nil
end

vim.keymap.set("n", ",r", function()
  reload()
end, {})

vim.keymap.set("n", ",x", function()
  require("go-test").run_test_input(vim.api.nvim_get_current_buf())
end, {})

vim.keymap.set("n", ",p", function()
  print(vim.inspect(require("go-test").get_tests_until_cursor(vim.api.nvim_get_current_buf())))
end)

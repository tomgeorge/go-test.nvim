vim.api.nvim_create_user_command("GoTestRunUnderCursor", function()
  require("go-test").run_test()
end, { nargs = 0 })

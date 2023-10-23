local M = {}

local Job = require("plenary.job")

M.setup = function(_)
  print("Set up go-test.nvim!")
end
local Test = {}

local set_quickfix = function()
  vim.fn.setqflist(Test.entries, "a")
  vim.fn.setqflist({}, "a", { title = "Go Test" })
end

-- {"Package":"test","Time":"2023-10-22T20:34:38.927173-05:00","Action":"start"
--{"Package":"test","Time":"2023-10-22T20:34:39.069263-05:00","Test":"TestMyFunc","Action":"run"
--{"Test":"TestMyFunc","Action":"output","Output":"=== RUN   TestMyFunc\n","Time":"2023-10-22T20:34:39.069318-05:00","Package":"test"
--{"Test":"TestMyFunc","Action":"fail","Package":"test","Elapsed":0,"Time":"2023-10-22T20:34:39.069358-05:00"
local handle_line = function(line)
  -- print("line is " .. vim.inspect(line))
  if line.Action == "output" then
    local meta = {
      bufnr = Test.bufnr,
      filename = Test.file_name,
      module = line.Test or "",
      lnum = Test.row,
      end_lnum = Test.row,
      text = line.Output,
    }
    print("inserting into tests")
    table.insert(Test.entries, meta)
  end
end

local run_job = function(test)
  return Job:new({
    command = "go",
    args = { "test", "-v", "./...", "-test.run", test.name, "-json" },
    cwd = vim.v.cwd or vim.fn.getcwd(),
    on_stdout = vim.schedule_wrap(function(_, line)
      local decoded = vim.fn.json_decode(line)
      -- print(vim.inspect(decoded))
      handle_line(decoded)
    end),
    on_stderr = vim.schedule_wrap(function()
      print("got stderr")
    end),
    on_exit = vim.schedule_wrap(function()
      vim.fn.setqflist({})
      set_quickfix()
      if #Test > 0 then
        vim.cmd.copen()
      end
    end),
  }):start()
end

local run_go_test = function(test)
  print("run_go_test")
  Test = {
    entries = {},
    row = test.row,
    col = test.col,
    file_name = test.file_name,
    bufnr = test.bufnr,
  }
  job = run_job(test)
end

M.run_test_under_cursor = function(bufnr)
  local win = vim.api.nvim_get_current_win()
  local cursorRow = vim.api.nvim_win_get_cursor(win)[1]
  print("win is " .. win .. " cursorRow is " .. cursorRow)
  local tests = M.get_tests_until_cursor(bufnr, vim.cmd.file()) or {}
  for _, test in ipairs(tests) do
    local startRow, _, endRow, _ = vim.treesitter.get_node_range(test.node)
    print("startRow " .. startRow .. " endRow " .. endRow .. " cursorRow " .. cursorRow)
    if cursorRow > startRow and cursorRow < endRow then
      run_go_test(test)
    end
  end
end

M.run_test_input = function(bufnr)
  local file_name = vim.cmd.file()
  local tests = M.get_tests_until_cursor(bufnr, file_name) or {}
  vim.ui.select(tests, {
    prompt = "Choose a test to run",
    format_item = function(item)
      return item.name
    end,
  }, function(choice, _)
    if choice == nil then
      print("Cancelled")
      return
    end
    run_go_test(choice)
  end)
end

local Test = {}

M.get_tests_until_cursor = function(bufnr, file_name)
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if filetype ~= "go" then
    print("Not a go file. Run get_test_method in a go file")
    return
  end
  local parser = vim.treesitter.get_parser(bufnr, "go")
  local tree = parser:parse()
  local root = tree[1]:root()
  local stop_row = vim.api.nvim_win_get_cursor(0)[1]

  local query = vim.treesitter.query.parse(
    "go",
    [[
    (function_declaration
    name: (identifier) @function-name (#match? @function-name "^Test.+$")
    parameters: (parameter_list) @parameter-list (#match? @parameter-list "*testing.(T|M)")
    body: (block))
  ]]
  )

  local tests = {}
  for _, captures, _ in query:iter_matches(root, bufnr, 0, stop_row) do
    local test_match = {}
    for i, node in pairs(captures) do
      local capture = query.captures[i]
      if capture == "function-name" then
        local function_name = vim.treesitter.get_node_text(node, bufnr)
        local startRow, startCol, endRow, _ = vim.treesitter.get_node_range(node)
        print("tests_until_cursor startRow " .. startRow .. " endRow " .. endRow)
        test_match.name = function_name
        test_match.row = startRow + 1
        test_match.col = startCol
        test_match.node = node
        test_match.file_name = file_name
        test_match.bufnr = bufnr
        table.insert(tests, test_match)
      end
    end
  end
  if #tests == 0 then
    print("No tests found")
  end
  return tests
end

return M

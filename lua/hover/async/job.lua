local async = require('hover.async')

local M = {}

M.job = async.wrap(function(obj, callback)
  local stdout_data = {}
  local stdout = vim.loop.new_pipe(false)

  local handle = vim.loop.spawn(obj[1], {
    args  = vim.list_slice(obj, 2),
    stdio = { nil, stdout },
    cwd   = obj.cwd
  },
    function()
      stdout:close()
      local stdout_result = #stdout_data > 0 and table.concat(stdout_data) or nil
      callback(stdout_result)
    end
  )

  if handle then
    stdout:read_start(function(_, data)
      stdout_data[#stdout_data+1] = data
    end)
  else
    stdout:close()
  end
end, 2)

return M

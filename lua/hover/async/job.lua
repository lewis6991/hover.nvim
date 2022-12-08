local async = require('hover.async')

local M = {}

---@async
---@return string[]
M.job = async.wrap(function(obj, callback)
  ---@type string[]
  local stdout_data = {}
  local stdout = vim.loop.new_pipe(false)

  local handle
  handle = vim.loop.spawn(obj[1], {
    args  = vim.list_slice(obj, 2),
    stdio = { nil, stdout },
    cwd   = obj.cwd,
    env   = obj.env
  },
    function()
      stdout:close()
      local stdout_result = #stdout_data > 0 and table.concat(stdout_data) or nil
      callback(stdout_result)
      handle:close()
    end
  )

  if handle then
    stdout:read_start(function(err, data)
      if not err then
        stdout_data[#stdout_data+1] = data
      end
    end)
  else
    stdout:close()
  end
end, 2)

return M

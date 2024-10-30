local async = require('hover.async')

local M = {}

---@async
---@return string|nil stdout result
---@return string|nil stderr result
M.job = async.wrap(function(obj, callback)
  ---@type string[]
  local stdout_data = {}
  local stdout = assert(vim.loop.new_pipe(false))

  ---@type string[]
  local stderr_data = {}
  local stderr = assert(vim.loop.new_pipe(false))

  local handle
  handle, pid_or_err = vim.loop.spawn(obj[1], {
    args = vim.list_slice(obj, 2),
    stdio = { nil, stdout, stderr },
    cwd = obj.cwd,
    env = obj.env,
  }, function(code, signal) -- on_exit
    stdout:close()
    stderr:close()
    if code ~= 0 then
      table.insert(
        stderr_data,
        1,
        'Process exited with a non-zero exit code ' .. tostring(code) .. ':\n\n'
      )
    end
    local stdout_result = #stdout_data > 0 and table.concat(stdout_data) or nil
    local stderr_result = #stderr_data > 0 and table.concat(stderr_data) or nil
    callback(stdout_result, stderr_result)
    handle:close()
  end)

  if handle then
    stdout:read_start(function(err, data)
      if not err then
        stdout_data[#stdout_data + 1] = data
      end
    end)
    stderr:read_start(function(err, data)
      if not err then
        stderr_data[#stderr_data + 1] = data
      end
    end)
  else
    -- command failed, possibly command not found
    stdout:close()
    stderr:close()
    callback(nil, pid_or_err .. '\n\ncmd = ' .. table.concat(obj, ' '))
  end
end, 2)

return M

-- Match 2 or more uppercase letters followed by a '-' and 1 or more digits.
local ISSUE_PATTERN = '%u[%u%d]+-%d+'

--- @param str string
--- @return string
local function strip_ansi_codes(str)
  return (str:gsub('\27%[[%d;]*m', ''))
end

--- @type Hover.Provider
return {
  name = 'Jira',
  priority = 175,
  enabled = function()
    return vim.fn.executable('jira') == 1 and vim.fn.expand('<cWORD>'):match(ISSUE_PATTERN) ~= nil
  end,
  execute = function(_params, done)
    local query = vim.fn.expand('<cWORD>'):match(ISSUE_PATTERN)

    vim.system({ 'jira', 'issue', 'view', query, '--plain' }, {}, function(result)
      if result.code > 0 then
        local stripped_stderr = strip_ansi_codes(result.stderr or '')
        done({ lines = vim.split(stripped_stderr, '\n'), filetype = 'text' })
        return
      end

      local lines = {} --- @type string[]
      for line in assert(result.stdout):gmatch('[^\r\n]+') do
        lines[#lines + 1] = strip_ansi_codes(line)
      end

      done({ lines = lines, filetype = 'markdown' })
    end)
  end,
}

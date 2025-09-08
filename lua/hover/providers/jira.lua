local ISSUE_PATTERN = '%u[%u%d]+-%d+'

--- @type Hover.Provider
return {
  name = 'Jira',
  priority = 175,
  enabled = function()
    -- Match 2 or more uppercase letters followed by a '-' and 1 or more digits.
    return vim.fn.expand('<cWORD>'):match(ISSUE_PATTERN) ~= nil
  end,
  execute = function(_params, done)
    local query = vim.fn.expand('<cWORD>'):match(ISSUE_PATTERN)

    vim.system({ 'jira', 'issue', 'view', query, '--plain' }, {}, function(result)
      if not result.code > 0 then
        done(false)
        return
      end

      local lines = {}
      for line in assert(result.stdout):gmatch('[^\r\n]+') do
        -- Remove lines starting with \27, which is not formatted well and
        -- is only there for help/context/suggestion lines anyway.
        if line:find('^\27') == nil then
          table.insert(lines, line)
        end
      end

      done({ lines = lines, filetype = 'markdown' })
    end)
  end,
}

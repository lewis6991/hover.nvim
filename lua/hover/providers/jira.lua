local job = require('hover.async.job').job

local function enabled()
    -- Match 2 or more uppercase letters followed by a '-' and 1 or more digits.
    return vim.fn.expand('<cWORD>'):match('%u%u+-%d+') ~= nil
end

local function execute(done)
    local bufnr = vim.api.nvim_get_current_buf()
    local cwd = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')

    local query = vim.fn.expand('<cWORD>')

    job({'jira', 'issue', 'view', query, '--plain', cwd = cwd}, function(result)
        if result == nil then
            done(false)
            return
        end

        local lines = {}
        for line in result:gmatch('[^\r\n]+') do
            -- Remove lines starting with \27, which is not formatted well and
            -- is only there for help/context/suggestion lines anyway.
            if line:find('^\27') == nil then
                table.insert(lines, line)
            end
        end

        done {lines = lines, filetype = 'markdown'}
    end)
end

require('hover').register {
    name = 'Jira',
    priority = 175,
    enabled = enabled,
    execute = execute
}


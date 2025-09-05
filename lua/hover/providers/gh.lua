local api, fn = vim.api, vim.fn

local async = require('hover.async')

local function enabled()
  return fn.expand('<cWORD>'):match('#%d+') ~= nil
end

--- @param cmd string[]
--- @param opts vim.SystemOpts?
--- @param cb fun(out: vim.SystemCompleted)
local function system(cmd, opts, cb)
  vim.system(cmd, opts, cb)
end

---@param result string?
---@param stderr string?
---@return string[]?
local function process(result, stderr)
  if not result then
    vim.notify(
      vim.trim(stderr or '(Unknown error)'),
      vim.log.levels.ERROR,
      { title = 'hover.nvim (gh)' }
    )
    return
  end

  local ok, json = pcall(vim.json.decode, result)
  if not ok then
    vim.schedule(function()
      vim.notify('Failed to parse gh result: ' .. json, vim.log.levels.ERROR)
    end)
    return
  end

  local lines = {
    string.format('#%d: %s', json.number, json.title),
    '',
    string.format('URL: %s', json.url),
    string.format('Author: %s', json.author.login),
    string.format('State: %s', json.state),
    string.format('Created: %s', json.createdAt),
    string.format('Last updated: %s', json.updatedAt),
    '',
  }

  for _, l in ipairs(vim.split(json.body, '\r?\n')) do
    lines[#lines + 1] = l
  end

  return lines
end

--- @param _params Hover.Provider.Params
--- @param done fun(result?: false|Hover.Result)
local function execute(_params, done)
  async.run(function()
    local bufnr = api.nvim_get_current_buf()
    local cwd = fn.fnamemodify(api.nvim_buf_get_name(bufnr), ':p:h')
    local id = fn.expand('<cword>')

    local word = fn.expand('<cWORD>')

    local obj --- @type vim.SystemCompleted

    local fields = 'author,title,number,body,state,createdAt,updatedAt,url'

    local repo, num = word:match('([%w-]+/[%w%.-_]+)#(%d+)')
    if repo then
      obj = async.await(3, system, {
        'gh',
        'issue',
        'view',
        '--json',
        fields,
        num,
        '-R',
        repo,
      }, { cwd = cwd })
    else
      num = word:match('#(%d+)')
      if num then
        obj = async.await(3, system, {
          'gh',
          'issue',
          'view',
          '--json',
          fields,
          id,
        }, { cwd = cwd })
      else
        done(false)
        return
      end
    end

    local results = process(obj.stdout, obj.stderr)
    done(results and { lines = results, filetype = 'markdown' })
  end)
end

require('hover').register({
  name = 'Github',
  priority = 200,
  enabled = enabled,
  execute = execute,
})

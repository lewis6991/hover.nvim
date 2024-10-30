local api, fn = vim.api, vim.fn

local async = require('hover.async')

---@return string
local function get_user()
  local WORD = fn.expand('<cWORD>')
  local user = WORD:match('TODO%(@?(.*)%):')
  return user
end

---@return boolean
local function enabled()
  return get_user() ~= nil
end

local function first_to_upper(str)
  return str:gsub('^%l', string.upper)
end

---@param result string|nil
---@param stderr string|nil
---@return string[]?
local function process(result, stderr)
  if result == nil then
    vim.notify(
      vim.trim(stderr or '(Unknown error)'),
      vim.log.levels.ERROR,
      { title = 'hover.nvim (gh_user)' }
    )
    return
  end

  local ok, json = pcall(vim.json.decode, result)
  if not ok then
    async.scheduler()
    vim.notify('Failed to parse gh user result' .. json, vim.log.levels.ERROR)
    return
  end

  assert(json)

  ---@type string[]
  local res = {}

  for _, key in ipairs({
    'login',
    'name',
    'email',
    'type',
    'location',
    'company',
    'followers',
    'following',
  }) do
    local field = json[key]
    if field and field ~= vim.NIL then
      res[#res + 1] = string.format('**%s**: `%s`', first_to_upper(key), field)
    end
  end

  if json.bio and json.bio ~= vim.NIL then
    res[#res + 1] = '**Bio**:'
    for _, l in ipairs(vim.split(json.bio:gsub('\r', ''), '\n')) do
      res[#res + 1] = '>  ' .. l
    end
  end

  -- 404 (user does not exist)
  if #res == 0 and json.message and json.message ~= vim.NIL then
    res[#res + 1] = 'ERROR: ' .. json.message
  end

  return res
end

local execute = async.void(function(_opts, done)
  local bufnr = api.nvim_get_current_buf()
  local cwd = fn.fnamemodify(api.nvim_buf_get_name(bufnr), ':p:h')
  local user = get_user()
  if not user then
    done(false)
  end
  local job = require('hover.async.job').job

  ---@type string, string?
  local output, stderr
  output, stderr = job({ 'gh', 'api', 'users/' .. user, cwd = cwd })

  local results = process(output, stderr)
  done(results and { lines = results, filetype = 'markdown' })
end)

require('hover').register({
  name = 'Github User',
  priority = 200,
  enabled = enabled,
  execute = execute,
})

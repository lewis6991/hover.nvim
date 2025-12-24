local api, fn = vim.api, vim.fn

local function get_user()
  local WORD = fn.expand('<cWORD>')
  -- The regex is not perfect, but it should match @user and user
  -- The %f[%w_] and %f[^%w_] is because of the lack of \b in Lua. https://stackoverflow.com/a/32854326/213124
  local user = WORD:match '%f[%w_]@?(.*)%f[^%w_]'
  return user
end

---@return boolean
local function enabled()
  return get_user() ~= nil
end

local function first_to_upper(str)
  return str:gsub('^%l', string.upper)
end

--- @param stdout string|nil
--- @param stderr string|nil
--- @return string[]?
local function process(stdout, stderr)
  if stdout == nil then
    vim.notify(
      vim.trim(stderr or '(Unknown error)'),
      vim.log.levels.ERROR,
      { title = 'hover.nvim (gh_user)' }
    )
    return
  end

  local ok, json = pcall(vim.json.decode, stdout)
  if not ok then
    vim.schedule(function()
      vim.notify('Failed to parse gh user result' .. json, vim.log.levels.ERROR)
    end)
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

--- @param _params Hover.Provider.Params
--- @param done fun(result?: false|Hover.Provider.Result)
local function execute(_params, done)
  local bufnr = api.nvim_get_current_buf()
  local cwd = fn.fnamemodify(api.nvim_buf_get_name(bufnr), ':p:h')
  local user = get_user()
  if not user then
    done(false)
  end

  vim.system({ 'gh', 'api', 'users/' .. user }, { cwd = cwd }, function(out)
    local results = process(out.stdout, out.stderr)
    done(results and { lines = results, filetype = 'markdown' })
  end)
end

--- @type Hover.Provider
return {
  name = 'Github User',
  priority = 200,
  enabled = enabled,
  execute = execute,
}

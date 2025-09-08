local async = require('hover.async')

--- @param result string?
--- @return string[]?
local function process(result)
  if not result then
    return
  end

  local ok, res = pcall(vim.json.decode, result)
  if not ok or not res[1] then
    -- async.scheduler()
    -- vim.notify("Failed to parse dictionary response", vim.log.levels.ERROR)
    return
  end

  ---@type table
  local json = res[1]

  ---@type string[]
  local lines = {
    json.word,
  }

  for _, def in ipairs(json.meanings[1].definitions) do
    lines[#lines + 1] = ''
    lines[#lines + 1] = def.definition
    if def.example then
      lines[#lines + 1] = 'Example: ' .. def.example
    end
  end

  return lines
end

local cache = {} --- @type table<string,string[]>

--- @param cmd string[]
--- @param cb fun(out: vim.SystemCompleted)
local function system(cmd, cb)
  --- @diagnostic disable-next-line: param-type-not-match
  vim.system(cmd, cb)
end

--- @param _params Hover.Provider.Params
--- @param done fun(result?: Hover.Provider.Result)
local function execute(_params, done)
  async.run(function()
    local word = vim.fn.expand('<cword>')

    if not cache[word] then
      local output = async.await(2, system, {
        'curl',
        'https://api.dictionaryapi.dev/api/v2/entries/en/' .. word,
      }).stdout

      cache[word] = process(output) or { 'no definition for ' .. word }
    end

    done({ lines = cache[word], filetype = 'markdown' })
  end)
end

--- @type Hover.Provider
return {
  name = 'Dictionary',
  priority = 100,
  enabled = function()
    local word = vim.fn.expand('<cword>')
    return #vim.spell.check(word) == 0
  end,
  execute = execute,
}

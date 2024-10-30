local async = require('hover.async')

local function enabled()
  local word = vim.fn.expand('<cword>')
  return #vim.spell.check(word) == 0
end

local function process(result)
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

local execute = async.void(function(_opts, done)
  local word = vim.fn.expand('<cword>')

  if not cache[word] then
    local job = require('hover.async.job').job

    ---@type string[]
    local output = job({
      'curl',
      'https://api.dictionaryapi.dev/api/v2/entries/en/' .. word,
    })

    local results = process(output) or { 'no definition for ' .. word }
    cache[word] = results
  end

  done({ lines = cache[word], filetype = 'markdown' })
end)

require('hover').register({
  name = 'Dictionary',
  priority = 100,
  enabled = enabled,
  execute = execute,
})

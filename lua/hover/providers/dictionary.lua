local api, fn = vim.api, vim.fn

local async = require('hover.async')
local job = require('hover.async.job').job
local util = require('vim.lsp.util')

local function enabled()
  local word = fn.expand('<cword>')
  return #vim.spell.check(word) == 0
end

local function process(result)
  local ok, res = pcall(vim.json.decode, result)
  if not ok or not res[1] then
    -- vim.notify "Failed to parse dictionary response"
    return
  end

  local json = res[1]

  local lines = {
    json.word,
  }

  for _, def in ipairs(json.meanings[1].definitions) do
    lines[#lines+1] = ''
    lines[#lines+1] = def.definition
    if def.example then
      lines[#lines+1] = 'Example: '..def.example
    end
  end

  return lines
end

local execute = async.void(function(done)
  local word = fn.expand('<cword>')

  local output = job {
    'curl', 'https://api.dictionaryapi.dev/api/v2/entries/en/'..word
  }

  async.scheduler()

  local results = process(output)
  if results then
    util.open_floating_preview(results, "markdown")
  end
  done(results and true or false)
end)

require('hover').register {
  name = 'Dictionary',
  priority = 100,
  enabled = enabled,
  execute = execute,
}

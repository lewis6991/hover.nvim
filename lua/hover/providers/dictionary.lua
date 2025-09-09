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

  --- @class Hover.provider.dictionary.Json.Meaning.Definition
  --- @field definition string
  --- @field example string
  --- @field antonyms string[]
  --- @field synonyms string[]

  --- @class Hover.provider.dictionary.Json.Meaning
  --- @field partOfSpeech? string
  --- @field definitions Hover.provider.dictionary.Json.Meaning.Definition[]
  --- @field antonyms string[]
  --- @field synonyms string[]

  --- @class Hover.provider.dictionary.Json
  --- @field phonetic string
  --- @field phonetics { text: string, audio: string }[]
  --- @field sourceUrls string[]
  --- @field meanings Hover.provider.dictionary.Json.Meaning[]
  --- @field word string
  local json = res[1]

  ---@type string[]
  local lines = {
    'Word: _' .. json.word .. '_',
  }

  for _, meaning in ipairs(json.meanings) do
    if meaning.partOfSpeech then
      vim.list_extend(lines, { '', '# Meaning (' .. meaning.partOfSpeech .. ')' })
    else
      vim.list_extend(lines, { '', '# Meaning' })
    end
    for _, def in ipairs(meaning.definitions) do
      vim.list_extend(lines, { '', '- ' .. def.definition })
      if def.example then
        vim.list_extend(lines, { '  E.g. "' .. def.example .. '"' })
      end

      if def.synonyms and #def.synonyms > 0 then
        vim.list_extend(lines, { '  Synonyms: ' .. table.concat(def.synonyms, ', ') })
      end
      if def.antonyms and #def.antonyms > 0 then
        vim.list_extend(lines, { '  Antonyms: ' .. table.concat(def.antonyms, ', ') })
      end
    end
    if meaning.synonyms and #meaning.synonyms > 0 then
      vim.list_extend(lines, { '', 'Synonyms: ' .. table.concat(meaning.synonyms, ', ') })
    end
    if meaning.antonyms and #meaning.antonyms > 0 then
      vim.list_extend(lines, { '', 'Antonyms: ' .. table.concat(meaning.antonyms, ', ') })
    end
  end

  if json.phonetics and #json.phonetics > 0 then
    vim.list_extend(lines, { '', '# Phonetics' })
    for _, phon in ipairs(json.phonetics) do
      if phon.audio and phon.audio ~= '' then
        lines[#lines + 1] = ('- [%s](%s)'):format(phon.text, phon.audio)
      else
        lines[#lines + 1] = '- ' .. phon.text
      end
    end
  elseif json.phonetic then
    vim.list_extend(lines, { '', '# Phonetic', '- ' .. json.phonetic })
  end

  if json.sourceUrls and #json.sourceUrls > 0 then
    lines[#lines + 1] = ''
    vim.list_extend(lines, { '', '# Sources' })
    for _, url in ipairs(json.sourceUrls or {}) do
      lines[#lines + 1] = '- ' .. url
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

      cache[word] = process(output) or { 'no definition for _' .. word .. '_' }
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

local async = require('hover.async')

local M = {}

local providers = {}
M.providers = providers

local config
local initialised = false

local function is_enabled(provider)
  return provider.enabled == nil or provider.enabled()
end

function M.register(provider)
  if not provider.execute or type(provider.execute) ~= 'function' then
    print(string.format('error: hover provider %s does not provide an execute function',
      provider.name or 'NA'))
    return
  end

  provider.execute = async.wrap(provider.execute, 1)

  if provider.priority then
    for i, p in ipairs(providers) do
      if not p.priority or p.priority < provider.priority then
        table.insert(providers, i, provider)
        return
      end
    end
  end
  providers[#providers+1] = provider
end

local function init()
  if initialised then
    return
  end
  initialised = true

  if config and type(config.init) == 'function' then
    config.init()
  end
end


M.setup = function(config0)
  config = config0
end

M.hover_select = function()
  init()

  local choices = {}
  for _, p in ipairs(providers) do
    if is_enabled(p) then
      choices[#choices+1] = p
    end
  end

  vim.ui.select(
    choices, {
      prompt = 'Select hover:',
      format_item = function(provider)
        return provider.name
      end,
    },
    async.void(function(provider)
      if provider then
        provider.execute()
      end
    end)
  )
end

M.hover = async.void(function()
  init()

  for _, provider in ipairs(providers) do
    if is_enabled(provider) then
      print('hover.nvim: Running '..provider.name)
      if provider.execute() ~= false then
        return
      end
    end
  end
  print('hover.nvim: could not find any hover providers')
end)

return M

local async = require('hover.async')

local M = {}

local providers = {}
M.providers = providers

function M.register(provider)
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

M.hover = async.void(function()
  for i, provider in ipairs(providers) do
    if provider.enabled == nil or provider.enabled() then
      if not provider.execute or type(provider.execute) ~= 'function' then
        print(string.format('warning: hover provider %s does not provide an execute function',
          provider.name or i))
      else
        print('Running '..provider.name)
        if provider.execute() ~= false then
          print('DONE')
          return
        end
      end
    end
  end
  print('hover.nvim: could not find any hover providers')
end)

return M

local M = {}

local providers = {}
M.providers = providers

function M.register(provider)
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

function M.hover()
  for i, provider in ipairs(providers) do
    if provider.enabled == nil or provider.enabled() then
      if not provider.execute or type(provider.execute) ~= 'function' then
        print(string.format('warning: hover provider %s does not provide an execute function',
          provider.name or i))
      else
        provider.execute()
        return
      end
    end
  end
  print('hover.nvim: coult not find any hover providers')
end

return M

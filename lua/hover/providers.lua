local async = require('hover.async')

local M  = {}

local providers = {}
M.providers = providers

local id_cnt = 0

function M.register(provider)
  if not provider.execute or type(provider.execute) ~= 'function' then
    print(string.format('error: hover provider %s does not provide an execute function',
      provider.name or 'NA'))
    return
  end

  provider.execute = async.wrap(provider.execute, 1)
  provider.id = id_cnt
  id_cnt  = id_cnt + 1

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

return M

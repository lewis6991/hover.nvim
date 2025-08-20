local config = require('hover.config').get()

local M = {}

--- @class Hover.Options
--- @field bufnr integer
--- @field pos {[1]: integer, [2]: integer}
--- @field relative? string
--- @field providers? string[]

--- @class Hover.RegisterProvider
--- @field priority integer
--- @field name string
--- @field execute fun(opts?: Hover.Options, done: fun(result?: false|Hover.Result))
--- @field enabled fun(bufnr: integer, opts?: Hover.Options): boolean

--- @class Hover.Provider : Hover.RegisterProvider
--- @field id integer
--- @field execute fun(opts?: Hover.Options): Hover.Result

--- @type Hover.Provider[]
local providers = {}
M.providers = providers

local id_cnt = 0

--- @param provider Hover.RegisterProvider
function M.register(provider)
  if not provider.execute or type(provider.execute) ~= 'function' then
    vim.notify(
      string.format(
        'error: hover provider %s does not provide an execute function',
        provider.name or 'NA'
      ),
      vim.log.levels.ERROR
    )
    return
  end

  --- @cast provider Hover.Provider

  provider.id = id_cnt
  id_cnt = id_cnt + 1

  local overriden_priorities = config.provider_priorities or {}

  if overriden_priorities[provider.name] then
    provider.priority = overriden_priorities[provider.name]
  end

  if provider.priority then
    for i, p in ipairs(providers) do
      if not p.priority or p.priority < provider.priority then
        table.insert(providers, i, provider)
        return
      end
    end
  end
  providers[#providers + 1] = provider
end

return M

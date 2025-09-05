local M = {}

--- @class Hover.Options
--- @field pos? [integer, integer]
--- @field relative? string
--- @field providers? string[]
---
--- @class Hover.Provider.Params
--- @field bufnr integer
--- @field pos [integer, integer]

--- @class Hover.RegisterProvider
--- @field name string
--- @field execute fun(params: Hover.Provider.Params, done: fun(result?: false|Hover.Result))
--- @field enabled fun(bufnr: integer, opts?: Hover.Options): boolean
--- @field priority? integer

--- @class Hover.Provider: Hover.RegisterProvider
--- @field id integer

--- @type Hover.Provider[]
M.providers = {}

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

  if provider.priority then
    for i, p in ipairs(M.providers) do
      if not p.priority or p.priority < provider.priority then
        table.insert(M.providers, i, provider)
        return
      end
    end
  end
  table.insert(M.providers, provider)
end

return M

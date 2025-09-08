local M = {}

--- @class Hover.Options
--- @field pos? [integer, integer]
--- @field relative? string
--- @field providers? string[]

--- @class Hover.Provider.Params
--- @field bufnr integer
--- @field pos [integer, integer]

--- @class Hover.Provider.Result
---
--- @field lines? string[]
---
--- @field filetype? string
---
--- Use a pre-populated buffer for the hover window. Ignores `lines`.
--- @field bufnr? integer

--- @class Hover.Provider
--- @field name string
---
--- Whether the hover is active for the current context
--- @field enabled fun(bufnr: integer, opts?: Hover.Options): boolean
---
--- Executes the hover
--- If the hover should not be shown for whatever reason call done with `nil` or
--- `false`.
--- @field execute fun(params: Hover.Provider.Params, done: fun(result?: false|Hover.Provider.Result))
--- @field priority? integer

--- @class Hover.ProviderWithId: Hover.Provider
--- @field id integer

--- @type Hover.ProviderWithId[]
M.providers = {}

local id_cnt = 0

--- @param provider Hover.Provider
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

  --- @cast provider Hover.ProviderWithId

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

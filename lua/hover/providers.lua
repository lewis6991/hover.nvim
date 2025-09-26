--- @class Hover.providers
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
--- @field enabled? fun(bufnr: integer, opts?: Hover.Options): boolean
---
--- Executes the hover
--- If the hover should not be shown for whatever reason call done with `nil` or
--- `false`.
--- @field execute fun(params: Hover.Provider.Params, done: fun(result?: false|Hover.Provider.Result))
--- @field priority? integer

--- @class Hover.ProviderGroup
---
--- Optional name used to prefix provider names
--- @field name? string
---
--- @field priority? integer
---
--- @field providers Hover.Provider[]

--- @class (exact) Hover.Provider.Resolved: Hover.Provider
--- @field id integer
--- @field module string

--- @type Hover.Provider.Resolved[]
M.providers = {}

local id_cnt = 0

--- @param provider Hover.Provider
--- @param mod string
--- @param group? Hover.ProviderGroup
function M.add_provider(provider, mod, group)
  if not provider.execute then
    error(
      ('error: hover provider %s does not provide an execute function'):format(
        provider.name or 'NA'
      )
    )
  end

  local resolved = vim.deepcopy(provider) --[[@as Hover.Provider.Resolved]]

  resolved.id = id_cnt
  id_cnt = id_cnt + 1
  resolved.module = mod

  if group then
    resolved.priority = provider.priority or group.priority
    if group.name then
      resolved.name = ('%s[%s]'):format(group.name, provider.name)
    end
  end

  if resolved.priority then
    for i, p in ipairs(M.providers) do
      if not p.priority or p.priority < resolved.priority then
        table.insert(M.providers, i, resolved)
        return
      end
    end
  end
  table.insert(M.providers, resolved)
end

--- @param provider_or_group Hover.Provider|Hover.ProviderGroup
--- @param module string
local function add_provider_or_group(provider_or_group, module)
  if provider_or_group.providers then
    local group = provider_or_group --[[@as Hover.ProviderGroup]]
    local gproviders = group.providers
    for _, p in ipairs(gproviders) do
      M.add_provider(p, module, group)
    end
  else
    local provider = provider_or_group --[[@as Hover.Provider]]
    M.add_provider(provider, module)
  end
end

--- @param module string
--- @param opts? Hover.Config.Provider
local function load_provider(module, opts)
  local ok, provider = pcall(require, module)
  if not ok then
    error(("Error loading provider module '%s': %s"):format(module, provider))
  end

  if type(provider) ~= 'table' then
    if provider == true then
      return -- actively registered
    end
    error(("Provider module '%s' did not return a table: %s"):format(module, provider))
  end

  --- @cast provider Hover.Provider

  for k, v in pairs(opts or {}) do
    if k ~= 'module' then
      provider[k] = v
    end
  end
  local ok2, err = pcall(add_provider_or_group, provider, module)
  if not ok2 then
    error(("Error registering provider '%s' from module %s: %s"):format(provider, module, err))
  end
end

--- @param config_providers (string|Hover.Config.Provider)[]
function M.init(config_providers)
  for _, provider in ipairs(config_providers) do
    if type(provider) == 'table' then
      if not provider.module or type(provider.module) ~= 'string' then
        error(('Invalid provider config, missing module field: %s'):format(vim.inspect(provider)))
      end
      load_provider(provider.module, provider)
    elseif type(provider) == 'string' then
      load_provider(provider)
    else
      error(('Invalid provider config: %s'):format(vim.inspect(provider)))
    end
  end
end

return M

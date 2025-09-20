local config = require('hover.config')

local api = vim.api
local lsp = vim.lsp
local methods = vim.lsp.protocol.Methods
local register_capability = vim.lsp.handlers[methods.client_registerCapability]

local module = 'hover.providers.lsp'

---@type Hover.Config.Provider
local default_config = {
  module = module,
  name = 'LSP',
  priority = 1000,
}

---@return Hover.Config.Provider
local function get_module_config()
  local provider_configs = config.get().providers

  for _, provider_config in ipairs(provider_configs) do
    if type(provider_config) == 'table' and provider_config.module == module then
      return provider_config
    end
  end
  return default_config
end

local module_config = get_module_config()

--- @type table<integer, Hover.Provider?> -- client_id -> provider_id
local lsp_providers = {}

--- @param client vim.lsp.Client
--- @param bufnr integer
--- @param pos [integer,integer]
--- @return lsp.TextDocumentPositionParams
local function create_params(client, bufnr, pos)
  local row, col = pos[1] - 1, pos[2]
  local line = api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]

  if not line then
    if config.get().dev_mode then
      error(string.format('ERROR: row %d is out of range (col=%d)', row, col))
    end
    line = ''
  end
  col = math.min(col, #line)

  return {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = {
      line = row,
      character = vim.str_utfindex(line, client.offset_encoding, col),
    },
  }
end

--- @class LSPProvider
--- @field client_id integer
local LSPProvider = {}
LSPProvider.__index = LSPProvider

function LSPProvider:new(client_id)
  return setmetatable({ client_id = client_id }, self)
end

--- @param bufnr integer
--- @return boolean
function LSPProvider:enabled(bufnr)
  local client =
    lsp.get_clients({ id = self.client_id, bufnr = bufnr, method = 'textDocument/hover' })[1]
  return (client and lsp_providers[client.id]) ~= nil
end

--- @param params Hover.Provider.Params
--- @param done fun(result? :false|Hover.Provider.Result)
function LSPProvider:execute(params, done)
  local client = assert(lsp.get_client_by_id(self.client_id))
  local rparams = create_params(client, params.bufnr, params.pos)
  client:request('textDocument/hover', rparams, function(err, result)
    --- @cast result lsp.Hover?
    if err then
      done({ lines = { 'Error: ' .. vim.inspect(err) } })
    elseif not result or not result.contents then
      done()
    else
      local lines = lsp.util.convert_input_to_markdown_lines(result.contents)
      if vim.tbl_isempty(lines) then
        lines = { 'empty' }
      end
      done({ lines = lines, filetype = 'markdown' })
    end
  end, params.bufnr)
end

--- @param client vim.lsp.Client
--- @return Hover.Provider?
local function register_lsp_provider(client)
  if not client:supports_method('textDocument/hover') then
    return
  end

  local lsp_provider = LSPProvider:new(client.id)
  lsp_providers[client.id] = {
    name = client.name,
    enabled = function(bufnr)
      return lsp_provider:enabled(bufnr)
    end,
    execute = function(params, done)
      lsp_provider:execute(params, done)
    end,
  }
  return lsp_providers[client.id]
end

---@param client_id integer
---@return boolean
local function is_registered(client_id)
  return not not lsp_providers[client_id]
end

---@param providers? Hover.Provider[]
local function providers_group(providers)
  return {
    name = module_config.name,
    priority = module_config.priority,
    providers = providers or {},
  }
end

---@param client_id integer
local function add_lsp_provider_by_id(client_id)
  if not is_registered(client_id) then
    local client = assert(lsp.get_client_by_id(client_id))
    local provider = register_lsp_provider(client)
    if provider then
      require('hover.providers').add_provider(provider, module, providers_group())
    end
  end
end

---@param res lsp.RegistrationParams
---@param capability string
---@return boolean
local function has_capability(res, capability)
  for _, registration in ipairs(res.registrations) do
    if registration.method == capability then
      return true
    end
  end
  return false
end

---@param err? lsp.ResponseError
---@param res lsp.RegistrationParams
---@param ctx lsp.HandlerContext
vim.lsp.handlers[methods.client_registerCapability] = function(err, res, ctx)
  local return_value = register_capability(err, res, ctx)

  if has_capability(res, methods.textDocument_hover) then
    add_lsp_provider_by_id(ctx.client_id)
  end

  return return_value
end

api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    add_lsp_provider_by_id(args.data.client_id)
  end,
})

-- TODO(lewis6991): reliably unregister providers when a client is destroyed.
-- Not currently possible because LspDetach is triggered before the buffer is
-- detached. Possibly need a LspExit event or similar.
-- api.nvim_create_autocmd('LspDetach', {
--   callback = function(args)
--     ...
--   end,
-- })

--- @type Hover.Provider[]
local providers = {}

for _, client in pairs(lsp.get_clients()) do
  local provider = register_lsp_provider(client)
  if provider then
    providers[#providers + 1] = provider
  end
end

return providers_group(providers)

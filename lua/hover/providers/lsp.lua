local api = vim.api
local lsp = vim.lsp

--- @type table<integer, integer?> -- client_id -> provider_id
local lsp_providers = {}

--- @param client vim.lsp.Client
--- @param bufnr integer
--- @param pos [integer,integer]
--- @return lsp.TextDocumentPositionParams
local function create_params(client, bufnr, pos)
  local row, col = pos[1] - 1, pos[2]
  local line = api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]

  if not line then
    if require('hover.config').get().dev_mode then
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
    if err then
      done()
      return
    elseif not result or not result.contents then
      -- no results
      done()
      return
    end

    local util = require('vim.lsp.util')
    local lines = util.convert_input_to_markdown_lines(result.contents)
    if vim.tbl_isempty(lines) then
      lines = { 'empty' }
    end
    done({ lines = lines, filetype = 'markdown' })
  end, params.bufnr)
end

--- @param client vim.lsp.Client
local function register_lsp_provider(client)
  if not client:supports_method('textDocument/hover') then
    return
  end

  local lsp_provider = LSPProvider:new(client.id)
  lsp_providers[client.id] = require('hover.providers').register({
    name = ('LSP[%s]'):format(client.name),
    -- TODO(lewis6991): allow this to be configured somehow
    priority = 1000,
    enabled = function(bufnr)
      return lsp_provider:enabled(bufnr)
    end,
    execute = function(params, done)
      lsp_provider:execute(params, done)
    end,
    client_id = client.id,
  })
end

api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client_id = args.data.client_id
    if not lsp_providers[client_id] then
      local client = assert(lsp.get_client_by_id(client_id))
      register_lsp_provider(client)
    end
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

for _, client in pairs(lsp.get_clients()) do
  register_lsp_provider(client)
end

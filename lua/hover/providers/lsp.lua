--- @param bufnr integer
--- @param method string
--- @param params_fn fun(client: vim.lsp.Client): table
--- @param handler fun(results: table<vim.lsp.Client, lsp.Hover>)
local function buf_request_all(bufnr, method, params_fn, handler)
  local results = {} --- @type table<vim.lsp.Client, lsp.Hover>

  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
  local remaining = #clients

  for _, client in ipairs(clients) do
    -- use _request for 0.10 support
    --- @diagnostic disable-next-line: undefined-field
    local request = client._request or client.request
    request(client, method, params_fn(client), function(_, result)
      remaining = remaining - 1
      results[client] = result
      if remaining == 0 then
        handler(results)
      end
    end, bufnr)
  end
end

--- @param bufnr integer
--- @param row integer
--- @param col integer
--- @return fun(client: vim.lsp.Client): table
local function create_params(bufnr, row, col)
  return function(client)
    local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, row, row + 1, true)

    if not ok then
      print(debug.traceback(('ERROR: row %d is out of range: %s'):format(row, lines)))
    end

    local line = lines[1]
    if not line then
      local config = require('hover.config').get()
      if config.dev_mode then
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
end

--- @type Hover.Provider
return {
  name = 'LSP',
  priority = 1000,
  enabled = function(bufnr)
    return next(vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/hover' })) ~= nil
  end,
  execute = function(params, done)
    local row, col = params.pos[1] - 1, params.pos[2]
    local util = require('vim.lsp.util')

    buf_request_all(
      params.bufnr,
      'textDocument/hover',
      create_params(params.bufnr, row, col),
      function(results)
        for _, result in pairs(results) do
          if result.contents then
            local lines = util.convert_input_to_markdown_lines(result.contents)
            if not vim.tbl_isempty(lines) then
              done({ lines = lines, filetype = 'markdown' })
              return
            end
          end
        end
        -- no results
        done()
      end
    )
  end,
}

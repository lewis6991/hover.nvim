local get_clients = vim.lsp.get_clients

local nvim11 = vim.fn.has('nvim-0.11') == 1

--- @param line string
--- @param encoding 'utf-8' | 'utf-16' | 'utf-32'
--- @param index? integer
--- @return integer
local function str_utfindex010(line, encoding, index)
  if encoding == 'utf-8' then
    return index or #line
  end

  --- @diagnostic disable-next-line: param-type-mismatch
  local col32, col16 = vim.str_utfindex(line, index)
  --- @diagnostic disable-next-line: return-type-mismatch
  return encoding == 'utf-32' and col32 or col16
end

local str_utfindex = nvim11 and vim.str_utfindex or str_utfindex010

--- @param bufnr integer
--- @param method string
--- @param params_fn fun(client: vim.lsp.Client): table
--- @param handler fun(results: table<vim.lsp.Client, lsp.Hover>)
local function buf_request_all(bufnr, method, params_fn, handler)
  local results = {} --- @type table<vim.lsp.Client, lsp.Hover>

  local clients = get_clients({ bufnr = bufnr, method = method })
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
        character = str_utfindex(line, client.offset_encoding, col)
      },
    }
  end
end

require('hover').register({
  name = 'LSP',
  priority = 1000,
  enabled = function(bufnr)
    return next(get_clients({ bufnr = bufnr, method = 'textDocument/hover' })) ~= nil
  end,
  execute = function(opts, done)
    local row, col = opts.pos[1] - 1, opts.pos[2]
    local util = require('vim.lsp.util')

    buf_request_all(
      opts.bufnr,
      'textDocument/hover',
      create_params(opts.bufnr, row, col),
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
})

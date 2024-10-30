local get_clients = vim.lsp.get_clients

--- @param line string?
--- @param index integer
--- @param encoding? 'utf-8' | 'utf-16' | 'utf-32'
--- @return integer
local function str_utfindex(line, index, encoding)
  if encoding == 'utf-8' or not line or #line < index then
    return index
  end

  local col32, col16 = vim.str_utfindex(line, index)
  return encoding == 'utf-32' and col32 or col16
end

--- @param bufnr integer
--- @param method string
--- @param params_fn fun(client: vim.lsp.Client): table
--- @param handler fun(results: table<vim.lsp.Client, lsp.Hover>)
local function buf_request_all(bufnr, method, params_fn, handler)
  local results = {} --- @type table<vim.lsp.Client, lsp.Hover>

  local clients = get_clients({ bufnr = bufnr, method = method })
  local remaining = #clients

  for _, client in ipairs(clients) do
    client.request(method, params_fn(client), function(_, result)
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
    local offset_encoding = client.offset_encoding
    local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, row, row + 1, true)

    if not ok then
      print(debug.traceback(string.format('ERROR: row %d is out of range: %s', row, lines)))
    end

    local ccol = lines and str_utfindex(lines[1], col, offset_encoding) or col

    return {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      position = {
        line = row,
        character = ccol,
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

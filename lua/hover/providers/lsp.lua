
--- @diagnostic disable-next-line:deprecated
local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

require('hover').register {
  name = 'LSP',
  priority = 1000,
  enabled = function()
    for _, client in pairs(get_clients()) do
      if client and client.supports_method('textDocument/hover') then
        return true
      end
    end
    return false
  end,
  execute = function(opts, done)
    local params = {
      textDocument = { uri = vim.uri_from_bufnr(opts.bufnr) },
      position = {
        line = opts.pos[1],
        character = opts.pos[2]
      }
    }

    vim.lsp.buf_request_all(0, 'textDocument/hover', params, function(responses)
      for _, response in pairs(responses) do
        if response.result and response.result.contents then
          local util = require('vim.lsp.util')
          local lines = util.convert_input_to_markdown_lines(response.result.contents)

          if not vim.tbl_isempty(lines) then
            done{lines=lines, filetype="markdown"}
            return
          end
        end
      end

      -- no results
      done()
    end)
  end
}

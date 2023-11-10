
--- @diagnostic disable-next-line:deprecated
local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

require('hover').register {
  name = 'LSP',
  priority = 1000,
  enabled = function()
    for _, client in pairs(get_clients({ bufnr = 0 })) do
      if client and client.supports_method('textDocument/hover') then
        return true
      end
    end
    return false
  end,
  execute = function(opts, done)
    local util = require('vim.lsp.util')

    local row, col = unpack(opts.pos)
    local offset_encoding = util._get_offset_encoding(opts.bufnr)
    row = row - 1
    local line = vim.api.nvim_buf_get_lines(opts.bufnr, row, row + 1, true)[1]
    if line then
      col = util._str_utfindex_enc(line, col, offset_encoding)
    end

    local params = {
      textDocument = util.make_text_document_params(opts.bufnr),
      position = {
        line = row,
        character = col,
      }
    }

    vim.lsp.buf_request_all(0, 'textDocument/hover', params, function(responses)
      for _, response in pairs(responses) do
        if response.result and response.result.contents then
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

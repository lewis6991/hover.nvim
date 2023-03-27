require('hover').register {
  name = 'LSP',
  priority = 1000,
  enabled = function()
    for _, client in pairs(vim.lsp.get_active_clients()) do
      if client and client.supports_method('textDocument/hover') then
        return true
      end
    end
    return false
  end,
  execute = function(done)
    local util = require('vim.lsp.util')
    local params = util.make_position_params()

    vim.lsp.buf_request_all(0, 'textDocument/hover', params, function(responses)
      for _, response in pairs(responses) do
        if response.result and response.result.contents then
          local lines = util.convert_input_to_markdown_lines(response.result.contents)
          lines = util.trim_empty_lines(lines)

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

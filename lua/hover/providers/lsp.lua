require('hover').register {
  name = 'LSP',
  priority = 1000,
  enabled = function()
    local clients = vim.tbl_values(vim.lsp.buf_get_clients())
    for _, client in pairs(clients) do
      if client.resolved_capabilities.hover then
        return true
      end
    end
    return false
  end,
  execute = function(done)
    local util = require('vim.lsp.util')
    local params = util.make_position_params()
    vim.lsp.buf_request(0, 'textDocument/hover', params, function(err, result, ctx, config)
      if result then
        vim.lsp.handlers['textDocument/hover'](err, result, ctx, config)
      end
      done(result and true or false)
    end)
  end
}

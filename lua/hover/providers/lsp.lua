require('hover').register {
  name = 'LSP',
  priority = 1000,
  enabled = function()
    for _, client in pairs(vim.lsp.buf_get_clients()) do
      if client and client.supports_method('textDocument/hover') then
        return true
      end
    end
    return false
  end,
  execute = function(config, done)
    local util = require('vim.lsp.util')
    local params = util.make_position_params()
    vim.lsp.buf_request(0, 'textDocument/hover', params, function(err, result, ctx, _)
      if result then
        vim.lsp.handlers['textDocument/hover'](err, result, ctx, config.preview_opts)
      end
      done(result and true or false)
    end)
  end
}

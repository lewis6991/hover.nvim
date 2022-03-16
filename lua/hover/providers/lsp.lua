require('hover').register {
  name = 'LSP',
  priority = 1000,
  enabled = function()
    return #vim.lsp.get_active_clients() > 0
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

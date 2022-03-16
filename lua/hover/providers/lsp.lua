require('hover').register {
  name = 'LSP',
  enabled = function()
    return #vim.lsp.get_active_clients() > 0
  end,
  execute = vim.lsp.buf.hover
}

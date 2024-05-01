local dap = require('dap')
local ui = require('dap.ui')
local widgets = require('dap.ui.widgets')
local hover = require('hover')

hover.register {
  name = 'DAP',
  enabled = function(bufnr)
    return dap.status() ~= ''
  end,
  execute = function(opts, done)
    local buf = widgets.expression.new_buf()
    local layer = ui.layer(buf)
    local view = {
      layer = function()
        return layer
      end,
    }
    local expression = vim.fn.expand('<cexpr>')
    widgets.expression.render(view, expression)
    done { bufnr = buf }
  end,
  priority = 1001, -- one above lsp
}

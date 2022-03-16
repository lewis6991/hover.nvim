
WIP

Goal: general framework for providing hover providers similar to vim.lsp.buf.hover

## Setup and Installation

via packer:

```lua
  {'lewis6991/hover.nvim', config = function()
    -- Require providers
    require('hover.providers.lsp')

    -- Setup keymap
    vim.keymap.set('n', 'K', require('hover').hover, { desc='hover.nvim' })
  end},
```

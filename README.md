
WIP

Goal: general framework for providing hover providers similar to `vim.lsp.buf.hover`

## Setup and Installation

via packer:

```lua
  {'lewis6991/hover.nvim', config = function()
    -- Require providers
    require('hover.providers.lsp')
    -- require('hover.providers.gh')

    -- Setup keymap
    vim.keymap.set('n', 'K', require('hover').hover, { desc='hover.nvim' })
  end}
```

## Built in Providers

### LSP
`require('hover.providers.lsp')`

### Github
`require('hover.providers.gh')`

Opens issue/PR's for symbols like `#123`.

Requires the `gh` command.

## Creating a hover provider

Call `require('hover').register(<provider>)` with a table containing the following fields:

- `name`: string, name of the hover provider
- `enabled`: function, whether the hover is active for the current context
- `execute`: function, executes the hover
- `priority`: number (optional), priority of the provider


### Example:

```lua
-- Simple
require('hover').register {
   name = 'Simple',
   enabled = function()
     return true
   end,
   execute = function()
     local util = require('vim.lsp.util')
     util.open_floating_preview({'TEST'}, "markdown")
   end
}

-- Built in LSP
require('hover').register {
  name = 'LSP',
  enabled = function()
    return #vim.lsp.get_active_clients() > 0
  end,
  execute = vim.lsp.buf.hover
}
```

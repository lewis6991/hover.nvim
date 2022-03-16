
WIP

Goal: general framework for providing hover providers similar to `vim.lsp.buf.hover`

## Setup and Installation

via packer:

```lua
  {'lewis6991/hover.nvim', config = function()
    -- Require providers
    require('hover.providers.lsp')
    -- require('hover.providers.gh')
    -- require('hover.providers.dictionary')

    -- Setup keymaps
    vim.keymap.set('n',  'K', require('hover').hover       , { desc='hover.nvim'         })
    vim.keymap.set('n', 'gK', require('hover').hover_select, { desc='hover.nvim (select)' })
  end}
```

## Built in Providers

### LSP
`require('hover.providers.lsp')`

Builtin LSP

Priority: 1000

### Github
`require('hover.providers.gh')`

Opens issue/PR's for symbols like `#123`.

Requires the `gh` command.

Priority: 200

### Dictionary
`require('hover.providers.dictionary')`

Definitions for valid words

Priority: 100

## Creating a hover provider

Call `require('hover').register(<provider>)` with a table containing the following fields:

- `name`: string, name of the hover provider
- `enabled`: function, whether the hover is active for the current context
- `execute`: function, executes the hover. Has a `done` callback as it's first argument.
  Call `done(false)` if the hover failed to execute. This will allow other lower priority hovers to run.
- `priority`: number (optional), priority of the provider


### Example:

```lua
-- Simple
require('hover').register {
   name = 'Simple',
   enabled = function()
     return true
   end,
   execute = function(done)
     local util = require('vim.lsp.util')
     util.open_floating_preview({'TEST'}, "markdown")
     done(true)
   end
}

-- Built in LSP
require('hover').register {
  name = 'LSP',
  enabled = function()
    return #vim.lsp.get_active_clients() > 0
  end,
  execute = function(done)
    vim.lsp.buf.hover()
    done(true)
  end
}
```

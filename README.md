# hover.nvim

General framework for context aware hover providers (similar to `vim.lsp.buf.hover`).

Requires Nvim `v0.11.0`

## Screenshots

<table>
  <tr>
    <td>LSP</td>
    <td>Github Issues</td>
  </tr>
  <tr>
    <td><img src="https://user-images.githubusercontent.com/7904185/160881442-1dcd0ccd-9b8c-4bd2-ad32-3fcd675c414d.png"></td>
    <td><img src="https://user-images.githubusercontent.com/7904185/160881424-6fb8d9a0-ced1-4240-a4bf-0991cdbff751.png"></td>
  </tr>
  <tr>
     <td>Dictionary</td>
     <td>Github User</td>
  </tr>
  <tr>
    <td><img src="https://user-images.githubusercontent.com/7904185/160881416-29017747-85df-45be-b704-452ec8f3a8f6.png"></td>
    <td><img src="https://user-images.githubusercontent.com/7904185/204776925-c28354d2-74f5-4d1e-b699-082eea9217dc.png"></td>
  </tr>
 </table>

## Configuration

```lua
require('hover').config({
  --- List of modules names to load as providers.
  --- @type (string|Hover.Config.Provider)[]
  providers = {
    'hover.providers.diagnostic',
    'hover.providers.lsp',
    'hover.providers.dap',
    'hover.providers.man',
    'hover.providers.dictionary',
    -- Optional, disabled by default:
    -- 'hover.providers.gh',
    -- 'hover.providers.gh_user',
    -- 'hover.providers.jira',
    -- 'hover.providers.fold_preview',
    -- 'hover.providers.highlight',
  },
  preview_opts = {
    border = 'single'
  },
  -- Whether the contents of a currently open hover window should be moved
  -- to a :h preview-window when pressing the hover keymap.
  preview_window = false,
  title = true,
  mouse_providers = {
    'hover.providers.lsp',
  },
  mouse_delay = 1000
})

-- Setup keymaps
vim.keymap.set('n', 'K', function()
  require('hover').open()
end, { desc = 'hover.nvim (open)' })

vim.keymap.set('n', 'gK', function()
  require('hover').enter()
end, { desc = 'hover.nvim (enter)' })

vim.keymap.set('n', '<C-p>', function()
    require('hover').hover_switch('previous')
end, { desc = 'hover.nvim (previous source)' })

vim.keymap.set('n', '<C-n>', function()
    require('hover').hover_switch('next')
end, { desc = 'hover.nvim (next source)' })

-- Mouse support
vim.keymap.set('n', '<MouseMove>', function()
  require('hover').mouse()
end, { desc = 'hover.nvim (mouse)' })

vim.o.mousemoveevent = true
```

### Customising providers

Note: Only supported for providers created with passive registration.

Instead of passing a string entry to `providers` in `config()`, an object can
be passed with additional keys to customise fields.

```lua
require('hover').config({
  providers = {
    {
      module = 'hover.providers.diagnostic',
      priority = 2000,
      name = 'Diags'
    }
  }
})
```

## Built in Providers

### LSP

Builtin LSP

Module: `hover.providers.lsp`
Priority: 1000

### Diagnostics

Diagnostics using `vim.diagnostic`

Module: `hover.providers.diagnostic`
Priority: 1001

### DAP

[DAP](https://github.com/mfussenegger/nvim-dap) hover

Module: `hover.providers.dap`
Priority: 1002

### Fold Previewing

Preview closed fold under cursor

Module: `hover.providers.fold_preview`
Priority: 1003

### Github: Issues and PR's

Opens issue/PR's for symbols like `#123`.

Requires the `gh` command.

Module: `hover.providers.gh`
Priority: 200

### Github: Users

Information for github users in `TODO` comments.
Matches `TODO(<user>)` and `TODO(@<user>)`.

Requires the `gh` command.

Module: `hover.providers.gh_user`
Priority: 200

### Jira

Opens issue for symbols like `ABC-123`.

Requires the `jira` [command](https://github.com/ankitpokhrel/jira-cli).

Module: `hover.providers.jira`
Priority: 175

### Man

`man` entries

Module: `hover.providers.man`
Priority: 150

### Dictionary

Definitions for valid words

Module: `hover.providers.dictionary`
Priority: 100

### Highlight

Highlight group preview using `vim.inspect_pos`

Module: `hover.providers.highlight`

## Creating a hover provider

A provider can be create in one of two ways:

### Active registration

Call `require('hover').register(<provider>)` with a `Hover.Provider` object.

#### Example:

```lua
require('hover').register {
   name = 'Simple',
   --- @param bufnr integer
   enabled = function(bufnr)
     return true
   end,
   --- @param params Hover.Provider.Params
   --- @param done fun(result?: false|Hover.Result)
   execute = function(params, done)
     done{lines={'TEST'}, filetype="markdown"}
   end
}
```

### Passive registration

Create a module in `runtimepath` which returns a `Hover.Provider` object.
This module will be loaded by `hover.nvim` when hover is triggered.

#### Example:

In `myplugin/simple_provider.lua`
```lua
return {
   name = 'Simple',
   --- @param bufnr integer
   enabled = function(bufnr)
     return true
   end,
   --- @param params Hover.Provider.Params
   --- @param done fun(result?: false|Hover.Result)
   execute = function(params, done)
     done{lines={'TEST'}, filetype="markdown"}
   end
}
```

```lua
require('hover').setup({
    providers = {
        'myplugin.simple_provider'
    }
})
```

### API

```lua
--- @class Hover.Provider
--- @field name string
---
--- Whether the hover is active for the current context
--- @field enabled fun(bufnr: integer, opts?: Hover.Options): boolean
---
--- Executes the hover
--- If the hover should not be shown for whatever reason call done with `nil` or
--- `false`.
--- @field execute fun(params: Hover.Provider.Params, done: fun(result?: false|Hover.Provider.Result))
--- @field priority? integer

--- @class Hover.Provider.Params
--- @field bufnr integer
--- @field pos [integer, integer]

--- @class Hover.Provider.Result
---
--- @field lines? string[]
---
--- @field filetype? string
---
--- Use a pre-populated buffer for the hover window. Ignores `lines`.
--- @field bufnr? integer

--- @param provider Hover.Provider
function Hover.register(provider) end
```

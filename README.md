# hover.nvim

General framework for context aware hover providers (similar to `vim.lsp.buf.hover`).

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

## Setup and Installation

via packer:

```lua
use {
    "lewis6991/hover.nvim",
    config = function()
        require("hover").setup {
            init = function()
                -- Require providers
                require("hover.providers.lsp")
                -- require('hover.providers.gh')
                -- require('hover.providers.gh_user')
                -- require('hover.providers.jira')
                -- require('hover.providers.man')
                -- require('hover.providers.dictionary')
            end,
            preview_opts = {
                border = nil
            },
            -- Whether the contents of a currently open hover window should be moved
            -- to a :h preview-window when pressing the hover keymap.
            preview_window = false,
            title = true,

            diagnostics = false,
        }

        -- Setup keymaps
        vim.keymap.set("n", "K", require("hover").hover, {desc = "hover.nvim"})
        vim.keymap.set("n", "gK", require("hover").hover_select, {desc = "hover.nvim (select)"})
    end
}
```

## Built in Providers

### LSP
`require('hover.providers.lsp')`

Builtin LSP

Priority: 1000

### Github: Issues and PR's
`require('hover.providers.gh')`

Opens issue/PR's for symbols like `#123`.

Requires the `gh` command.

Priority: 200

### Github: Users
`require('hover.providers.gh_user')`

Information for github users in `TODO` comments.
Matches `TODO(<user>)` and `TODO(@<user>)`.

Requires the `gh` command.

Priority: 200

### Jira
`require('hover.providers.jira')`

Opens issue for symbols like `ABC-123`.

Requires the `jira` [command](https://github.com/ankitpokhrel/jira-cli).

Priority: 175

### Man
`require('hover.providers.man')`

`man` entries

Priority: 150

### Dictionary
`require('hover.providers.dictionary')`

Definitions for valid words

Priority: 100

## Creating a hover provider

Call `require('hover').register(<provider>)` with a table containing the following fields:

- `name`: string, name of the hover provider
- `enabled`: function, whether the hover is active for the current context
- `execute`: function, executes the hover. Has the following arguments:
    - `done`: callback. First argument should be passed:
        - `nil`/`false` if the hover failed to execute. This will allow other lower priority hovers to run.
        - A table with the following fields:
          - `lines` (string array)
          - `filetype` (string)
          - `bufnr` (integer?) use a pre-populated buffer for the hover window. Ignores `lines`.
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
     done{lines={'TEST'}, filetype="markdown"}
   end
}
```

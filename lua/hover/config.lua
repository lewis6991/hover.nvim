local M = {}

--- @class Hover.Config.Provider
--- @field module string
--- @field name? string
--- @field priority? integer

--- @class Hover.Config
--- @field dev_mode? boolean
--- @field init? fun()
local default_config = {
  preview_opts = {
    border = 'single',
  },
  preview_window = false,
  title = true,
  mouse_delay = 1000,
  --- @type (string|Hover.Config.Provider)[]
  providers = {
    'hover.providers.diagnostic',
    'hover.providers.lsp',
    'hover.providers.dap',
    'hover.providers.man',
    'hover.providers.dictionary',
  },
  mouse_providers = { 'hover.providers.lsp' },
}

--- @class Hover.UserConfig : Hover.Config
---
--- Whether the contents of a currently open hover window should be moved
--- to a :h preview-window when pressing the hover keymap.
--- @field preview_window? boolean
---
--- @field title? boolean
---
--- List of modules names to load as providers.
--- @field providers? (string|Hover.Config.Provider)[]
---
--- List of modules names to load as providers for the hover window created
--- by `require('hover').mouse()`.
--- @field mouse_providers? string[]
---
--- @field mouse_delay? integer
---
--- @field preview_opts? vim.api.keyset.win_config

--- @type Hover.Config
local config

--- @param user_config Hover.UserConfig
function M.set(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config)
end

function M.get()
  return config or default_config
end

return M

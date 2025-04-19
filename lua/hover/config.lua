local M = {}

--- @class Hover.Config
--- @field dev_mode? boolean
--- @field init? fun()
local default_config = {
  preview_opts = {
    border = 'single',
  },
  preview_window = false,
  title = true,
  mouse_providers = { 'LSP' },
  mouse_delay = 1000,
}

--- @class Hover.UserConfig: Hover.Config
--- @field title? boolean | table
--- @field mouse_providers? string[]
--- @field mouse_delay? integer
--- @field preview_opts? table
--- @field preview_window? boolean

--- @type Hover.Config
local config

--- @param user_config Hover.UserConfig
function M.set(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config)
end

function M.get()
  return config
end

return M

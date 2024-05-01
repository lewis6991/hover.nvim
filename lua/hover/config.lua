local M = {}

--- @class Hover.Config
--- @field init? fun()
--- @field preview_opts table
--- @field multiple_hover "cycle_providers"|"focus"|"preview_window"|"close"|"ignore"
--- @field title boolean
--- @field mouse_providers string[]
--- @field mouse_delay integer
local default_config = {
  preview_opts = {
    border = 'single'
  },
  multiple_hover = 'cycle_providers',
  preview_window = false,
  title = true,
  mouse_providers = { 'LSP' },
  mouse_delay = 1000,
}

--- @type Hover.Config
local config

--- @param user_config Hover.Config
function M.set(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config)
end

function M.get()
  return config
end

return M

local M = {}

--- @class Hover.Config
--- @field init fun()
local default_config = {
  preview_opts = {
    border = 'single',
  },
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

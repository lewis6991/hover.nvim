local M = {}

---@class HoverConfig
---@field init fun()
local default_config = {
  preview_opts = {
    border = 'single'
  },
  preview_window = false,
  title = true,
  diagnostics = false,
}

---@type HoverConfig
local config

---@param user_config HoverConfig
function M.set(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config)
end

function M.get()
  return config
end

return M

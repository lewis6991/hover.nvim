local M = {}

local default_config = {
  preview_opts = {
    border = 'single'
  },
  title = false
}

local config

function M.set(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config)
end

function M.get()
  return config
end

return M

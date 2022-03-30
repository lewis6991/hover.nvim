local M = {}

local default_config = {
  preview_opts = {
    border = 'single'
  }
}

function M.set(user_config)
  M.config = vim.tbl_deep_extend('force', default_config, user_config)
end

return M

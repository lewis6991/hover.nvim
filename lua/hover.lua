local M = {}

--- @param provider Hover.RegisterProvider
function M.register(provider)
  require('hover.providers').register(provider)
end

--- @param opts Hover.Options
function M.hover(opts)
  require('hover.actions').hover(opts)
end

--- @param opts Hover.Options
function M.hover_select(opts)
  require('hover.actions').hover_select(opts)
end

function M.hover_mouse()
  require('hover.actions').hover_mouse()
end

--- @param bufnr integer
function M.close(bufnr)
  require('hover.actions').close(bufnr)
end

---@param user_config Hover.Config
function M.setup(user_config)
  require('hover.config').set(user_config)
end

return M

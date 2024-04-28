local M = {}

--- @param provider Hover.RegisterProvider
function M.register(provider)
  require('hover.providers').register(provider)
end

--- @param opts? Hover.PartialOptions
function M.hover(opts)
  require('hover.actions').hover(opts)
end

--- @param opts? Hover.PartialOptions
function M.hover_select(opts)
  require('hover.actions').hover_select(opts)
end

--- @param direction 'previous'|'next'
--- @param opts? Hover.PartialOptions
function M.hover_switch(direction, opts)
  require('hover.actions').hover_switch(direction, opts)
end

function M.hover_mouse()
  require('hover.actions').hover_mouse()
end

function M.close()
  require('hover.actions').close()
end

--- @param user_config Hover.Config
function M.setup(user_config)
  require('hover.config').set(user_config)
end

return M

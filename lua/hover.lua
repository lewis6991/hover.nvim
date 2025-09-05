--- @class Hover
local M = {}

--- Registers a new hover provider
--- @param provider Hover.RegisterProvider
function M.register(provider)
  require('hover.providers').register(provider)
end

--- Opens the hover window
--- @param opts? Hover.Options
function M.open(opts)
  require('hover.actions').open(opts)
end

--- Select a hover provider interactively.
--- @param opts? Hover.Options
function M.select(opts)
  require('hover.actions').select(opts)
end

--- Switch between hover providers in the window
--- @param direction 'previous'|'next'
--- @param opts? Hover.Options
function M.switch(direction, opts)
  require('hover.actions').switch(direction, opts)
end

--- Enters the hover window (focuses it).
function M.enter()
  require('hover.actions').enter()
end

--- Handles mouse events for hover.
--- Will open hover window if not opened after a delay.
function M.mouse()
  require('hover.actions').mouse()
end

--- Closes the hover window for the given buffer.
--- @param bufnr? integer
function M.close(bufnr)
  require('hover.actions').close(bufnr)
end

--- Sets up Hover.nvim with user configuration.
--- @param user_config Hover.UserConfig
function M.setup(user_config)
  require('hover.config').set(user_config)
end

do -- deprecated
  --- @deprecated use select() instead.
  function M.hover_select(opts)
    M.select(opts)
  end

  --- @deprecated use switch() instead
  function M.hover_switch(direction, opts)
    M.switch(direction, opts)
  end

  --- @deprecated use mouse() instead.
  function M.hover_mouse()
    M.mouse()
  end

  --- @deprecated use open() instead.
  function M.hover(opts)
    M.open(opts)
  end
end

return M

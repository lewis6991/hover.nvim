local M = {}

local exports = {
  register     = 'hover.providers',
  hover        = 'hover.actions',
  hover_select = 'hover.actions'
}

---@param user_config HoverConfig
function M.setup(user_config)
  require('hover.config').set(user_config)
end

return setmetatable(M, {
  __index = function(t, k)
    if exports[k] then
      t[k] = require(exports[k])[k]
    end
    return t[k]
  end
})

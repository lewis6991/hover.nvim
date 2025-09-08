local api = vim.api
local hover = require('hover')

--- @param buf integer
--- @return integer? win
local function find_window(buf)
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
end

--- @param win integer
--- @param buf integer
local function resize_window(win, buf)
  if not api.nvim_win_is_valid(win) then
    -- Could happen if the user moves the buffer into a new window
    return
  end
  local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
  local width = 0
  local height = #lines
  for _, line in pairs(lines) do
    width = math.max(width, #line)
  end
  local columns = vim.o.columns
  local max_win_width = math.floor(columns * 0.9)
  width = math.min(width, max_win_width)
  local max_win_height = vim.o.lines
  height = math.min(height, max_win_height)
  api.nvim_win_set_width(win, width)
  api.nvim_win_set_height(win, height)
end

--- @param buf integer
--- @return any
local function resizing_layer(buf)
  local ui = require('dap.ui')
  local layer = ui.layer(buf)
  local orig_render = layer.render
  layer.render = function(...)
    orig_render(...)
    local win = find_window(buf)
    if win ~= nil and api.nvim_win_get_config(win).relative ~= '' then
      resize_window(win, buf)
    end
  end
  return layer
end

--- @param buf integer
local function set_default_bufopts(buf)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = 'nofile'

  local function keymap(key, f)
    vim.keymap.set('n', key, f, { buffer = buf })
  end

  keymap('<CR>', function()
    require('dap.ui').trigger_actions({ mode = 'first' })
  end)
  keymap('a', function()
    require('dap.ui').trigger_actions()
  end)
  keymap('o', function()
    require('dap.ui').trigger_actions()
  end)
  keymap('<2-LeftMouse>', function()
    require('dap.ui').trigger_actions()
  end)
end

--- @type Hover.Provider
return {
  name = 'DAP',
  enabled = function()
    local has_dap, dap = pcall(require, 'dap')
    return has_dap and dap.session()
  end,
  execute = function(_params, done)
    local buf = api.nvim_create_buf(false, true)
    set_default_bufopts(buf)
    local layer = resizing_layer(buf)
    local fake_view = {
      layer = function()
        return layer
      end,
    }
    local expression = vim.fn.expand('<cexpr>')
    local widgets = require('dap.ui.widgets')
    widgets.expression.render(fake_view, expression)
    done({ bufnr = buf })
  end,
  priority = 1002, -- above lsp and diagnostics
}

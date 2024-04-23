local api = vim.api
local dap = require('dap')
local ui = require('dap.ui')
local widgets = require('dap.ui.widgets')
local hover = require('hover')

local function find_window (buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
end

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
  local columns = api.nvim_get_option('columns')
  local max_win_width = math.floor(columns * 0.9)
  width = math.min(width, max_win_width)
  local max_win_height = api.nvim_get_option('lines')
  height = math.min(height, max_win_height)
  api.nvim_win_set_width(win, width)
  api.nvim_win_set_height(win, height)
end


local function resizing_layer(buf)
  local layer = ui.layer(buf)
  local orig_render = layer.render
  layer.render = function(...)
    orig_render(...)
    local win = find_window(buf)
    if api.nvim_win_get_config(win).relative ~= '' then
      resize_window(win, buf)
    end
  end
  return layer
end

hover.register {
  name = 'DAP',
  --- @param bufnr integer
  enabled = function(bufnr)
    return dap.status() ~= ""
  end,
  --- @param opts Hover.Options
  --- @param done fun(result: any)
  execute = function(opts, done)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.keymap.set("n", "<CR>", function () ui.trigger_actions({ mode = 'first' }) end, { buffer = buf })
    vim.keymap.set("n", "a", ui.trigger_actions, { buffer = buf })
    vim.keymap.set("n", "o", ui.trigger_actions, { buffer = buf })
    vim.keymap.set("n", "<2-LeftMouse>", ui.trigger_actions, { buffer = buf })
    local layer = resizing_layer(buf)
    local session = require('dap').session()
    if not session then
      layer.render({'No active session'})
      return
    end
    local fake_view = {
      layer = function ()
        return layer
      end,
    }
    local expression = vim.fn.expand('<cexpr>')
    widgets.expression.render(fake_view, expression)
    done { bufnr = buf }
  end,
  priority = 1001, -- one above lsp
}

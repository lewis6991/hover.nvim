local api = vim.api
local npcall = vim.F.npcall

local has_winbar = vim.fn.has('nvim-0.8') == 1

local async = require('hover.async')

local providers = require('hover.providers').providers
local get_config = require('hover.config').get

local M = {}

local initialised = false

local function is_enabled(provider)
  return provider.enabled == nil or provider.enabled()
end

local function add_title(winnr, active_provider_id)
  if not has_winbar then
    vim.notify_once('hover.nvim: `config.title` requires neovim >= 0.8.0',
                    vim.log.levels.WARN)
    return
  end

  ---@type string[]
  local title = {}
  local winbar_length = 0

  for _, p in ipairs(providers) do
    if is_enabled(p) then
      local hl = p.id == active_provider_id and 'TabLineSel' or 'TabLineFill'
      title[#title+1] = string.format('%%#%s# %s ', hl, p.name)
      title[#title+1] = '%#Normal# '
      winbar_length = winbar_length + #p.name + 2 -- + 2 for whitespace padding
    end
  end

  vim.wo[winnr].winbar = table.concat(title, '')
  local config = api.nvim_win_get_config(winnr)
  api.nvim_win_set_config(winnr, {
    height = config.height + 1,
    width = math.max(config.width, winbar_length + 2) -- + 2 for border
  })
end

---@param name string
---@param value any
---@return integer?
local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

local function focus_or_close_floating_window()
  local bufnr = api.nvim_get_current_buf()
  local winnr = api.nvim_get_current_win()

  -- Go back to previous window if we are in a focusable one
  if npcall(api.nvim_win_get_var, winnr, 'hover') then
    api.nvim_command("wincmd p")
    return true
  end
  local win = find_window_by_var('hover', bufnr)
  if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
    -- focus and return the existing buf, win
    api.nvim_set_current_win(win)
    api.nvim_command("stopinsert")
    return true
  end
  return false
end

local function get_preview_window()
  for _, win in ipairs(api.nvim_tabpage_list_wins(api.nvim_get_current_tabpage())) do
    if vim.wo[win].previewwindow then
      return win
    end
  end
end

local function create_preview_window()
  vim.cmd.new()
  vim.cmd.stopinsert()
  local pwin = api.nvim_get_current_win()
  vim.wo[pwin].previewwindow = true
  api.nvim_win_set_height(pwin, api.nvim_get_option('previewheight'))
  return pwin
end

local function send_to_preview_window()
  local bufnr = api.nvim_get_current_buf()
  local winid = api.nvim_get_current_win()
  local hover_win = find_window_by_var('hover', bufnr)
  if not hover_win or not api.nvim_win_is_valid(hover_win) then
    return false
  end
  local hover_bufnr = api.nvim_win_get_buf(hover_win)
  if not hover_bufnr or not api.nvim_buf_is_valid(hover_bufnr) then
    return false
  end
  if vim.fn.pumvisible() ~= 0 then
    return false
  end
  local pwin = get_preview_window() or create_preview_window()
  local pwin_prev_buf = api.nvim_win_get_buf(pwin)
  api.nvim_win_set_buf(pwin, hover_bufnr)
  -- Unload the empty buffer created along with preview window
  local bufexist, buflinecnt = pcall(api.nvim_buf_line_count, pwin_prev_buf)
  if bufexist and buflinecnt == 1 and
    api.nvim_buf_get_lines(pwin_prev_buf, 0, -1, false)[1] == "" then
    api.nvim_buf_delete(pwin_prev_buf, {})
  end
  vim.wo[pwin].winbar = vim.wo[hover_win].winbar
  api.nvim_win_close(hover_win, true)
  api.nvim_set_current_win(winid)
  return true
end

local function do_hover()
  if get_config().preview_window then
    return send_to_preview_window()
  else
    return focus_or_close_floating_window()
  end
end

local function show_hover(provider_id, config, result, opts)
  local util = require('hover.util')
  local _, winnr = util.open_floating_preview(result.lines, result.bufnr, result.filetype, opts)

  if config.title then
    add_title(winnr, provider_id)
  end
end

---@async
---@param provider Provider
local function run_provider(provider)
  local config = get_config()
  if config.diagnostics then
    api.nvim_echo({{'hover.nvim: Running provider: '..provider.name}}, false, {})
  end
  local opts = vim.deepcopy(config.preview_opts)
  opts.focus_id = 'hover'

  if opts.focusable ~= false and opts.focus ~= false then
    if do_hover() then
      return true
    end
  end

  local result = provider.execute_a()
  if result then
    async.scheduler()
    show_hover(provider.id, config, result, opts)
    return true
  end

  return false
end

local function init()
  if initialised then
    return
  end
  initialised = true

  local config = get_config()
  if config and type(config.init) == 'function' then
    config.init()
  end
end

---@async
M.hover = async.void(function()
  init()

  for _, provider in ipairs(providers) do
    async.scheduler()
    if is_enabled(provider) and run_provider(provider) then
      return
    end
  end

  local config = get_config()
  if config.diagnostics then
    api.nvim_echo({{'hover.nvim: could not find any hover providers', 'WarningMsg'}}, false, {})
  end
end)

M.hover_select = function()
  init()

  vim.ui.select(
    vim.tbl_filter(is_enabled, providers),
    {
      prompt = 'Select hover:',
      format_item = function(provider)
        return provider.name
      end
    },
    function (provider)
      if provider then
        async.void(run_provider)(provider)
      end
    end
  )
end

return M

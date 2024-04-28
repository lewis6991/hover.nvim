local api = vim.api

local has_winbar = vim.fn.has('nvim-0.8') == 1

local async = require('hover.async')

local providers = require('hover.providers').providers
local get_config = require('hover.config').get

local M = {}

local initialised = false

--- @type integer?
local _hover_win = nil

--- @return integer?
local function get_hover_win()
  if _hover_win and api.nvim_win_is_valid(_hover_win) then
    return _hover_win
  end
end

--- @param provider Hover.Provider
--- @param bufnr integer
--- @return boolean
local function is_enabled(provider, bufnr)
  return provider.enabled == nil or provider.enabled(bufnr)
end

--- @param bufnr integer
--- @param winnr integer
--- @param active_provider_id integer
local function add_title(bufnr, winnr, active_provider_id)
  if not has_winbar then
    vim.notify_once('hover.nvim: `config.title` requires neovim >= 0.8.0',
                    vim.log.levels.WARN)
    return
  end

  ---@type string[]
  local title = {}
  local winbar_length = 0

  for _, p in ipairs(providers) do
    if is_enabled(p, bufnr) then
      local hl = p.id == active_provider_id and 'TabLineSel' or 'TabLineFill'
      title[#title+1] = string.format('%%#%s# %s ', hl, p.name)
      title[#title+1] = '%#Normal# '
      winbar_length = winbar_length + #p.name + 2 -- + 2 for whitespace padding
    end
  end

  local config = api.nvim_win_get_config(winnr)
  api.nvim_win_set_config(winnr, {
    height = config.height + 1,
    width = math.max(config.width, winbar_length + 2) -- + 2 for border
  })
  vim.wo[winnr].winbar = table.concat(title, '')
end

--- @param winid integer
local function focus_floating_window(winid)
  if vim.fn.pumvisible() ~= 0 then
    return
  end

  api.nvim_set_current_win(winid)
  vim.cmd.stopinsert()
end

--- @return integer?
local function get_preview_window()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].previewwindow then
      return win
    end
  end
end

--- @return integer
local function create_preview_window()
  local curwin = api.nvim_get_current_win()

  -- open a horizontal window with height = previewheight
  vim.cmd.new({ range = { vim.o.previewheight } })
  local pwin = api.nvim_get_current_win()
  vim.wo[pwin].previewwindow = true

  api.nvim_set_current_win(curwin)

  return pwin
end

--- @param winid integer
local function send_to_preview_window(winid)
  if vim.fn.pumvisible() ~= 0 then
    return
  end

  local bufnr = api.nvim_win_get_buf(winid)
  local pwin = get_preview_window()
  if not pwin then
    pwin = create_preview_window()
    local pwin_empty_buf = api.nvim_win_get_buf(pwin)
    api.nvim_win_set_buf(pwin, bufnr)
    -- Unload the empty buffer created along with preview window
    api.nvim_buf_delete(pwin_empty_buf, {})
  else
    api.nvim_win_set_buf(pwin, bufnr)
  end

  vim.wo[pwin].winbar = vim.wo[winid].winbar
  api.nvim_win_close(winid, true)

  return pwin
end

--- @class Hover.Result
--- @field lines? string[]
--- @field bufnr? integer
--- @field filetype? string

--- @param popts Hover.Options
--- @param provider_id integer
--- @param result Hover.Result
local function show_hover(popts, provider_id, result)
  local config = get_config()

  local opts = vim.deepcopy(config.preview_opts)
  opts.relative = popts.relative

  local util = require('hover.util')
  local hover_win, hover_buf = util.open_floating_preview(result.lines, result.bufnr, result.filetype, opts)

  _hover_win = hover_win

  if config.title then
    add_title(popts.bufnr, hover_win, provider_id)
  end

  vim.b[hover_buf].hover = popts.bufnr
  vim.b[hover_buf].hover_pos = popts.pos
  vim.b[hover_buf].hover_provider = provider_id
end

--- @param provider Hover.Provider
--- @param popts Hover.Options
--- @return boolean
local function do_provider(provider, popts)
  local result = provider.execute_a(popts)
  if result then
    async.scheduler()
    show_hover(popts, provider.id, result)
    return true
  end

  return false
end

--- @param provider Hover.Provider
--- @param opts Hover.Options
local function run_provider(provider, opts)
  local focus_window = false

  local hover_win = get_hover_win()
  if hover_win then
    -- if the popup is focused now, refocus it afterwards
    if hover_win == api.nvim_get_current_win() then
      focus_window = true
    end

    -- close the popup
    api.nvim_win_close(hover_win, true)
  end

  do_provider(provider, opts)

  if focus_window then
    hover_win = get_hover_win()
    if hover_win then
      focus_floating_window(hover_win)
    end
  end
end

--- @param opts Hover.Options
--- @param direction 'previous'|'next'
local function run_cycle_providers(opts, direction)
  local focus_window = false

  local current_id

  local hover_win = get_hover_win()
  if hover_win then
    local hover_buf = api.nvim_win_get_buf(hover_win)
    current_id = vim.b[hover_buf].hover_provider

    -- if the popup is focused now, refocus it afterwards
    if hover_win == api.nvim_get_current_win() then
      focus_window = true
    end

    -- close the popup
    api.nvim_win_close(hover_win, true)
  end

  local current_idx
  local active_providers = {} -- zero-indexed
  local provider_count = 0
  for _, p in ipairs(providers) do
    if not opts.providers or vim.tbl_contains(opts.providers, p.name) then
      if p.id == current_id then
        current_idx = provider_count
      end
      if is_enabled(p, opts.bufnr) then
        active_providers[provider_count] = p
        provider_count = provider_count + 1
      end
    end
  end

  if provider_count == 0 then
    return
  end

  -- start at current_idx +/- 1, or 0 if current_idx == nil
  local start_idx = 0
  if current_idx then
    if direction == 'previous' then
      start_idx = (current_idx - 1) % provider_count
    elseif direction == 'next' then
      start_idx = (current_idx + 1) % provider_count
    end
  end

  -- go forwards/backwards through active_providers until one works
  -- start at start_idx, wrap around when hitting either end
  -- exit when we get back to start_idx (no providers worked)
  local i = start_idx
  while not do_provider(active_providers[i], opts) do
    if direction == 'previous' then
      i = (i - 1) % provider_count
    elseif direction == 'next' then
      i = (i + 1) % provider_count
    end
    if i == start_idx then
      return
    end
  end

  if focus_window then
    hover_win = get_hover_win()
    if hover_win then
      focus_floating_window(hover_win)
    end
  end
end

--- @param opts Hover.Options?
--- @return Hover.Options
local function make_opts(opts)
  opts = opts or {}

  local hover_win = get_hover_win()
  if hover_win then
    -- if a popup already exists, override with its opts
    local hover_buf = api.nvim_win_get_buf(hover_win)
    opts.bufnr = vim.b[hover_buf].hover
    opts.pos = vim.b[hover_buf].hover_pos
  else
    opts.bufnr = opts.bufnr or api.nvim_get_current_buf()
    opts.pos = opts.pos or api.nvim_win_get_cursor(0)
  end

  return opts
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

function M.close()
  local hover_win = get_hover_win()
  if hover_win then
    api.nvim_win_close(hover_win, true)
  end
end

--- @param opts Hover.Options?
M.hover = async.void(function(opts)
  init()

  opts = make_opts(opts)

  -- hover window exists, and in focus -> cycle providers
  -- hover window exists, not in focus -> use config.multiple_hover
  -- else -> cycle providers

  local hover_win = get_hover_win()
  if hover_win and hover_win ~= api.nvim_get_current_win() then
    local config = get_config()

    if config.multiple_hover == 'focus' then
      focus_floating_window(hover_win)
      return
    elseif config.multiple_hover == 'preview_window' then
      send_to_preview_window(hover_win)
      return
    elseif config.multiple_hover == 'close' then
      api.nvim_win_close(hover_win, true)
      return
    elseif config.multiple_hover == 'ignore' then
      return
    end
    -- fallthrough if config.multiple_hover == 'cycle_providers'
    -- (or an invalid string)
  end

  run_cycle_providers(opts, 'next')
end)

--- @param direction 'previous'|'next'
--- @param opts Hover.Options?
M.hover_switch = async.void(function(direction, opts)
  init()

  opts = make_opts(opts)

  run_cycle_providers(opts, direction)
end)

--- @param opts Hover.Options?
function M.hover_select(opts)
  init()

  opts = make_opts(opts)

  local active_providers = vim.tbl_filter(function(p)
    if not opts.providers or vim.tbl_contains(opts.providers, p.name) then
      if is_enabled(p, opts.bufnr) then
        return true
      end
    end
    return false
  end, opts.providers or providers)

  vim.ui.select(
    active_providers,
    {
      prompt = 'Select hover:',
      format_item = function(provider)
        return provider.name
      end
    },
    function(provider)
      if provider then
        async.void(run_provider)(provider, opts)
      end
    end
  )
end

local timer --- @type uv.uv_timer_t

function M.hover_mouse()
  timer = timer or assert(vim.uv.new_timer())

  local config = get_config()

  timer:start(config.mouse_delay, 0, vim.schedule_wrap(function()
    local pos = vim.fn.getmousepos()
    if pos.winid == 0 then return end

    local buf = vim.fn.winbufnr(pos.winid)
    if buf == -1 then return end

    -- don't trigger if hovering in the popup window
    local hover_win = get_hover_win()
    if hover_win then
      local hover_buf = api.nvim_win_get_buf(hover_win)
      if buf == hover_buf then
        return
      end
    end

    M.close()

    M.hover {
      providers = config.mouse_providers,
      relative = 'mouse',
      pos = { pos.line, pos.column },
      bufnr = buf
    }
  end))
end

return M

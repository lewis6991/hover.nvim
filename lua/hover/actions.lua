local api = vim.api

local async = require('hover.async')

local function get_config()
  return require('hover.config').get()
end

--- @class Hover.actions
local M = {}

local initialised = false

--- @param provider Hover.Provider
--- @param bufnr integer
--- @param opts Hover.Options
--- @return boolean
local function is_enabled(provider, bufnr, opts)
  opts.pos = opts.pos or api.nvim_win_get_cursor(0)

  if opts.providers and not vim.tbl_contains(opts.providers, provider.name) then
    return false
  end

  assert(type(bufnr) == 'number')
  return provider.enabled == nil or provider.enabled(bufnr, opts)
end

--- @param bufnr integer
--- @param opts Hover.Options
--- @return Hover.Provider[]
local function get_providers(bufnr, opts)
  local providers = require('hover.providers').providers
  local ret = {} --- @type Hover.Provider[]
  for _, p in ipairs(providers) do
    if is_enabled(p, bufnr, opts) then
      ret[#ret + 1] = p
    end
  end
  return ret
end

--- @param bufnr integer
--- @param winnr integer
--- @param active_provider_id integer
--- @param opts Hover.Options
local function add_title(bufnr, winnr, active_provider_id, opts)
  ---@type string[]
  local title = {}
  local winbar_length = 0

  for _, p in ipairs(get_providers(bufnr, opts)) do
    local hl = p.id == active_provider_id and 'TabLineSel' or 'TabLineFill'
    title[#title + 1] = string.format('%%#%s# %s ', hl, p.name)
    title[#title + 1] = '%#Normal# '
    winbar_length = winbar_length + #p.name + 2 -- + 2 for whitespace padding
  end

  local config = api.nvim_win_get_config(winnr)
  api.nvim_win_set_config(winnr, {
    height = assert(config.height) + 1,
    width = math.max(assert(config.width), winbar_length + 2), -- + 2 for border
  })
  vim.wo[winnr].winbar = table.concat(title, '')
end

---@param name string
---@param value any
---@return integer?
local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.w[win][name] == value then
      return win
    end
  end
end

--- @return integer? winid
local function focus_or_close_floating_window()
  local bufnr = api.nvim_get_current_buf()
  local winid = api.nvim_get_current_win()

  -- Go back to previous window if we are in a focusable one
  if vim.w[winid].hover then
    vim.cmd.wincmd('p')
    return winid
  end

  local win = find_window_by_var('hover', bufnr)
  if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
    -- focus and return the existing buf, win
    api.nvim_set_current_win(win)
    vim.cmd.stopinsert()
    return win
  end
end

--- @return integer?
local function get_preview_window()
  for _, win in ipairs(api.nvim_tabpage_list_wins(api.nvim_get_current_tabpage())) do
    if vim.wo[win].previewwindow then
      return win
    end
  end
end

--- @return integer
local function create_preview_window()
  vim.cmd.new()
  vim.cmd.stopinsert()
  local pwin = api.nvim_get_current_win()
  vim.wo[pwin].previewwindow = true
  api.nvim_win_set_height(pwin, vim.o.previewheight)
  return pwin
end

--- @return integer? winid
local function send_to_preview_window()
  local bufnr = api.nvim_get_current_buf()
  local winid = api.nvim_get_current_win()
  local hover_win = find_window_by_var('hover', bufnr)
  if not hover_win or not api.nvim_win_is_valid(hover_win) then
    return
  end
  local hover_bufnr = api.nvim_win_get_buf(hover_win)
  if not hover_bufnr or not api.nvim_buf_is_valid(hover_bufnr) then
    return
  end
  if vim.fn.pumvisible() ~= 0 then
    return
  end
  local pwin = get_preview_window() or create_preview_window()
  local pwin_prev_buf = api.nvim_win_get_buf(pwin)
  api.nvim_win_set_buf(pwin, hover_bufnr)
  -- Unload the empty buffer created along with preview window
  local bufexist, buflinecnt = pcall(api.nvim_buf_line_count, pwin_prev_buf)
  if
    bufexist
    and buflinecnt == 1
    and api.nvim_buf_get_lines(pwin_prev_buf, 0, -1, false)[1] == ''
  then
    api.nvim_buf_delete(pwin_prev_buf, {})
  end
  vim.wo[pwin].winbar = vim.wo[hover_win].winbar
  api.nvim_win_close(hover_win, true)
  api.nvim_set_current_win(winid)
  return pwin
end

--- @return integer? winid
local function do_hover()
  if get_config().preview_window then
    return send_to_preview_window()
  end
  return focus_or_close_floating_window()
end

--- @class Hover.Result
--- @field lines? string[]
--- @field bufnr? integer
--- @field filetype? string

--- @param bufnr integer
--- @param provider_id integer
--- @param config Hover.Config
--- @param result Hover.Result
--- @param popts Hover.Options
--- @param float_opts table
--- @return integer hover_winid
local function show_hover(bufnr, provider_id, config, result, popts, float_opts)
  local util = require('hover.util')
  local winid = util.open_floating_preview(result.lines, result.bufnr, result.filetype, float_opts)

  if config.title then
    add_title(bufnr, winid, provider_id, popts)
  end
  vim.w[winid].hover_provider = provider_id

  return winid
end

--- @async
--- @param provider Hover.Provider
--- @param bufnr integer
--- @param popts Hover.Options
--- @return boolean
local function run_provider(provider, bufnr, popts)
  local config = get_config()
  local opts = vim.deepcopy(config.preview_opts)

  if opts.focusable ~= false and opts.focus ~= false then
    if do_hover() then
      return false
    end
  end

  popts = popts or {}

  opts.relative = popts.relative

  local result = async.await(2, provider.execute, {
    bufnr = bufnr,
    pos = popts.pos or api.nvim_win_get_cursor(0),
  })

  if not result then
    return false
  end

  async.scheduler()
  show_hover(bufnr, provider.id, config, result, popts, opts)
  return true
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

--- @param bufnr? integer
function M.close(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local cur_hover = vim.b[bufnr].hover_preview
  if cur_hover and api.nvim_win_is_valid(cur_hover) then
    api.nvim_win_close(cur_hover, true)
  end
  vim.b[bufnr].hover_preview = nil
end

--- @class Hover.actions.open.Options: Hover.Options
--- @field bufnr? integer

--- @param opts? Hover.actions.open.Options
function M.open(opts)
  opts = opts or {}
  init()

  async.run(function()
    local bufnr = opts and opts.bufnr or api.nvim_get_current_buf()

    local hover_win = vim.b[bufnr].hover_preview
    local current_provider = hover_win
        and api.nvim_win_is_valid(hover_win)
        and vim.w[hover_win].hover_provider
      or nil

    --- If hover is open then set use_provider to false until we cycle to the
    --- next available provider.
    local use_provider = current_provider == nil

    local providers = get_providers(bufnr, opts)

    for _, provider in ipairs(providers) do
      async.scheduler()
      if use_provider and run_provider(provider, bufnr, opts) then
        return
      end
      if provider.id == current_provider then
        use_provider = true
      end
    end

    for _, provider in ipairs(providers) do
      async.scheduler()
      if run_provider(provider, bufnr, opts) then
        return
      end
    end
  end)
end

--- @param direction 'previous'|'next'
--- @param opts? Hover.Options
function M.switch(direction, opts)
  direction = direction or 'next'
  opts = opts or {}
  local bufnr = api.nvim_get_current_buf()
  local current_provider_idx = 0
  local active_providers = {} --- @type Hover.Provider[]
  local hover_win = vim.b[bufnr].hover_preview
  local current_provider_id = hover_win
      and api.nvim_win_is_valid(hover_win)
      and vim.w[hover_win].hover_provider
    or nil

  if not current_provider_id then
    return
  end

  for _, p in ipairs(get_providers(bufnr, opts)) do
    active_providers[#active_providers + 1] = p
    if p.id == current_provider_id then
      current_provider_idx = #active_providers
    end
  end

  local offset = direction == 'next' and 1 or -1
  -- -1 and +1 to convert to 0-indexed and back
  local provider_id_sel = ((current_provider_idx + offset - 1) % #active_providers) + 1
  local provider = assert(active_providers[provider_id_sel])
  async.run(run_provider, provider, bufnr, opts)
end

function M.select(opts)
  init()

  local bufnr = opts and opts.bufnr or api.nvim_get_current_buf()

  vim.ui.select(get_providers(bufnr, opts), {
    prompt = 'Select hover:',
    format_item = function(provider)
      return provider.name
    end,
  }, function(provider)
    if provider then
      async.run(run_provider, provider, bufnr, opts)
    end
  end)
end

local timer --- @type uv.uv_timer_t?

function M.mouse()
  timer = timer or assert(vim.uv.new_timer())

  local config = get_config()

  timer:start(
    config.mouse_delay,
    0,
    vim.schedule_wrap(function()
      timer:stop()
      timer = nil

      local pos = vim.fn.getmousepos()
      if pos.winid == 0 then
        return
      end

      local buf = vim.fn.winbufnr(pos.winid)
      if buf == -1 then
        return
      end

      M.close(buf)

      M.open({
        providers = config.mouse_providers,
        relative = 'mouse',
        pos = { pos.line, pos.column },
        bufnr = buf,
      })
    end)
  )
end

function M.enter()
  local bufnr = api.nvim_get_current_buf()
  local hover_win = vim.b[bufnr].hover_preview
  if hover_win and api.nvim_win_is_valid(hover_win) then
    api.nvim_set_current_win(hover_win)
  end
end

return M

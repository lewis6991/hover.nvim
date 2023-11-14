local api = vim.api
local npcall = vim.F.npcall

local M = {}

local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

local function close_preview_window(winnr, bufnrs)
  vim.schedule(function()
    -- exit if we are in one of ignored buffers
    if bufnrs and vim.tbl_contains(bufnrs, api.nvim_get_current_buf()) then
      return
    end

    pcall(api.nvim_del_augroup_by_name, 'preview_window_' .. winnr)
    pcall(api.nvim_win_close, winnr, true)
  end)
end

local function close_preview_autocmd(winnr, bufnrs)
  local augroup = api.nvim_create_augroup('preview_window_' .. winnr, {})

  -- close the preview window when entered a buffer that is not
  -- the floating window buffer or the buffer that spawned it
  api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function()
      close_preview_window(winnr, bufnrs)
    end,
  })

  api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertCharPre' }, {
    group = augroup,
    buffer = bufnrs[2],
    callback = function()
      close_preview_window(winnr)
    end,
  })
end

local function trim_empty_lines(lines)
  local start = 1
  for i = 1, #lines do
    if lines[i] ~= nil and #lines[i] > 0 then
      start = i
      break
    end
  end
  local finish = 1
  for i = #lines, 1, -1 do
    if lines[i] ~= nil and #lines[i] > 0 then
      finish = i
      break
    end
  end
  return vim.list_extend({}, lines, start, finish)
end

---@type ({[1]: string, [2]: string}|string)[]
local default_border = {
  { '' , 'NormalFloat' },
  { '' , 'NormalFloat' },
  { '' , 'NormalFloat' },
  { ' ', 'NormalFloat' },
  { '' , 'NormalFloat' },
  { '' , 'NormalFloat' },
  { '' , 'NormalFloat' },
  { ' ', 'NormalFloat' },
}

local function make_floating_popup_options(width, height, opts)
  opts = opts or {}

  local anchor = ''
  local row, col

  local lines_above = vim.fn.winline() - 1
  local lines_below = vim.fn.winheight(0) - lines_above

  if lines_above < lines_below then
    anchor = anchor .. 'N'
    height = math.min(lines_below, height)
    row = 1
  else
    anchor = anchor .. 'S'
    height = math.min(lines_above, height)
    row = 0
  end

  if vim.fn.wincol() + width + (opts.offset_x or 0) <= vim.o.columns then
    anchor = anchor .. 'W'
    col = 0
  else
    anchor = anchor .. 'E'
    col = 1
  end

  return {
    anchor    = anchor,
    col       = col + (opts.offset_x or 0),
    height    = height,
    focusable = opts.focusable,
    relative  = opts.relative or 'cursor',
    row       = row + (opts.offset_y or 0),
    style     = 'minimal',
    width     = width,
    border    = opts.border or default_border,
    zindex    = opts.zindex or 50,
  }
end

local function get_border_size(opts)
  local border = opts and opts.border or default_border
  local height = 0
  local width = 0

  if type(border) == 'string' then
    local border_size = {
      none    = { 0, 0 },
      single  = { 2, 2 },
      double  = { 2, 2 },
      rounded = { 2, 2 },
      solid   = { 2, 2 },
      shadow  = { 1, 1 },
    }
    if border_size[border] == nil then
      error(string.format(
        'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
        vim.inspect(border)
      ))
    end
    height, width = unpack(border_size[border])
  else
    if 8 % #border ~= 0 then
      error(string.format(
        'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
        vim.inspect(border)
      ))
    end

    ---@param id integer
    ---@return integer
    local function border_width(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == 'table' then
        -- border specified as a table of <character, highlight group>
        return vim.fn.strdisplaywidth(border[id][1])
      elseif type(border[id]) == 'string' then
        -- border specified as a list of border characters
        return vim.fn.strdisplaywidth(border[id] --[[@as string]])
      end
      error(
        string.format(
          'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
          vim.inspect(border)
        )
      )
    end

    local function border_height(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == 'table' then
        -- border specified as a table of <character, highlight group>
        return #border[id][1] > 0 and 1 or 0
      elseif type(border[id]) == 'string' then
        -- border specified as a list of border characters
        return #border[id] > 0 and 1 or 0
      end
      error(
        string.format(
          'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
          vim.inspect(border)
        )
      )
    end

    height = height + border_height(2) -- top
    height = height + border_height(6) -- bottom
    width  = width  + border_width(4)  -- right
    width  = width  + border_width(8)  -- left
  end

  return { height = height, width = width }
end

local function make_floating_popup_size(contents, opts)
  opts = opts or {}

  local width      = opts.width
  local height     = opts.height
  local wrap_at    = opts.wrap_at
  local max_width  = opts.max_width
  local max_height = opts.max_height
  local line_widths = {}

  if not width then
    width = 0
    for i, line in ipairs(contents) do
      line_widths[i] = vim.fn.strdisplaywidth(line)
      width = math.max(line_widths[i], width)
    end
  end

  local border_width = get_border_size(opts).width
  local screen_width = api.nvim_win_get_width(0)
  width = math.min(width, screen_width)

  -- make sure borders are always inside the screen
  if width + border_width > screen_width then
    width = width - (width + border_width - screen_width)
  end

  if wrap_at and wrap_at > width then
    wrap_at = width
  end

  if max_width then
    width = math.min(width, max_width)
    wrap_at = math.min(wrap_at or max_width, max_width)
  end

  if not height then
    height = #contents
    if wrap_at and width >= wrap_at then
      height = 0
      if vim.tbl_isempty(line_widths) then
        for _, line in ipairs(contents) do
          local line_width = vim.fn.strdisplaywidth(line)
          height = height + math.ceil(line_width / wrap_at)
        end
      else
        for i = 1, #contents do
          height = height + math.max(1, math.ceil(line_widths[i] / wrap_at))
        end
      end
    end
  end
  if max_height then
    height = math.min(height, max_height)
  end

  return width, height
end

function M.open_floating_preview(contents, bufnr, syntax, opts)
  opts = opts or {}
  opts.wrap = opts.wrap ~= false -- wrapping by default
  opts.stylize_markdown = opts.stylize_markdown ~= false and vim.g.syntax_on ~= nil
  opts.focus = opts.focus ~= false

  if not contents and bufnr then
    contents = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local cbuf = api.nvim_get_current_buf()

  -- check if this popup is focusable and we need to focus
  if opts.focus_id and opts.focusable ~= false and opts.focus then
    -- Go back to previous window if we are in a focusable one
    local current_winnr = api.nvim_get_current_win()
    if npcall(api.nvim_win_get_var, current_winnr, opts.focus_id) then
      vim.cmd.wincmd('p')
      return cbuf, current_winnr
    end
    local win = find_window_by_var(opts.focus_id, cbuf)
    if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
      -- focus and return the existing buf, win
      api.nvim_set_current_win(win)
      vim.cmd.stopinsert()
      return api.nvim_win_get_buf(win), win
    end
  end

  -- check if another floating preview already exists for this buffer
  -- and close it if needed
  local cur_hover = npcall(api.nvim_buf_get_var, cbuf, 'hover_preview')
  if cur_hover and api.nvim_win_is_valid(cur_hover) then
    api.nvim_win_close(cur_hover, true)
  end
  vim.b[cbuf].hover_preview = nil

  local floating_bufnr = bufnr or api.nvim_create_buf(false, true)
  local do_stylize = syntax == 'markdown' and opts.stylize_markdown

  -- Clean up input: trim empty lines from the end, pad
  contents = trim_empty_lines(contents)

  if do_stylize then
    -- applies the syntax and sets the lines to the buffer
    contents = vim.lsp.util.stylize_markdown(floating_bufnr, contents, opts)
  else
    if syntax then
      vim.bo[floating_bufnr].syntax = syntax
    end

    local m = vim.bo[floating_bufnr].modifiable
    local ro = vim.bo[floating_bufnr].readonly
    vim.bo[floating_bufnr].modifiable = true
    vim.bo[floating_bufnr].readonly = false
    api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)
    vim.bo[floating_bufnr].modifiable = m
    vim.bo[floating_bufnr].readonly = ro
  end

  -- Compute size of float needed to show (wrapped) lines
  opts.wrap_at = opts.wrap and (opts.wrap_at or api.nvim_win_get_width(0)) or nil
  local width, height = make_floating_popup_size(contents, opts)

  local float_option = make_floating_popup_options(width, height, opts)
  local hover_winid = api.nvim_open_win(floating_bufnr, false, float_option)
  if do_stylize then
    vim.wo[hover_winid].conceallevel = 2
    vim.wo[hover_winid].concealcursor = 'n'
  end

  -- disable folding
  vim.wo[hover_winid].foldenable = false
  -- soft wrapping
  vim.wo[hover_winid].wrap = opts.wrap

  vim.bo[floating_bufnr].modifiable = false
  vim.bo[floating_bufnr].bufhidden = 'wipe'

  vim.keymap.set('n', 'q', '<cmd>bdelete<cr>', { buffer = floating_bufnr, silent = true, nowait = true })

  close_preview_autocmd(hover_winid, { floating_bufnr, cbuf })

  -- save focus_id
  if opts.focus_id then
    vim.w[hover_winid][opts.focus_id] = cbuf
  end
  vim.w[hover_winid].hover_preview = hover_winid
  vim.b[cbuf].hover_preview = hover_winid

  return hover_winid
end

return M

local api = vim.api

local M = {}

--- @param winid integer
--- @param hover_bufnr integer
--- @param bufnr integer
local function close_preview_autocmd(winid, hover_bufnr, bufnr)
  local augroup = api.nvim_create_augroup('preview_window_' .. winid, {})

  local close_preview_window = function()
    vim.schedule(function()
      pcall(api.nvim_del_augroup_by_id, augroup)
      pcall(api.nvim_win_close, winid, true)
    end)
  end

  -- close the preview window when entered a buffer that is not
  -- the floating window buffer or the buffer that spawned it
  api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function(opts)
      if vim.tbl_contains({ hover_bufnr, bufnr }, opts.buf) then
        return
      end
      close_preview_window()
    end,
  })

  api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertCharPre' }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      close_preview_window()
    end,
  })
end

--- @param lines string[]
--- @return string[]
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

local BORDER_SIZES = {
  none = { 0, 0 },
  single = { 2, 2 },
  double = { 2, 2 },
  rounded = { 2, 2 },
  solid = { 2, 2 },
  shadow = { 1, 1 },
}

--- Check the border given by opts or the default border for the additional
--- size it adds to a float.
--- @param opts table optional options for the floating window
---           - border (string or table) the border
--- @return table size of border in the form of { height = height, width = width }
local function get_border_size(opts)
  --- @type ({[1]: string, [2]: string}|string)[]
  local border = opts and opts.border or default_border

  local height = 0
  local width = 0

  if type(border) == 'string' then
    if not BORDER_SIZES[border] then
      error(string.format(
        'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
        vim.inspect(border)
      ))
    end
    height, width = unpack(BORDER_SIZES[border])
  else
    if 8 % #border ~= 0 then
      error(string.format(
        'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
        vim.inspect(border)
      ))
    end

    --- @param id integer
    --- @return integer
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

    --- @param id integer
    --- @return integer
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
    width = width + border_width(4)    -- right
    width = width + border_width(8)    -- left
  end

  return { height = height, width = width }
end

--- @param contents string[]
--- @param opts table
--- @return integer width
--- @return integer height
local function make_floating_popup_size(contents, opts)
  opts = opts or {}

  local width = opts.width
  local height = opts.height
  local max_width = opts.max_width
  local max_height = opts.max_height
  local line_widths = {}

  local border_width = get_border_size(opts).width
  if not max_width or vim.o.columns - border_width < max_width then
    max_width = vim.o.columns - border_width
  end

  if not width then
    width = 1 -- not zero, avoid modulo by zero if content is empty
    for i, line in ipairs(contents) do
      line_widths[i] = vim.fn.strdisplaywidth(line)
      width = math.max(line_widths[i], width)
    end
  end

  if opts.winbar_length then
    width = math.max(width, opts.winbar_length)
  end

  local wrap_at
  if width > max_width then
    width = max_width
    if opts.wrap then
      wrap_at = width
    end
  end

  if not height then
    height = #contents
    if wrap_at then
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

  if opts.winbar then
    height = height + 1
  end

  if max_height then
    height = math.min(height, max_height)
  end

  return width, height
end

--- @param width integer
--- @param height integer
--- @param opts vim.api.keyset.win_config
--- @return vim.api.keyset.win_config
local function make_floating_popup_options(width, height, opts)
  opts = opts or {}

  local anchor = ''
  local row = opts.row or 0
  local col = opts.col or 0

  local editor_height = vim.o.lines - vim.o.cmdheight

  local lines_above = row
  local lines_below = editor_height - lines_above - 1

  local border_size = get_border_size(opts)

  local border_height = border_size.height
  if lines_above < lines_below then
    anchor = anchor .. 'N'
    height = math.max(math.min(lines_below - border_height, height), 0)
    row = row + 1
  else
    anchor = anchor .. 'S'
    height = math.max(math.min(lines_above - border_height, height), 0)
  end

  local border_width = border_size.width
  if col + width + border_width <= vim.o.columns then
    anchor = anchor .. 'W'
  else
    anchor = anchor .. 'E'
    col = col + 1
  end

  return {
    anchor    = anchor,
    col       = col,
    height    = height,
    focusable = opts.focusable,
    relative  = 'editor',
    row       = row,
    style     = 'minimal',
    width     = width,
    border    = opts.border or default_border,
    zindex    = opts.zindex or 50,
  }
end

--- @param contents string[]?
--- @param bufnr integer?
--- @param syntax string?
--- @param opts table
--- @return integer, integer
function M.open_floating_preview(contents, bufnr, syntax, opts)
  opts = opts or {}
  opts.wrap = opts.wrap ~= false -- wrapping by default
  opts.stylize_markdown = opts.stylize_markdown ~= false and vim.g.syntax_on ~= nil
  opts.focus = opts.focus ~= false

  local cbuf = api.nvim_get_current_buf()

  local floating_bufnr = bufnr or api.nvim_create_buf(false, true)
  local do_stylize = syntax == 'markdown' and opts.stylize_markdown

  -- if contents given, always set buf lines
  -- if no bufnr, contents is required
  if contents or not bufnr then
    -- Clean up input: trim empty lines from the end, pad
    contents = trim_empty_lines(assert(contents))

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
  else
    -- no contents provided, but we have a bufnr
    -- so get contents from the buffer (needed to compute float size)
    contents = api.nvim_buf_get_lines(bufnr, 0, -1, false)

    if syntax then
      vim.bo[floating_bufnr].syntax = syntax
    end
  end

  local width, height = make_floating_popup_size(contents, opts)

  local float_option = make_floating_popup_options(width, height, opts)
  local hover_winid = api.nvim_open_win(floating_bufnr, false, float_option)

  if opts.winbar then
    vim.wo[hover_winid].winbar = opts.winbar
  end

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

  vim.keymap.set('n', 'q', '<cmd>bdelete<cr>', {
    buffer = floating_bufnr,
    silent = true,
    nowait = true
  })

  close_preview_autocmd(hover_winid, floating_bufnr, cbuf)

  return hover_winid, floating_bufnr
end

return M

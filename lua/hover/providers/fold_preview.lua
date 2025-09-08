local fn = vim.fn
local api = vim.api

local config = require('hover.config').get()

local border_shift = {} --- @type [integer, integer, integer, integer]

local function set_border_shift(border)
  if type(border) == 'string' then
    if border == 'none' then
      border_shift = { 0, 0, 0, 0 }
      return
    elseif vim.tbl_contains({ 'single', 'double', 'rounded', 'solid' }, border) then
      border_shift = { -1, -1, -1, -1 }
      return
    elseif border == 'shadow' then
      border_shift = { 0, -1, -1, 0 }
      return
    end
    -- error() if `border` matches non of the values above
  elseif type(border) == 'table' then
    for i = 1, 4 do
      border_shift[i] = border[i * 2] == '' and 0 or -1
    end
    return
  end
  error('Invalid border type or value')
end

set_border_shift(config.preview_opts.border)

--- @param params Hover.Provider.Params
--- @param done fun(result?: Hover.Provider.Result)
local function execute(params, done)
  local cur_bufnr = params.bufnr
  local cur_pos = params.pos
  local cur_line = cur_pos[1]

  local fold_bounds = api.nvim_buf_call(cur_bufnr, function()
    return { fn.foldclosed(cur_line), fn.foldclosedend(cur_line) }
  end)

  --- @cast fold_bounds [integer, integer]

  local fold_start = fold_bounds[1]
  local fold_end = fold_bounds[2]

  local folded_lines = api.nvim_buf_get_lines(cur_bufnr, fold_start - 1, fold_end, true)

  local blank_chars = assert(folded_lines[1]):match('^%s+') or ''
  local nbc = #blank_chars
  local indent = #(blank_chars:gsub('\t', string.rep(' ', vim.bo[cur_bufnr].tabstop)))

  if nbc > 0 then
    for i, line in ipairs(folded_lines) do
      line = line:sub(nbc + 1) -- remove all space characters from the beginning
      folded_lines[i] = line
    end
  end

  local bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(bufnr, 0, 1, false, folded_lines)
  vim.bo[bufnr].filetype = vim.bo[cur_bufnr].filetype
  vim.bo[bufnr].modifiable = false

  local function update_win_config(win)
    if not api.nvim_win_is_valid(win) then
      return
    end
    local win_config = api.nvim_win_get_config(win)
    win_config.bufpos = {
      fold_start - 1, -- zero-indexed, so minus one
      0,
    }
    -- Align the text of two buffers.
    -- The position of the window relative to 'bufpos' field.
    win_config.row = border_shift[1] - 1 -- the hover win title
    win_config.col = indent + border_shift[4] -- the beginning space characters
    api.nvim_win_set_config(win, win_config)
  end

  api.nvim_create_autocmd('BufWinEnter', {
    buffer = bufnr,
    callback = function()
      update_win_config(api.nvim_get_current_win())
    end,
  })

  done({ bufnr = bufnr })
end

--- @type Hover.Provider
return {
  name = 'Fold Preview',
  enabled = function(bufnr, opts)
    local pos = opts and opts.pos or api.nvim_win_get_cursor(0)
    local lnum = pos[1]

    return api.nvim_buf_call(bufnr, function()
      return fn.foldclosed(lnum) ~= -1
    end)
  end,
  execute = execute,
  priority = 1003, -- above lsp and diagnostics and dap
}

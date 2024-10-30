local fn = vim.fn
local api = vim.api

local hover = require('hover')
local config = require('hover.config').get()

local border_shift = {} --- @type integer[]

local function set_border_shift(border)
  if type(border) == 'string' then
    if border == 'none' then
      border_shift = { 0, 0, 0, 0 }
    elseif vim.tbl_contains({ 'single', 'double', 'rounded', 'solid' }, border) then
      border_shift = { -1, -1, -1, -1 }
    elseif border == 'shadow' then
      border_shift = { 0, -1, -1, 0 }
    end
  elseif type(border) == 'table' then
    for i = 1, 4 do
      border_shift[i] = border[i * 2] == '' and 0 or -1
    end
  else
    assert(false, 'Invalid border type or value')
  end
end

set_border_shift(config.preview_opts.border)

hover.register({
  name = 'Fold Preview',
  enabled = function()
    return fn.foldclosed(fn.line('.')) ~= -1
  end,
  execute = function(_opts, done)
    local cur_line = fn.line('.')
    local fold_start = fn.foldclosed(cur_line)
    local fold_end = fn.foldclosedend(cur_line)

    local cur_win = api.nvim_get_current_win()
    local cur_bufnr = api.nvim_win_get_buf(cur_win)

    local folded_lines = api.nvim_buf_get_lines(cur_bufnr, fold_start - 1, fold_end, true)

    local blank_chars = folded_lines[1]:match('^%s+') or ''
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
  end,
  priority = 1003, -- above lsp and diagnostics and dap
})

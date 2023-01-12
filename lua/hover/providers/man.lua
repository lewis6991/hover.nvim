local api = vim.api

local async = require('hover.async')

local function enabled()
  return vim.tbl_contains({
    'sh', 'zsh', 'tcl', 'make',
  }, vim.bo.filetype)
end

local execute = async.void(function(done)
  local word = vim.fn.expand('<cword>')
  local section = vim.bo.filetype == 'tcl' and 'n' or '1'
  local uri = string.format('man://%s(%s)', word, section)

  local bufnr = api.nvim_create_buf(false, true)

  local ok = pcall(api.nvim_buf_call, bufnr, function()
    -- This will execute when the buffer is hidden
    api.nvim_exec_autocmds('BufReadCmd', { pattern = uri })
  end)

  if not ok or api.nvim_buf_line_count(bufnr) <= 1 then
    api.nvim_buf_delete(bufnr, {force = true})
    done()
    return
  end

  -- Run BufReadCmd again to resize properly
  api.nvim_create_autocmd('BufWinEnter', {
    buffer = bufnr,
    once = true,
    callback = function()
      api.nvim_exec_autocmds('BufReadCmd', { pattern = uri })
    end
  })

  done{ bufnr = bufnr }
end)

require('hover').register {
  name = 'Man',
  priority = 150,
  enabled = enabled,
  execute = execute,
}

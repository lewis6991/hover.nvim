local api, fn = vim.api, vim.fn

local async = require('hover.async')
local job = require('hover.async.job').job
local util = require('vim.lsp.util')

local function enabled()
  return fn.expand('<cWORD>'):match('#%d+') ~= nil
end

local function process(result)
  local ok, json = pcall(vim.json.decode, result)
  if not ok then
    vim.notify "Failed to parse gh result"
    return
  end

  local lines = {
    string.format('#%d: %s', json.number, json.title),
    '',
    string.format('URL: %s', json.url),
    string.format('Author: %s', json.author.login),
    string.format('State: %s', json.state),
    string.format('Created: %s', json.createdAt),
    string.format('Last updated: %s', json.updatedAt),
    ''
  }

  for _, l in ipairs(vim.split(json.body, '\r\n')) do
    lines[#lines+1] = l
  end

  return lines
end

local execute = async.void(function()
  local bufnr = api.nvim_get_current_buf()
  local cwd = fn.fnamemodify(api.nvim_buf_get_name(bufnr), ':p:h')
  local id = fn.expand('<cword>')

  local output = job {
    'gh', 'issue', 'view', '--json',
    'author,title,number,body,state,createdAt,updatedAt,url',
    id,
    cwd = cwd
  }

  async.scheduler()
  local results = process(output)
  if results then
    util.open_floating_preview(results, "markdown")
  end
end)

require('hover').register {
  name = 'Github',
  priority = 100,
  enabled = enabled,
  execute = execute,
}

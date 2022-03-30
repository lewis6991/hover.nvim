local util = require('vim.lsp.util')
local api = vim.api

local async = require('hover.async')

local providers = require('hover.providers').providers
local get_config = require('hover.config').get

local M = {}

local initialised = false

local function is_enabled(provider)
  return provider.enabled == nil or provider.enabled()
end

local ns = api.nvim_create_namespace('hover')

local function add_title(bufnr, active_provider_id)
  local title = {}

  for _, p in ipairs(providers) do
    if is_enabled(p) then
      local hl = p.id == active_provider_id and 'TabLineSel' or 'TabLineFill'
      title[#title+1] = {string.format(' %s ', p.name), hl}
      title[#title+1] = {' ', 'Normal'}
    end
  end

  api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
    virt_text = title,
    virt_text_pos = 'overlay'
  })
end

local function run_provider(provider)
  print('hover.nvim: Running provider: '..provider.name)
  if provider then
    local result = provider.execute()
    if result then
      async.scheduler()

      local config = get_config()

      local opts = config.preview_opts

      if config.title then
        opts.pad_top = 1
      end

      opts.focus_id = provider.name

      local bufnr = util.open_floating_preview(result.lines, result.filetype, opts)

      if config.title then
        add_title(bufnr, provider.id)
      end

      return true
    end
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

M.hover = async.void(function()
  init()

  for _, provider in ipairs(providers) do
    async.scheduler()
    if is_enabled(provider) and run_provider(provider) then
      return
    end
  end
  print('hover.nvim: could not find any hover providers')
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
    async.void(run_provider)
  )
end

return M

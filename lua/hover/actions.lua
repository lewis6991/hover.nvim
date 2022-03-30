local async = require('hover.async')

local config = require('hover.config').config

local M = {}

local initialised = false

local function is_enabled(provider)
  return provider.enabled == nil or provider.enabled()
end

local function run_provider(provider)
  print('hover.nvim: Running provider: '..provider.name)
  if provider then
    local result = provider.execute()
    if result then
      local util = require('vim.lsp.util')
      util.open_floating_preview(result.lines, result.filetype, config.preview_opts)
      return true
    end
  end
  return false
end

local function get_providers()
  return require('hover.providers').providers
end

local function init()
  if initialised then
    return
  end
  initialised = true

  if config and type(config.init) == 'function' then
    config.init()
  end
end

M.hover = async.void(function()
  init()

  local providers = get_providers()

  for _, provider in ipairs(providers) do
    if is_enabled(provider) then
      if run_provider(provider) then
        return
      end
    end
  end
  print('hover.nvim: could not find any hover providers')
end)

M.hover_select = function()
  init()

  local choices = {}

  local providers = get_providers()

  for _, p in ipairs(providers) do
    if is_enabled(p) then
      choices[#choices+1] = p
    end
  end

  vim.ui.select(
    choices, {
      prompt = 'Select hover:',
      format_item = function(provider)
        return provider.name
      end,
    },
    async.void(function(provider)
      run_provider(provider)
    end)
  )
end

return M

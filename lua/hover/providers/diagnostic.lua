local api = vim.api
local diagnostic = vim.diagnostic

-- Most of this is taken straight from vim.diagnostic.open_float,
-- with some tweaks to remove some unnecessary parts

--- @type table<vim.diagnostic.Severity, HoverHighlightGroup>
local highlight_map = {
  [diagnostic.severity.ERROR] = 'HoverFloatingError',
  [diagnostic.severity.WARN] = 'HoverFloatingWarn',
  [diagnostic.severity.INFO] = 'HoverFloatingInfo',
  [diagnostic.severity.HINT] = 'HoverFloatingHint',
}

--- @return vim.diagnostic.Opts.Float
local function get_float_opts()
  local config = diagnostic.config() --[[@as vim.diagnostic.Opts]]
  local t = config.float
  if type(t) ~= 'table' then
    -- vim.diagnostic.open_float also ignores non-table config
    return {}
  end
  -- expand shorthand
  t.scope = ({ l = 'line', c = 'cursor', b = 'buffer' })[t.scope] or t.scope
  return t
end

--- @param diagnostics vim.Diagnostic[]
--- @return integer
local function count_sources(diagnostics)
  local seen = {} --- @type table<string,true>
  local count = 0
  for _, d in ipairs(diagnostics) do
    local source = d.source
    if source and not seen[source] then
      seen[source] = true
      count = count + 1
    end
  end
  return count
end

--- @param pos [integer, integer]
--- @return vim.diagnostic.GetOpts
local function get_diag_opts(pos)
  local float_opts = get_float_opts()
  local scope = float_opts.scope or 'line'

  local opts = {}
  if scope == 'line' then
    opts.lnum = pos[1] - 1
  elseif scope == 'cursor' then
    opts.pos = { pos[1] - 1, pos[2] }
  end
  return opts
end

--- @param bufnr integer
--- @param opts? Hover.Options
--- @return boolean
local function enabled(bufnr, opts)
  local pos = opts and opts.pos or api.nvim_win_get_cursor(0)
  return next(diagnostic.get(bufnr, get_diag_opts(pos))) ~= nil
end

local ns = api.nvim_create_namespace('hover.diagnostic')

--- @param bufnr integer Buffer number
--- @param hl_group? string Highlight group name
--- @param lnum integer Line number (0-indexed)
--- @param col integer Start column (0-indexed)
--- @param end_col integer End column (exclusive)
local function highlight(bufnr, hl_group, lnum, col, end_col)
  api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, col, {
    end_col = end_col,
    hl_group = hl_group,
  })
end

--- @param params Hover.Provider.Params
--- @param done fun(result?: Hover.Provider.Result)
local function execute(params, done)
  local buffer_diagnostics = diagnostic.get(params.bufnr)
  local diagnostics = diagnostic.get(params.bufnr, get_diag_opts(params.pos))

  local float_opts = get_float_opts()

  local severity_sort = float_opts.severity_sort
  if severity_sort then
    if type(severity_sort) == 'table' and severity_sort.reverse then
      table.sort(diagnostics, function(a, b)
        return a.severity > b.severity
      end)
    else
      table.sort(diagnostics, function(a, b)
        return a.severity < b.severity
      end)
    end
  end

  local source = float_opts.source
  if source == 'if_many' and count_sources(buffer_diagnostics) <= 1 then
    source = false
  end

  local scope = float_opts.scope or 'line'

  local prefix_opt = float_opts.prefix
  if prefix_opt == nil then
    if scope == 'cursor' and #diagnostics <= 1 then
      prefix_opt = ''
    else
      prefix_opt = function(_, i)
        return string.format('%d. ', i)
      end
    end
  end

  local prefix, prefix_hl_group --- @type string?, string?
  if prefix_opt then
    vim.validate('prefix', prefix_opt, { 'string', 'table', 'function' })
    if type(prefix_opt) == 'string' then
      prefix = prefix_opt
    elseif type(prefix_opt) == 'table' then
      --- @type string, string?
      prefix, prefix_hl_group = prefix_opt[1], prefix_opt[2]
    end
  end

  local suffix_opt = float_opts.suffix
  if suffix_opt == nil then
    --- @param d vim.Diagnostic
    suffix_opt = function(d)
      return d.code and string.format(' [%s]', d.code)
    end
  end

  local suffix, suffix_hl_group --- @type string?, string?
  if suffix_opt then
    vim.validate('suffix', suffix_opt, { 'string', 'table', 'function' })
    if type(suffix_opt) == 'string' then
      suffix = suffix_opt
    elseif type(suffix_opt) == 'table' then
      --- @type string, string?
      suffix, suffix_hl_group = suffix_opt[1], suffix_opt[2]
    end
  end

  local lines = {} --- @type string[]

  --- @class Hover.provider.diagnostic.Hl
  --- @field hlname string
  --- @field prefix { length: integer, hlname?: string }
  --- @field suffix { length: integer, hlname?: string }

  local highlights = {} --- @type Hover.provider.diagnostic.Hl[]

  for i, d in ipairs(diagnostics) do
    if type(prefix_opt) == 'function' then
      --- @cast prefix_opt fun(...): string?, string?
      local prefix0, prefix_hl_group0 = prefix_opt(d, i, #diagnostics)
      prefix, prefix_hl_group = prefix0 or '', prefix_hl_group0 or 'HoverWindow'
    end
    if type(suffix_opt) == 'function' then
      --- @cast suffix_opt fun(...): string?, string?
      local suffix0, suffix_hl_group0 = suffix_opt(d, i, #diagnostics)
      suffix, suffix_hl_group = suffix0 or '', suffix_hl_group0 or 'HoverWindow'
    end
    local message = d.message
    if source and d.source then
      message = string.format('%s: %s', d.source, message)
    end
    local message_lines = vim.split(message, '\n')
    for j = 1, #message_lines do
      local pre = j == 1 and prefix or string.rep(' ', #prefix)
      local suf = j == #message_lines and suffix or ''
      table.insert(lines, pre .. message_lines[j] .. suf)
      highlights[#highlights + 1] = {
        hlname = highlight_map[d.severity],
        prefix = {
          length = j == 1 and #prefix or 0,
          hlname = prefix_hl_group,
        },
        suffix = {
          length = j == #message_lines and #suffix or 0,
          hlname = suffix_hl_group,
        },
      }
    end
  end

  local float_bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(float_bufnr, 0, -1, true, lines)

  for i, hl in ipairs(highlights) do
    local line = lines[i]
    local prefix_len = hl.prefix.length
    local suffix_len = hl.suffix.length
    if prefix_len > 0 then
      highlight(float_bufnr, hl.prefix.hlname, i, 0, prefix_len)
    end
    highlight(float_bufnr, hl.hlname, i, prefix_len, #line - suffix_len)
    if suffix_len > 0 then
      highlight(float_bufnr, hl.suffix.hlname, i, #line - suffix_len, #line)
    end
  end

  done({ bufnr = float_bufnr })
end

--- @type Hover.Provider
return {
  name = 'Diagnostics',
  priority = 1001, -- above lsp
  enabled = enabled,
  execute = execute,
}

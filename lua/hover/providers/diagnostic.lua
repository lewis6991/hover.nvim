local highlights = require('hover.highlights').HIGHLIGHT_GROUPS
local api, if_nil = vim.api, vim.F.if_nil

-- Most of this is taken straight from vim.diagnostic.open_float,
-- with some tweaks to remove some unnecessary parts

local highlight_map = {
  [vim.diagnostic.severity.ERROR] = highlights.HoverFloatingError,
  [vim.diagnostic.severity.WARN] = highlights.HoverFloatingWarn,
  [vim.diagnostic.severity.INFO] = highlights.HoverFloatingInfo,
  [vim.diagnostic.severity.HINT] = highlights.HoverFloatingHint,
}

--- @return vim.diagnostic.Opts.Float
local function get_float_opts()
  local config = vim.diagnostic.config() --[[@as vim.diagnostic.Opts]]
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
  for _, diagnostic in ipairs(diagnostics) do
    local source = diagnostic.source
    if source and not seen[source] then
      seen[source] = true
      count = count + 1
    end
  end
  return count
end

--- @param diagnostics vim.Diagnostic[]
--- @param bufnr integer
--- @return vim.Diagnostic[]
local function filter_diagnostics(diagnostics, bufnr)
  local float_opts = get_float_opts()
  local scope = float_opts.scope or 'line'

  local pos = api.nvim_win_get_cursor(0)
  local lnum = pos[1] - 1
  local col = pos[2]
  if scope == 'line' then
    --- @param d vim.Diagnostic
    diagnostics = vim.tbl_filter(function(d)
      return lnum >= d.lnum
        and lnum <= d.end_lnum
        and (d.lnum == d.end_lnum or lnum ~= d.end_lnum or d.end_col ~= 0)
    end, diagnostics)
  elseif scope == 'cursor' then
    -- If `col` is past the end of the line, show if the cursor is on the last char in the line
    local line_length = #api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
    --- @param d vim.Diagnostic
    diagnostics = vim.tbl_filter(function(d)
      return lnum >= d.lnum
        and lnum <= d.end_lnum
        and (lnum ~= d.lnum or col >= math.min(d.col, line_length - 1))
        and ((d.lnum == d.end_lnum and d.col == d.end_col) or lnum ~= d.end_lnum or col < d.end_col)
    end, diagnostics)
  end
  return diagnostics
end

--- @param bufnr integer
local function enabled(bufnr)
  local buffer_diagnostics = vim.diagnostic.get(bufnr)
  local diagnostics = filter_diagnostics(buffer_diagnostics, bufnr)
  return #diagnostics ~= 0
end

--- @param opts Hover.Options
--- @param done fun(result?: Hover.Result)
local function execute(opts, done)
  local buffer_diagnostics = vim.diagnostic.get(opts.bufnr)
  local diagnostics = filter_diagnostics(buffer_diagnostics, opts.bufnr)

  local float_opts = get_float_opts()

  local severity_sort = float_opts.severity_sort
  if float_opts.severity_sort then
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

  local prefix_opt =
    if_nil(float_opts.prefix, (scope == 'cursor' and #diagnostics <= 1) and '' or function(_, i)
      return string.format('%d. ', i)
    end)

  local prefix, prefix_hl_group --- @type string?, string?
  if prefix_opt then
    vim.validate({
      prefix = {
        prefix_opt,
        { 'string', 'table', 'function' },
        "'string' or 'table' or 'function'",
      },
    })
    if type(prefix_opt) == 'string' then
      prefix = prefix_opt
    elseif type(prefix_opt) == 'table' then
      prefix, prefix_hl_group = prefix_opt[1], prefix_opt[2]
    end
  end

  local suffix_opt = if_nil(float_opts.suffix, function(diagnostic)
    return diagnostic.code and string.format(' [%s]', diagnostic.code)
  end)

  local suffix, suffix_hl_group --- @type string?, string?
  if suffix_opt then
    vim.validate({
      suffix = {
        suffix_opt,
        { 'string', 'table', 'function' },
        "'string' or 'table' or 'function'",
      },
    })
    if type(suffix_opt) == 'string' then
      suffix = suffix_opt
    elseif type(suffix_opt) == 'table' then
      suffix, suffix_hl_group = suffix_opt[1], suffix_opt[2]
    end
  end

  local lines = {} --- @type string[]
  local _highlights = {} --- @type table[]

  for i, diagnostic in ipairs(diagnostics) do
    if type(prefix_opt) == 'function' then
      --- @cast prefix_opt fun(...): string?, string?
      local prefix0, prefix_hl_group0 = prefix_opt(diagnostic, i, #diagnostics)
      prefix, prefix_hl_group = prefix0 or '', prefix_hl_group0 or highlights.HoverWindow
    end
    if type(suffix_opt) == 'function' then
      --- @cast suffix_opt fun(...): string?, string?
      local suffix0, suffix_hl_group0 = suffix_opt(diagnostic, i, #diagnostics)
      suffix, suffix_hl_group = suffix0 or '', suffix_hl_group0 or highlights.HoverWindow
    end
    --- @type string?
    local hiname = highlight_map[assert(diagnostic.severity)]
    local message = diagnostic.message
    if source and diagnostic.source then
      message = string.format('%s: %s', diagnostic.source, message)
    end
    local message_lines = vim.split(message, '\n')
    for j = 1, #message_lines do
      local pre = j == 1 and prefix or string.rep(' ', #prefix)
      local suf = j == #message_lines and suffix or ''
      table.insert(lines, pre .. message_lines[j] .. suf)
      table.insert(_highlights, {
        hlname = hiname,
        prefix = {
          length = j == 1 and #prefix or 0,
          hlname = prefix_hl_group,
        },
        suffix = {
          length = j == #message_lines and #suffix or 0,
          hlname = suffix_hl_group,
        },
      })
    end
  end

  local float_bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(float_bufnr, 0, -1, true, lines)

  for i, hl in ipairs(_highlights) do
    local line = lines[i]
    local prefix_len = hl.prefix and hl.prefix.length or 0
    local suffix_len = hl.suffix and hl.suffix.length or 0
    if prefix_len > 0 then
      api.nvim_buf_add_highlight(float_bufnr, -1, hl.prefix.hlname, i - 1, 0, prefix_len)
    end
    api.nvim_buf_add_highlight(float_bufnr, -1, hl.hlname, i - 1, prefix_len, #line - suffix_len)
    if suffix_len > 0 then
      api.nvim_buf_add_highlight(float_bufnr, -1, hl.suffix.hlname, i - 1, #line - suffix_len, -1)
    end
  end

  done { bufnr = float_bufnr }
end

require('hover').register {
  name = 'Diagnostics',
  priority = 1001, -- above lsp
  enabled = enabled,
  execute = execute,
}

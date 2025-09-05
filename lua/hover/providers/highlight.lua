--- @param bufnr integer
--- @return boolean
local function enabled(bufnr)
  local inspect = vim.inspect_pos(bufnr)
  if inspect == nil then
    return false
  end
  return (inspect.treesitter ~= nil and #inspect.treesitter > 0)
    or (inspect.semantic_tokens ~= nil and #inspect.semantic_tokens > 0)
    or (inspect.syntax ~= nil and #inspect.syntax > 0)
    or (inspect.extmarks ~= nil and #inspect.extmarks > 0)
end

--- @param params Hover.Provider.Params
--- @param done fun(result?: Hover.Result)
local function execute(params, done)
  local items = vim.inspect_pos(
    params.bufnr,
    params and params.pos and params.pos[1] - 1,
    params and params.pos and params.pos[2]
  )
  if items == nil then
    done()
    return
  end

  local hls = {}
  local line = ''
  local lines = {}

  local function append(str, hl)
    line = line .. str
    if hl ~= nil then
      table.insert(hls, { hl, #lines + 1, #line - #str, #line })
    end
  end

  local function nl()
    table.insert(lines, line)
    line = ''
  end

  local function item(data, comment)
    append('  - ')
    append(data.hl_group, data.hl_group)
    append(' ')
    if data.hl_group ~= data.hl_group_link then
      append('links to ', 'MoreMsg')
      append(data.hl_group_link, data.hl_group_link)
      append(' ')
    end
    if comment then
      append(comment, 'Comment')
    end
    nl()
  end

  -- treesitter
  if #items.treesitter > 0 then
    append('Treesitter', 'Title')
    nl()
    for _, capture in ipairs(items.treesitter) do
      item(capture, capture.lang)
    end
    nl()
  end

  -- semantic tokens
  if #items.semantic_tokens > 0 then
    append('Semantic Tokens', 'Title')
    nl()
    local sorted_marks = vim.fn.sort(items.semantic_tokens, function(left, right)
      local left_first = left.opts.priority < right.opts.priority
        or left.opts.priority == right.opts.priority and left.opts.hl_group < right.opts.hl_group
      return left_first and -1 or 1
    end)
    for _, extmark in ipairs(sorted_marks) do
      item(extmark.opts, 'priority: ' .. extmark.opts.priority)
    end
    nl()
  end

  -- syntax
  if #items.syntax > 0 then
    append('Syntax', 'Title')
    nl()
    for _, syn in ipairs(items.syntax) do
      item(syn)
    end
    nl()
  end

  -- extmarks
  if #items.extmarks > 0 then
    append('Extmarks', 'Title')
    nl()
    for _, extmark in ipairs(items.extmarks) do
      if extmark.opts.hl_group then
        item(extmark.opts, extmark.ns)
      else
        append('  - ')
        append(extmark.ns, 'Comment')
        nl()
      end
    end
    nl()
  end

  local buffer = vim.api.nvim_create_buf(false, true)
  local ns = vim.api.nvim_create_namespace('')

  vim.api.nvim_buf_set_lines(buffer, -1, -1, true, lines)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(buffer, ns, hl[2], hl[3], {
      end_col = hl[4],
      hl_group = hl[1],
    })
  end

  done({ bufnr = buffer })
end

require('hover').register({
  name = 'Highlight',
  enabled = enabled,
  execute = execute,
})

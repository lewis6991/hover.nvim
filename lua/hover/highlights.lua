local M = {}

---@enum HoverHighlightGroup
M.HIGHLIGHT_GROUPS = {
  HoverWindow = 'HoverWindow',
  HoverBorder = 'HoverBorder',
  HoverActiveSource = 'HoverActiveSource',
  HoverInactiveSource = 'HoverInactiveSource',
  HoverSourceLine = 'HoverSourceLine',
  HoverFloatingError = 'HoverFloatingError',
  HoverFloatingWarn = 'HoverFloatingWarn',
  HoverFloatingInfo = 'HoverFloatingInfo',
  HoverFloatingHint = 'HoverFloatingHint',
}

---@type table<HoverHighlightGroup, string>
M.HIGHLIGHT_GROUP_DEFAULTS = {
  [M.HIGHLIGHT_GROUPS.HoverWindow] = 'NormalFloat',
  [M.HIGHLIGHT_GROUPS.HoverBorder] = 'FloatBorder',
  [M.HIGHLIGHT_GROUPS.HoverSourceLine] = 'TabLine',
  [M.HIGHLIGHT_GROUPS.HoverActiveSource] = 'TabLineSel',
  [M.HIGHLIGHT_GROUPS.HoverInactiveSource] = 'TabLineFill',
  [M.HIGHLIGHT_GROUPS.HoverFloatingError] = 'DiagnosticFloatingError',
  [M.HIGHLIGHT_GROUPS.HoverFloatingWarn] = 'DiagnosticFloatingWarn',
  [M.HIGHLIGHT_GROUPS.HoverFloatingInfo] = 'DiagnosticFloatingInfo',
  [M.HIGHLIGHT_GROUPS.HoverFloatingHint] = 'DiagnosticFloatingHint',
}

function M.setup()
  for highlight, value in pairs(M.HIGHLIGHT_GROUP_DEFAULTS) do
    local existing = vim.api.nvim_get_hl(0, { name = highlight })

    if vim.tbl_isempty(existing) then
      vim.api.nvim_set_hl(0, highlight, { link = value })
    end
  end
end

return M

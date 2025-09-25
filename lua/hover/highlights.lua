local M = {}

---@alias HoverHighlightGroup
---| '"HoverWindow"'
---| '"HoverBorder"'
---| '"HoverActiveSource"'
---| '"HoverInactiveSource"'
---| '"HoverSourceLine"'
---| '"HoverFloatingError"'
---| '"HoverFloatingWarn"'
---| '"HoverFloatingInfo"'
---| '"HoverFloatingHint"'

---@type table<HoverHighlightGroup, string>
M.HIGHLIGHT_GROUP_DEFAULTS = {
  HoverWindow = 'NormalFloat',
  HoverBorder = 'FloatBorder',
  HoverSourceLine = 'TabLine',
  HoverActiveSource = 'TabLineSel',
  HoverInactiveSource = 'TabLineFill',
  HoverFloatingError = 'DiagnosticFloatingError',
  HoverFloatingWarn = 'DiagnosticFloatingWarn',
  HoverFloatingInfo = 'DiagnosticFloatingInfo',
  HoverFloatingHint = 'DiagnosticFloatingHint',
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

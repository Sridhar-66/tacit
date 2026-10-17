-- Neovim colours from the wallpaper palette. Rendered by matugen into
-- ~/.config/nvim/colors/matugen.lua on every wallpaper change; edit THIS file
-- (~/.config/matugen/templates/nvim/matugen.lua), never the output.
--
-- Every colour is a Material role, mapped exactly as the VS Code "martida" theme
-- maps them (templates/vscode/martida-color-theme.json) so the two editors agree.
-- Where that theme uses an alpha overlay (selection 99, bracket 66, indent 55,
-- diff 33) the colour is blended over `surface` here, since a terminal has no alpha.
-- The editor background is left transparent so foot's blur shows through, like
-- every other window; floats and menus get the theme's solid widget colour.

local c = {
  surface                   = "{{colors.surface.default.hex}}",
  surface_container_low     = "{{colors.surface_container_low.default.hex}}",
  surface_container         = "{{colors.surface_container.default.hex}}",
  surface_container_high    = "{{colors.surface_container_high.default.hex}}",
  surface_container_highest = "{{colors.surface_container_highest.default.hex}}",
  on_surface                = "{{colors.on_surface.default.hex}}",
  on_surface_variant        = "{{colors.on_surface_variant.default.hex}}",
  outline                   = "{{colors.outline.default.hex}}",
  outline_variant           = "{{colors.outline_variant.default.hex}}",
  primary                   = "{{colors.primary.default.hex}}",
  on_primary                = "{{colors.on_primary.default.hex}}",
  primary_container         = "{{colors.primary_container.default.hex}}",
  on_primary_container      = "{{colors.on_primary_container.default.hex}}",
  primary_fixed_dim         = "{{colors.primary_fixed_dim.default.hex}}",
  secondary                 = "{{colors.secondary.default.hex}}",
  secondary_fixed_dim       = "{{colors.secondary_fixed_dim.default.hex}}",
  tertiary                  = "{{colors.tertiary.default.hex}}",
  tertiary_fixed_dim        = "{{colors.tertiary_fixed_dim.default.hex}}",
  error                     = "{{colors.error.default.hex}}",
}

local function rgb(h) return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16) end
-- `fg` laid over `bg` at alpha a (0..255), as VS Code draws an #rrggbbaa colour.
local function over(fg, bg, a)
  local fr, fg_, fb = rgb(fg); local br, bg_, bb = rgb(bg); local t = a / 255
  return string.format("#%02x%02x%02x", fr * t + br * (1 - t) + 0.5, fg_ * t + bg_ * (1 - t) + 0.5, fb * t + bb * (1 - t) + 0.5)
end

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "matugen"
local r, g, b = rgb(c.surface)
vim.o.background = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 > 0.5 and "light" or "dark"

local function hl(group, spec) vim.api.nvim_set_hl(0, group, spec) end
local function link(group, to) vim.api.nvim_set_hl(0, group, { link = to }) end

-- ── editor ────────────────────────────────────────────────────────────────
hl("Normal",       { fg = c.on_surface })
hl("NormalNC",     { fg = c.on_surface })
hl("NormalFloat",  { fg = c.on_surface, bg = c.surface_container_high })
hl("FloatBorder",  { fg = c.outline_variant, bg = c.surface_container_high })
hl("FloatTitle",   { fg = c.primary, bg = c.surface_container_high, bold = true })
hl("LineNr",       { fg = c.outline_variant })
hl("CursorLineNr", { fg = c.primary })
hl("CursorLine",   { bg = c.surface_container_low })
hl("CursorColumn", { bg = c.surface_container_low })
hl("ColorColumn",  { bg = c.surface_container_low })
hl("Cursor",       { fg = c.surface, bg = c.primary })
hl("TermCursor",   { fg = c.surface, bg = c.primary })
hl("Visual",       { bg = over(c.primary_container, c.surface, 0x99) })
hl("Search",       { fg = c.on_primary_container, bg = c.primary_container })
hl("CurSearch",    { fg = c.on_primary, bg = c.primary })
link("IncSearch", "CurSearch")
hl("MatchParen",   { bg = over(c.primary_container, c.surface, 0x66), bold = true })
hl("NonText",      { fg = c.outline_variant })
hl("Whitespace",   { fg = over(c.outline_variant, c.surface, 0x55) })
hl("EndOfBuffer",  { fg = c.surface })
hl("SignColumn",   {})
hl("FoldColumn",   { fg = c.outline_variant })
hl("Folded",       { fg = c.on_surface_variant, bg = c.surface_container_low })
hl("WinSeparator", { fg = c.outline_variant })
hl("StatusLine",   { fg = c.on_surface_variant, bg = c.surface_container })
hl("StatusLineNC", { fg = c.outline, bg = c.surface_container })
hl("TabLine",      { fg = c.outline, bg = c.surface_container })
hl("TabLineSel",   { fg = c.on_surface, bg = c.surface_container_high })
hl("TabLineFill",  { bg = c.surface_container })
hl("Pmenu",        { fg = c.on_surface, bg = c.surface_container_high })
hl("PmenuSel",     { fg = c.on_primary_container, bg = c.primary_container })
hl("PmenuSbar",    { bg = c.surface_container_high })
hl("PmenuThumb",   { bg = c.outline_variant })
hl("WildMenu",     { fg = c.on_primary_container, bg = c.primary_container })
hl("Directory",    { fg = c.primary })
hl("Title",        { fg = c.primary, bold = true })
hl("ErrorMsg",     { fg = c.error })
hl("WarningMsg",   { fg = c.tertiary })
hl("MoreMsg",      { fg = c.primary })
hl("Question",     { fg = c.primary })
hl("ModeMsg",      { fg = c.on_surface_variant })
hl("QuickFixLine", { bg = c.surface_container })

-- ── diff and gutter (VS Code: added primary, modified tertiary, deleted error) ─
hl("Added",      { fg = c.primary })
hl("Changed",    { fg = c.tertiary })
hl("Removed",    { fg = c.error })
hl("DiffAdd",    { bg = over(c.primary_container, c.surface, 0x33) })
hl("DiffChange", { bg = over(c.tertiary, c.surface, 0x22) })
hl("DiffText",   { bg = over(c.tertiary, c.surface, 0x44) })
hl("DiffDelete", { fg = c.error })

-- ── diagnostics (VS Code: error = error, warning = tertiary) ─────────────────
hl("DiagnosticError", { fg = c.error })
hl("DiagnosticWarn",  { fg = c.tertiary })
hl("DiagnosticInfo",  { fg = c.secondary })
hl("DiagnosticHint",  { fg = c.outline })
hl("DiagnosticOk",    { fg = c.primary })
hl("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hl("DiagnosticUnderlineWarn",  { undercurl = true, sp = c.tertiary })
hl("DiagnosticUnderlineInfo",  { undercurl = true, sp = c.secondary })
hl("DiagnosticUnderlineHint",  { undercurl = true, sp = c.outline })

-- ── syntax: the martida tokenColors, role for role ────────────────────────
hl("Comment",    { fg = c.outline, italic = true })          -- comment
hl("String",     { fg = c.tertiary })                        -- string
link("Character", "String")
hl("Constant",   { fg = c.secondary })                       -- constant.numeric / .language / .character
link("Number", "Constant"); link("Float", "Constant"); link("Boolean", "Constant")
hl("SpecialChar", { fg = c.secondary })                      -- constant.character.escape
hl("Keyword",    { fg = c.primary })                         -- keyword / storage.type / storage.modifier
for _, gr in ipairs({ "Statement", "Conditional", "Repeat", "Label", "Exception", "StorageClass",
  "Structure", "Typedef", "Include", "PreProc", "Define", "Macro", "PreCondit" }) do link(gr, "Keyword") end
hl("Operator",   { fg = c.on_surface_variant })              -- keyword.operator
hl("Function",   { fg = c.primary_fixed_dim })               -- entity.name.function
hl("Type",       { fg = c.tertiary_fixed_dim })              -- entity.name.type / .class
hl("Identifier", { fg = c.on_surface })                      -- variable
hl("Delimiter",  { fg = c.on_surface_variant })              -- punctuation
hl("Special",    { fg = c.tertiary })
hl("Tag",        { fg = c.primary })                         -- entity.name.tag
hl("Error",      { fg = c.error })                           -- invalid
hl("Todo",       { fg = c.tertiary, bold = true })
hl("Underlined", { underline = true })

-- ── tree-sitter captures, onto the same roles ─────────────────────────────
local ts = {
  ["@comment"] = "Comment", ["@comment.documentation"] = "Comment",
  ["@string"] = "String", ["@string.escape"] = "SpecialChar", ["@string.special"] = "SpecialChar",
  ["@character"] = "String", ["@number"] = "Constant", ["@number.float"] = "Constant",
  ["@boolean"] = "Constant", ["@constant"] = "Constant", ["@constant.builtin"] = "Constant",
  ["@keyword"] = "Keyword", ["@keyword.function"] = "Keyword", ["@keyword.return"] = "Keyword",
  ["@keyword.import"] = "Keyword", ["@keyword.modifier"] = "Keyword", ["@keyword.type"] = "Keyword",
  ["@keyword.conditional"] = "Keyword", ["@keyword.repeat"] = "Keyword", ["@keyword.exception"] = "Keyword",
  ["@keyword.operator"] = "Operator", ["@operator"] = "Operator",
  ["@attribute"] = "Keyword",                                  -- Kotlin/Swift annotations: storage.type.annotation
  ["@function"] = "Function", ["@function.call"] = "Function", ["@function.method"] = "Function",
  ["@function.method.call"] = "Function", ["@function.builtin"] = "Function", ["@constructor"] = "Type",
  ["@type"] = "Type", ["@type.builtin"] = "Type", ["@type.definition"] = "Type",
  ["@variable"] = "Identifier", ["@variable.member"] = "Identifier", ["@property"] = "Identifier",
  ["@module"] = "Identifier", ["@label"] = "Keyword",
  ["@punctuation"] = "Delimiter", ["@punctuation.delimiter"] = "Delimiter",
  ["@punctuation.bracket"] = "Delimiter", ["@punctuation.special"] = "Delimiter",
  ["@tag"] = "Tag", ["@tag.delimiter"] = "Delimiter",
}
for capture, to in pairs(ts) do link(capture, to) end
hl("@variable.parameter", { fg = c.secondary_fixed_dim })     -- variable.parameter
hl("@variable.builtin",   { fg = c.primary })                 -- this / self / it
hl("@tag.attribute",      { fg = c.tertiary, italic = true }) -- entity.other.attribute-name
hl("@markup.heading",     { fg = c.primary, bold = true })    -- markup.heading
hl("@markup.strong",      { bold = true })
hl("@markup.italic",      { italic = true })
hl("@markup.raw",         { fg = c.tertiary })                -- markup.inline.raw
hl("@markup.link",        { fg = c.primary, underline = true })
hl("@markup.list",        { fg = c.on_surface_variant })

-- LSP semantic tokens follow the same roles instead of overriding tree-sitter.
link("@lsp.type.parameter", "@variable.parameter"); link("@lsp.type.property", "@property")
link("@lsp.type.function", "Function"); link("@lsp.type.method", "Function")
link("@lsp.type.class", "Type"); link("@lsp.type.interface", "Type"); link("@lsp.type.enum", "Type")
link("@lsp.type.keyword", "Keyword"); link("@lsp.type.namespace", "@module")

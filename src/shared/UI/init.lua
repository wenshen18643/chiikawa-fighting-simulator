--[[
	The UI barrel. One import gets you tokens, motion, glyphs, primitives and
	components:

		local UI = require(ReplicatedStorage.Shared.UI)

		local card = UI.card(parent, "Purse")
		UI.padding(card, UI.space.base)
		UI.label(card, "Yen", { text = "0", font = UI.font.display, size = UI.text.display })
		UI.glyph(card, "coin", { color = UI.color.gold })
		UI.motion.to(card, UI.motion.pop, { Size = UDim2.fromOffset(240, 96) })

	Shared deliberately, not client-only: area files and server services build
	world-space signs from the same components the HUD is made of, so the game
	looks like one thing rather than two.

	Nothing in here depends on an uploaded asset. Icons are geometry (Glyphs),
	shadows and rings are frames (Primitives), and motion is named rather than
	hand-tuned per call site (Motion). That is what keeps the whole interface
	reviewable in a diff.
]]

local Components = require(script.Components)
local Glyphs = require(script.Glyphs)
local Motion = require(script.Motion)
local Primitives = require(script.Primitives)
local Templates = require(script.Templates)
local Theme = require(script.Theme)

local UI = {}

-- Tokens
UI.color = Theme.color
UI.font = Theme.font
UI.radius = Theme.radius
UI.space = Theme.space
UI.text = Theme.text
UI.Theme = Theme

-- Motion
UI.motion = Motion

-- Primitives
UI.corner = Primitives.corner
UI.stroke = Primitives.stroke
UI.padding = Primitives.padding
UI.gradient = Primitives.gradient
UI.list = Primitives.list
UI.shadow = Primitives.shadow
UI.aspect = Primitives.aspect
UI.grid = Primitives.grid
UI.ring = Primitives.ring
UI.vignette = Primitives.vignette

-- Components
UI.card = Components.card
UI.label = Components.label
UI.bar = Components.bar
UI.chip = Components.chip
UI.button = Components.button
UI.sign = Components.sign
UI.ticker = Components.ticker
UI.pips = Components.pips
UI.tabs = Components.tabs
UI.modal = Components.modal

-- Studio-authored templates (assets/UI/*.model.json)
UI.template = Templates.mount
UI.hasTemplate = Templates.exists
UI.Templates = Templates

-- Glyphs
UI.glyph = Glyphs.render
UI.skillGlyph = Glyphs.forSkill
UI.Glyphs = Glyphs

export type LabelConfig = Components.LabelConfig
export type MountConfig = Templates.MountConfig

return UI

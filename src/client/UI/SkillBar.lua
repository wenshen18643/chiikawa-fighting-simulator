--[[
	The bottom-centre skill bar: one big round button per skill, numbered.

	--------------------------------------------------------------------------
	WHY THIS REPLACED THE SIDE STACK
	--------------------------------------------------------------------------

	The skills used to live in a card down the left as six text rows. Everything
	needed was in it and none of it was reachable — the one control the player
	touches constantly sat as far from the crosshair as it is possible to put
	something, and read as a readout rather than as a row of buttons.

	Round, numbered, bottom-centre is the genre's convention for exactly this
	reason: it is where the thumb already is on a phone, where the eye already
	is on a desktop, and the digit on the badge matches the key that selects it.

	--------------------------------------------------------------------------
	WHAT EACH BUTTON CARRIES
	--------------------------------------------------------------------------

		( 1 )   <- round button, glyph, ringed in the skill's own colour
		 1.2K   <- the stat value
		 ====   <- progress to the next certification grade
		 ooooo  <- one pip per canon grade, lit for the ones reached

	So the bar did not lose what the stack showed; it stacked it vertically
	under each icon instead of horizontally across a row.

	--------------------------------------------------------------------------
	ACTIVE vs. SELECTED
	--------------------------------------------------------------------------

	Two states the caller passes separately (see HUD.update). ACTIVE is what a
	click raises right now; SELECTED is what the player picked. They agree
	today — nothing overrides the player's choice any more — but the pair is
	kept because the distinction is a display decision, not a gameplay one.

	This module owns how those look and exposes them as `setState(lit, picked)`
	rather than handing its Instances out, so HUD never reaches in to tween a
	frame it does not own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Certifications = require(Shared.Modules.Config.Certifications)
local Skills = require(Shared.Modules.Config.Skills)
local UI = require(Shared.UI)

local WorkController = require(script.Parent.Parent.Controllers.WorkController)

local SkillBar = {}

local BUTTON = 68
local CELL_WIDTH = 82
local CELL_HEIGHT = 106
local GAP = 10

export type SkillEntry = {
	setValue: (text: string, numeric: number?) -> (),
	setProgress: (fraction: number) -> (),
	setPips: (met: number) -> (),
	setGrade: (text: string?) -> (),
	setState: (lit: boolean, picked: boolean) -> (),
}

local holder: Frame

local function buildCell(
	parent: Instance,
	index: number,
	skillId: string,
	gradeCount: number,
	onBlocked: (string) -> ()
): SkillEntry
	local definition = Skills.get(skillId)
	local accent = (definition and definition.color) or UI.color.leaf

	local cell = Instance.new("Frame")
	cell.Name = skillId
	cell.BackgroundTransparency = 1
	cell.Size = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT)
	cell.LayoutOrder = index
	cell.ZIndex = 4
	cell.Parent = parent

	--[[
		The button is the circle itself, not a frame containing one, so the
		whole disc is the hit target rather than a square around it.
	]]
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 0)
	button.Size = UDim2.fromOffset(BUTTON, BUTTON)
	button.BackgroundColor3 = UI.color.paper
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 5
	button.Parent = cell
	UI.corner(button, UI.radius.pill)

	local ring = UI.stroke(button, UI.color.line, UI.Theme.stroke.heavy)

	-- A wash of the skill's colour inside the disc, so an unlit button still
	-- says which skill it is without relying on the glyph alone.
	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = accent
	wash.BackgroundTransparency = 0.86
	wash.BorderSizePixel = 0
	wash.ZIndex = 5
	wash.Parent = button
	UI.corner(wash, UI.radius.pill)

	UI.skillGlyph(button, skillId, {
		color = accent,
		extent = UDim2.fromOffset(30, 30),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		zIndex = 7,
	})

	--[[
		The number badge. It is the keyboard digit, sitting on the thing that
		digit selects, which is cheaper than a legend explaining the mapping.
	]]
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.94, 0.1)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.BackgroundColor3 = UI.color.paperDeep
	badge.BorderSizePixel = 0
	badge.ZIndex = 8
	badge.Parent = button
	UI.corner(badge, UI.radius.pill)
	UI.stroke(badge, UI.color.line, UI.Theme.stroke.base)

	UI.label(badge, "Number", {
		text = tostring(index),
		font = UI.font.display,
		size = 13,
		color = UI.color.ink,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 1),
		zIndex = 9,
	})

	button.Activated:Connect(function()
		if WorkController.isSelectable(skillId) then
			WorkController.selectSkill(skillId)
		else
			onBlocked(skillId)
		end
	end)

	local value, setValue = UI.ticker(cell, "Value", {
		text = "0",
		font = UI.font.display,
		size = 16,
		color = UI.color.ink,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.new(1, 0, 0, 19),
		position = UDim2.fromOffset(0, BUTTON + 3),
	})
	value.TextStrokeColor3 = UI.color.line
	value.TextStrokeTransparency = 0.2

	local track, fill = UI.bar(cell, "Progress", accent)
	track.Size = UDim2.fromOffset(CELL_WIDTH - 20, 5)
	track.Position = UDim2.fromOffset(10, BUTTON + 24)
	track.ZIndex = 4

	local _, setPips = UI.pips(cell, "Grades", {
		total = gradeCount,
		color = accent,
		extent = UDim2.fromOffset(CELL_WIDTH - 24, 4),
		position = UDim2.fromOffset(12, BUTTON + 33),
		zIndex = 5,
	})

	-- Certification grade, hidden until there is one to show.
	local grade = UI.label(cell, "Grade", {
		text = "",
		font = UI.font.bold,
		size = 10,
		color = accent,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.new(1, 0, 0, 12),
		position = UDim2.fromOffset(0, BUTTON + 40),
	})
	grade.Visible = false

	local function setState(lit: boolean, picked: boolean)
		--[[
			Three visual states off two booleans:
			  lit      full colour ring, thick, disc washed in the colour
			  picked   colour ring at normal weight
			  neither  the near-black outline every other surface wears
		]]
		UI.motion.to(ring, UI.motion.settle, {
			Color = if lit or picked then accent else UI.color.line,
			Thickness = if lit then UI.Theme.stroke.heavy else UI.Theme.stroke.base,
		})
		UI.motion.to(wash, UI.motion.settle, {
			BackgroundTransparency = if lit then 0.55 else 0.86,
		})
		-- The active button sits slightly proud of the row. Size, not position,
		-- so the row never reflows and the digits stay where they were learned.
		UI.motion.to(button, UI.motion.settle, {
			Size = UDim2.fromOffset(if lit then BUTTON + 6 else BUTTON, if lit then BUTTON + 6 else BUTTON),
		})
		UI.motion.to(value, UI.motion.settle, {
			TextColor3 = if lit then accent else UI.color.ink,
		})
	end

	setState(false, false)

	return {
		setValue = setValue,
		setProgress = function(fraction: number)
			fill.Size = UDim2.fromScale(fraction, 1)
		end,
		setPips = setPips,
		setGrade = function(text: string?)
			grade.Visible = text ~= nil
			grade.Text = text or ""
		end,
		setState = setState,
	}
end

--[[
	Build the bar. Returns the entries keyed by skill id, plus the holder so the
	caller can hide it on a compact screen.
]]
function SkillBar.build(parent: Instance, onBlocked: (string) -> ()): ({ [string]: SkillEntry }, Frame)
	local count = #Skills.ORDER
	local gradeCount = Certifications.MAX_CANON_ORDER

	holder = Instance.new("Frame")
	holder.Name = "SkillBar"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -14)
	holder.Size = UDim2.fromOffset(count * CELL_WIDTH + (count - 1) * GAP, CELL_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 4
	holder.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = holder

	local entries: { [string]: SkillEntry } = {}
	for index, skillId in Skills.ORDER do
		entries[skillId] = buildCell(holder, index, skillId, gradeCount, onBlocked)
	end

	return entries, holder
end

return SkillBar

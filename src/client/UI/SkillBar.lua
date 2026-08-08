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
local COMPACT_BUTTON = 52
local COMPACT_CELL_WIDTH = 66
local COMPACT_CELL_HEIGHT = 84
local COMPACT_GAP = 6

export type SkillEntry = {
	setValue: (text: string, numeric: number?) -> (),
	setProgress: (fraction: number) -> (),
	setPips: (met: number) -> (),
	setGrade: (text: string?) -> (),
	setState: (lit: boolean, picked: boolean) -> (),
}

local holder: Frame
local holderLayout: UIListLayout
local compact = false
local inputMode = "keyboard"
local cells: { {
	cell: Frame,
	button: TextButton,
	badge: Frame,
	value: TextLabel,
	track: Frame,
	pips: Frame,
	grade: TextLabel,
} } = {}

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

	local pips, setPips = UI.pips(cell, "Grades", {
		total = gradeCount,
		color = accent,
		extent = UDim2.fromOffset(CELL_WIDTH - 24, 4),
		position = UDim2.fromOffset(12, BUTTON + 33),
		zIndex = 5,
	})

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
		button:SetAttribute("Lit", lit)
		local baseButton = if compact then COMPACT_BUTTON else BUTTON
		UI.motion.to(ring, UI.motion.settle, {
			Color = if lit or picked then accent else UI.color.line,
			Thickness = if lit then UI.Theme.stroke.heavy else UI.Theme.stroke.base,
		})
		UI.motion.to(wash, UI.motion.settle, {
			BackgroundTransparency = if lit then 0.55 else 0.86,
		})
		UI.motion.to(button, UI.motion.settle, {
			Size = UDim2.fromOffset(if lit then baseButton + 6 else baseButton, if lit then baseButton + 6 else baseButton),
		})
		UI.motion.to(value, UI.motion.settle, {
			TextColor3 = if lit then accent else UI.color.ink,
		})
	end

	setState(false, false)
	table.insert(cells, {
		cell = cell,
		button = button,
		badge = badge,
		value = value,
		track = track,
		pips = pips,
		grade = grade,
	})

	return {
		setValue = setValue,

		setProgress = function(fraction: number)
			fill.Size = UDim2.fromScale(fraction, 1)
		end,
		setPips = setPips,

		setGrade = function(text: string?)
			grade:SetAttribute("HasGrade", text ~= nil)
			grade.Visible = text ~= nil and not compact
			grade.Text = text or ""
		end,
		setState = setState,
	}
end

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

	holderLayout = Instance.new("UIListLayout")
	holderLayout.FillDirection = Enum.FillDirection.Horizontal
	holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	holderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	holderLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	holderLayout.Padding = UDim.new(0, GAP)
	holderLayout.Parent = holder

	local entries: { [string]: SkillEntry } = {}
	for index, skillId in Skills.ORDER do
		entries[skillId] = buildCell(holder, index, skillId, gradeCount, onBlocked)
	end

	return entries, holder
end

function SkillBar.setInputMode(mode: string)
	inputMode = mode
	for _, record in cells do
		record.badge.Visible = not compact and inputMode == "keyboard"
	end
end

function SkillBar.setCompact(value: boolean)
	compact = value
	local count = #cells
	holder.Position = UDim2.new(0.5, 0, 1, if compact then -8 else -14)
	holder.Size = UDim2.fromOffset(
		if compact then count * COMPACT_CELL_WIDTH + (count - 1) * COMPACT_GAP else count * CELL_WIDTH + (count - 1) * GAP,
		if compact then COMPACT_CELL_HEIGHT else CELL_HEIGHT
	)
	holderLayout.Padding = UDim.new(0, if compact then COMPACT_GAP else GAP)
	for _, record in cells do
		local buttonSize = if compact then COMPACT_BUTTON else BUTTON
		if record.button:GetAttribute("Lit") == true then
			buttonSize += 6
		end
		record.cell.Size = UDim2.fromOffset(if compact then COMPACT_CELL_WIDTH else CELL_WIDTH, if compact then COMPACT_CELL_HEIGHT else CELL_HEIGHT)
		record.button.Size = UDim2.fromOffset(buttonSize, buttonSize)
		record.badge.Visible = not compact and inputMode == "keyboard"
		record.value.TextSize = if compact then 14 else 16
		record.value.Position = UDim2.fromOffset(0, if compact then COMPACT_BUTTON + 2 else BUTTON + 3)
		record.track.Size = UDim2.fromOffset(if compact then COMPACT_CELL_WIDTH - 12 else CELL_WIDTH - 20, 5)
		record.track.Position = UDim2.fromOffset(if compact then 6 else 10, if compact then 73 else BUTTON + 24)
		record.pips.Visible = not compact
		record.grade.Visible = not compact and record.grade:GetAttribute("HasGrade") == true
	end
end

return SkillBar

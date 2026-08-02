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

	local _, setPips = UI.pips(cell, "Grades", {
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
		UI.motion.to(ring, UI.motion.settle, {
			Color = if lit or picked then accent else UI.color.line,
			Thickness = if lit then UI.Theme.stroke.heavy else UI.Theme.stroke.base,
		})
		UI.motion.to(wash, UI.motion.settle, {
			BackgroundTransparency = if lit then 0.55 else 0.86,
		})
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Skills = require(Shared.Modules.Config.Skills)
local UI = require(Shared.UI)
local WorkCore = {}
local RING_SIZE = 84
local root: Frame
local setRing: (number) -> ()
local ringGlyph: Frame
local ringValue: TextLabel
local ringCaption: TextLabel
local titleLabel: TextLabel
local detailLabel: TextLabel
local actionPill: Frame
local actionLabel: TextLabel
local currentSkill: string? = nil
local ringGlyphSkill: string? = nil
local lastRatio = 0

function WorkCore.build(parent: Instance): Frame
	root = UI.card(parent, "WorkCore")

	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -18, 1, -18)
	root.Size = UDim2.fromOffset(320, 108)
	UI.padding(root, 12)
	UI.shadow(root)

	local ring
	ring, setRing = UI.ring(root, "Stamina", {
		extent = UDim2.fromOffset(RING_SIZE, RING_SIZE),
		position = UDim2.fromOffset(0, 0),
		thickness = 9,
		color = UI.color.leaf,
		zIndex = 3,
	})
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.new(0, 0, 0.5, 0)

	ringGlyph = UI.glyph(ring, "leaf", {
		color = UI.color.leafDeep,
		extent = UDim2.fromOffset(24, 24),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.34),
		zIndex = 6,
	})

	ringValue = UI.label(ring, "Value", {
		text = "100",
		font = UI.font.display,
		size = 19,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 0.2),
		position = UDim2.fromScale(0, 0.46),
		zIndex = 6,
	})

	ringCaption = UI.label(ring, "Caption", {
		text = "STAMINA",
		font = UI.font.bold,
		size = 9,
		color = UI.color.inkFaint,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 0.16),
		position = UDim2.fromScale(0, 0.63),
		zIndex = 6,
	})

	local column = Instance.new("Frame")
	column.Name = "Detail"
	column.Position = UDim2.fromOffset(RING_SIZE + 16, 4)
	column.Size = UDim2.new(1, -(RING_SIZE + 16), 1, -8)
	column.BackgroundTransparency = 1
	column.ZIndex = 3
	column.Parent = root

	titleLabel = UI.label(column, "Title", {
		text = "",
		font = UI.font.display,
		size = 20,
		extent = UDim2.new(1, 0, 0, 26),
		position = UDim2.fromOffset(0, 2),
	})

	detailLabel = UI.label(column, "Detail", {
		text = "",
		font = UI.font.body,
		size = 13,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 30),
	})

	actionPill = Instance.new("Frame")
	actionPill.Name = "ActionPill"
	actionPill.AnchorPoint = Vector2.new(0, 1)
	actionPill.Position = UDim2.new(0, 0, 1, 0)
	actionPill.Size = UDim2.new(1, 0, 0, 30)
	actionPill.BackgroundColor3 = UI.color.leaf
	actionPill.BorderSizePixel = 0
	actionPill.ZIndex = 4
	actionPill.Parent = column
	UI.corner(actionPill, UI.radius.pill)

	actionLabel = UI.label(actionPill, "Action", {
		text = "",
		font = UI.font.bold,
		size = 13,
		color = UI.color.white,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 1),
		zIndex = 5,
	})

	return root
end

local function showTraining(snapshot: any)
	local selected = snapshot.selectedSkill
	local definition = selected and Skills.get(selected)
	currentSkill = selected

	local studying = selected ~= nil and Skills.canonicalize(selected) == "examprep"
	local gain = snapshot.gainPerAction
	local rate = if gain then BigNumber.toString(gain) else "0"

	titleLabel.Text = if definition then `Training {definition.name}` else "Training"

	detailLabel.Text = if studying then `+{rate} a page` else `+{rate} a click  ·  press 1-4 to switch skill`
	detailLabel.TextColor3 = UI.color.inkSoft

	actionPill.BackgroundColor3 = if definition and definition.color
		then definition.color
		else (UI.color.leaf or Color3.fromRGB(126, 190, 104))
	actionLabel.Text = if studying
		then string.upper(if UserInputService.TouchEnabled then "tap skill 4 to open book" else "press 4 to open book")
		else string.upper(
			`{if UserInputService.TouchEnabled then "tap" else "click"} to {definition and definition.verb or "work"}`
		)
end

function WorkCore.update(snapshot: any)
	if not root then
		return
	end

	local stamina = snapshot.stamina
	local ratio = if stamina.max > 0 then math.clamp(stamina.current / stamina.max, 0, 1) else 0

	lastRatio += (ratio - lastRatio) * 0.5
	setRing(lastRatio)

	ringValue.Text = tostring(math.floor(stamina.current))
	ringCaption.Text = if snapshot.resting then "RESTING" else "STAMINA"
	ringCaption.TextColor3 = if snapshot.resting then UI.color.rest else UI.color.inkFaint

	showTraining(snapshot)

	actionLabel.TextColor3 = UI.color.white

	local glyphSkill = currentSkill
	if glyphSkill and glyphSkill ~= ringGlyphSkill then
		ringGlyphSkill = glyphSkill
		local skill = Skills.get(glyphSkill)
		local host = ringGlyph.Parent :: Instance
		ringGlyph:Destroy()
		ringGlyph = UI.skillGlyph(host, glyphSkill, {
			color = skill and skill.color or UI.color.leafDeep,
			extent = UDim2.fromOffset(24, 24),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.34),
			zIndex = 6,
		})
	end
end

function WorkCore.setVisible(visible: boolean)
	if root then
		root.Visible = visible
	end
end

return WorkCore

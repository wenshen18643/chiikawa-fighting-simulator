--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local UI = require(Shared.UI)

type PullResult = {
	skinId: string,
	rarity: CompanionSkins.RarityId,
	isNew: boolean,
}

local GachaResults = {}
local BACKDROP = Color3.fromRGB(9, 13, 29)
local PANEL = Color3.fromRGB(25, 31, 52)
local WHITE = Color3.fromRGB(255, 250, 235)

local function addResultCard(parent: Instance, result: PullResult, index: number)
	local rarity = CompanionSkins.RARITIES[result.rarity]
	local skin = CompanionSkins.get(result.skinId)
	if not skin then
		return
	end
	local character = CompanionSkins.CHARACTERS[skin.characterId]

	local card = UI.card(parent, `Result{index}`, {
		color = rarity.color:Lerp(BACKDROP, 0.78),
		radius = UI.radius.card,
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	card.LayoutOrder = index
	card.Visible = false

	local stroke = UI.stroke(card, rarity.color, 2)
	stroke.Transparency = 0.08

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rarity.color:Lerp(WHITE, 0.12)),
		ColorSequenceKeypoint.new(0.02, rarity.color:Lerp(BACKDROP, 0.72)),
		ColorSequenceKeypoint.new(1, BACKDROP),
	})
	gradient.Rotation = 90
	gradient.Parent = card

	local scale = Instance.new("UIScale")
	scale.Scale = 0.82
	scale.Parent = card

	UI.label(card, "Number", {
		text = `#{index}`,
		font = UI.font.bold,
		size = UI.text.caption,
		color = Color3.fromRGB(190, 197, 218),
		position = UDim2.fromOffset(12, 8),
		extent = UDim2.fromOffset(40, 18),
	})
	UI.label(card, "Rarity", {
		text = string.upper(rarity.name),
		font = UI.font.bold,
		size = UI.text.caption,
		color = rarity.color,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0.42, 0, 0, 8),
		extent = UDim2.new(0.58, -12, 0, 18),
	})
	UI.label(card, "Name", {
		text = skin.name,
		font = UI.font.display,
		size = UI.text.body,
		color = WHITE,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(10, 36),
		extent = UDim2.new(1, -20, 0, 50),
		wrapped = true,
	})
	UI.label(card, "Character", {
		text = if character then character.name else skin.characterId,
		font = UI.font.body,
		size = UI.text.small,
		color = Color3.fromRGB(196, 202, 220),
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 10, 1, -52),
		extent = UDim2.new(1, -20, 0, 20),
	})
	UI.label(card, "CopyState", {
		text = if result.isNew then "NEW!" else "EXTRA COPY",
		font = UI.font.bold,
		size = UI.text.caption,
		color = if result.isNew then Color3.fromRGB(138, 244, 192) else Color3.fromRGB(176, 183, 204),
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 10, 1, -29),
		extent = UDim2.new(1, -20, 0, 18),
	})

	task.delay((index - 1) * 0.045, function()
		if not card.Parent then
			return
		end
		card.Visible = true
		UI.motion.to(scale, UI.motion.pop, { Scale = 1 })
	end)
end

function GachaResults.show(
	parent: PlayerGui,
	results: { PullResult },
	drawId: string,
	onClosed: () -> ()
): () -> ()
	local finished = false
	local screen = Instance.new("ScreenGui")
	screen.Name = "GachaPullResults"
	screen.DisplayOrder = 79
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = parent

	local scrim = Instance.new("Frame")
	scrim.Name = "Scrim"
	scrim.Active = true
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 0.18
	scrim.BorderSizePixel = 0
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.Parent = screen

	local panel = UI.card(scrim, "ResultsPanel", {
		color = PANEL,
		radius = UI.radius.card,
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		stroke = false,
		sheen = false,
		innerLine = false,
		elevation = "high",
	})
	panel.Size = UDim2.fromScale(0.84, 0.82)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(540, 440)
	constraint.MaxSize = Vector2.new(980, 720)
	constraint.Parent = panel

	local panelStroke = UI.stroke(panel, Color3.fromRGB(104, 116, 158), 1.5)
	panelStroke.Transparency = 0.25

	UI.label(panel, "Eyebrow", {
		text = "WISH COMPLETE",
		font = UI.font.bold,
		size = UI.text.caption,
		color = Color3.fromRGB(148, 183, 255),
		position = UDim2.fromOffset(24, 18),
		extent = UDim2.new(1, -48, 0, 18),
	})
	UI.label(panel, "Title", {
		text = if drawId == "premium" then "Premium Results" else "Standard Results",
		font = UI.font.display,
		size = UI.text.title,
		color = WHITE,
		position = UDim2.fromOffset(24, 34),
		extent = UDim2.new(1, -48, 0, 34),
	})
	UI.label(panel, "Subtitle", {
		text = `{#results} capsule{if #results == 1 then "" else "s"} opened`,
		font = UI.font.body,
		size = UI.text.small,
		color = Color3.fromRGB(190, 197, 218),
		position = UDim2.fromOffset(24, 68),
		extent = UDim2.new(1, -48, 0, 22),
	})

	local resultList = Instance.new("ScrollingFrame")
	resultList.Name = "Results"
	resultList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	resultList.BackgroundTransparency = 1
	resultList.BorderSizePixel = 0
	resultList.CanvasSize = UDim2.fromOffset(0, 0)
	resultList.Position = UDim2.fromOffset(24, 104)
	resultList.ScrollBarImageColor3 = Color3.fromRGB(104, 116, 158)
	resultList.ScrollBarThickness = 5
	resultList.Size = UDim2.new(1, -48, 1, -180)
	resultList.Parent = panel

	local grid = Instance.new("UIGridLayout")
	local columns = math.min(math.max(#results, 1), 5)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.CellSize = if #results == 1
		then UDim2.new(0.56, 0, 0, 210)
		else UDim2.new(1 / columns, -10, 0, 160)
	grid.FillDirectionMaxCells = columns
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = resultList

	for index, result in results do
		addResultCard(resultList, result, index)
	end

	local continueButton = UI.button(panel, "Continue", {
		text = "Continue",
		color = Color3.fromRGB(126, 168, 246),
		textColor = Color3.fromRGB(17, 24, 43),
		extent = UDim2.fromOffset(180, 42),
		position = UDim2.new(0.5, -90, 1, -58),
		stroke = false,
		sheen = false,
	})

	local function close(completed: boolean)
		if finished then
			return
		end
		finished = true
		screen:Destroy()
		if completed then
			onClosed()
		end
	end

	continueButton.Activated:Connect(function()
		close(true)
	end)

	return function()
		close(false)
	end
end

return GachaResults

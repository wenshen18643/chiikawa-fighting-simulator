local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local ShopMenu = {}

type Row = {
	id: string,
	name: string,
	sub: string,
	skill: string?,
	level: number,
	tierProgress: number,
	multiplier: number,
	nextMultiplier: number,
	cost: any?,
}

local ROW_HEIGHT = 96
local ROW_TINTS = { UI.color.gold, UI.color.sky }
local screen: ScreenGui
local panel: Frame
local listHolder: ScrollingFrame
local setOpen: (boolean) -> ()
local buyRemote: RemoteEvent
local built: { [string]: { [string]: any } } = {}
local order: { string } = {}
local latest: { [string]: Row } = {}
local yen: any = nil

local function multiplierText(multiplier: number): string
	if multiplier < 1000 then
		return string.format("%.2f", multiplier)
	end
	return BigNumber.toString(BigNumber.fromNumber(multiplier))
end

local function canAfford(row: Row): boolean
	if not row.cost then
		return false
	end
	if not BigNumber.isValid(yen) then
		return false
	end
	return BigNumber.gte(yen, row.cost)
end

local function tintFor(row: Row, index: number): Color3
	local definition = row.skill and Skills.get(row.skill)
	if definition then
		return definition.color
	end
	return ROW_TINTS[(index - 1) % #ROW_TINTS + 1]
end

local function buildRow(row: Row, index: number)
	local tint = tintFor(row, index)

	local card = UI.card(listHolder, row.id, {
		color = UI.color.paper,
		radius = UI.radius.chip,
	})
	card.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	card.LayoutOrder = index

	UI.label(card, "Name", {
		text = row.name,
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(UI.space.base, UI.space.snug),
		extent = UDim2.new(1, -190, 0, 26),
	})

	UI.label(card, "Sub", {
		text = row.sub,
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(UI.space.base, UI.space.snug + 26),
		extent = UDim2.new(1, -190, 0, 18),
	})

	local _, setLevel = UI.meter(card, "Level", {
		color = tint,
		caption = "",
		position = UDim2.fromOffset(UI.space.base, ROW_HEIGHT - 34),
		extent = UDim2.new(1, -190 - UI.space.base, 0, 28),
	})

	local caption = card:FindFirstChild("Caption", true)

	local costChip = UI.chip(card, "Cost", {
		text = "",
		color = UI.color.paperSunken,
		textColor = UI.color.gold,
		extent = UDim2.fromOffset(150, 22),
		position = UDim2.new(1, -166, 0, UI.space.snug),
	})

	local costLabel = costChip:FindFirstChildWhichIsA("TextLabel", true)

	local buy = UI.button(card, "Buy", {
		text = "Buy",
		color = tint,
		textColor = UI.color.paperDeep,
		extent = UDim2.fromOffset(150, 34),
		position = UDim2.new(1, -166, 1, -46),
		states = false,

		onActivated = function()
			local current = latest[row.id]
			if current and canAfford(current) then
				buyRemote:FireServer(row.id)
			end
		end,
	})

	local parts = {
		card = card,
		buy = buy,
		setLevel = setLevel,
		caption = caption,
		costLabel = costLabel,
		tint = tint,
		enabled = false,
		hovered = false,
	}

	local function paintHover()
		if not parts.enabled then
			return
		end
		UI.motion.to(buy, UI.motion.hover, {
			BackgroundColor3 = if parts.hovered then UI.lighten(tint, UI.Theme.state.hover.lighten) else tint,
		})
	end

	buy.MouseEnter:Connect(function()
		parts.hovered = true
		paintHover()
	end)
	buy.MouseLeave:Connect(function()
		parts.hovered = false
		paintHover()
	end)

	built[row.id] = parts
end

local function paintRow(row: Row)
	local parts = built[row.id]
	if not parts then
		return
	end

	parts.setLevel(row.tierProgress)

	if parts.caption and parts.caption:IsA("TextLabel") then
		parts.caption.Text = `Level {row.level}`
	end

	local affordable = canAfford(row)

	if parts.costLabel and parts.costLabel:IsA("TextLabel") then
		parts.costLabel.Text = `x{multiplierText(row.multiplier)} → x{multiplierText(row.nextMultiplier)}`
	end

	local button = parts.buy :: TextButton
	parts.enabled = affordable

	button.Text = `{BigNumber.toString(row.cost)} yen`
	button.BackgroundColor3 = if parts.enabled then parts.tint else UI.color.paperSunken
	button.TextColor3 = if parts.enabled then UI.color.paperDeep else UI.color.inkFaint
	button.Active = parts.enabled
end

local function repaint()
	for _, id in order do
		local row = latest[id]
		if row then
			paintRow(row)
		end
	end
end

local function render(payload: { [string]: any })
	local rows = payload.rows or {}
	yen = payload.yen or yen

	for index, row in rows do
		latest[row.id] = row
		if not built[row.id] then
			table.insert(order, row.id)
			buildRow(row, index)
		end
	end

	repaint()
end

local function buildPanel(parent: ScreenGui)
	local _scrim, content, toggle = UI.modal(parent, "ShopMenu", {
		extent = UDim2.new(0, 560, 0, 540),
		zIndex = 20,
	})
	panel = content
	setOpen = toggle

	UI.padding(panel, UI.space.loose)

	UI.label(panel, "Title", {
		text = "Upgrades",
		font = UI.font.display,
		size = UI.text.title,
		extent = UDim2.new(1, 0, 0, 30),
	})

	UI.label(panel, "Subtitle", {
		text = "Each stat has its own multiplier. Permanent, and they stack with everything else.",
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(0, 32),
		extent = UDim2.new(1, 0, 0, 20),
	})

	listHolder = Instance.new("ScrollingFrame")
	listHolder.Name = "List"
	listHolder.BackgroundTransparency = 1
	listHolder.BorderSizePixel = 0
	listHolder.Position = UDim2.fromOffset(0, 64)
	listHolder.Size = UDim2.new(1, 0, 1, -108)
	listHolder.ScrollingDirection = Enum.ScrollingDirection.Y
	listHolder.ScrollBarThickness = 8
	listHolder.ScrollBarImageColor3 = UI.color.inkSoft
	listHolder.ScrollBarImageTransparency = 0.2
	listHolder.CanvasSize = UDim2.fromOffset(0, 0)
	listHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listHolder.ZIndex = panel.ZIndex + 1
	listHolder.Parent = panel
	UI.list(listHolder, UI.space.snug)
	UI.padding(listHolder, 0, { right = 14 })

	UI.button(panel, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(120, 34),
		position = UDim2.new(0.5, -60, 1, -34),
		zIndex = panel.ZIndex + 1,

		onActivated = function()
			setOpen(false)
		end,
	})
end

function ShopMenu.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "ShopMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 9
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	buildPanel(screen)

	buyRemote = Remotes.event("Shop", "Buy")

	Remotes.event("Shop", "Open").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		render(payload)
		setOpen(true)
	end)

	Remotes.event("Shop", "Event").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.board) == "table" then
			render(payload.board)
		end
	end)

	StateController.onChanged(function(snapshot)
		if snapshot and snapshot.yen then
			yen = snapshot.yen
			repaint()
		end
	end)
end

function ShopMenu.setOpen(open: boolean)
	if setOpen then
		setOpen(open)
	end
end

return ShopMenu

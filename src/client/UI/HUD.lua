local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Boosts = require(Shared.Modules.Boosts)
local Certifications = require(Shared.Modules.Config.Certifications)
local Constants = require(Shared.Modules.Constants)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local UI = require(Shared.UI)
local WorkOrders = require(Shared.Modules.Config.WorkOrders)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local ControlsPanel = require(script.Parent.ControlsPanel)
local ControlTutorial = require(script.Parent.ControlTutorial)
local FarmMenu = require(script.Parent.FarmMenu)
local InventoryMenu = require(script.Parent.InventoryMenu)
local OrderTracker = require(script.Parent.OrderTracker)
local SkillBar = require(script.Parent.SkillBar)
local WorkCore = require(script.Parent.WorkCore)
local InputMode = require(script.Parent.InputMode)
local HUD = {}
local RAIL_MARGIN = 18
local RAIL_MARGIN_COMPACT = 8
local RAIL_BUTTON = 52
local RAIL_BUTTON_COMPACT = 44
local RAIL_TOP_OFFSET = 328
local RAIL_TOP_OFFSET_COMPACT = 264
local CURRENCY_WIDTH = 200
local CURRENCY_HEIGHT = 72
local CURRENCY_DISC = 34
local CURRENCY_GAP = 4
local CURRENCY_INSET = CURRENCY_DISC + 10
local CURRENCY_SCALE_COMPACT = 0.82
local skillEntries: { [string]: SkillBar.SkillEntry } = {}
local screen: ScreenGui
local skillBarHolder: Frame
local currencyRail: CanvasGroup
local currencyScale: UIScale
local yenPunch: UIScale
local lastYen = ""
local yenSet: (string, number?) -> ()
local stampLabel: TextLabel
local toastHolder: Frame
local buffHolder: ScrollingFrame
local activeSkill: string? = nil
local selectedSkill: string? = nil
local buffChips: { TextLabel } = {}
local buffKey = ""
local sideRail: Frame
local sideRailButtons: { TextButton } = {}
local compactLayout = false
local tutorialActive = false

local function outlined(label: TextLabel, thickness: number)
	local stroke = UI.stroke(label, UI.color.glassDark, thickness)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Transparency = 0.1
end

local function currencyRow(parent: Instance, name: string, glyph: string, tint: Color3, y: number, disc: number): (Frame, Frame)
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.new(1, 0, 0, disc)
	row.ZIndex = 4
	row.Parent = parent

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 0, 0.5, 0)
	badge.Size = UDim2.fromOffset(disc, disc)
	badge.BackgroundColor3 = UI.color.glassDark
	badge.BackgroundTransparency = 0.32
	badge.BorderSizePixel = 0
	badge.ZIndex = 4
	badge.Parent = row
	UI.corner(badge, UI.radius.pill)
	UI.stroke(badge, tint, UI.Theme.stroke.hair).Transparency = 0.35

	UI.glyph(badge, glyph, {
		color = tint,
		extent = UDim2.fromOffset(math.floor(disc * 0.58), math.floor(disc * 0.58)),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		zIndex = 5,
	})

	return row, badge
end

local function buildCurrencyRail(parent: Instance)
	local group = Instance.new("CanvasGroup")
	group.Name = "Currency"
	group.AnchorPoint = Vector2.new(0, 1)
	group.Position = UDim2.new(0, RAIL_MARGIN, 1, -RAIL_MARGIN)
	group.Size = UDim2.fromOffset(CURRENCY_WIDTH, CURRENCY_HEIGHT)
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.ZIndex = 3
	group.Parent = parent
	currencyRail = group

	currencyScale = Instance.new("UIScale")
	currencyScale.Parent = group

	local yenRow, coinBadge = currencyRow(group, "Yen", "coin", UI.color.gold, 0, CURRENCY_DISC)
	yenPunch = Instance.new("UIScale")
	yenPunch.Parent = yenRow

	local yenLabel
	yenLabel, yenSet = UI.ticker(yenRow, "Value", {
		text = "0",
		font = UI.font.display,
		size = 26,
		color = UI.color.gold,
		extent = UDim2.new(1, -CURRENCY_INSET, 1, 0),
		position = UDim2.fromOffset(CURRENCY_INSET, 0),
		zIndex = 5,
	})
	yenLabel.TextTruncate = Enum.TextTruncate.AtEnd
	outlined(yenLabel, 3)

	local stampRow = currencyRow(group, "Stamps", "stamp", UI.color.blush, CURRENCY_DISC + CURRENCY_GAP, CURRENCY_DISC)
	stampLabel = UI.label(stampRow, "Value", {
		text = "0",
		font = UI.font.bold,
		size = 22,
		color = UI.color.inkInverse,
		extent = UDim2.new(1, -CURRENCY_INSET, 1, 0),
		position = UDim2.fromOffset(CURRENCY_INSET, 0),
		zIndex = 5,
	})
	stampLabel.TextTruncate = Enum.TextTruncate.AtEnd
	outlined(stampLabel, 2.5)

	UI.motion.loop(coinBadge, 2.6, { Rotation = 7 })
end

local function buffLabel(boost: any): string
	if boost.skill then
		local skill = Skills.get(boost.skill)
		return if skill then string.upper(string.sub(skill.name, 1, 3)) else "ALL"
	end
	if boost.stat == "yen" then
		return "YEN"
	end
	if boost.stat == Constants.FOOD.AMPLIFIER_STAT then
		return "FOOD"
	end
	return "ALL"
end

local function buffColor(boost: any): Color3
	return (boost.skill and UI.color[boost.skill]) or UI.color.gold
end

local function buildBuffs(parent: Instance)
	buffHolder = Instance.new("ScrollingFrame")
	buffHolder.Name = "Buffs"
	buffHolder.Position = UDim2.fromOffset(RAIL_MARGIN, RAIL_MARGIN)
	buffHolder.Size = UDim2.fromOffset(300, 24)
	buffHolder.BackgroundTransparency = 1
	buffHolder.BorderSizePixel = 0
	buffHolder.AutomaticCanvasSize = Enum.AutomaticSize.X
	buffHolder.CanvasSize = UDim2.fromOffset(0, 0)
	buffHolder.ScrollingDirection = Enum.ScrollingDirection.X
	buffHolder.ScrollBarThickness = 0
	buffHolder.Visible = false
	buffHolder.ZIndex = 4
	buffHolder.Parent = parent

	UI.list(buffHolder, UI.space.tight).FillDirection = Enum.FillDirection.Horizontal
end

local function updateBuffs(boosts: { any }?, foodBuffs: { any }?)
	local now = os.time()
	local active = {}
	local key = ""
	local allBoosts: { any } = boosts or {}
	local allFood: { any } = foodBuffs or {}

	for _, boost in allBoosts do
		if (boost.expiresAt or 0) - now > 0 then
			table.insert(active, { kind = "boost", data = boost })
			key ..= `b_{boost.id};`
		end
	end

	for _, food in allFood do
		local stacks = Boosts.foodStacks(food, now)
		if stacks > 0 then
			table.insert(active, { kind = "food", data = food, stacks = stacks })
			key ..= `f_{food.id}_{stacks};`
		end
	end

	if key ~= buffKey then
		buffKey = key
		buffChips = {}
		for _, child in buffHolder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		for index, item in active do
			local isFood = item.kind == "food"
			local chip = UI.chip(buffHolder, item.data.id, {
				text = "",
				textSize = 11,
				color = isFood and UI.color.leafDeep or buffColor(item.data),
				textColor = UI.readable(if isFood then UI.color.leafDeep else buffColor(item.data)),
				extent = UDim2.fromOffset(if isFood then 122 else 96, 24),
				zIndex = 5,
			})
			chip.LayoutOrder = index
			table.insert(buffChips, chip:FindFirstChild("Text") :: TextLabel)
		end
	end

	for index, label in buffChips do
		local item = active[index]
		if item.kind == "boost" then
			local boost = item.data
			label.Text = `x{boost.multiplier} {buffLabel(boost)} {boost.expiresAt - now}s`
		else
			local food = item.data
			local stacks = item.stacks
			local soonest = 0
			for i = #food.expiries, 1, -1 do
				if food.expiries[i] > now then
					soonest = food.expiries[i]
					break
				end
			end
			label.Text = `+{food.bonus} {buffLabel(food)} x{stacks} · {soonest - now}s`
		end
	end

	buffHolder.Visible = #active > 0
end

type SideRailButton = {
	name: string?,
	glyph: string?,
	emoji: string?,
	activated: () -> (),
}

local function railHeight(count: number, button: number, padding: number): number
	return count * button + math.max(count - 1, 0) * padding
end

local function buildSideRail(parent: Instance, buttons: { SideRailButton })
	sideRail = Instance.new("Frame")
	sideRail.Name = "SideRail"
	sideRail.Size = UDim2.fromOffset(RAIL_BUTTON, railHeight(#buttons, RAIL_BUTTON, UI.space.tight))
	sideRail.BackgroundTransparency = 1
	sideRail.ZIndex = 4
	sideRail.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, UI.space.tight)
	layout.Parent = sideRail

	for index, spec in buttons do
		local button = UI.button(sideRail, spec.name or spec.glyph or "Action", {
			text = "",
			color = UI.color.paper,
			extent = UDim2.fromOffset(RAIL_BUTTON, RAIL_BUTTON),
			radius = UI.radius.pill,
			zIndex = 5,
			onActivated = spec.activated,
		})
		button.LayoutOrder = index
		table.insert(sideRailButtons, button)

		local entrance = Instance.new("UIScale")
		entrance.Scale = 0
		entrance.Parent = button
		task.delay(0.06 * index, function()
			if button.Parent then
				UI.motion.to(entrance, UI.motion.pop, { Scale = 1 })
			end
		end)

		if spec.emoji then
			UI.label(button, "Emoji", {
				text = spec.emoji,
				font = UI.font.bold,
				size = 25,
				align = Enum.TextXAlignment.Center,
				extent = UDim2.fromScale(1, 1),
				zIndex = 6,
			})
		else
			UI.glyph(button, assert(spec.glyph, "Side rail button needs a glyph or emoji"), {
				color = UI.color.ink,
				extent = UDim2.fromOffset(22, 22),
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
				zIndex = 6,
			})
		end
	end
end

local TOAST_GLYPH = {
	unlock = "home",
	locked = "lock",
	travel = "pin",
	info = "leaf",
}

local MAX_TOASTS = 3
local TOAST_LIFETIME = 3.6

type Toast = {
	card: CanvasGroup,
	text: TextLabel,
	channel: string,
	message: string,
	count: number,
	token: number,
	dying: boolean,
}

local toasts: { Toast } = {}
local toastSerial = 0

local function buildToasts(parent: Instance)
	toastHolder = Instance.new("Frame")
	toastHolder.Name = "Toasts"
	toastHolder.AnchorPoint = Vector2.new(0.5, 0)
	toastHolder.Position = UDim2.new(0.5, 0, 0, 18)
	toastHolder.Size = UDim2.fromOffset(420, 260)
	toastHolder.BackgroundTransparency = 1
	toastHolder.ZIndex = 10
	toastHolder.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = toastHolder
end

local function dismissToast(toast: Toast)
	if toast.dying then
		return
	end
	toast.dying = true

	local index = table.find(toasts, toast)
	if index then
		table.remove(toasts, index)
	end

	local out = UI.motion.play(toast.card, UI.motion.wipe, { GroupTransparency = 1 })
	out.Completed:Once(function()
		toast.card:Destroy()
	end)
end

local function armToast(toast: Toast)
	toast.token += 1
	local token = toast.token
	task.delay(TOAST_LIFETIME, function()
		if toast.token == token then
			dismissToast(toast)
		end
	end)
end

local function refreshToast(toast: Toast, message: string)
	toast.count = if toast.message == message then toast.count + 1 else 1
	toast.message = message
	toast.text.Text = if toast.count > 1 then `{message}  x{toast.count}` else message
	armToast(toast)
end

local function showToast(message: string, kind: string, key: string?)
	local channel = key or message

	for _, toast in toasts do
		if toast.channel == channel then
			refreshToast(toast, message)
			return
		end
	end

	while #toasts >= MAX_TOASTS do
		dismissToast(toasts[1])
	end

	local isUnlock = kind == "unlock"
	local fill = UI.fill(if isUnlock then UI.color.leaf else UI.color.paper)
	toastSerial += 1

	local card = Instance.new("CanvasGroup")
	card.Size = UDim2.new(1, 0, 0, 44)
	card.BackgroundColor3 = fill
	card.BackgroundTransparency = 0.02
	card.GroupTransparency = 1
	card.BorderSizePixel = 0
	card.LayoutOrder = toastSerial
	card.ZIndex = 11
	card.Parent = toastHolder
	UI.corner(card, UI.radius.card)
	UI.stroke(card, if isUnlock then UI.color.leafDeep else UI.color.line).Transparency = 0.35

	UI.glyph(card, TOAST_GLYPH[kind] or "leaf", {
		color = if isUnlock then UI.legible(fill) else UI.color.inkSoft,
		extent = UDim2.fromOffset(16, 16),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, 14, 0.5, 0),
		zIndex = 12,
	})

	local text = UI.label(card, "Text", {
		text = message,
		font = if isUnlock then UI.font.bold else UI.font.body,
		size = 13,
		color = UI.legible(fill),
		align = Enum.TextXAlignment.Left,
		wrapped = true,
		extent = UDim2.new(1, -50, 1, 0),
		position = UDim2.fromOffset(38, 0),
		zIndex = 12,
	})

	local toast: Toast = {
		card = card,
		text = text,
		channel = channel,
		message = message,
		count = 1,
		token = 0,
		dying = false,
	}
	table.insert(toasts, toast)

	UI.motion.to(card, UI.motion.settle, { GroupTransparency = 0 })
	armToast(toast)
end

local function gradeProgress(value: any): (number, number)
	local current = math.max(BigNumber.log10(value), 0)
	local lower = 0
	local met = 0

	for order = 1, Certifications.MAX_CANON_ORDER do
		local requirement = BigNumber.log10(BigNumber.coerce(Certifications.requirementForOrder(order)))
		if current < requirement then
			local span = requirement - lower
			if span <= 0 then
				return 1, met
			end
			return math.clamp((current - lower) / span, 0, 1), met
		end
		met += 1
		lower = requirement
	end

	return 1, met
end

local function update(snapshot: any)
	local yenText = if snapshot.unlimitedYen then "∞" else BigNumber.toString(snapshot.yen)
	if snapshot.unlimitedYen then
		yenSet(yenText)
	else
		yenSet(yenText, BigNumber.toNumber(snapshot.yen))
	end

	if yenText ~= lastYen then
		lastYen = yenText
		yenPunch.Scale = 1.12
		UI.motion.to(yenPunch, UI.motion.pop, { Scale = 1 })
	end

	stampLabel.Text = BigNumber.toString(snapshot.stamps)

	updateBuffs(snapshot.boosts, snapshot.foodBuffs)

	local nowActive = snapshot.selectedSkill
	local activeChanged = nowActive ~= activeSkill or snapshot.selectedSkill ~= selectedSkill
	activeSkill = nowActive
	selectedSkill = snapshot.selectedSkill

	for skillId, entry in skillEntries do
		local value = snapshot.skills[skillId]
		local text = if value then BigNumber.toString(value) else "0"
		entry.setValue(text, if value then BigNumber.toNumber(value) else nil)

		local met = 0
		if value then
			local _, bands = gradeProgress(value)
			met = bands
		end

		local tier = (snapshot.trainTier and snapshot.trainTier[skillId]) or 0
		entry.setProgress(WorkOrders.trainProgress(value, tier) / WorkOrders.TRAIN_STEPS)
		entry.setPips(met)

		local order = snapshot.certifications[skillId] or 0
		entry.setGrade(if order > 0 then Certifications.describe(order) else nil)

		if activeChanged then
			entry.setState(skillId == activeSkill, skillId == selectedSkill)
		end
	end

	WorkCore.update(snapshot)
end

local function applyResponsiveLayout()
	local compact = UI.responsive.isCompact(screen.AbsoluteSize)
	compactLayout = compact

	if skillBarHolder then
		SkillBar.setInputMode(InputMode.current())
		SkillBar.setCompact(compact)
	end

	local margin = if compact then RAIL_MARGIN_COMPACT else RAIL_MARGIN
	local scale = if compact then CURRENCY_SCALE_COMPACT else 1
	local top = if compact then RAIL_TOP_OFFSET_COMPACT else RAIL_TOP_OFFSET
	currencyScale.Scale = scale
	currencyRail.Position = UDim2.new(0, margin, 1, -margin)
	buffHolder.Position = UDim2.fromOffset(margin, margin)

	if sideRail then
		local button = if compact then RAIL_BUTTON_COMPACT else RAIL_BUTTON
		local padding = if compact then UI.space.hair else UI.space.tight
		sideRail.Size = UDim2.fromOffset(button, railHeight(#sideRailButtons, button, padding))
		sideRail.Position = UDim2.new(0, margin, 1, -top)

		local layout = sideRail:FindFirstChildWhichIsA("UIListLayout")
		if layout then
			layout.Padding = UDim.new(0, padding)
		end
		for _, rail in sideRailButtons do
			rail.Size = UDim2.fromOffset(button, button)
		end
	end

	toastHolder.Position = UDim2.new(0.5, 0, 0, 8)
	toastHolder.Size = UDim2.fromOffset(
		if compact then math.max(120, math.min(240, screen.AbsoluteSize.X - 408)) else 420,
		180
	)
	WorkCore.setCompact(compact)
	WorkCore.setSuppressed(false)
	OrderTracker.setLayout(compact, margin, top)
	OrderTracker.setSuppressed(compact and tutorialActive)
end

function HUD.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "HUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	buildCurrencyRail(screen)
	buildBuffs(screen)
	buildToasts(screen)

	skillEntries, skillBarHolder = SkillBar.build(screen, function()
		showToast("Eat giant food to train Resilience.", "info")
	end)
	WorkCore.build(screen)
	ControlTutorial.onChanged(function(active)
		tutorialActive = active
		OrderTracker.setSuppressed(compactLayout and tutorialActive)
	end)

	buildSideRail(screen, {
		{
			name = "Farm",
			emoji = "🌸",

			activated = function()
				FarmMenu.toggle()
			end,
		},
		{
			glyph = "platter",

			activated = function()
				InventoryMenu.toggle()
			end,
		},
		{
			glyph = "help",

			activated = function()
				ControlsPanel.setOpen(true)
			end,
		},
	})

	applyResponsiveLayout()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout)
	InputMode.onChanged(applyResponsiveLayout)

	currencyRail.Position += UDim2.fromOffset(0, 18)
	UI.motion.to(currencyRail, UI.motion.settle, {
		GroupTransparency = 0,
		Position = currencyRail.Position - UDim2.fromOffset(0, 18),
	})

	StateController.onChanged(update)

	Remotes.event("Notify", "Message").OnClientEvent:Connect(showToast)
end

return HUD

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local WorkOrders = require(Shared.Modules.Config.WorkOrders)
local UI = require(Shared.UI)
local UIManager = require(script.Parent.UIManager)
local OrderBoard = {}

type Entry = {
	id: string,
	name: string,
	blurb: string,
	summary: string,
	objective: { kind: string, target: string, count: number },
	reward: { [string]: any },
	grade: string?,
	progress: number,
	accepted: boolean,
}

local ROW_HEIGHT = 120
local ROW_PAD = UI.space.base
local ACTION_WIDTH = 116
local ACTION_HEIGHT = 36
local TEXT_INSET = ROW_PAD * 3 + ACTION_WIDTH
local TEMPLATE = "OrderBoard"
local MENU_ID = "order-board"
local screen: ScreenGui
local panel: Frame
local listHolder: ScrollingFrame
local emptyLabel: TextLabel
local setPanelOpen: (boolean, boolean?) -> ()
local closeButton: GuiButton? = nil
local acceptRemote: RemoteEvent
local turnInRemote: RemoteEvent

local function ingredientName(id: string): string
	local definition = Ingredients.get(id)
	return if definition then definition.name else id
end

local function rewardText(reward: { [string]: any }): string
	local parts = {}
	if reward.unlock then
		table.insert(parts, reward.unlock.label)
	end
	if reward.yen then
		table.insert(parts, `{reward.yen} yen`)
	end
	for _, entry in reward.ingredients or {} do
		table.insert(parts, `{entry.count}x {ingredientName(entry.id)}`)
	end
	return table.concat(parts, "  •  ")
end

local function buildRow(entry: Entry, index: number, full: boolean)
	local done = entry.progress >= entry.objective.count
	local surface = if entry.accepted then UI.color.paperDeep else UI.color.paper

	local row = UI.card(listHolder, entry.id, {
		color = surface,
		radius = UI.radius.chip,
	})
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = index

	UI.label(row, "Name", {
		text = entry.name,
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(ROW_PAD, 12),
		extent = UDim2.new(1, -(ROW_PAD * 3 + 64), 0, 24),
	})

	if entry.grade then
		UI.chip(row, "Grade", {
			text = entry.grade,
			color = UI.color.sky,
			extent = UDim2.fromOffset(64, 22),
			position = UDim2.new(1, -(ROW_PAD + 64), 0, 13),
		})
	end

	UI.label(row, "Blurb", {
		text = entry.blurb,
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(ROW_PAD, 40),
		extent = UDim2.new(1, -TEXT_INSET, 0, 32),
	})

	local requirement = if entry.objective.kind == "train"
		then `{entry.summary}  —  {entry.progress}%`
		elseif entry.accepted
			then `{entry.summary}  —  {WorkOrders.formatCount(entry.progress)}/{WorkOrders.formatCount(entry.objective.count)}`
		else entry.summary
	UI.label(row, "Requirement", {
		text = requirement,
		font = UI.font.body,
		size = UI.text.small,
		color = if done then UI.accentInk(surface, UI.color.leafDeep) else UI.color.ink,
		position = UDim2.fromOffset(ROW_PAD, 78),
		extent = UDim2.new(1, -TEXT_INSET, 0, 18),
	})

	UI.label(row, "Reward", {
		text = rewardText(entry.reward),
		font = UI.font.body,
		size = UI.text.caption,
		color = UI.accentInk(surface, UI.color.gold),
		position = UDim2.fromOffset(ROW_PAD, 97),
		extent = UDim2.new(1, -TEXT_INSET, 0, 16),
	})

	local actionExtent = UDim2.fromOffset(ACTION_WIDTH, ACTION_HEIGHT)
	local actionPosition = UDim2.new(1, -(ROW_PAD + ACTION_WIDTH), 1, -(ACTION_HEIGHT + 18))

	if entry.accepted and not done then
		UI.chip(row, "InProgress", {
			text = "In hand",
			color = UI.color.rest,
			extent = actionExtent,
			position = actionPosition,
		})
		return
	end

	if full and not done then
		UI.chip(row, "Full", {
			text = "Hands full",
			color = UI.color.rest,
			extent = actionExtent,
			position = actionPosition,
		})
		return
	end

	UI.button(row, if done then "TurnIn" else "Accept", {
		text = if done then "Hand it in" else "Take it",
		color = if done then UI.color.leafDeep else UI.color.sky,
		extent = actionExtent,
		position = actionPosition,

		onActivated = function()
			if done then
				turnInRemote:FireServer(entry.id)
			else
				acceptRemote:FireServer(entry.id)
			end
		end,
	})
end

local function render(payload: { [string]: any })
	for _, child in listHolder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local entries = payload.orders or {}
	local full = payload.full == true
	emptyLabel.Visible = #entries == 0
	for index, entry in entries do
		buildRow(entry, index, full)
	end
	listHolder.CanvasPosition = Vector2.zero
end

local function buildPanel(parent: ScreenGui)
	if UI.hasTemplate(TEMPLATE) then
		local mounted = UI.template(TEMPLATE, { parent = parent })
		if mounted and mounted:IsA("Frame") then
			panel = mounted
			local holder = panel:FindFirstChild("List", true)
			local empty = panel:FindFirstChild("Empty", true)
			if holder and holder:IsA("ScrollingFrame") and empty and empty:IsA("TextLabel") then
				listHolder = holder
				emptyLabel = empty
				panel.Visible = false

				setPanelOpen = function(open: boolean)
					panel.Visible = open
				end
				closeButton = panel:FindFirstChildWhichIsA("GuiButton", true)
				UIManager.register(MENU_ID, {
					setVisible = setPanelOpen,

					focus = function()
						return closeButton
					end,
					dismissible = true,
					kind = "ordinary",
				})
				return
			end
			warn(`[OrderBoard] template "{TEMPLATE}" is missing a List or Empty child; using the built panel`)
			mounted:Destroy()
		end
	end

	local _scrim, content, toggle = UI.modal(parent, "OrderBoard", {
		extent = UDim2.new(0, 560, 0.78, 0),
		maxSize = Vector2.new(720, 680),
		zIndex = 20,

		onDismiss = function()
			OrderBoard.setOpen(false)
		end,
	})
	panel = content
	setPanelOpen = toggle

	UI.padding(panel, UI.space.loose)

	UI.label(panel, "Title", {
		text = "Work Orders",
		font = UI.font.display,
		size = UI.text.title,
		extent = UDim2.new(1, 0, 0, 30),
	})

	UI.label(panel, "Subtitle", {
		text = `Yoroi-san has jobs. Up to {WorkOrders.MAX_ACTIVE} at a time, and no overtime is expected of you.`,
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
	UI.padding(listHolder, UI.strokeClearance, { right = 14 })

	emptyLabel = UI.label(panel, "Empty", {
		text = "Yoroi-san has nothing on the counter. Try again in a moment.",
		font = UI.font.light,
		size = UI.text.body,
		color = UI.color.inkFaint,
		position = UDim2.fromOffset(0, 120),
		extent = UDim2.new(1, 0, 0, 24),
	})
	emptyLabel.Visible = false

	closeButton = UI.button(panel, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(120, 44),
		position = UDim2.new(0.5, -60, 1, -44),
		zIndex = panel.ZIndex + 1,

		onActivated = function()
			OrderBoard.setOpen(false)
		end,
	})

	UIManager.register(MENU_ID, {
		setVisible = setPanelOpen,

		focus = function()
			return closeButton
		end,
		dismissible = true,
		kind = "ordinary",
	})
end

function OrderBoard.setOpen(open: boolean)
	if open then
		UIManager.open(MENU_ID)
	else
		UIManager.close(MENU_ID)
	end
end

function OrderBoard.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "OrderBoard"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 6
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	buildPanel(screen)

	acceptRemote = Remotes.event("Order", "Accept")
	turnInRemote = Remotes.event("Order", "TurnIn")

	Remotes.event("Order", "Open").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		render(payload)
		OrderBoard.setOpen(true)
	end)

	Remotes.event("Order", "Event").OnClientEvent:Connect(function(kind, payload)
		if kind == "board" and type(payload) == "table" and UIManager.isOpen(MENU_ID) then
			render(payload)
		end
	end)
end

return OrderBoard

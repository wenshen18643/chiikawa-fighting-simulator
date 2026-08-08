local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local UIManager = require(script.Parent.UIManager)
local CompanionMenu = {}
local MENU_ID = "companion"

type Entry = { id: string, name: string, blurb: string }

local ROW_HEIGHT = 62
local screen: ScreenGui
local panel: Frame
local listHolder: ScrollingFrame
local setPanelOpen: (boolean, boolean?) -> ()
local closeButton: TextButton
local selectRemote: RemoteEvent

local function buildRow(entry: Entry, index: number, isSelected: boolean)
	local row = UI.card(listHolder, entry.id, {
		color = if isSelected then UI.color.paperDeep else UI.color.paper,
		radius = UI.radius.chip,
	})
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = index

	UI.label(row, "Name", {
		text = entry.name,
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(UI.space.base, UI.space.tight),
		extent = UDim2.new(1, -140, 0, 24),
	})

	UI.label(row, "Blurb", {
		text = entry.blurb,
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(UI.space.base, UI.space.tight + 26),
		extent = UDim2.new(1, -140, 0, 20),
	})

	if isSelected then
		local chip = UI.chip(row, "Current", {
			text = "Following",
			color = UI.color.leafDeep,
			textColor = UI.readable(UI.color.leafDeep),
			extent = UDim2.fromOffset(104, 30),
			position = UDim2.new(1, -116, 0.5, -15),
		})
		chip.AnchorPoint = Vector2.new(0, 0)
		return
	end

	UI.button(row, "Choose", {
		text = "Choose",
		color = UI.color.sky,
		textColor = UI.color.paperDeep,
		extent = UDim2.fromOffset(104, 30),
		position = UDim2.new(1, -116, 0.5, -15),

		onActivated = function()
			selectRemote:FireServer(entry.id)
			CompanionMenu.setOpen(false)
		end,
	})
end

local function render(entries: { Entry }, current: string?)
	for _, child in listHolder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for index, entry in entries do
		buildRow(entry, index, entry.id == current)
	end

	listHolder.CanvasPosition = Vector2.zero
end

local function buildPanel(parent: ScreenGui)
	local scrim, content, toggle = UI.modal(parent, "CompanionMenu", {
		extent = UDim2.new(0, 540, 0.82, 0),
		zIndex = 20,

		onDismiss = function()
			CompanionMenu.setOpen(false)
		end,
	})
	panel = content
	setPanelOpen = toggle

	UI.padding(panel, UI.space.loose)

	UI.label(panel, "Title", {
		text = "Who is coming with you?",
		font = UI.font.display,
		size = UI.text.title,
		extent = UDim2.new(1, 0, 0, 30),
	})

	UI.label(panel, "Subtitle", {
		text = "They will follow you anywhere. Change your mind any time.",
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

	closeButton = UI.button(panel, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(120, 44),
		position = UDim2.new(0.5, -60, 1, -44),

		onActivated = function()
			CompanionMenu.setOpen(false)
		end,
	})

	scrim.Visible = false
	UIManager.register(MENU_ID, {
		setVisible = function(open, instant)
			setPanelOpen(open, instant)
		end,

		focus = function()
			return closeButton
		end,
	})
end

function CompanionMenu.setOpen(open: boolean)
	if open then
		UIManager.open(MENU_ID)
	else
		UIManager.close(MENU_ID)
	end
end

function CompanionMenu.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "CompanionMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 6
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	buildPanel(screen)

	selectRemote = Remotes.event("Companion", "Select")

	Remotes.event("Companion", "Open").OnClientEvent:Connect(function(entries, current)
		if type(entries) ~= "table" then
			return
		end
		render(entries, current)
		CompanionMenu.setOpen(true)
	end)
end

return CompanionMenu

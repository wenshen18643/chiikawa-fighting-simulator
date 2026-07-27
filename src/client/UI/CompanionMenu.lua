--[[
	The friend picker, opened by pressing E at the stand in town.

	--------------------------------------------------------------------------
	THE SERVER DECIDES WHAT IS IN IT
	--------------------------------------------------------------------------

	The roster arrives with the open message rather than being read from the
	shared config here. Which companions exist is a runtime fact -- an uploaded
	model can fail to download and its row must simply not be there -- and the
	server is the only side that knows. This module renders a list and sends
	back an id; it has no opinion about what is on it.

	Built and thrown away per open. The list is small, opening is a deliberate
	act at a physical object, and rebuilding costs a handful of frames' worth of
	instances -- much cheaper than keeping a stale roster around and having to
	reconcile it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)

local CompanionMenu = {}

type Entry = { id: string, name: string, blurb: string }

local ROW_HEIGHT = 62

local screen: ScreenGui
local panel: Frame
local listHolder: ScrollingFrame
local setOpen: (boolean) -> ()
local selectRemote: RemoteEvent
local selected: string?

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

--[[
	One companion.

	The current pick is marked rather than removed, so the menu answers "who is
	following me" as well as "who could be" -- which is the question you
	actually walked over to the stand with.
]]
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
			textColor = UI.color.white,
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
			--[[
				Fire and close. The server owns the outcome and says so with a
				toast, so waiting here for a confirmation would add a second of
				dead menu to a decision the player has already made.
			]]
			selectRemote:FireServer(entry.id)
			setOpen(false)
		end,
	})
end

local function render(entries: { Entry }, current: string?)
	selected = current

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

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function buildPanel(parent: ScreenGui)
	--[[
		Tall enough for six rows before scrolling, capped by scale so it does
		not overrun a phone screen: on a short viewport the panel shrinks and
		the list keeps scrolling, rather than the buttons falling off the bottom.
	]]
	local scrim, content, toggle = UI.modal(parent, "CompanionMenu", {
		extent = UDim2.new(0, 540, 0.82, 0),
		zIndex = 20,
	})
	panel = content
	setOpen = toggle

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

	--[[
		The roster is longer than the panel and always will be -- mascots and
		uploads both keep arriving -- so the list scrolls.

		AutomaticCanvasSize rather than a computed CanvasSize: the first version
		set the canvas from the row count and row height, which is the same
		number written twice and silently wrong the moment a row is a different
		size. The scrollbar is also deliberately fat and light: at four pixels
		of inkFaint it was invisible against the panel, and a list that scrolls
		without looking like it scrolls reads as a list of four companions.
	]]
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

	-- The bar sits inside the frame, so rows stop short of it rather than
	-- running underneath.
	UI.padding(listHolder, 0, { right = 14 })

	UI.button(panel, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(120, 34),
		position = UDim2.new(0.5, -60, 1, -34),
		onActivated = function()
			setOpen(false)
		end,
	})

	-- The scrim swallows world input while it is up, so the panel must never be
	-- left visible across a respawn.
	scrim.Visible = false
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

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
		setOpen(true)
	end)
end

-- Exposed for the same reason ControlsPanel exposes its toggle: so a later
-- keybind or HUD button can open this without re-triggering the prompt.
function CompanionMenu.setOpen(open: boolean)
	if setOpen then
		setOpen(open)
	end
end

function CompanionMenu.current(): string?
	return selected
end

return CompanionMenu

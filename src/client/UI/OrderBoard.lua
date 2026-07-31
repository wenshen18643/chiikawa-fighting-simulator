--[[
	Yoroi-san's counter, opened by the prompt at the job booth.

	--------------------------------------------------------------------------
	THE SERVER DECIDES WHAT IS ON IT
	--------------------------------------------------------------------------

	The board arrives with the open message. Which orders a player may take is
	a fact about their profile and the day's date, and only the server holds
	both -- so this module renders rows and sends back an id, exactly as
	CompanionMenu does with the roster. It has no opinion about what is on it,
	and it cannot invent an order that was not offered.

	Rebuilt per open rather than kept and reconciled. The board is at most three
	rows, opening it is a deliberate walk across town, and a stale board that
	quietly disagrees with the server is worse than a handful of instances.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)

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

local ROW_HEIGHT = 108
local TEMPLATE = "OrderBoard"

local screen: ScreenGui
local panel: Frame
local listHolder: ScrollingFrame
local emptyLabel: TextLabel
local setOpen: (boolean) -> ()
local acceptRemote: RemoteEvent
local turnInRemote: RemoteEvent

--------------------------------------------------------------------------------
-- Reward copy
--------------------------------------------------------------------------------

--[[
	One line, in the order a player cares about: the thing money cannot buy
	first, then the money. An unlock is the reason to take the job; the yen is
	why it is a job.
]]
local function rewardText(reward: { [string]: any }): string
	local parts = {}
	if reward.unlock then
		table.insert(parts, reward.unlock.label)
	end
	if reward.yen then
		table.insert(parts, `{reward.yen} yen`)
	end
	if reward.skill and reward.skillAmount then
		table.insert(parts, `{reward.skillAmount} {reward.skill}`)
	end
	for _, entry in reward.ingredients or {} do
		table.insert(parts, `{entry.count}x {entry.id}`)
	end
	return table.concat(parts, "  •  ")
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local function buildRow(entry: Entry, index: number)
	local done = entry.progress >= entry.objective.count

	local row = UI.card(listHolder, entry.id, {
		color = if entry.accepted then UI.color.paperDeep else UI.color.paper,
		radius = UI.radius.chip,
	})
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = index

	UI.label(row, "Name", {
		text = entry.name,
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(UI.space.base, UI.space.snug),
		extent = UDim2.new(1, -160, 0, 26),
	})

	--[[
		The grade, where the chain would show nothing. It is the only number on
		the row that says how far the player has come, and a rank badge next to
		the job is how Yoroi-san's booth reads in the first place.
	]]
	if entry.grade then
		UI.chip(row, "Grade", {
			text = entry.grade,
			color = UI.color.sky,
			textColor = UI.color.paperDeep,
			extent = UDim2.fromOffset(64, 22),
			position = UDim2.new(1, -80, 0, UI.space.snug),
		})
	end

	UI.label(row, "Blurb", {
		text = entry.blurb,
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(UI.space.base, UI.space.snug + 28),
		extent = UDim2.new(1, -UI.space.base * 2, 0, 34),
	})

	--[[
		Progress is shown ONLY once the order is taken. On an offer it would be
		a row of zeroes that reads as a requirement the player has failed.
	]]
	local requirement = if entry.accepted
		then `{entry.summary}  —  {entry.progress}/{entry.objective.count}`
		else entry.summary
	UI.label(row, "Requirement", {
		text = requirement,
		font = UI.font.body,
		size = UI.text.small,
		color = if done then UI.color.leaf else UI.color.ink,
		position = UDim2.fromOffset(UI.space.base, ROW_HEIGHT - 32),
		extent = UDim2.new(0.55, 0, 0, 20),
	})

	UI.label(row, "Reward", {
		text = rewardText(entry.reward),
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.gold,
		position = UDim2.fromOffset(UI.space.base, ROW_HEIGHT - 14),
		extent = UDim2.new(0.7, 0, 0, 14),
	})

	if entry.accepted and not done then
		UI.chip(row, "InProgress", {
			text = "In hand",
			color = UI.color.rest,
			textColor = UI.color.paperDeep,
			extent = UDim2.fromOffset(112, 32),
			position = UDim2.new(1, -128, 1, -46),
		})
		return
	end

	UI.button(row, if done then "TurnIn" else "Accept", {
		text = if done then "Hand it in" else "Take it",
		color = if done then UI.color.leafDeep else UI.color.sky,
		textColor = UI.color.paperDeep,
		extent = UDim2.fromOffset(112, 32),
		position = UDim2.new(1, -128, 1, -46),
		onActivated = function()
			--[[
				Fire and close. The server owns the outcome and toasts it, so
				sitting here waiting for a confirmation would add a second of
				dead menu to a decision already made.
			]]
			if done then
				turnInRemote:FireServer(entry.id)
			else
				acceptRemote:FireServer(entry.id)
			end
			setOpen(false)
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
	emptyLabel.Visible = #entries == 0
	for index, entry in entries do
		buildRow(entry, index)
	end
	listHolder.CanvasPosition = Vector2.zero
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function buildPanel(parent: ScreenGui)
	--[[
		A Studio-authored template wins if one has been exported; otherwise this
		builds the same shape in code so the board works from the first run.
		Swapping in a designed panel later means dropping the model into
		assets/UI and changing nothing here.
	]]
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
				setOpen = function(open: boolean)
					panel.Visible = open
				end
				return
			end
			warn(`[OrderBoard] template "{TEMPLATE}" is missing a List or Empty child; using the built panel`)
			mounted:Destroy()
		end
	end

	local _scrim, content, toggle = UI.modal(parent, "OrderBoard", {
		extent = UDim2.new(0, 560, 0.78, 0),
		zIndex = 20,
	})
	panel = content
	setOpen = toggle

	UI.padding(panel, UI.space.loose)

	UI.label(panel, "Title", {
		text = "Work Orders",
		font = UI.font.display,
		size = UI.text.title,
		extent = UDim2.new(1, 0, 0, 30),
	})

	UI.label(panel, "Subtitle", {
		text = "Yoroi-san has jobs. One at a time, and no overtime is expected of you.",
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

	--[[
		The booth never actually runs dry -- the ledger past the chain is
		generated and has no last rung -- so this is a fault message, not a
		state the game reaches on its own.
	]]
	emptyLabel = UI.label(panel, "Empty", {
		text = "Yoroi-san has nothing on the counter. Try again in a moment.",
		font = UI.font.light,
		size = UI.text.body,
		color = UI.color.inkFaint,
		position = UDim2.fromOffset(0, 120),
		extent = UDim2.new(1, 0, 0, 24),
	})
	emptyLabel.Visible = false

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

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

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
		setOpen(true)
	end)

	--[[
		A board refresh while the panel is shut is not an invitation to open it.
		The server sends one after every accept and turn-in so the next open is
		already correct; opening on it would put a menu in front of somebody who
		is halfway down a cave.
	]]
	Remotes.event("Order", "Event").OnClientEvent:Connect(function(kind, payload)
		if kind == "board" and type(payload) == "table" then
			render(payload)
		end
	end)
end

function OrderBoard.setOpen(open: boolean)
	if setOpen then
		setOpen(open)
	end
end

return OrderBoard

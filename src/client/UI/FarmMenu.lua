--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Farming = require(Shared.Modules.Config.Farming)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)

local StateController = require(script.Parent.Parent.Controllers.StateController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)

type CropSnapshot = {
	id: string,
	plantedAt: number,
	maturesAt: number,
}

type PlotSnapshot = {
	plotId: number,
	ownerUserId: number?,
	ownerName: string?,
	leaseEndsAt: number?,
	crop: CropSnapshot?,
	highestBid: number?,
	highestBidderUserId: number?,
	highestBidderName: string?,
	minimumBid: number,
	serverNow: number,
}

local FarmMenu = {}

local screen: ScreenGui
local panel: Frame
local body: ScrollingFrame
local titleLabel: TextLabel
local leaseLabel: TextLabel
local cropClockLabel: TextLabel
local inventoryLabel: TextLabel
local setPanelOpen: (boolean) -> ()
local selected: PlotSnapshot? = nil
local usageCount = 0
local isOpen = false
local pendingLateCrop: string? = nil

local rentRemote: RemoteEvent
local bidRemote: RemoteEvent
local plantRemote: RemoteEvent
local harvestRemote: RemoteEvent

local function clockText(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
end

local function ingredientCount(cropId: string): number
	local snapshot = StateController.snapshot
	return if snapshot and snapshot.ingredients then snapshot.ingredients[cropId] or 0 else 0
end

local function clearBody()
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function card(height: number): Frame
	local result = UI.card(body, "Section", { radius = UI.radius.chip })
	result.Size = UDim2.new(1, -4, 0, height)
	return result
end

local function sectionTitle(parent: Instance, text: string)
	UI.label(parent, "Heading", {
		text = text,
		font = UI.font.display,
		size = UI.text.body,
		position = UDim2.fromOffset(14, 10),
		extent = UDim2.new(1, -28, 0, 24),
		zIndex = 26,
	})
end

local function updateLiveLabels()
	local snapshot = selected
	if not snapshot then
		return
	end
	local atTime = os.time()
	if snapshot.leaseEndsAt then
		leaseLabel.Text = string.format("Lease remaining: %s", clockText(snapshot.leaseEndsAt - atTime))
	else
		leaseLabel.Text = "Available now · 10-minute lease"
	end

	if snapshot.crop and cropClockLabel then
		local elapsed = atTime - snapshot.crop.plantedAt
		local currentYield = Farming.yieldForElapsed(elapsed)
		local finalElapsed = if snapshot.leaseEndsAt then snapshot.leaseEndsAt - snapshot.crop.plantedAt else elapsed
		local finalYield = Farming.yieldForElapsed(finalElapsed)
		if elapsed >= Farming.MATURE_SECONDS then
			cropClockLabel.Text = string.format("Mature · harvest 13 now · lease settlement %d", finalYield)
		else
			cropClockLabel.Text = string.format(
				"Growing %s · current settlement %d · lease settlement %d",
				clockText(Farming.MATURE_SECONDS - elapsed),
				currentYield,
				finalYield
			)
		end
	end

	if inventoryLabel then
		inventoryLabel.Text = string.format(
			"Seeds on hand  ·  Carrot %d  ·  Potato %d  ·  Rice %d",
			ingredientCount("carrot"),
			ingredientCount("potato"),
			ingredientCount("rice")
		)
	end
end

local render: () -> ()

local function buildSummary(snapshot: PlotSnapshot)
	local summary = card(158)
	sectionTitle(summary, "LEASE STATUS")
	local owner = snapshot.ownerName or "No renter"
	UI.label(summary, "Owner", {
		text = string.format("Renter: %s", owner),
		font = UI.font.bold,
		size = UI.text.body,
		position = UDim2.fromOffset(14, 40),
		extent = UDim2.new(1, -28, 0, 22),
		zIndex = 26,
	})
	leaseLabel = UI.label(summary, "Lease", {
		text = "",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 66),
		extent = UDim2.new(1, -28, 0, 20),
		zIndex = 26,
	})
	local bidText = if snapshot.highestBid and snapshot.highestBidderName
		then string.format("Next lease: %s leads at Yen %d", snapshot.highestBidderName, snapshot.highestBid)
		else "Next lease: no bids yet"
	UI.label(summary, "Auction", {
		text = bidText,
		font = UI.font.bold,
		size = UI.text.small,
		color = UI.color.gold,
		position = UDim2.fromOffset(14, 92),
		extent = UDim2.new(1, -28, 0, 20),
		zIndex = 26,
	})
	UI.label(summary, "Usage", {
		text = string.format("Your active leases + leading bids: %d / %d", usageCount, Farming.MAX_POSITIONS_PER_USER),
		font = UI.font.body,
		size = UI.text.small,
		color = if usageCount >= Farming.MAX_POSITIONS_PER_USER then UI.color.tobatsu else UI.color.inkSoft,
		position = UDim2.fromOffset(14, 120),
		extent = UDim2.new(1, -28, 0, 20),
		zIndex = 26,
	})
end

local function buildRent(snapshot: PlotSnapshot)
	local action = card(94)
	sectionTitle(action, "RENT THIS PLOT")
	UI.label(action, "Terms", {
		text = "Yen 20 · one 10-minute lease",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 42),
		extent = UDim2.new(1, -170, 0, 32),
		zIndex = 26,
	})
	UI.button(action, "Rent", {
		text = "Rent · Yen 20",
		color = UI.color.leafDeep,
		position = UDim2.new(1, -154, 0, 40),
		extent = UDim2.fromOffset(140, 40),
		zIndex = 27,
		onActivated = function()
			rentRemote:FireServer(snapshot.plotId)
		end,
	})
end

local function buildBid(snapshot: PlotSnapshot)
	local auction = card(154)
	sectionTitle(auction, "BID FOR THE NEXT LEASE")
	local minimum = snapshot.minimumBid
	local capped = minimum > Farming.MAX_BID

	local input = Instance.new("TextBox")
	input.Name = "BidAmount"
	input.BackgroundColor3 = UI.color.paperDeep
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Font = UI.font.bold
	input.PlaceholderText = "Whole Yen"
	input.Text = if capped then "10000" else tostring(minimum)
	input.TextColor3 = UI.color.white
	input.TextSize = UI.text.body
	input.Position = UDim2.fromOffset(14, 42)
	input.Size = UDim2.new(1, -168, 0, 40)
	input.ZIndex = 27
	input.Parent = auction
	UI.corner(input, UI.radius.chip)
	UI.stroke(input, UI.color.line, 2)

	local function amount(): number
		local parsed = tonumber(input.Text)
		if not parsed then
			return minimum
		end
		return math.clamp(math.floor(parsed), math.min(minimum, Farming.MAX_BID), Farming.MAX_BID)
	end

	UI.button(auction, "Submit", {
		text = if capped then "Capped" else "Place bid",
		color = if capped then UI.color.paperDeep else UI.color.gold,
		textColor = if capped then UI.color.inkFaint else UI.color.line,
		position = UDim2.new(1, -144, 0, 42),
		extent = UDim2.fromOffset(130, 40),
		zIndex = 27,
		onActivated = function()
			if not capped then
				bidRemote:FireServer(snapshot.plotId, amount())
			end
		end,
	})

	for index, increment in { 10, 100, 1000 } do
		UI.button(auction, `Plus{increment}`, {
			text = `+{increment}`,
			position = UDim2.new((index - 1) / 3, 14 - (index - 1) * 4, 0, 94),
			extent = UDim2.new(1 / 3, -14, 0, 38),
			zIndex = 27,
			onActivated = function()
				input.Text = tostring(math.clamp(amount() + increment, math.min(minimum, Farming.MAX_BID), Farming.MAX_BID))
			end,
		})
	end
end

local function requestPlant(snapshot: PlotSnapshot, cropId: string)
	local leaseEndsAt = snapshot.leaseEndsAt or os.time()
	local remaining = leaseEndsAt - os.time()
	if remaining < Farming.MATURE_SECONDS and pendingLateCrop ~= cropId then
		pendingLateCrop = cropId
		render()
		return
	end
	pendingLateCrop = nil
	plantRemote:FireServer(snapshot.plotId, cropId)
end

local function buildPlant(snapshot: PlotSnapshot)
	local crops = card(226)
	sectionTitle(crops, "PLANT A CROP")
	inventoryLabel = UI.label(crops, "Inventory", {
		text = "",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 38),
		extent = UDim2.new(1, -28, 0, 22),
		zIndex = 26,
	})

	for index, cropId in Farming.CROP_IDS do
		local definition = Ingredients.get(cropId)
		local owned = ingredientCount(cropId)
		local y = 68 + (index - 1) * 48
		UI.label(crops, cropId, {
			text = string.format(
				"%s  ·  use %d  ·  have %d",
				if definition then definition.name else cropId,
				Farming.SEED_COST,
				owned
			),
			font = UI.font.bold,
			size = UI.text.small,
			position = UDim2.fromOffset(14, y + 8),
			extent = UDim2.new(1, -172, 0, 24),
			zIndex = 26,
		})
		local isConfirmation = pendingLateCrop == cropId
		local guaranteed = Farming.yieldForElapsed((snapshot.leaseEndsAt or os.time()) - os.time())
		UI.button(crops, `Plant{cropId}`, {
			text = if isConfirmation then string.format("Confirm · get %d", guaranteed) else "Plant",
			color = if owned >= Farming.SEED_COST then UI.color.leafDeep else UI.color.paperDeep,
			textColor = if owned >= Farming.SEED_COST then UI.color.white else UI.color.inkFaint,
			position = UDim2.new(1, -146, 0, y),
			extent = UDim2.fromOffset(132, 38),
			zIndex = 27,
			onActivated = function()
				if owned >= Farming.SEED_COST then
					requestPlant(snapshot, cropId)
				end
			end,
		})
	end
end

local function buildCrop(snapshot: PlotSnapshot, crop: CropSnapshot)
	local section = card(124)
	sectionTitle(section, string.upper(crop.id))
	cropClockLabel = UI.label(section, "CropStatus", {
		text = "",
		font = UI.font.bold,
		size = UI.text.small,
		color = UI.color.leaf,
		position = UDim2.fromOffset(14, 42),
		extent = UDim2.new(1, -28, 0, 28),
		zIndex = 26,
	})
	if os.time() >= crop.maturesAt then
		UI.button(section, "Harvest", {
			text = "Harvest 13",
			color = UI.color.leafDeep,
			position = UDim2.fromOffset(14, 78),
			extent = UDim2.new(1, -28, 0, 38),
			zIndex = 27,
			onActivated = function()
				harvestRemote:FireServer(snapshot.plotId)
			end,
		})
	end
end

render = function()
	local snapshot = selected
	if not snapshot or not body then
		return
	end
	clearBody()
	titleLabel.Text = string.format("FARM PLOT %02d", snapshot.plotId)
	leaseLabel = nil :: any
	cropClockLabel = nil :: any
	inventoryLabel = nil :: any
	buildSummary(snapshot)

	if not snapshot.ownerUserId then
		buildRent(snapshot)
	else
		buildBid(snapshot)
		if snapshot.ownerUserId == Players.LocalPlayer.UserId then
			if snapshot.crop then
				buildCrop(snapshot, snapshot.crop)
			else
				buildPlant(snapshot)
			end
		end
	end
	updateLiveLabels()
end

local function buildPanel(parent: ScreenGui)
	local scrim, content, toggle = UI.modal(parent, "FarmMenu", {
		extent = UDim2.new(0.9, 0, 0.84, 0),
		zIndex = 24,
		onToggled = function(open)
			isOpen = open
			WorkController.setInputLocked("farm-menu", open)
			if not open then
				selected = nil
				pendingLateCrop = nil
			end
		end,
	})
	panel = content
	setPanelOpen = toggle
	scrim.Visible = false
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(330, 420)
	constraint.MaxSize = Vector2.new(620, 760)
	constraint.Parent = panel

	titleLabel = UI.label(panel, "Title", {
		text = "FARM PLOT",
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(20, 16),
		extent = UDim2.new(1, -90, 0, 34),
		zIndex = 26,
	})
	UI.button(panel, "Close", {
		text = "X",
		color = UI.color.paperDeep,
		position = UDim2.new(1, -54, 0, 14),
		extent = UDim2.fromOffset(40, 36),
		zIndex = 27,
		onActivated = function()
			setPanelOpen(false)
		end,
	})

	body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(16, 60)
	body.Size = UDim2.new(1, -32, 1, -76)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = UI.color.inkFaint
	body.ZIndex = 25
	body.Parent = panel
	UI.padding(body, 4)
	UI.list(body, UI.space.snug)
end

function FarmMenu.init()
	if screen then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "FarmMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screen = gui

	rentRemote = Remotes.event("Farm", "Rent")
	bidRemote = Remotes.event("Farm", "Bid")
	plantRemote = Remotes.event("Farm", "Plant")
	harvestRemote = Remotes.event("Farm", "Harvest")
	buildPanel(gui)

	Remotes.event("Farm", "Open").OnClientEvent:Connect(function(snapshot: PlotSnapshot, count: number)
		selected = snapshot
		usageCount = count
		pendingLateCrop = nil
		render()
		setPanelOpen(true)
	end)
	Remotes.event("Farm", "State").OnClientEvent:Connect(function(snapshot: PlotSnapshot, count: number)
		usageCount = count
		if selected then
			if selected.plotId == snapshot.plotId then
				selected = snapshot
			end
			pendingLateCrop = nil
			if isOpen then
				render()
			end
		end
	end)
	StateController.onChanged(function()
		if isOpen then
			updateLiveLabels()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if isOpen then
				updateLiveLabels()
			end
		end
	end)
end

return FarmMenu

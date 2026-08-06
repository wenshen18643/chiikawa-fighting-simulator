--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Farming = require(Shared.Modules.Config.Farming)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)
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

type Page = "grid" | "detail"

local FarmMenu = {}
local ACTION_NAME = "ToggleFarmMenu"
local SOIL = Color3.fromRGB(102, 72, 51)
local WOOD = Color3.fromRGB(176, 132, 86)
local AISLE = Color3.fromRGB(224, 205, 165)
local screen: ScreenGui
local panel: Frame
local contentHost: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local backButton: TextButton
local setPanelOpen: (boolean) -> ()
local snapshots: { [number]: PlotSnapshot } = {}
local receivedPlots: { [number]: boolean } = {}
local receivedCount = 0
local usageCount = 0
local page: Page = "grid"
local selectedPlotId: number? = nil
local isOpen = false
local pendingLateCrop: string? = nil
local lastNear = false
local lastCropReady = false
local gridRenderQueued = false
local leaseLabel: TextLabel? = nil
local cropClockLabel: TextLabel? = nil
local proximityLabel: TextLabel? = nil
local inventoryLabel: TextLabel? = nil
local usageLabel: TextLabel? = nil
local rentRemote: RemoteEvent
local bidRemote: RemoteEvent
local plantRemote: RemoteEvent
local harvestRemote: RemoteEvent
local requestStateRemote: RemoteEvent
local teleportRemote: RemoteEvent

local function clockText(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
end

local function ingredientCount(cropId: string): number
	local snapshot = StateController.getSnapshot()
	return if snapshot and snapshot.ingredients then snapshot.ingredients[cropId] or 0 else 0
end

local function clearContent()
	for _, child in contentHost:GetChildren() do
		child:Destroy()
	end
	leaseLabel = nil
	cropClockLabel = nil
	proximityLabel = nil
	inventoryLabel = nil
	usageLabel = nil
end

local function selectedSnapshot(): PlotSnapshot?
	return if selectedPlotId then snapshots[selectedPlotId] else nil
end

local function isNearPlot(plotId: number): boolean
	local area = Areas.get(Areas.STARTING_AREA)
	local plotCFrame = area and Layout.farmPlotCFrame(area, plotId)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plotCFrame or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - plotCFrame.Position).Magnitude <= Farming.INTERACTION_DISTANCE + 3
end

local function makeScrollingBody(): ScrollingFrame
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.fromScale(1, 1)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = UI.color.inkFaint
	body.ZIndex = 25
	body.Parent = contentHost
	UI.padding(body, 4, { right = 10 })
	UI.list(body, UI.space.snug)
	return body
end

local function card(parent: Instance, height: number): Frame
	local result = UI.card(parent, "Section", { radius = UI.radius.chip, zIndex = 26 })
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
		zIndex = 28,
	})
end

local function plotTileCopy(snapshot: PlotSnapshot?): (string, string)
	if not snapshot then
		return "SYNCING", "Waiting for state"
	end
	local localUserId = Players.LocalPlayer.UserId
	if not snapshot.ownerUserId then
		return "VACANT", string.format("Rent ¥%d", Farming.RENT_PRICE)
	end
	local state = if snapshot.ownerUserId == localUserId
		then "YOURS"
		elseif snapshot.highestBidderUserId == localUserId then "LEADING"
		else "LEASED"
	local bid = if snapshot.highestBid then string.format("Next ¥%d", snapshot.highestBid) else "No next bid"
	return state, bid
end

local function plotTileColor(snapshot: PlotSnapshot?): Color3
	if not snapshot then
		return UI.color.paperSunken
	end
	local localUserId = Players.LocalPlayer.UserId
	if snapshot.ownerUserId == localUserId then
		return UI.color.leafDeep
	elseif snapshot.highestBidderUserId == localUserId then
		return UI.color.gold
	elseif not snapshot.ownerUserId then
		return WOOD
	end
	return SOIL
end

local render: (boolean?) -> ()

local function renderGrid(shouldFocus: boolean?)
	local body = makeScrollingBody()
	local statusText = if receivedCount >= Farming.PLOT_COUNT
		then "Choose a plot to rent, bid, or manage."
		else string.format("Syncing plots… %d / %d", receivedCount, Farming.PLOT_COUNT)
	UI.label(body, "Guide", {
		text = statusText,
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -4, 0, 28),
		zIndex = 26,
	})

	local field = UI.card(body, "Field", {
		color = AISLE,
		radius = UI.radius.tile,
		strokeColor = WOOD,
		zIndex = 26,
		sheen = false,
		innerLine = false,
	})
	field.Size = UDim2.new(1, -4, 0, 476)
	UI.padding(field, 10)

	local grid = Instance.new("Frame")
	grid.Name = "Plots"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 1)
	grid.ZIndex = 27
	grid.Parent = field

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / Farming.COLUMNS, -6, 0, 84)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.FillDirectionMaxCells = Farming.COLUMNS
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local firstButton: TextButton? = nil
	for plotId = 1, Farming.PLOT_COUNT do
		local snapshot = snapshots[plotId]
		local tileColor = plotTileColor(snapshot)
		local stateText, bidText = plotTileCopy(snapshot)
		local textColor = UI.readable(tileColor)
		local tile = Instance.new("TextButton")
		tile.Name = `Plot_{plotId}`
		tile.LayoutOrder = plotId
		tile.BackgroundColor3 = tileColor
		tile.BorderSizePixel = 0
		tile.AutoButtonColor = false
		tile.Text = ""
		tile.Selectable = snapshot ~= nil
		tile:SetAttribute("FarmPlotId", plotId)
		tile.ZIndex = 28
		tile.Parent = grid
		UI.corner(tile, UI.radius.chip)
		local outline = if snapshot and snapshot.highestBidderUserId == Players.LocalPlayer.UserId
			then UI.color.gold
			else WOOD
		UI.stroke(tile, outline, 3)

		UI.label(tile, "Number", {
			text = string.format("PLOT %02d", plotId),
			font = UI.font.display,
			size = 15,
			color = textColor,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(6, 8),
			extent = UDim2.new(1, -12, 0, 21),
			zIndex = 29,
		})
		UI.label(tile, "State", {
			text = stateText,
			font = UI.font.bold,
			size = 11,
			color = textColor,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(6, 34),
			extent = UDim2.new(1, -12, 0, 16),
			zIndex = 29,
		})
		UI.label(tile, "Bid", {
			text = bidText,
			font = UI.font.body,
			size = 10,
			color = textColor,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(5, 55),
			extent = UDim2.new(1, -10, 0, 18),
			zIndex = 29,
		})

		if snapshot then
			tile.Activated:Connect(function()
				selectedPlotId = plotId
				pendingLateCrop = nil
				page = "detail"
				lastNear = isNearPlot(plotId)
				render(true)
			end)
			firstButton = firstButton or tile
		end
	end

	if shouldFocus and UserInputService.GamepadEnabled and firstButton then
		task.defer(function()
			GuiService.SelectedObject = firstButton
		end)
	end
end

local function updateLiveLabels()
	local snapshot = selectedSnapshot()
	if not snapshot then
		return
	end
	local atTime = os.time()
	local crop = snapshot.crop
	if leaseLabel then
		leaseLabel.Text = if snapshot.leaseEndsAt
			then string.format("Lease remaining: %s", clockText(snapshot.leaseEndsAt - atTime))
			else "Available now · 10-minute lease"
	end

	if proximityLabel then
		proximityLabel.Text = if lastNear
			then "At this plot · crop actions ready"
			else "Away from plot · teleport to manage crops"
		proximityLabel.TextColor3 = if lastNear then UI.color.leafDeep else UI.color.inkSoft
	end

	if cropClockLabel and crop then
		local definition = Ingredients.get(crop.id)
		local cropName = if definition then definition.name else crop.id
		cropClockLabel.Text = if atTime >= crop.maturesAt
			then string.format("%s · Ready to harvest", cropName)
			else string.format("%s · Ready in %s", cropName, clockText(crop.maturesAt - atTime))
		cropClockLabel.TextColor3 = if atTime >= crop.maturesAt then UI.color.leafDeep else UI.color.ink
	end

	if inventoryLabel then
		inventoryLabel.Text = string.format(
			"Seeds on hand  ·  Carrot %d  ·  Potato %d  ·  Rice %d",
			ingredientCount("carrot"),
			ingredientCount("potato"),
			ingredientCount("rice")
		)
	end

	if usageLabel then
		usageLabel.Text = string.format(
			"Your active leases + leading bids: %d / %d",
			usageCount,
			Farming.MAX_POSITIONS_PER_USER
		)
		usageLabel.TextColor3 = if usageCount >= Farming.MAX_POSITIONS_PER_USER then UI.color.tobatsu else UI.color.inkSoft
	end
end

local function buildSummary(parent: Instance, snapshot: PlotSnapshot)
	local summary = card(parent, 158)
	sectionTitle(summary, "LEASE STATUS")
	UI.label(summary, "Owner", {
		text = string.format("Current renter: %s", snapshot.ownerName or "No renter"),
		font = UI.font.bold,
		size = UI.text.body,
		position = UDim2.fromOffset(14, 40),
		extent = UDim2.new(1, -28, 0, 22),
		zIndex = 28,
	})
	leaseLabel = UI.label(summary, "Lease", {
		text = "",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 66),
		extent = UDim2.new(1, -28, 0, 20),
		zIndex = 28,
	})
	local bidText = if snapshot.highestBid and snapshot.highestBidderName
		then string.format("Next lease: %s leads at ¥%d", snapshot.highestBidderName, snapshot.highestBid)
		else string.format("Next lease: no bids · minimum ¥%d", snapshot.minimumBid)
	UI.label(summary, "Auction", {
		text = bidText,
		font = UI.font.bold,
		size = UI.text.small,
		color = UI.color.gold,
		position = UDim2.fromOffset(14, 92),
		extent = UDim2.new(1, -28, 0, 20),
		zIndex = 28,
	})
	usageLabel = UI.label(summary, "Usage", {
		text = string.format("Your active leases + leading bids: %d / %d", usageCount, Farming.MAX_POSITIONS_PER_USER),
		font = UI.font.body,
		size = UI.text.small,
		color = if usageCount >= Farming.MAX_POSITIONS_PER_USER then UI.color.tobatsu else UI.color.inkSoft,
		position = UDim2.fromOffset(14, 120),
		extent = UDim2.new(1, -28, 0, 20),
		zIndex = 28,
	})
end

local function buildRent(parent: Instance, snapshot: PlotSnapshot)
	local action = card(parent, 94)
	sectionTitle(action, "RENT THIS PLOT")
	UI.label(action, "Terms", {
		text = string.format("¥%d · one 10-minute lease", Farming.RENT_PRICE),
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 42),
		extent = UDim2.new(1, -170, 0, 32),
		zIndex = 28,
	})
	UI.button(action, "Rent", {
		text = string.format("Rent · ¥%d", Farming.RENT_PRICE),
		color = UI.color.leafDeep,
		position = UDim2.new(1, -154, 0, 40),
		extent = UDim2.fromOffset(140, 40),
		zIndex = 29,

		onActivated = function()
			rentRemote:FireServer(snapshot.plotId)
		end,
	})
end

local function buildBid(parent: Instance, snapshot: PlotSnapshot)
	local auction = card(parent, 154)
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
	input.Text = if capped then tostring(Farming.MAX_BID) else tostring(minimum)
	input.TextColor3 = UI.color.ink
	input.TextSize = UI.text.body
	input.Position = UDim2.fromOffset(14, 42)
	input.Size = UDim2.new(1, -168, 0, 40)
	input.ZIndex = 29
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

	UI.button(auction, "PlaceBid", {
		text = if capped then "Bid capped" else "Place bid",
		color = if capped then UI.color.paperDeep else UI.color.gold,
		textColor = if capped then UI.color.inkFaint else UI.color.ink,
		position = UDim2.new(1, -144, 0, 42),
		extent = UDim2.fromOffset(130, 40),
		zIndex = 29,

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
			zIndex = 29,

			onActivated = function()
				input.Text = tostring(math.clamp(amount() + increment, math.min(minimum, Farming.MAX_BID), Farming.MAX_BID))
			end,
		})
	end
end

local function buildOwnerCard(parent: Instance, snapshot: PlotSnapshot)
	local owner = card(parent, 108)
	sectionTitle(owner, "YOUR PLOT")
	proximityLabel = UI.label(owner, "Proximity", {
		text = "",
		font = UI.font.bold,
		size = UI.text.small,
		position = UDim2.fromOffset(14, 44),
		extent = UDim2.new(1, -172, 0, 42),
		wrapped = true,
		zIndex = 28,
	})
	UI.button(owner, "Teleport", {
		text = "Teleport",
		color = UI.color.sky,
		textColor = UI.color.ink,
		position = UDim2.new(1, -154, 0, 44),
		extent = UDim2.fromOffset(140, 42),
		zIndex = 29,

		onActivated = function()
			teleportRemote:FireServer(snapshot.plotId)
			setPanelOpen(false)
		end,
	})
end

local function requestPlant(snapshot: PlotSnapshot, cropId: string)
	local leaseEndsAt = snapshot.leaseEndsAt or os.time()
	local remaining = leaseEndsAt - os.time()
	local growthSeconds = Farming.growthSeconds(cropId) or 0
	if remaining < growthSeconds and pendingLateCrop ~= cropId then
		pendingLateCrop = cropId
		render()
		return
	end
	pendingLateCrop = nil
	plantRemote:FireServer(snapshot.plotId, cropId)
end

local function buildPlant(parent: Instance, snapshot: PlotSnapshot)
	local crops = card(parent, 226)
	sectionTitle(crops, "PLANT A CROP")
	inventoryLabel = UI.label(crops, "Inventory", {
		text = "",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 38),
		extent = UDim2.new(1, -28, 0, 22),
		zIndex = 28,
	})

	for index, cropId in Farming.CROP_IDS do
		local definition = Ingredients.get(cropId)
		local farmDefinition = Farming.cropDefinition(cropId)
		local owned = ingredientCount(cropId)
		local y = 68 + (index - 1) * 48
		UI.label(crops, cropId, {
			text = string.format(
				"%s · %dm → %d · use %d · have %d",
				if definition then definition.name else cropId,
				if farmDefinition then farmDefinition.growthSeconds / 60 else 0,
				if farmDefinition then farmDefinition.harvestYield else 0,
				Farming.SEED_COST,
				owned
			),
			font = UI.font.bold,
			size = UI.text.small,
			position = UDim2.fromOffset(14, y + 8),
			extent = UDim2.new(1, -172, 0, 24),
			zIndex = 28,
		})
		local isConfirmation = pendingLateCrop == cropId
		local guaranteed = Farming.yieldForElapsed(cropId, (snapshot.leaseEndsAt or os.time()) - os.time())
		UI.button(crops, `Plant{cropId}`, {
			text = if isConfirmation then string.format("Confirm · get %d", guaranteed) else "Plant",
			color = if owned >= Farming.SEED_COST then UI.color.leafDeep else UI.color.paperDeep,
			textColor = if owned >= Farming.SEED_COST then UI.color.white else UI.color.inkFaint,
			position = UDim2.new(1, -146, 0, y),
			extent = UDim2.fromOffset(132, 38),
			zIndex = 29,

			onActivated = function()
				if owned >= Farming.SEED_COST then
					requestPlant(snapshot, cropId)
				end
			end,
		})
	end
end

local function buildCrop(parent: Instance, snapshot: PlotSnapshot, crop: CropSnapshot)
	local section = card(parent, 132)
	sectionTitle(section, "CURRENT CROP")
	cropClockLabel = UI.label(section, "CropStatus", {
		text = "",
		font = UI.font.bold,
		size = UI.text.body,
		position = UDim2.fromOffset(14, 42),
		extent = UDim2.new(1, -28, 0, 28),
		zIndex = 28,
	})
	if lastNear and os.time() >= crop.maturesAt then
		local definition = Farming.cropDefinition(crop.id)
		UI.button(section, "Harvest", {
			text = string.format("Harvest %d", if definition then definition.harvestYield else 0),
			color = UI.color.leafDeep,
			position = UDim2.fromOffset(14, 82),
			extent = UDim2.new(1, -28, 0, 38),
			zIndex = 29,

			onActivated = function()
				harvestRemote:FireServer(snapshot.plotId)
			end,
		})
	elseif not lastNear then
		UI.label(section, "ManageHint", {
			text = "Teleport to this plot to harvest when ready.",
			font = UI.font.body,
			size = UI.text.small,
			color = UI.color.inkSoft,
			position = UDim2.fromOffset(14, 82),
			extent = UDim2.new(1, -28, 0, 24),
			zIndex = 28,
		})
	end
end

local function buildEmptyCrop(parent: Instance)
	local section = card(parent, 88)
	sectionTitle(section, "CURRENT CROP")
	UI.label(section, "Empty", {
		text = "No crop planted · teleport to this plot to plant.",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 43),
		extent = UDim2.new(1, -28, 0, 28),
		zIndex = 28,
	})
end

local function renderDetail(shouldFocus: boolean?)
	local snapshot = selectedSnapshot()
	if not snapshot then
		local body = makeScrollingBody()
		UI.label(body, "Loading", {
			text = "Loading this plot…",
			font = UI.font.bold,
			size = UI.text.body,
			color = UI.color.inkSoft,
			extent = UDim2.new(1, 0, 0, 44),
			zIndex = 26,
		})
		return
	end
	local crop = snapshot.crop
	lastCropReady = crop ~= nil and os.time() >= crop.maturesAt

	local body = makeScrollingBody()
	buildSummary(body, snapshot)
	if not snapshot.ownerUserId then
		buildRent(body, snapshot)
	else
		local ownsPlot = snapshot.ownerUserId == Players.LocalPlayer.UserId
		if ownsPlot then
			buildOwnerCard(body, snapshot)
			if snapshot.crop then
				buildCrop(body, snapshot, snapshot.crop)
			elseif lastNear then
				buildPlant(body, snapshot)
			else
				buildEmptyCrop(body)
			end
		end
		buildBid(body, snapshot)
	end
	updateLiveLabels()

	if shouldFocus and UserInputService.GamepadEnabled then
		task.defer(function()
			GuiService.SelectedObject = backButton
		end)
	end
end

render = function(shouldFocus: boolean?)
	if not contentHost then
		return
	end
	clearContent()
	backButton.Visible = page == "detail"
	if page == "grid" then
		titleLabel.Text = "COMMUNITY FARM"
		subtitleLabel.Text = "15 plots · live leases and next bids"
		renderGrid(shouldFocus)
	else
		local plotId = selectedPlotId or 0
		titleLabel.Text = string.format("FARM PLOT %02d", plotId)
		subtitleLabel.Text = "Lease, bid, and crop details"
		renderDetail(shouldFocus)
	end
end

local function queueGridRender()
	if gridRenderQueued then
		return
	end
	gridRenderQueued = true
	local selected = GuiService.SelectedObject
	local focusedPlotId = if selected then selected:GetAttribute("FarmPlotId") else nil
	task.defer(function()
		gridRenderQueued = false
		if not isOpen or page ~= "grid" then
			return
		end
		render()
		if type(focusedPlotId) == "number" then
			local replacement = panel:FindFirstChild(`Plot_{focusedPlotId}`, true)
			if replacement and replacement:IsA("GuiObject") then
				GuiService.SelectedObject = replacement
			end
		end
	end)
end

local function buildPanel(parent: ScreenGui)
	local _, content, toggle = UI.modal(parent, "FarmMenu", {
		extent = UDim2.new(0.94, 0, 0.88, 0),
		zIndex = 24,

		onToggled = function(open)
			isOpen = open
			WorkController.setInputLocked("farm-menu", open)
			if not open then
				page = "grid"
				selectedPlotId = nil
				pendingLateCrop = nil
				local selected = GuiService.SelectedObject
				if selected and selected:IsDescendantOf(panel) then
					GuiService.SelectedObject = nil
				end
			end
		end,
	})
	panel = content
	setPanelOpen = toggle
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(330, 430)
	constraint.MaxSize = Vector2.new(720, 760)
	constraint.Parent = panel

	backButton = UI.button(panel, "Back", {
		text = "‹ Back",
		color = UI.color.paperDeep,
		position = UDim2.fromOffset(14, 16),
		extent = UDim2.fromOffset(76, 34),
		zIndex = 27,

		onActivated = function()
			page = "grid"
			selectedPlotId = nil
			pendingLateCrop = nil
			render(true)
		end,
	})
	backButton.Visible = false

	titleLabel = UI.label(panel, "Title", {
		text = "COMMUNITY FARM",
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(102, 12),
		extent = UDim2.new(1, -164, 0, 28),
		align = Enum.TextXAlignment.Center,
		zIndex = 26,
	})
	subtitleLabel = UI.label(panel, "Subtitle", {
		text = "15 plots · live leases and next bids",
		font = UI.font.body,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(102, 38),
		extent = UDim2.new(1, -164, 0, 18),
		align = Enum.TextXAlignment.Center,
		zIndex = 26,
	})
	UI.button(panel, "Close", {
		text = "×",
		color = UI.color.paperDeep,
		position = UDim2.new(1, -54, 0, 14),
		extent = UDim2.fromOffset(40, 36),
		zIndex = 27,

		onActivated = function()
			setPanelOpen(false)
		end,
	})

	contentHost = Instance.new("Frame")
	contentHost.Name = "Content"
	contentHost.BackgroundTransparency = 1
	contentHost.Position = UDim2.fromOffset(16, 66)
	contentHost.Size = UDim2.new(1, -32, 1, -82)
	contentHost.ZIndex = 25
	contentHost.Parent = panel
end

function FarmMenu.setOpen(open: boolean)
	if not setPanelOpen then
		return
	end
	if open then
		page = "grid"
		selectedPlotId = nil
		pendingLateCrop = nil
		render(true)
		setPanelOpen(true)
		requestStateRemote:FireServer()
	else
		setPanelOpen(false)
	end
end

function FarmMenu.toggle()
	FarmMenu.setOpen(not isOpen)
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
	requestStateRemote = Remotes.event("Farm", "RequestState")
	teleportRemote = Remotes.event("Farm", "Teleport")
	buildPanel(gui)

	Remotes.event("Farm", "State").OnClientEvent:Connect(function(snapshot: PlotSnapshot, count: number)
		if type(snapshot) ~= "table"
			or type(snapshot.plotId) ~= "number"
			or snapshot.plotId % 1 ~= 0
			or snapshot.plotId < 1
			or snapshot.plotId > Farming.PLOT_COUNT
		then
			return
		end
		if not receivedPlots[snapshot.plotId] then
			receivedPlots[snapshot.plotId] = true
			receivedCount += 1
		end
		snapshots[snapshot.plotId] = snapshot
		if type(count) == "number" then
			usageCount = count
		end
		if isOpen then
			if page == "grid" then
				queueGridRender()
			elseif selectedPlotId == snapshot.plotId then
				pendingLateCrop = nil
				render()
			else
				updateLiveLabels()
			end
		end
	end)

	StateController.onChanged(function()
		if isOpen and page == "detail" then
			updateLiveLabels()
		end
	end)

	ContextActionService:BindAction(ACTION_NAME, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			FarmMenu.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if isOpen and page == "detail" and selectedPlotId then
				local near = isNearPlot(selectedPlotId)
				local snapshot = selectedSnapshot()
				local crop = if snapshot then snapshot.crop else nil
				local cropReady = crop ~= nil and os.time() >= crop.maturesAt
				if near ~= lastNear or cropReady ~= lastCropReady then
					lastNear = near
					lastCropReady = cropReady
					render()
				else
					updateLiveLabels()
				end
			end
		end
	end)
end

return FarmMenu

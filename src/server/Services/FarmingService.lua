--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local ModelUtil = require(Shared.Modules.ModelUtil)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local Farming = require(Shared.Modules.Config.Farming)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)

local AssetService = require(script.Parent.AssetService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local FarmMailboxService = require(script.Parent.FarmMailboxService)
local FarmPlotModule = require(script.Parent.FarmPlot)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

type FarmPlot = FarmPlotModule.FarmPlot
type CropState = FarmPlotModule.CropState
type Credit = FarmMailboxService.Credit

local FarmingService = {}

local plots: { [number]: FarmPlot } = {}
local plotLocks: { [number]: boolean } = {}
local limiters: { [Player]: RateLimiter.RateLimiter } = {}
local deferredCredits: { { userId: number, credit: Credit } } = {}
local creditSequence = 0
local farmFolder: Folder? = nil
local shuttingDown = false

local rentRemote: RemoteEvent
local bidRemote: RemoteEvent
local plantRemote: RemoteEvent
local harvestRemote: RemoteEvent
local openRemote: RemoteEvent
local stateRemote: RemoteEvent

local function now(): number
	return os.time()
end

local function validInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
end

local function plotFromArgument(value: any): FarmPlot?
	if not validInteger(value) then
		return nil
	end
	return plots[value]
end

local function limiterFor(player: Player): RateLimiter.RateLimiter
	local limiter = limiters[player]
	if not limiter then
		limiter = RateLimiter.new(Farming.ACTIONS_PER_SECOND, Farming.ACTIONS_PER_SECOND * 2)
		limiters[player] = limiter
	end
	return limiter
end

local function canAct(player: Player): boolean
	return player.Parent == Players and limiterFor(player):consume()
end

local function isNear(player: Player, plot: FarmPlot): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - plot:getPosition()).Magnitude <= Farming.INTERACTION_DISTANCE + 3
end

local function positionSet(userId: number): { [number]: boolean }
	local occupied: { [number]: boolean } = {}
	for plotId, plot in plots do
		if plot:getOwnerUserId() == userId then
			occupied[plotId] = true
		end
		local bid = plot:getBid()
		if bid and bid.userId == userId then
			occupied[plotId] = true
		end
	end
	return occupied
end

local function positionCount(userId: number): number
	local leases = {}
	local bids = {}
	for plotId, plot in plots do
		if plot:getOwnerUserId() == userId then
			table.insert(leases, plotId)
		end
		local bid = plot:getBid()
		if bid and bid.userId == userId then
			table.insert(bids, plotId)
		end
	end
	return Farming.countPositions(leases, bids)
end

local function canTakePosition(userId: number, plotId: number): boolean
	local occupied = positionSet(userId)
	return occupied[plotId] == true or positionCount(userId) < Farming.MAX_POSITIONS_PER_USER
end

local function pushPlot(plot: FarmPlot)
	if not stateRemote then
		return
	end
	local snapshot = plot:snapshot(now())
	for _, player in Players:GetPlayers() do
		stateRemote:FireClient(player, snapshot, positionCount(player.UserId))
	end
end

local function pushAll(player: Player)
	local count = positionCount(player.UserId)
	for plotId = 1, Farming.PLOT_COUNT do
		local plot = plots[plotId]
		if plot then
			stateRemote:FireClient(player, plot:snapshot(now()), count)
		end
	end
end

local function creditId(kind: string, plotId: number, userId: number): string
	creditSequence += 1
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	return string.format("%s:%s:%d:%d:%d", jobId, kind, plotId, userId, creditSequence)
end

local function deliverCredit(userId: number, credit: Credit, forceMailbox: boolean?): boolean
	if not forceMailbox then
		local player = Players:GetPlayerByUserId(userId)
		local profile = player and DataService.get(player)
		if player and profile then
			FarmMailboxService.apply(player, profile, credit)
			return true
		end
	end
	return FarmMailboxService.enqueue(userId, credit)
end

local function deliverOrDefer(userId: number, credit: Credit, forceMailbox: boolean?)
	if deliverCredit(userId, credit, forceMailbox) then
		return
	end
	table.insert(deferredCredits, { userId = userId, credit = credit })
	warn(string.format("[FarmingService] Deferred credit %s for a later retry", credit.id))
end

local function settleCrop(plot: FarmPlot, crop: CropState, elapsed: number, forceMailbox: boolean?)
	local ownerUserId = plot:getOwnerUserId()
	if not ownerUserId then
		return
	end
	local itemCount = Farming.yieldForElapsed(math.max(0, elapsed))
	local credit: Credit = {
		id = creditId("crop", plot:getId(), ownerUserId),
		ingredientId = crop.id,
		itemCount = itemCount,
		kusatoriGain = BigNumber.mulNumber(crop.xpPerItem, itemCount),
		reason = "Farm harvest",
	}
	deliverOrDefer(ownerUserId, credit, forceMailbox)

	local player = Players:GetPlayerByUserId(ownerUserId)
	if player and not forceMailbox then
		local definition = Ingredients.get(crop.id)
		NotifyService.send(
			player,
			string.format(
				"Harvested %d %s from Plot %02d.",
				itemCount,
				if definition then definition.name else crop.id,
				plot:getId()
			),
			"reward"
		)
	end
end

local function withPlotLock(plotId: number, callback: (FarmPlot) -> ())
	local plot = plots[plotId]
	if not plot or plotLocks[plotId] then
		return
	end
	plotLocks[plotId] = true
	local ok, failure = pcall(callback, plot)
	plotLocks[plotId] = nil
	if not ok then
		warn(string.format("[FarmingService] Plot %02d mutation failed: %s", plotId, tostring(failure)))
	end
end

local function turnoverLocked(plot: FarmPlot, atTime: number, forceMailbox: boolean?)
	local leaseEndsAt = plot:getLeaseEndsAt()
	if not leaseEndsAt or atTime < leaseEndsAt then
		return
	end

	local crop = plot:takeCrop()
	if crop then
		settleCrop(plot, crop, leaseEndsAt - crop.plantedAt, forceMailbox)
	end

	local winningBid = plot:takeBid()
	if winningBid then
		plot:beginLease(winningBid.userId, winningBid.name, atTime + Farming.LEASE_SECONDS)
	else
		plot:vacate()
	end
	pushPlot(plot)
end

local function ensureCurrentLocked(plot: FarmPlot, atTime: number)
	local leaseEndsAt = plot:getLeaseEndsAt()
	if leaseEndsAt and atTime >= leaseEndsAt then
		turnoverLocked(plot, atTime)
	end
end

local function reject(player: Player, message: string)
	NotifyService.send(player, message, "locked")
end

local function onPrompt(player: Player, plotId: number)
	local plot = plots[plotId]
	if not plot or not isNear(player, plot) then
		return
	end
	withPlotLock(plotId, function(lockedPlot)
		ensureCurrentLocked(lockedPlot, now())
		openRemote:FireClient(player, lockedPlot:snapshot(now()), positionCount(player.UserId))
	end)
end

local function onLeaseExpired(plotId: number, _generation: number)
	withPlotLock(plotId, function(plot)
		turnoverLocked(plot, now())
	end)
end

local function handleRent(player: Player, rawPlotId: any)
	if shuttingDown or not canAct(player) then
		return
	end
	local plot = plotFromArgument(rawPlotId)
	if not plot or not isNear(player, plot) then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		reject(player, "Your profile is still loading.")
		return
	end

	withPlotLock(plot:getId(), function(lockedPlot)
		local atTime = now()
		ensureCurrentLocked(lockedPlot, atTime)
		if lockedPlot:getOwnerUserId() then
			reject(player, "That plot is already leased. Bid for its next turn instead.")
			return
		end
		if not canTakePosition(player.UserId, lockedPlot:getId()) then
			reject(player, string.format("You may hold or lead bids on at most %d plots.", Farming.MAX_POSITIONS_PER_USER))
			return
		end
		if not CurrencyService.spend(profile, "yen", BigNumber.fromNumber(Farming.RENT_PRICE)) then
			reject(player, string.format("You need ¥%d to rent this plot.", Farming.RENT_PRICE))
			return
		end

		lockedPlot:beginLease(player.UserId, player.DisplayName, atTime + Farming.LEASE_SECONDS)
		NotifyService.send(player, string.format("Plot %02d is yours for 10 minutes.", lockedPlot:getId()), "reward")
		pushPlot(lockedPlot)
	end)
end

local function handleBid(player: Player, rawPlotId: any, rawAmount: any)
	local receivedAt = now()
	if shuttingDown or not canAct(player) then
		return
	end
	local plot = plotFromArgument(rawPlotId)
	if not plot or not validInteger(rawAmount) or not isNear(player, plot) then
		return
	end
	local amount = rawAmount :: number
	local profile = DataService.get(player)
	if not profile then
		reject(player, "Your profile is still loading.")
		return
	end

	withPlotLock(plot:getId(), function(lockedPlot)
		local leaseEndsAt = lockedPlot:getLeaseEndsAt()
		if not leaseEndsAt or receivedAt >= leaseEndsAt or not lockedPlot:getOwnerUserId() then
			ensureCurrentLocked(lockedPlot, now())
			reject(player, "Bidding for that lease has closed.")
			return
		end

		local oldBid = lockedPlot:getBid()
		if not Farming.isValidBid(amount, if oldBid then oldBid.amount else nil) then
			local minimum = Farming.minimumBid(if oldBid then oldBid.amount else nil)
			if minimum > Farming.MAX_BID then
				reject(player, "This auction has reached the ¥10,000 cap.")
			else
				reject(player, string.format("Enter a whole-Yen bid from ¥%d to ¥%d.", minimum, Farming.MAX_BID))
			end
			return
		end
		if not canTakePosition(player.UserId, lockedPlot:getId()) then
			reject(player, string.format("You may hold or lead bids on at most %d plots.", Farming.MAX_POSITIONS_PER_USER))
			return
		end

		local sameBidder = oldBid and oldBid.userId == player.UserId
		local charge = Farming.escrowCharge(amount, if oldBid then oldBid.amount else nil, sameBidder == true)
		if not CurrencyService.spend(profile, "yen", BigNumber.fromNumber(charge)) then
			reject(player, string.format("You need ¥%d available for that bid.", charge))
			return
		end

		if oldBid and not sameBidder then
			local refund: Credit = {
				id = creditId("refund", lockedPlot:getId(), oldBid.userId),
				yen = oldBid.amount,
				reason = "Farm auction refund",
			}
			if not deliverCredit(oldBid.userId, refund) then
				CurrencyService.award(profile, "yen", BigNumber.fromNumber(charge))
				reject(player, "The prior escrow could not be returned. Please try again shortly.")
				return
			end
			local oldPlayer = Players:GetPlayerByUserId(oldBid.userId)
			if oldPlayer then
				NotifyService.send(
					oldPlayer,
					string.format("You were outbid on Plot %02d; Yen %d was returned.", lockedPlot:getId(), oldBid.amount)
				)
			end
		end

		lockedPlot:setBid({ userId = player.UserId, name = player.DisplayName, amount = amount })
		NotifyService.send(player, string.format("You lead Plot %02d at ¥%d.", lockedPlot:getId(), amount), "reward")
		pushPlot(lockedPlot)
	end)
end

local function handlePlant(player: Player, rawPlotId: any, rawCropId: any)
	if shuttingDown or not canAct(player) then
		return
	end
	local plot = plotFromArgument(rawPlotId)
	if not plot or type(rawCropId) ~= "string" or not Farming.isCrop(rawCropId) or not isNear(player, plot) then
		return
	end
	local cropId = rawCropId :: string
	local profile = DataService.get(player)
	if not profile then
		reject(player, "Your profile is still loading.")
		return
	end

	withPlotLock(plot:getId(), function(lockedPlot)
		local atTime = now()
		ensureCurrentLocked(lockedPlot, atTime)
		if lockedPlot:getOwnerUserId() ~= player.UserId or not lockedPlot:isActive(atTime) then
			reject(player, "Only the current renter can plant here.")
			return
		end
		if lockedPlot:getCrop() then
			reject(player, "Harvest the current crop before planting another.")
			return
		end

		local definition = Ingredients.get(cropId)
		local ingredients = profile.currencies.ingredients
		local owned = ingredients[cropId] or 0
		if not definition or owned < Farming.SEED_COST then
			reject(player, string.format("Planting needs %d matching ingredients.", Farming.SEED_COST))
			return
		end

		ingredients[cropId] = owned - Farming.SEED_COST
		local xpPerItem = BigNumber.mulNumber(Formulas.gainPerAction(profile, "kusatori", nil), definition.xpMultiplier)
		lockedPlot:plant({ id = cropId, plantedAt = atTime, xpPerItem = xpPerItem })
		local leaseEndsAt = lockedPlot:getLeaseEndsAt() or atTime
		local guaranteed = Farming.yieldForElapsed(leaseEndsAt - atTime)
		NotifyService.send(
			player,
			string.format("Planted %s. This lease guarantees %d at settlement.", definition.name, guaranteed),
			"reward"
		)
		pushPlot(lockedPlot)
	end)
end

local function handleHarvest(player: Player, rawPlotId: any)
	if shuttingDown or not canAct(player) then
		return
	end
	local plot = plotFromArgument(rawPlotId)
	if not plot or not isNear(player, plot) then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		reject(player, "Your profile is still loading.")
		return
	end

	withPlotLock(plot:getId(), function(lockedPlot)
		local atTime = now()
		ensureCurrentLocked(lockedPlot, atTime)
		if lockedPlot:getOwnerUserId() ~= player.UserId or not lockedPlot:isActive(atTime) then
			reject(player, "Only the current renter can harvest here.")
			return
		end
		local crop = lockedPlot:getCrop()
		if not crop then
			reject(player, "There is no crop to harvest.")
			return
		end
		if atTime - crop.plantedAt < Farming.MATURE_SECONDS then
			reject(player, "This crop is not mature yet. It will settle automatically if the lease ends first.")
			return
		end

		lockedPlot:takeCrop()
		settleCrop(lockedPlot, crop, atTime - crop.plantedAt)
		pushPlot(lockedPlot)
	end)
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function addTitleSign(parent: Instance, entrance: CFrame)
	local postColor = Color3.fromRGB(148, 104, 70)
	for _, x in { -7, 7 } do
		makePart(
			parent,
			"EntrancePost",
			Vector3.new(1.2, 8, 1.2),
			entrance * CFrame.new(x, 4, 0),
			postColor,
			Enum.Material.WoodPlanks
		)
	end
	local beam = makePart(
		parent,
		"EntranceBeam",
		Vector3.new(16, 2.2, 1.4),
		entrance * CFrame.new(0, 8, 0),
		postColor,
		Enum.Material.WoodPlanks
	)

	local gui = Instance.new("BillboardGui")
	gui.Name = "FarmTitle"
	gui.Size = UDim2.fromOffset(260, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 220
	gui.Parent = beam
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "C5 COMMUNITY FARM"
	label.TextColor3 = Color3.fromRGB(255, 249, 218)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
end

local function addKusatoriRoutes(parent: Instance, area: Areas.AreaDefinition, topY: number)
	local routes = Instance.new("Folder")
	routes.Name = "KusatoriRoutes"
	routes.Parent = parent

	for _, route in Layout.farmRouteSegments(area) do
		local segment = Instance.new("Folder")
		segment.Name = route.id
		segment:SetAttribute("From", route.from)
		segment:SetAttribute("To", route.to)
		segment.Parent = routes

		local span = Vector3.new(route.to.X - route.from.X, 0, route.to.Z - route.from.Z)
		local steps = math.max(1, math.ceil(span.Magnitude / Farming.ROUTE_STONE_SPACING))
		for index = 0, steps do
			local alpha = index / steps
			local position = route.from:Lerp(route.to, alpha)
			local size = Farming.ROUTE_STONE_SIZE * (if index % 3 == 1 then 0.9 else 1)
			local stone = makePart(
				segment,
				`RouteStone_{string.format("%03d", index)}`,
				Vector3.new(Farming.ROUTE_STONE_THICKNESS, size, size),
				CFrame.new(position.X, topY, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
				if index % 5 == 2 then Color3.fromRGB(244, 206, 210) else Color3.fromRGB(239, 230, 204),
				Enum.Material.SmoothPlastic
			)
			stone.Shape = Enum.PartType.Cylinder
			stone.CanCollide = false
			stone.CastShadow = false
		end
	end
end

local function addFieldDressing(parent: Instance, area: Areas.AreaDefinition)
	local field = Layout.farmFieldCFrame(area)
	local topY = Constants.WORLD.PLATFORM_TOP + 0.16
	local pathColor = Color3.fromRGB(224, 205, 165)
	addKusatoriRoutes(parent, area, topY)

	for column = 1, Farming.COLUMNS - 1 do
		local x = (column - Farming.COLUMNS / 2) * Farming.PLOT_STRIDE
		makePart(
			parent,
			"Aisle",
			Vector3.new(Farming.AISLE_SIZE, 0.32, Farming.FIELD_LENGTH),
			CFrame.new(field.Position.X + x, topY, field.Position.Z),
			pathColor,
			Enum.Material.Ground
		).CanCollide = false
	end
	for row = 1, Farming.ROWS - 1 do
		local z = (row - Farming.ROWS / 2) * Farming.PLOT_STRIDE
		makePart(
			parent,
			"Aisle",
			Vector3.new(Farming.FIELD_WIDTH, 0.32, Farming.AISLE_SIZE),
			CFrame.new(field.Position.X, topY, field.Position.Z + z),
			pathColor,
			Enum.Material.Ground
		).CanCollide = false
	end

	local entrance = Layout.farmEntranceCFrame(area)
	local fieldSouth = field.Position.Z - Farming.FIELD_LENGTH / 2
	local pathCentreZ = (entrance.Position.Z + fieldSouth) / 2
	makePart(
		parent,
		"EntranceWalk",
		Vector3.new(12, 0.36, math.max(2, fieldSouth - entrance.Position.Z)),
		CFrame.new(entrance.Position.X, topY, pathCentreZ),
		pathColor,
		Enum.Material.Cobblestone
	).CanCollide = false

	local borderColor = Color3.fromRGB(150, 111, 73)
	local halfWidth = Farming.FIELD_WIDTH / 2 + 2
	local halfLength = Farming.FIELD_LENGTH / 2 + 2
	for _, side in { -1, 1 } do
		makePart(
			parent,
			"FieldBorder",
			Vector3.new(1, 2, Farming.FIELD_LENGTH + 5),
			CFrame.new(field.Position.X + side * halfWidth, topY + 0.8, field.Position.Z),
			borderColor,
			Enum.Material.WoodPlanks
		)
	end
	makePart(
		parent,
		"FieldBorder",
		Vector3.new(Farming.FIELD_WIDTH + 5, 2, 1),
		CFrame.new(field.Position.X, topY + 0.8, field.Position.Z + halfLength),
		borderColor,
		Enum.Material.WoodPlanks
	)
	local southSegment = (Farming.FIELD_WIDTH - 14) / 2
	for side in { -1, 1 } do
		makePart(
			parent,
			"FieldBorder",
			Vector3.new(southSegment, 2, 1),
			CFrame.new(field.Position.X + side * (7 + southSegment / 2), topY + 0.8, field.Position.Z - halfLength),
			borderColor,
			Enum.Material.WoodPlanks
		)
	end
	addTitleSign(parent, entrance)
end

local function makeProceduralSprout(parent: Instance, position: Vector3, stage: number, cropId: string)
	local model = Instance.new("Model")
	model.Name = "ProceduralCrop"
	local stemHeight = ({ 0.7, 1.2, 1.8 })[stage]
	local stem = makePart(
		model,
		"Stem",
		Vector3.new(0.22, stemHeight, 0.22),
		CFrame.new(position + Vector3.new(0, stemHeight / 2, 0)),
		Color3.fromRGB(83, 151, 68),
		Enum.Material.SmoothPlastic
	)
	stem.CanCollide = false
	local cropColor = if cropId == "carrot"
		then Color3.fromRGB(235, 131, 53)
		elseif cropId == "potato" then Color3.fromRGB(181, 143, 94)
		else Color3.fromRGB(239, 222, 137)
	local bulb = makePart(
		model,
		"Crop",
		Vector3.new(0.55, 0.55, 0.55),
		CFrame.new(position + Vector3.new(0, stemHeight, 0)),
		cropColor,
		Enum.Material.SmoothPlastic
	)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	model.Parent = parent
end

local function renderCrop(parent: Folder, cropId: string, stage: number, baseCFrame: CFrame)
	local definition = Ingredients.get(cropId)
	local targetHeight = (if definition and definition.height then definition.height else 2.2) * ({ 0.4, 0.7, 1 })[stage]
	local offsets = { -8, 0, 8 }
	for row, z in offsets do
		for column, x in offsets do
			local position = baseCFrame:PointToWorldSpace(Vector3.new(x, 0, z))
			local model = definition and AssetService.clone(definition.asset) or nil
			if model then
				ModelUtil.standUpright(model)
				if ModelUtil.scaleToLongest(model, targetHeight) then
					for _, descendant in model:GetDescendants() do
						if descendant:IsA("BasePart") then
							descendant.Anchored = true
							descendant.CanCollide = false
							descendant.CanQuery = false
							descendant.CanTouch = false
						end
					end
					ModelUtil.seat(
						model,
						position,
						math.rad((row * 47 + column * 83) % 360),
						nil,
						if definition and definition.ground then 0.18 else 0
					)
					model.Name = cropId
					model.Parent = parent
				else
					model:Destroy()
					makeProceduralSprout(parent, position, stage, cropId)
				end
			else
				makeProceduralSprout(parent, position, stage, cropId)
			end
		end
	end
end

local function buildFarm()
	WorldService.awaitDressed()
	if shuttingDown then
		return
	end
	local area = Areas.get(Areas.STARTING_AREA)
	local regionFolder = WorldService.getRegionFolder(Areas.STARTING_AREA)
	if not area or not regionFolder then
		warn("[FarmingService] Town region is unavailable")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "C5Farm"
	folder.Parent = regionFolder
	farmFolder = folder
	addFieldDressing(folder, area)

	for plotId = 1, Farming.PLOT_COUNT do
		local cframe = Layout.farmPlotCFrame(area, plotId)
		assert(cframe, string.format("Farming layout is missing Plot %02d", plotId))
		plots[plotId] = FarmPlotModule.new(plotId, cframe, folder, {
			clock = now,
			onPrompt = onPrompt,
			onLeaseExpired = onLeaseExpired,
			renderCrop = renderCrop,
		})
	end

	for _, player in Players:GetPlayers() do
		pushAll(player)
	end
end

local function retryDeferredCredits()
	while not shuttingDown do
		task.wait(10)
		local pending = deferredCredits
		deferredCredits = {}
		for _, entry in pending do
			if not deliverCredit(entry.userId, entry.credit) then
				table.insert(deferredCredits, entry)
			end
		end
	end
end

local function shutdown()
	if shuttingDown then
		return
	end
	shuttingDown = true

	for plotId = 1, Farming.PLOT_COUNT do
		local plot = plots[plotId]
		if plot then
			local crop = plot:takeCrop()
			if crop then
				settleCrop(plot, crop, now() - crop.plantedAt, true)
			end
			local bid = plot:takeBid()
			if bid then
				deliverOrDefer(bid.userId, {
					id = creditId("shutdown-refund", plotId, bid.userId),
					yen = bid.amount,
					reason = "Farm auction shutdown refund",
				}, true)
			end
			plot:Destroy()
			plots[plotId] = nil
		end
	end

	for attempt = 1, 3 do
		if #deferredCredits == 0 then
			break
		end
		local pending = deferredCredits
		deferredCredits = {}
		for _, entry in pending do
			if not FarmMailboxService.enqueue(entry.userId, entry.credit) then
				table.insert(deferredCredits, entry)
			end
		end
		if #deferredCredits > 0 and attempt < 3 then
			task.wait(1)
		end
	end

	if #deferredCredits > 0 then
		warn(string.format("[FarmingService] %d credit(s) could not be persisted during shutdown", #deferredCredits))
	end
	if farmFolder then
		farmFolder:Destroy()
		farmFolder = nil
	end
end

function FarmingService.init()
	rentRemote = Remotes.event("Farm", "Rent")
	bidRemote = Remotes.event("Farm", "Bid")
	plantRemote = Remotes.event("Farm", "Plant")
	harvestRemote = Remotes.event("Farm", "Harvest")
	openRemote = Remotes.event("Farm", "Open")
	stateRemote = Remotes.event("Farm", "State")

	rentRemote.OnServerEvent:Connect(handleRent)
	bidRemote.OnServerEvent:Connect(handleBid)
	plantRemote.OnServerEvent:Connect(handlePlant)
	harvestRemote.OnServerEvent:Connect(handleHarvest)
	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
	end)
	DataService.onLoaded(function(player)
		if next(plots) then
			task.defer(pushAll, player)
		end
	end)

	task.spawn(buildFarm)
	task.spawn(retryDeferredCredits)
	game:BindToClose(shutdown)
end

return FarmingService

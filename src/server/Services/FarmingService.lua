--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local BigNumber = require(Shared.Modules.BigNumber)
local Formulas = require(Shared.Modules.Formulas)
local ModelUtil = require(Shared.Modules.ModelUtil)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local Farming = require(Shared.Modules.Config.Farming)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)
local AssetService = require(script.Parent.AssetService)
local CurrencyService = require(script.Parent.CurrencyService)
local FarmEnvironmentBuilder = require(script.Parent.FarmEnvironmentBuilder)
local DataService = require(script.Parent.DataService)
local FarmMailboxService = require(script.Parent.FarmMailboxService)
local FarmPlotModule = require(script.Parent.FarmPlot)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

type FarmPlot = FarmPlotModule.FarmPlot
type CropState = FarmPlotModule.CropState
type Credit = FarmMailboxService.Credit

local FarmingService = {}
local STATE_REQUESTS_PER_SECOND = 1
local plots: { [number]: FarmPlot } = {}
local plotLocks: { [number]: boolean } = {}
local limiters: { [Player]: RateLimiter.RateLimiter } = {}
local stateRequestLimiters: { [Player]: RateLimiter.RateLimiter } = {}
local deferredCredits: { { userId: number, credit: Credit } } = {}
local creditSequence = 0
local farmFolder: Folder? = nil
local shuttingDown = false
local rentRemote: RemoteEvent
local bidRemote: RemoteEvent
local plantRemote: RemoteEvent
local harvestRemote: RemoteEvent
local requestStateRemote: RemoteEvent
local stateRemote: RemoteEvent
local teleportRemote: RemoteEvent

local function now(): number
	return os.time()
end

local function validInteger(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value % 1 == 0
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
		limiter = RateLimiter.new(Farming.ACTIONS_PER_SECOND, 1)
		limiters[player] = limiter
	end
	return limiter
end

local function canAct(player: Player): boolean
	return player.Parent == Players and limiterFor(player):consume()
end

local function canRequestState(player: Player): boolean
	if player.Parent ~= Players then
		return false
	end
	local limiter = stateRequestLimiters[player]
	if not limiter then
		limiter = RateLimiter.new(STATE_REQUESTS_PER_SECOND, 1)
		stateRequestLimiters[player] = limiter
	end
	return limiter:consume()
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
	local itemCount = Farming.yieldForElapsed(crop.id, math.max(0, elapsed))
	local player = Players:GetPlayerByUserId(ownerUserId)
	local definition = Ingredients.get(crop.id)
	if itemCount <= 0 then
		if player and not forceMailbox then
			NotifyService.send(
				player,
				string.format(
					"%s on Plot %02d did not mature before the lease ended.",
					if definition then definition.name else crop.id,
					plot:getId()
				)
			)
		end
		return
	end
	local credit: Credit = {
		id = creditId("crop", plot:getId(), ownerUserId),
		ingredientId = crop.id,
		itemCount = itemCount,
		kusatoriGain = BigNumber.mulNumber(crop.xpPerItem, itemCount),
		reason = "Farm harvest",
	}
	deliverOrDefer(ownerUserId, credit, forceMailbox)

	if player and not forceMailbox then
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

local function withPlotLock(plotId: number, callback: (FarmPlot) -> ...any)
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
	if not plot then
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
			reject(
				player,
				string.format("You may hold or lead bids on at most %d plots.", Farming.MAX_POSITIONS_PER_USER)
			)
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
	if not plot or not validInteger(rawAmount) then
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
			reject(
				player,
				string.format("You may hold or lead bids on at most %d plots.", Farming.MAX_POSITIONS_PER_USER)
			)
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
					string.format(
						"You were outbid on Plot %02d; Yen %d was returned.",
						lockedPlot:getId(),
						oldBid.amount
					)
				)
			end
		end

		lockedPlot:setBid({ userId = player.UserId, name = player.DisplayName, amount = amount })
		NotifyService.send(player, string.format("You lead Plot %02d at ¥%d.", lockedPlot:getId(), amount), "reward")
		pushPlot(lockedPlot)
	end)
end

local function handleRequestState(player: Player)
	if shuttingDown or not canRequestState(player) then
		return
	end
	local atTime = now()
	for plotId = 1, Farming.PLOT_COUNT do
		withPlotLock(plotId, function(plot)
			ensureCurrentLocked(plot, atTime)
		end)
	end
	pushAll(player)
end

local function handleTeleport(player: Player, rawPlotId: any)
	if shuttingDown or not canAct(player) then
		return
	end
	local plot = plotFromArgument(rawPlotId)
	if not plot then
		return
	end

	withPlotLock(plot:getId(), function(lockedPlot)
		local atTime = now()
		ensureCurrentLocked(lockedPlot, atTime)
		if lockedPlot:getOwnerUserId() ~= player.UserId or not lockedPlot:isActive(atTime) then
			reject(player, "You no longer own that plot.")
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			reject(player, "Your character is not ready to teleport.")
			return
		end

		local area = Areas.get(Areas.STARTING_AREA)
		local plotCFrame = area and Layout.farmPlotCFrame(area, lockedPlot:getId())
		if not area or not plotCFrame then
			reject(player, "That plot is not available right now.")
			return
		end

		local targetPosition = plotCFrame.Position + Vector3.new(0, Farming.PLOT_THICKNESS / 2 + 3, 0)
		local entrancePosition = Layout.farmEntranceCFrame(area).Position
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame =
			CFrame.lookAt(targetPosition, Vector3.new(entrancePosition.X, targetPosition.Y, entrancePosition.Z))
		NotifyService.send(player, string.format("Teleported to Plot %02d.", lockedPlot:getId()), "travel")
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
		local xpPerItem = BigNumber.mulNumber(Formulas.gainPerAction(profile, "kusatori"), definition.xpMultiplier)
		lockedPlot:plant({ id = cropId, plantedAt = atTime, xpPerItem = xpPerItem })
		local leaseEndsAt = lockedPlot:getLeaseEndsAt() or atTime
		local guaranteed = Farming.yieldForElapsed(cropId, leaseEndsAt - atTime)
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
		local growthSeconds = Farming.growthSeconds(crop.id)
		if not growthSeconds or atTime - crop.plantedAt < growthSeconds then
			reject(player, "This crop is not mature yet. Unfinished crops yield nothing when the lease ends.")
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

local function cropVisualColor(cropId: string, color: Color3): Color3
	local definition = Farming.cropDefinition(cropId)
	if not definition then
		return color
	end

	local hue, saturation, value = color:ToHSV()
	return Color3.fromHSV(
		hue,
		math.clamp(saturation * definition.visualSaturation, 0, 1),
		math.clamp(value * definition.visualBrightness, 0, 1)
	)
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
		cropVisualColor(cropId, Color3.fromRGB(83, 151, 68)),
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
		cropVisualColor(cropId, cropColor),
		Enum.Material.SmoothPlastic
	)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	model.Parent = parent
end

local function renderCrop(parent: Folder, cropId: string, stage: number, baseCFrame: CFrame)
	local definition = Ingredients.get(cropId)
	local farmDefinition = Farming.cropDefinition(cropId)
	local targetHeight = (if definition and definition.height then definition.height else 2.2)
		* ({ 0.4, 0.7, 1 })[stage]
	local spacing = if farmDefinition then farmDefinition.plotSpacing else 8
	local offsets = { -spacing, 0, spacing }
	local baseYaw = math.atan2(-baseCFrame.LookVector.X, -baseCFrame.LookVector.Z)
	for row, z in offsets do
		for column, x in offsets do
			local position = baseCFrame:PointToWorldSpace(Vector3.new(x, 0, z))
			local model = definition and AssetService.clone(definition.asset) or nil
			if model then
				ModelUtil.standUpright(model)
				if ModelUtil.scaleToLongest(model, targetHeight) then
					for _, descendant in model:GetDescendants() do
						if descendant:IsA("BasePart") then
							descendant.Color = cropVisualColor(cropId, descendant.Color)
							descendant.Anchored = true
							descendant.CanCollide = false
							descendant.CanQuery = false
							descendant.CanTouch = false
						end
					end
					ModelUtil.seat(
						model,
						position,
						baseYaw + math.rad((row * 47 + column * 83) % 360),
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

	for plotId, plot in plots do
		plot:Destroy()
		plots[plotId] = nil
	end
	if farmFolder then
		farmFolder:Destroy()
		farmFolder = nil
	end
	local stale = regionFolder:FindFirstChild("CommunityFarm")
	if stale then
		stale:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "CommunityFarm"
	folder.Parent = regionFolder
	farmFolder = folder
	FarmEnvironmentBuilder.build(area, folder)

	for plotId = 1, Farming.PLOT_COUNT do
		local cframe = Layout.farmPlotCFrame(area, plotId)
		assert(cframe, string.format("Farming layout is missing Plot %02d", plotId))
		plots[plotId] = FarmPlotModule.new(plotId, cframe, folder, {
			clock = now,
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
	requestStateRemote = Remotes.event("Farm", "RequestState")
	stateRemote = Remotes.event("Farm", "State")
	teleportRemote = Remotes.event("Farm", "Teleport")

	rentRemote.OnServerEvent:Connect(handleRent)
	bidRemote.OnServerEvent:Connect(handleBid)
	plantRemote.OnServerEvent:Connect(handlePlant)
	harvestRemote.OnServerEvent:Connect(handleHarvest)
	requestStateRemote.OnServerEvent:Connect(handleRequestState)
	teleportRemote.OnServerEvent:Connect(handleTeleport)
	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
		stateRequestLimiters[player] = nil
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

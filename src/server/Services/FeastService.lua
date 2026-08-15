local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local BigNumber = require(Shared.Modules.BigNumber)
local Boosts = require(Shared.Modules.Boosts)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local ModelUtil = require(Shared.Modules.ModelUtil)
local Remotes = require(Shared.Modules.Remotes)
local Feast = require(Shared.Modules.Config.Feast)
local Layout = require(Shared.Modules.Config.Layout)
local Sections = require(Shared.Modules.Config.Sections)
local AirdropService = require(script.Parent.AirdropService)
local AssetService = require(script.Parent.AssetService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local ForagingService = require(script.Parent.ForagingService)
local NotifyService = require(script.Parent.NotifyService)
local SafeZoneService = require(script.Parent.SafeZoneService)
local SkillService = require(script.Parent.SkillService)
local WorldService = require(script.Parent.WorldService)
local FeastService = {}

FeastService.TAG = "Feast"

type Food = {
	def: Feast.FoodDefinition,
	model: Model,
	center: Vector3,
	progress: number,
	bites: { [Player]: number },
	expiresAt: number,
	landed: boolean,
	home: Instance?,
	readyAt: number?,
}

local FOOTPRINT = {
	Vector2.new(1, 0),
	Vector2.new(-1, 0),
	Vector2.new(0, 1),
	Vector2.new(0, -1),
	Vector2.new(0.7, 0.7),
	Vector2.new(-0.7, -0.7),
	Vector2.new(0.7, -0.7),
	Vector2.new(-0.7, 0.7),
}

local alive: { Food } = {}
local props: { Food } = {}
local reserved: { Layout.Zone } = {}
local overlapParams = OverlapParams.new()
local groundParams = RaycastParams.new()
local rng = Random.new()
local feastEvent: RemoteEvent
local workFeedback: RemoteEvent
local folder: Folder

local function farFromOtherFood(x: number, z: number): boolean
	for _, food in alive do
		if (Vector2.new(food.center.X, food.center.Z) - Vector2.new(x, z)).Magnitude < Feast.MIN_GAP then
			return false
		end
	end
	return true
end

local function groundAt(x: number, z: number): number?
	local top = Constants.WORLD.TERRAIN_TOP + Feast.GROUND_SCAN
	local hit = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -Feast.GROUND_SCAN * 2, 0), groundParams)
	return if hit then hit.Position.Y else nil
end

local function footing(x: number, z: number, radius: number): number?
	local high = groundAt(x, z)
	if not high then
		return nil
	end

	local low = high
	for _, offset in FOOTPRINT do
		local sample = groundAt(x + offset.X * radius, z + offset.Y * radius)
		if not sample then
			return nil
		end
		high = math.max(high, sample)
		low = math.min(low, sample)
	end

	return if high - low <= Feast.GROUND_FLATNESS then high else nil
end

local function findSpot(height: number, radius: number): Vector3?
	local cells = Sections.cells()
	local margin = Feast.CELL_MARGIN + height / 2

	for _ = 1, Feast.PLACE_ATTEMPTS do
		local cell = cells[rng:NextInteger(1, #cells)]
		local x = rng:NextNumber(cell.minX + margin, cell.maxX - margin)
		local z = rng:NextNumber(cell.minZ + margin, cell.maxZ - margin)

		if Layout.isReserved(reserved, x, z) or not farFromOtherFood(x, z) then
			continue
		end

		local ground = footing(x, z, radius)
		if not ground or SafeZoneService.containsPosition(Vector3.new(x, ground + height / 2, z)) then
			continue
		end

		local box = CFrame.new(x, ground + height / 2, z)
		if #Workspace:GetPartBoundsInBox(box, Vector3.new(height, height, height), overlapParams) == 0 then
			return Vector3.new(x, ground, z)
		end
	end

	return nil
end

local function announce(def: Feast.FoodDefinition, at: Vector3)
	local cell = Sections.cellAt(at.X, at.Z)
	local theme = cell and Sections.THEMES[cell.theme]
	local where = if theme then theme.name else "the wilds"

	for _, player in Players:GetPlayers() do
		NotifyService.send(
			player,
			`A supply plane is dropping a {def.name} over {where}. Be there when it lands!`,
			"reward"
		)
	end
end

local function spawnOne()
	local def = Feast.roll(rng)
	local model = AssetService.clone(def.asset)
	if not model then
		return
	end

	ModelUtil.scaleToLongest(model, def.height)
	model.PrimaryPart = model.PrimaryPart or ModelUtil.firstPart(model)

	local _, size = ModelUtil.worldBox(model)
	local radius = math.max(size.X, size.Z) / 2
	local spot = if model.PrimaryPart then findSpot(def.height, radius) else nil
	if not spot then
		model:Destroy()
		return
	end

	model.Name = `Feast_{def.id}`
	model:SetAttribute("FeastId", def.id)
	model.Parent = folder

	local food: Food = {
		def = def,
		model = model,
		center = spot + Vector3.new(0, def.height / 2, 0),
		progress = 0,
		bites = {},
		expiresAt = os.clock() + Feast.LIFETIME,
		landed = false,
	}
	table.insert(alive, food)

	AirdropService.deliver(model, spot, rng:NextNumber(0, math.pi * 2), function()
		food.center = model:GetPivot().Position
		food.expiresAt = os.clock() + Feast.LIFETIME
		food.landed = true
		CollectionService:AddTag(model, FeastService.TAG)
	end)

	announce(def, spot)
end

local function remove(food: Food)
	local index = table.find(alive, food)
	if index then
		table.remove(alive, index)
	end
	food.model:Destroy()
end

local function adopt(model: Model)
	local def = Feast.get(model:GetAttribute("FeastId") :: string)
	if not def or not model.Parent then
		return
	end

	table.insert(props, {
		def = def,
		model = model,
		center = model:GetBoundingBox().Position,
		progress = 0,
		bites = {},
		expiresAt = math.huge,
		landed = true,
		home = model.Parent,
	})
end

local function park(food: Food)
	food.model.Parent = nil
	food.progress = 0
	table.clear(food.bites)
	food.readyAt = os.clock() + Feast.PROP_RESPAWN
end

local function regrow(now: number)
	for _, food in props do
		if food.readyAt and now >= food.readyAt then
			food.model.Parent = food.home
			food.readyAt = nil
		end
	end
end

local function tell(food: Food, kind: string)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - food.center).Magnitude <= Feast.ANNOUNCE_RADIUS then
			feastEvent:FireClient(player, kind, food.def.id, food.progress, food.def.clicks, food.center)
		end
	end
end

local function awardResilience(player: Player, profile: any, clicks: number)
	local gain = BigNumber.mulNumber(Formulas.gainPerAction(profile, "resilience"), clicks)
	SkillService.award(player, profile, "resilience", gain)
	if not BigNumber.isZero(gain) then
		workFeedback:FireClient(player, "resilience", gain)
	end
	return gain
end

local function payout(food: Food, player: Player, profile: any, share: number)
	local def = food.def
	local yen = BigNumber.mulNumber(Formulas.yenPerSecond(profile), def.wageSeconds * share)
	CurrencyService.award(profile, "yen", yen)
	Boosts.applyFood(profile, def.buff, Constants.FOOD.DURATION_TIER)

	local gain = awardResilience(player, profile, def.clicks * Feast.FINISH_XP_PER_CLICK * share)

	NotifyService.send(
		player,
		`The {def.name} is gone! You ate {math.round(share * 100)}% of it: +{BigNumber.toString(yen)} yen, +{BigNumber.toString(
			gain
		)} Resilience, and {Boosts.describeFood(def.buff)}.`,
		"reward"
	)
end

local function finish(food: Food)
	local total = 0
	for _, count in food.bites do
		total += count
	end

	if total > 0 then
		for player, count in food.bites do
			local profile = DataService.get(player)
			if profile then
				payout(food, player, profile, count / total)
			end
		end
	end

	tell(food, "done")

	if food.home then
		park(food)
	else
		remove(food)
	end
end

local function nearest(position: Vector3): Food?
	local best: Food? = nil
	local bestDist = Feast.BITE_RADIUS

	for _, list in { alive, props } do
		for _, food in list do
			local delta = food.center - position
			local dist = Vector2.new(delta.X, delta.Z).Magnitude
			if food.landed and not food.readyAt and dist < bestDist then
				bestDist = dist
				best = food
			end
		end
	end

	return best
end

function FeastService.bite(player: Player, profile: any): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local food = nearest(root.Position)
	if not food then
		return false
	end

	food.progress += 1
	food.bites[player] = (food.bites[player] or 0) + 1
	food.expiresAt = os.clock() + Feast.LIFETIME
	awardResilience(player, profile, Feast.XP_PER_BITE)

	if food.progress >= food.def.clicks then
		finish(food)
	else
		tell(food, "progress")
	end

	return true
end

local function sweep()
	while true do
		task.wait(Feast.TICK)

		local now = os.clock()
		regrow(now)

		for index = #alive, 1, -1 do
			if now >= alive[index].expiresAt then
				remove(alive[index])
			end
		end

		if #alive < Feast.MAX_ALIVE and rng:NextNumber() < Feast.SPAWN_CHANCE then
			spawnOne()
		end
	end
end

function FeastService.init()
	feastEvent = Remotes.event("Feast", "Event")
	workFeedback = Remotes.event("Work", "Feedback")

	local area = Areas.get(1)
	local regionFolder = area and WorldService.getRegionFolder(area.id)
	if not area or not regionFolder then
		warn("[FeastService] no Town region folder - did WorldService run first?")
		return
	end

	reserved = Layout.reservedZones(area)

	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = { Workspace.Terrain }

	Players.PlayerRemoving:Connect(function(player)
		for _, list in { alive, props } do
			for _, food in list do
				food.bites[player] = nil
			end
		end
	end)

	local existingFolder = regionFolder:FindFirstChild("Feast")
	if existingFolder then
		existingFolder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "Feast"
	folder:SetAttribute("RuntimeGenerated", true)
	folder.Parent = regionFolder

	task.spawn(function()
		ForagingService.awaitReady()
		WorldService.awaitDressed()

		overlapParams.FilterType = Enum.RaycastFilterType.Include
		overlapParams.FilterDescendantsInstances = { regionFolder }

		for _, model in CollectionService:GetTagged(Feast.PROP_TAG) do
			if model:IsA("Model") then
				adopt(model)
			end
		end

		sweep()
	end)
end

return FeastService

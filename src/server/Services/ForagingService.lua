local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local ModelUtil = require(Shared.Modules.ModelUtil)
local Remotes = require(Shared.Modules.Remotes)
local Areas = require(Shared.Areas)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)
local Budget = require(Shared.Modules.Budget)
local AssetService = require(script.Parent.AssetService)
local CurrencyService = require(script.Parent.CurrencyService)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)
local WorldService = require(script.Parent.WorldService)
local ForagingService = {}
local FORAGE = Constants.FORAGE

ForagingService.TAG = "Forage"
ForagingService.PULL_RADIUS = FORAGE.PULL_RADIUS

export type Node = {
	model: Model,
	ingredient: Ingredients.IngredientDefinition,
	center: Vector3,
	transparency: { [BasePart]: number },
	solid: { [BasePart]: boolean },
	pulled: boolean,
	retired: boolean?,
	progress: { [Player]: number },
	clicks: number,
	yield: number,
}

export type PlantOptions = {
	parent: Instance,
	height: number?,
	clicks: number?,
	yield: number?,
	yaw: number?,
	dirt: boolean?,
	upright: boolean?,
	roll: number?,
	sink: number?,
	collide: boolean?,
	glow: boolean?,
}

local nodes: { [Node]: boolean } = {}
local BUCKET = 32
local BUCKET_STRIDE = 100000
local buckets: { [number]: { [Node]: boolean } } = {}
local nodeBucketKeys: { [Node]: number } = {}

local function bucketKey(gx: number, gz: number): number
	return gx * BUCKET_STRIDE + gz
end

local function registerNode(node: Node)
	nodes[node] = true

	local key = bucketKey(math.floor(node.center.X / BUCKET), math.floor(node.center.Z / BUCKET))
	local bucket = buckets[key]
	if not bucket then
		bucket = {}
		buckets[key] = bucket
	end
	bucket[node] = true
	nodeBucketKeys[node] = key
end

local function unregisterNode(node: Node)
	nodes[node] = nil
	node.progress = {}

	local key = nodeBucketKeys[node]
	if key then
		local bucket = buckets[key]
		if bucket then
			bucket[node] = nil
			if next(bucket) == nil then
				buckets[key] = nil
			end
		end
		nodeBucketKeys[node] = nil
	end

	CollectionService:RemoveTag(node.model, ForagingService.TAG)
	node.model:Destroy()
end

local forageEvent: RemoteEvent
local groundParams: RaycastParams
local groundTop = 0
local readySignal = Instance.new("BindableEvent")
local ready = false

function ForagingService.awaitReady()
	if ready then
		return
	end
	readySignal.Event:Wait()
end

local pulledCallbacks: { (Player, Ingredients.IngredientDefinition, number) -> () } = {}

function ForagingService.onPulled(callback: (Player, Ingredients.IngredientDefinition, number) -> ())
	table.insert(pulledCallbacks, callback)
end

local function setGlow(model: Model, on: boolean)
	local light = model:FindFirstChild("Glow", true)
	if light and light:IsA("PointLight") then
		light.Enabled = on
	end
end

local function clicksNeeded(profile: any, node: Node): number
	local def = node.ingredient
	local exponent = math.floor(BigNumber.log10(profile.skills.kusatori))
	return node.clicks + FORAGE.CLICKS_PER_EXPONENT_BEHIND * math.max(0, def.gateExponent - exponent)
end

local function harvest(player: Player, profile: any, node: Node)
	local def = node.ingredient
	local yield = node.yield

	node.progress = {}
	node.pulled = true

	profile.currencies.ingredients[def.id] = (profile.currencies.ingredients[def.id] or 0) + yield

	local gain = BigNumber.mulNumber(Formulas.gainPerAction(profile, "kusatori"), def.xpMultiplier * yield)
	SkillService.award(player, profile, "kusatori", gain)

	local yen = Formulas.yenForGain("kusatori", gain)
	if not BigNumber.isZero(yen) then
		CurrencyService.award(profile, "yen", yen)
	end

	forageEvent:FireClient(player, "success", def.id, gain, node.center)

	for _, callback in pulledCallbacks do
		task.spawn(callback, player, def, yield)
	end

	if def.rarity == "super" or def.rarity == "legendary" then
		local suffix = if yield > 1 then ` x{yield}` else ""
		NotifyService.send(player, `Foraged {def.name}{suffix}!`, "reward")
	end

	for part in node.transparency do
		if part.Parent then
			part.Transparency = 1
			part.CanCollide = false
		end
	end
	CollectionService:RemoveTag(node.model, ForagingService.TAG)

	setGlow(node.model, false)

	task.delay(def.regrowSeconds, function()
		if node.retired then
			return
		end
		node.pulled = false
		for part, original in node.transparency do
			if part.Parent then
				part.Transparency = original
				part.CanCollide = node.solid[part] == true
			end
		end
		if node.model.Parent then
			CollectionService:AddTag(node.model, ForagingService.TAG)
		end
		setGlow(node.model, true)
	end)
end

function ForagingService.clearArea(centre: Vector3, radius: number)
	for node in nodes do
		if node.retired then
			continue
		end
		local planar = Vector3.new(node.center.X - centre.X, 0, node.center.Z - centre.Z).Magnitude
		if planar > radius then
			continue
		end

		node.retired = true
		node.pulled = true
		table.clear(node.transparency)
		table.clear(node.solid)
		unregisterNode(node)
	end
end

function ForagingService.nearestPullable(position: Vector3, maxDist: number): Node?
	local best: Node? = nil
	local bestDist = maxDist
	local minX = math.floor((position.X - maxDist) / BUCKET)
	local maxX = math.floor((position.X + maxDist) / BUCKET)
	local minZ = math.floor((position.Z - maxDist) / BUCKET)
	local maxZ = math.floor((position.Z + maxDist) / BUCKET)

	for gx = minX, maxX do
		for gz = minZ, maxZ do
			local bucket = buckets[bucketKey(gx, gz)]
			if not bucket then
				continue
			end
			for node in bucket do
				if node.pulled or node.retired then
					continue
				end
				local delta = node.center - position
				local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if dist < bestDist then
					bestDist = dist
					best = node
				end
			end
		end
	end

	return best
end

function ForagingService.pull(player: Player, profile: any, node: Node): boolean
	if node.pulled then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local def = node.ingredient
	local current = (node.progress[player] or 0) + 1
	node.progress[player] = current

	character:SetAttribute("ForageClip", def.clip)
	character:SetAttribute("ForageClipAt", os.clock())

	local needed = clicksNeeded(profile, node)
	if current >= needed then
		harvest(player, profile, node)
	else
		forageEvent:FireClient(player, "progress", def.id, current, needed, node.center)
	end

	return true
end

local function groundAt(x: number, z: number, top: number, params: RaycastParams): number
	local hit = Workspace:Raycast(Vector3.new(x, top + 80, z), Vector3.new(0, -260, 0), params)
	return if hit then hit.Position.Y else top
end

function ForagingService.groundAt(x: number, z: number): number
	return groundAt(x, z, groundTop, groundParams)
end

local function buildDirt(parent: Instance, position: Vector3, rng: Random)
	local size = FORAGE.DIRT_PATCH_SIZE * rng:NextNumber(0.85, 1.2)
	local dirt = Instance.new("Part")
	dirt.Name = "Soil"
	dirt.Shape = Enum.PartType.Cylinder
	dirt.Size = Vector3.new(0.4, size, size)
	dirt.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	dirt.Color = Color3.fromRGB(122, 92, 66)
	dirt.Material = Enum.Material.Ground
	dirt.Anchored = true
	dirt.CanCollide = false
	dirt.CanQuery = false
	dirt.CanTouch = false
	dirt.CastShadow = false
	dirt.Parent = parent
end

local GLOW_COLOR = Color3.fromRGB(178, 226, 208)

local function lightUp(model: Model)
	local widest: BasePart? = nil
	local widestSize = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Material = Enum.Material.Neon
			descendant.Color = descendant.Color:Lerp(GLOW_COLOR, 0.45)
			local size = descendant.Size.X * descendant.Size.Z
			if size > widestSize then
				widest, widestSize = descendant, size
			end
		end
	end
	if not widest then
		return
	end

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Brightness = 1.6
	light.Range = 26
	light.Color = GLOW_COLOR
	light.Shadows = false
	light.Parent = widest
end

function ForagingService.plant(def: Ingredients.IngredientDefinition, position: Vector3, options: PlantOptions): Node?
	local model = AssetService.clone(def.asset)
	if not model then
		warn(`[ForagingService] no model for "{def.asset}" ({def.id}) - skipping node`)
		return nil
	end

	model.Name = `Forage_{def.id}`
	model:SetAttribute("IngredientId", def.id)

	if options.upright ~= false then
		ModelUtil.standUpright(model)
	end

	local height = options.height or def.height
	if height then
		ModelUtil.scaleToLongest(model, height)
	end

	model.PrimaryPart = model.PrimaryPart or ModelUtil.firstPart(model)
	if not model.PrimaryPart then
		warn(`[ForagingService] "{def.asset}" has no parts - skipping node`)
		model:Destroy()
		return nil
	end

	if options.dirt then
		buildDirt(options.parent, position, Random.new(math.floor(position.X * 73 + position.Z)))
	end

	ModelUtil.seat(model, position, options.yaw or 0, options.roll, options.sink)
	model.Parent = options.parent

	CollectionService:AddTag(model, ForagingService.TAG)

	if options.glow then
		lightUp(model)
	end

	local transparency: { [BasePart]: number } = {}
	local solid: { [BasePart]: boolean } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if options.collide ~= nil then
				descendant.CanCollide = options.collide
			end
			transparency[descendant] = descendant.Transparency
			solid[descendant] = descendant.CanCollide
		end
	end

	local node: Node = {
		model = model,
		ingredient = def,
		center = model:GetPivot().Position,
		transparency = transparency,
		solid = solid,
		pulled = false,
		progress = {},
		clicks = options.clicks or def.minClicks,
		yield = options.yield or 1,
	}
	registerNode(node)

	return node
end

local JITTER_SCALE = 19

local function drift(x: number, z: number, seed: number, reach: number): (number, number)
	return math.noise(x / JITTER_SCALE, z / JITTER_SCALE, seed) * reach,
		math.noise(z / JITTER_SCALE, x / JITTER_SCALE, seed + 41) * reach
end

local function buildPlot(
	plot: Ingredients.PlotDefinition,
	parent: Instance,
	params: RaycastParams,
	top: number,
	step: () -> ()
)
	local area = Areas.get(1)
	local centre = area and Layout.plotCentre(area, plot)
	if not area or not centre then
		warn(`[ForagingService] plot "{plot.id}" names section "{plot.cell}" which does not exist - skipped`)
		return
	end

	local def = Ingredients.get(plot.ingredient)
	if not def then
		warn(`[ForagingService] plot "{plot.id}" names unknown ingredient "{plot.ingredient}" - skipped`)
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = plot.id
	folder:SetAttribute("PlotName", plot.name)
	folder:SetAttribute("IngredientId", def.id)

	local yaw = math.rad(plot.yaw)
	local cosYaw, sinYaw = math.cos(yaw), math.sin(yaw)
	local halfDepth = (plot.rows - 1) * plot.rowSpacing / 2
	local halfWidth = (plot.columns - 1) * plot.columnSpacing / 2
	local seed = 0
	for index = 1, #plot.id do
		seed += string.byte(plot.id, index) * index
	end
	seed %= 512

	local planted = 0
	for row = 1, plot.rows do
		local alongRow = (row - 1) * plot.rowSpacing - halfDepth
		local half = plot.stagger * plot.columnSpacing / 2
		local lean = if row % 2 == 0 then half else -half

		for column = 1, plot.columns do
			step()
			local acrossRow = (column - 1) * plot.columnSpacing - halfWidth + lean
			local localX = acrossRow * cosYaw - alongRow * sinYaw
			local localZ = acrossRow * sinYaw + alongRow * cosYaw
			local driftX, driftZ = drift(localX, localZ, seed, plot.jitter)
			local x = centre.X + localX + driftX
			local z = centre.Z + localZ + driftZ

			local node = ForagingService.plant(def, Vector3.new(x, groundAt(x, z, top, params), z), {
				parent = folder,
				dirt = def.ground,
				yaw = yaw + math.noise(x / JITTER_SCALE, z / JITTER_SCALE, seed + 97) * 0.5,
			})
			if node then
				planted += 1
			end
		end
	end

	folder:SetAttribute("NodeCount", planted)
	folder.Parent = parent

	if planted == 0 then
		warn(`[ForagingService] plot "{plot.id}" planted nothing - is the "{def.asset}" model missing?`)
	end
end

local function seedOf(id: string): number
	local sum = 0
	for index = 1, #id do
		sum += string.byte(id, index) * index
	end
	return sum
end

local function buildZone(
	zone: Ingredients.ZoneDefinition,
	parent: Instance,
	params: RaycastParams,
	top: number,
	step: () -> ()
)
	local area = Areas.get(1)
	if not area then
		return
	end

	local rng = Random.new(seedOf(zone.id))
	local centre = Layout.forageZoneCentre(area, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	for index, ingredientId in Ingredients.clumpPlan(zone) do
		local def = Ingredients.get(ingredientId)
		if not def then
			continue
		end

		local angle = (index / zone.clumps) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local reach = zone.radius * rng:NextNumber(0.35, 1)
		local clumpX = centre.X + math.cos(angle) * reach
		local clumpZ = centre.Z + math.sin(angle) * reach

		for _ = 1, zone.perClump do
			step()
			local x = clumpX + rng:NextNumber(-FORAGE.CLUMP_SPREAD, FORAGE.CLUMP_SPREAD)
			local z = clumpZ + rng:NextNumber(-FORAGE.CLUMP_SPREAD, FORAGE.CLUMP_SPREAD)
			ForagingService.plant(def, Vector3.new(x, groundAt(x, z, top, params), z), {
				parent = folder,
				yaw = rng:NextNumber(0, math.pi * 2),
				dirt = def.ground,
			})
		end
	end
end

function ForagingService.init()
	forageEvent = Remotes.event("Forage", "Event")

	local area = Areas.get(1)
	local regionFolder = area and WorldService.getRegionFolder(area.id)
	if not area or not regionFolder then
		warn("[ForagingService] no Town region folder - did WorldService run first?")
		return
	end

	local existingGroves = regionFolder:FindFirstChild("Forage")
	if existingGroves then
		existingGroves:Destroy()
	end

	local groves = Instance.new("Folder")
	groves.Name = "Forage"
	groves:SetAttribute("RuntimeGenerated", true)
	groves.Parent = regionFolder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { regionFolder }
	groundParams = params
	groundTop = Layout.plazaCFrame(area).Position.Y

	task.spawn(function()
		TerrainBuilder.awaitReady()
		local step = Budget.stepper()

		for _, plot in Ingredients.PLOTS do
			local ok, err = pcall(buildPlot, plot, groves, params, groundTop, step)
			if not ok then
				warn(`[ForagingService] plot "{plot.id}" failed: {err}`)
			end
		end

		for _, zone in Ingredients.ZONES do
			local ok, err = pcall(buildZone, zone, groves, params, groundTop, step)
			if not ok then
				warn(`[ForagingService] zone "{zone.id}" failed: {err}`)
			end
		end

		ready = true
		readySignal:Fire()
	end)

	Players.PlayerRemoving:Connect(function(player)
		for node in nodes do
			node.progress[player] = nil
		end
	end)
end

return ForagingService

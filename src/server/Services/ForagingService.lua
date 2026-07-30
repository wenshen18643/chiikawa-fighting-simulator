--[[
	The things that grow in Town, and pulling them out of the ground.

	--------------------------------------------------------------------------------
	IT IS THE WEED MECHANIC
	--------------------------------------------------------------------------------

	A forage node is pulled with the Work click, not a prompt: stand near it
	with Kusatori selected and click, exactly as you would a weed. WorkService
	owns that click and asks this module for the nearest node, so there is one
	rule for "what does clicking do here" instead of two competing ones.

	Where things grow is Config/Ingredients ZONES. Nodes come in clumps of one
	ingredient so a grove reads as a carrot patch rather than a salad, and a
	clump is pulled node by node — each one is its own small commitment.

	Ground crops (carrot, potato) leave their dug soil behind when taken. The
	dirt patch is the memory of the plant: it says something grew here and will
	again, which an empty lawn does not.

	Home Fields is the dynamic exception to ordinary node regrowth: its six
	clumps stay depleted node by node, then the cleared clump moves and rerolls as
	one crop after that crop's delay. The other forage zones still regrow in place.
]]

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
	progress: { [Player]: number },
	clicks: number, -- base clicks for THIS node: a bigger tree costs more
	yield: number, -- how many ingredients one pull pays
}

export type PlantOptions = {
	parent: Instance,
	height: number?, -- longest dimension once placed: height standing, length lying
	clicks: number?,
	yield: number?,
	yaw: number?,
	dirt: boolean?,
	upright: boolean?, -- false leaves it lying where the asset was authored
	roll: number?,
	sink: number?, -- fraction of its own height settled into the ground
	collide: boolean?, -- true/false forces every part; nil keeps the asset's own
}

type DynamicClump = {
	slot: number,
	folder: Folder?,
	nodes: { [Node]: boolean },
	remaining: number,
	centre: Vector3?,
	ingredient: Ingredients.IngredientDefinition?,
	generation: number,
}

type DynamicZoneRuntime = {
	definition: Ingredients.ZoneDefinition,
	folder: Folder,
	centre: Vector3,
	params: RaycastParams,
	top: number,
	rng: Random,
	clumps: { DynamicClump },
}

local nodes: { [Node]: boolean } = {}

--[[
	Nodes bucketed on a flat grid as well as listed.

	Every Work click asks for the nearest node, and the forest alone is ~900 of
	them, so a scan of the whole list runs on every click of every player. The
	pull radius is smaller than one bucket, so the answer is always inside four
	of them. Fixed nodes stay in place, but dynamic Home Fields clumps are removed
	and rebuilt. Set-shaped buckets prevent stale nodes after repeated rerolls.
]]
local BUCKET = 32
local BUCKET_STRIDE = 100000 -- > any grid index the island can reach
local buckets: { [number]: { [Node]: boolean } } = {}
local nodeBucketKeys: { [Node]: number } = {}
local nodeClumps: { [Node]: DynamicClump } = {}
local clumpRuntimes: { [DynamicClump]: DynamicZoneRuntime } = {}

local CLUMP_PLACEMENT_ATTEMPTS = 32
local NODE_PLACEMENT_ATTEMPTS = 24
local NODE_MIN_SPACING = 3
local CLUMP_RESPAWN_ATTEMPTS = 3
local CLUMP_RESPAWN_RETRY_SECONDS = 5

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
	nodeClumps[node] = nil
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
local onClumpNodeHarvested: ((Node) -> boolean)? = nil

ForagingService.ready = false

-- Yields until the ground is measurable and the zones are planted. Anything
-- that plants its own nodes waits on this rather than racing the terrain pass.
function ForagingService.awaitReady()
	if ForagingService.ready then
		return
	end
	readySignal.Event:Wait()
end

--------------------------------------------------------------------------------
-- Pulling
--------------------------------------------------------------------------------

local function clicksNeeded(profile: any, node: Node): number
	local def = node.ingredient
	local exponent = math.floor(BigNumber.log10(profile.skills.kusatori))
	return node.clicks + FORAGE.CLICKS_PER_EXPONENT_BEHIND * math.max(0, def.gateExponent - exponent)
end

local function harvest(player: Player, profile: any, node: Node)
	local def = node.ingredient
	local yield = node.yield

	-- A finished node resets for everyone, not just whoever landed the last click.
	node.progress = {}
	node.pulled = true

	profile.currencies.ingredients[def.id] = (profile.currencies.ingredients[def.id] or 0) + yield

	local gain = BigNumber.mulNumber(Formulas.gainPerAction(profile, "kusatori", nil), def.xpMultiplier * yield)
	SkillService.award(player, profile, "kusatori", gain)

	local yen = Formulas.yenForGain("kusatori", gain)
	if not BigNumber.isZero(yen) then
		CurrencyService.award(profile, "yen", yen)
	end

	forageEvent:FireClient(player, "success", def.id, gain, node.center)

	if def.rarity == "super" or def.rarity == "legendary" then
		local suffix = if yield > 1 then ` x{yield}` else ""
		NotifyService.send(player, `Foraged {def.name}{suffix}!`, "reward")
	end

	-- Collision goes with the picture. A pulled tree that is still solid is an
	-- invisible wall in the middle of a forest you are trying to walk through.
	for part in node.transparency do
		if part.Parent then
			part.Transparency = 1
			part.CanCollide = false
		end
	end
	CollectionService:RemoveTag(node.model, ForagingService.TAG)

	if onClumpNodeHarvested and onClumpNodeHarvested(node) then
		return
	end

	task.delay(def.regrowSeconds, function()
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
	end)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

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
				if node.pulled then
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

--[[
	One click on `node`. Returns true when the click was spent on it.

	The caller still credits the click as ordinary Kusatori work — every click
	pays, and finishing the node pays again on top. Being close to done is not
	worth less than standing on a lawn.
]]
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

	-- Spectators watch the gesture through the character; the local player's
	-- own clip is started client-side so it does not wait for the round trip.
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

--------------------------------------------------------------------------------
-- Building the zones
--------------------------------------------------------------------------------

local function groundAt(x: number, z: number, top: number, params: RaycastParams): number
	local hit = Workspace:Raycast(Vector3.new(x, top + 80, z), Vector3.new(0, -260, 0), params)
	return if hit then hit.Position.Y else top
end

-- Terrain height, ignoring everything already placed in the region.
function ForagingService.groundAt(x: number, z: number): number
	return groundAt(x, z, groundTop, groundParams)
end

--[[
	The dug soil a ground crop sits in.

	Built as a flat disc rather than terrain: terrain edits are permanent, and a
	crop that regrows would have to fill its own hole back in. A dark disc under
	the leaves reads as turned earth and costs one part.
]]
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

--[[
	Grow one pullable node.

	Public because the sausage forest lays its trees out by board section rather
	than by zone: it picks size, clicks and yield per tree, and this stays the
	one place that knows how a node is built and registered.
]]
function ForagingService.plant(
	def: Ingredients.IngredientDefinition,
	position: Vector3,
	options: PlantOptions
): Node?
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

	-- Sized against the player rather than against whatever the author uploaded:
	-- a two-storey carrot and a thumbnail sausage tree both break the scene.
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

	-- The client finds the nearest of these to start the right dig animation
	-- before the server has answered.
	CollectionService:AddTag(model, ForagingService.TAG)

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

local function flatDistance(a: Vector3, b: Vector3): number
	local delta = a - b
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function randomDiskOffset(rng: Random, radius: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local reach = math.sqrt(rng:NextNumber()) * radius
	return Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
end

local function nearestClumpDistance(runtime: DynamicZoneRuntime, candidate: Vector3, ignore: DynamicClump): number
	local nearest = math.huge
	for _, other in runtime.clumps do
		if other ~= ignore and other.centre then
			nearest = math.min(nearest, flatDistance(candidate, other.centre))
		end
	end
	return nearest
end

-- Pick inside the field after subtracting the node spread, so every crop in a
-- clump stays inside the configured radius. If the requested spacing cannot be
-- met in bounded attempts, the best-separated candidate still fills the slot.
local function chooseClumpCentre(runtime: DynamicZoneRuntime, clump: DynamicClump): Vector3
	local zone = runtime.definition
	local radius = math.max(zone.radius - FORAGE.CLUMP_SPREAD, 0)
	local spacing = zone.minClumpSpacing or 0
	local best = runtime.centre
	local bestDistance = -math.huge

	for _ = 1, CLUMP_PLACEMENT_ATTEMPTS do
		local candidate = runtime.centre + randomDiskOffset(runtime.rng, radius)
		local distance = nearestClumpDistance(runtime, candidate, clump)
		if distance > bestDistance then
			best = candidate
			bestDistance = distance
		end
		if distance >= spacing then
			return candidate
		end
	end

	return best
end

local function nearestOffsetDistance(candidate: Vector3, offsets: { Vector3 }): number
	local nearest = math.huge
	for _, offset in offsets do
		nearest = math.min(nearest, flatDistance(candidate, offset))
	end
	return nearest
end

local function chooseNodeOffset(rng: Random, offsets: { Vector3 }): Vector3
	local best = Vector3.zero
	local bestDistance = -math.huge

	for _ = 1, NODE_PLACEMENT_ATTEMPTS do
		local candidate = randomDiskOffset(rng, FORAGE.CLUMP_SPREAD)
		local distance = nearestOffsetDistance(candidate, offsets)
		if distance > bestDistance then
			best = candidate
			bestDistance = distance
		end
		if distance >= NODE_MIN_SPACING then
			return candidate
		end
	end

	return best
end

local function clearDynamicClump(clump: DynamicClump)
	local folder = clump.folder
	for node in clump.nodes do
		unregisterNode(node)
	end

	clump.folder = nil
	clump.nodes = {}
	clump.remaining = 0
	clump.centre = nil
	clump.ingredient = nil

	if folder then
		folder:Destroy()
	end
end

local function populateDynamicClump(runtime: DynamicZoneRuntime, clump: DynamicClump): boolean
	local ingredientId = Ingredients.rollIngredient(runtime.definition, runtime.rng)
	local def = ingredientId and Ingredients.get(ingredientId)
	if not def then
		warn(`[ForagingService] zone "{runtime.definition.id}" rolled an unknown ingredient - clump omitted`)
		return false
	end

	local centre = chooseClumpCentre(runtime, clump)
	local folder = Instance.new("Folder")
	folder.Name = string.format("Clump_%02d_%s", clump.slot, def.id)
	folder:SetAttribute("ForageZoneId", runtime.definition.id)
	folder:SetAttribute("ClumpSlot", clump.slot)
	folder:SetAttribute("IngredientId", def.id)
	folder:SetAttribute("NodeCount", runtime.definition.perClump)

	local offsets: { Vector3 } = {}
	local planted: { [Node]: boolean } = {}
	for _ = 1, runtime.definition.perClump do
		local offset = chooseNodeOffset(runtime.rng, offsets)
		table.insert(offsets, offset)

		local x, z = centre.X + offset.X, centre.Z + offset.Z
		local node = ForagingService.plant(def, Vector3.new(x, groundAt(x, z, runtime.top, runtime.params), z), {
			parent = folder,
			yaw = runtime.rng:NextNumber(0, math.pi * 2),
			dirt = def.ground,
		})
		if not node then
			for previous in planted do
				unregisterNode(previous)
			end
			folder:Destroy()
			return false
		end

		planted[node] = true
		nodeClumps[node] = clump
	end

	clump.folder = folder
	clump.nodes = planted
	clump.remaining = runtime.definition.perClump
	clump.centre = centre
	clump.ingredient = def
	folder.Parent = runtime.folder
	return true
end

local function attemptPopulateDynamicClump(
	runtime: DynamicZoneRuntime,
	clump: DynamicClump,
	attempt: number,
	generation: number
)
	if clump.generation ~= generation then
		return
	end
	if populateDynamicClump(runtime, clump) then
		return
	end

	if attempt >= CLUMP_RESPAWN_ATTEMPTS then
		warn(
			`[ForagingService] gave up filling {runtime.definition.id} clump {clump.slot} `
				.. `after {CLUMP_RESPAWN_ATTEMPTS} attempts`
		)
		return
	end

	task.delay(CLUMP_RESPAWN_RETRY_SECONDS, function()
		attemptPopulateDynamicClump(runtime, clump, attempt + 1, generation)
	end)
end

onClumpNodeHarvested = function(node: Node): boolean
	local clump = nodeClumps[node]
	if not clump then
		return false
	end
	if clump.remaining <= 0 then
		return true
	end

	clump.remaining -= 1
	if clump.remaining > 0 then
		-- Deliberate scarcity: dynamic clumps do not refill individual nodes.
		return true
	end

	local runtime = clumpRuntimes[clump]
	local def = clump.ingredient or node.ingredient
	clump.generation += 1
	local generation = clump.generation
	clearDynamicClump(clump)

	if not runtime then
		warn(`[ForagingService] dynamic clump {clump.slot} lost its zone runtime and cannot respawn`)
		return true
	end

	task.delay(def.regrowSeconds, function()
		attemptPopulateDynamicClump(runtime, clump, 1, generation)
	end)
	return true
end

local function buildDynamicZone(
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

	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	local runtime: DynamicZoneRuntime = {
		definition = zone,
		folder = folder,
		centre = Layout.forageZoneCentre(area, zone),
		params = params,
		top = top,
		rng = Random.new(),
		clumps = {},
	}

	for slot = 1, zone.clumps do
		step()
		local clump: DynamicClump = {
			slot = slot,
			folder = nil,
			nodes = {},
			remaining = 0,
			centre = nil,
			ingredient = nil,
			generation = 1,
		}
		table.insert(runtime.clumps, clump)
		clumpRuntimes[clump] = runtime
		attemptPopulateDynamicClump(runtime, clump, 1, clump.generation)
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
	if zone.lifecycle == "clump-reroll" then
		buildDynamicZone(zone, parent, params, top, step)
		return
	end

	-- Seeded per zone: the same grove on every server, and moving one zone in
	-- config does not reshuffle the others.
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

		-- Clumps ring the zone centre; the ring is what keeps two clumps from
		-- landing on top of each other while a plain random scatter would.
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

	local groves = Instance.new("Folder")
	groves.Name = "Forage"
	groves.Parent = regionFolder

	-- Exclude the whole region folder so a node stands on terrain rather than
	-- on a pad, a hut roof or an already-placed bush.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { regionFolder }
	groundParams = params
	groundTop = Layout.plazaCFrame(area).Position.Y

	--[[
		Off the boot path and behind the terrain pass. Section relief is built on
		a background task, and a node seated before the hills arrive is a node
		buried in one -- every plant here is placed by a raycast against ground
		that has to exist first.
	]]
	task.spawn(function()
		TerrainBuilder.awaitReady()
		local step = Budget.stepper()
		for _, zone in Ingredients.ZONES do
			buildZone(zone, groves, params, groundTop, step)
		end
		ForagingService.ready = true
		readySignal:Fire()
	end)

	Players.PlayerRemoving:Connect(function(player)
		for node in nodes do
			node.progress[player] = nil
		end
	end)
end

return ForagingService

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Budget = require(Shared.Modules.Budget)
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Cave = require(Shared.Modules.Config.Cave)
local Layout = require(Shared.Modules.Config.Layout)
local UI = require(Shared.UI)
local AssetService = require(script.Parent.AssetService)
local NotifyService = require(script.Parent.NotifyService)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local WorldService = {}
local WORLD = Constants.WORLD
local regionSpawns: { [number]: CFrame } = {}
local worldFolder: Folder
local dressedSignal = Instance.new("BindableEvent")
local dressed = false

function WorldService.awaitDressed()
	if dressed then
		return
	end
	dressedSignal.Event:Wait()
end

local ACCESS_PREFIX = "Access_"
local GATE_PREFIX = "Gate_"
local collisionGroupsReady = false

function WorldService.accessGroupFor(highestUnlocked: number): string
	return ACCESS_PREFIX .. math.clamp(highestUnlocked, 1, #Areas.ALL)
end

function WorldService.setCharacterAccess(character: Model, highestUnlocked: number)
	if not collisionGroupsReady then
		return
	end

	local group = WorldService.accessGroupFor(highestUnlocked)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end

local function registerGroup(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

local function buildCollisionMatrix()
	for _, area in Areas.ALL do
		registerGroup(ACCESS_PREFIX .. area.id)
		if area.id > 1 then
			registerGroup(GATE_PREFIX .. area.id)
		end
	end

	for _, access in Areas.ALL do
		local accessGroup = ACCESS_PREFIX .. access.id

		for _, other in Areas.ALL do
			PhysicsService:CollisionGroupSetCollidable(accessGroup, ACCESS_PREFIX .. other.id, false)
		end

		for _, gated in Areas.ALL do
			if gated.id > 1 then
				PhysicsService:CollisionGroupSetCollidable(accessGroup, GATE_PREFIX .. gated.id, gated.id > access.id)
			end
		end
	end
end

local function configureCollisionGroups()
	local ok, err = pcall(buildCollisionMatrix)
	collisionGroupsReady = ok

	if not ok then
		warn(
			`[WorldService] collision groups unavailable ({err}). Area gates will not be solid; `
				.. "you can walk into an area you have not unlocked, but working there still pays nothing."
		)
	end
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function buildWallSide(
	area: Areas.AreaDefinition,
	parent: Folder,
	name: string,
	offset: Vector3,
	axis: string,
	gapWidth: number
)
	local span = area.terrain.islandSize
	local thickness = WORLD.WALL_THICKNESS
	local wallHeight = WORLD.WALL_HEIGHT
	local segments: { { centre: number, length: number } } = {}
	if gapWidth <= 0 then
		table.insert(segments, { centre = 0, length = span })
	else
		local stub = (span - gapWidth) / 2
		if stub > 0 then
			table.insert(segments, { centre = -(gapWidth / 2 + stub / 2), length = stub })
			table.insert(segments, { centre = gapWidth / 2 + stub / 2, length = stub })
		end
	end

	for index, segment in segments do
		local along = if axis == "x" then Vector3.new(segment.centre, 0, 0) else Vector3.new(0, 0, segment.centre)
		local footprint = if axis == "x"
			then Vector3.new(segment.length, 1, thickness)
			else Vector3.new(thickness, 1, segment.length)

		part({
			Name = `{name}_Wall_{index}`,
			Size = Vector3.new(footprint.X, wallHeight, footprint.Z),
			Position = area.origin + offset + along + Vector3.new(0, WORLD.TERRAIN_TOP + wallHeight / 2, 0),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false,
			Parent = parent,
		})
	end
end

local FENCE = {
	SPACING = 18,
	HEIGHT = 7,
	POST = 1.3,
	INSET = 6,
	RAIL = 0.6,
	RAIL_SEGMENT = 180,
	POST_COLOR = Color3.fromRGB(253, 250, 246),
	CAP_COLOR = Color3.fromRGB(244, 186, 190),
}

local function buildFenceRun(parent: Folder, from: Vector3, to: Vector3, step: (() -> ())?)
	local span = to - from
	local length = span.Magnitude
	if length < FENCE.SPACING then
		return
	end

	local direction = span.Unit
	local yaw = math.atan2(direction.X, direction.Z)
	local posts = math.max(1, math.round(length / FENCE.SPACING))

	for index = 0, posts do
		local at = from + direction * (length * index / posts)
		if step then
			step()
		end
		part({
			Name = "FencePost",
			Size = Vector3.new(FENCE.POST, FENCE.HEIGHT, FENCE.POST),
			Position = at + Vector3.new(0, FENCE.HEIGHT / 2, 0),
			Color = FENCE.POST_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = parent,
		})
		part({
			Name = "FenceCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(FENCE.POST * 1.5, FENCE.POST * 1.5, FENCE.POST * 1.5),
			Position = at + Vector3.new(0, FENCE.HEIGHT, 0),
			Color = FENCE.CAP_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = parent,
		})
	end

	local segments = math.max(1, math.ceil(length / FENCE.RAIL_SEGMENT))
	local segmentLength = length / segments

	for segment = 0, segments - 1 do
		local centre = from + direction * (segment * segmentLength + segmentLength / 2)
		for _, fraction in { 0.38, 0.74 } do
			part({
				Name = "FenceRail",
				Size = Vector3.new(FENCE.RAIL, FENCE.RAIL, segmentLength),
				CFrame = CFrame.new(centre + Vector3.new(0, FENCE.HEIGHT * fraction, 0)) * CFrame.Angles(0, yaw, 0),
				Color = FENCE.POST_COLOR,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Parent = parent,
			})
		end
	end
end

local function buildFenceGate(parent: Folder, at: Vector3, yaw: number)
	local width = 16
	local height = FENCE.HEIGHT * 1.5
	local base = CFrame.new(at) * CFrame.Angles(0, yaw, 0)

	for _, side in { -1, 1 } do
		part({
			Name = "GatePost",
			Size = Vector3.new(FENCE.POST * 1.6, height, FENCE.POST * 1.6),
			CFrame = base * CFrame.new(side * width / 2, height / 2, 0),
			Color = FENCE.POST_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = parent,
		})
		part({
			Name = "GateFinial",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = base * CFrame.new(side * width / 2, height + 0.6, 0),
			Color = FENCE.CAP_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = parent,
		})

		part({
			Name = "GateLeaf",
			Size = Vector3.new(0.5, FENCE.HEIGHT, width / 2),
			CFrame = base
				* CFrame.new(side * width / 2, FENCE.HEIGHT / 2, 0)
				* CFrame.Angles(0, side * math.rad(70), 0)
				* CFrame.new(0, 0, -width / 4),
			Color = FENCE.POST_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = parent,
		})
	end

	part({
		Name = "GateLintel",
		Size = Vector3.new(width + 3, 1.4, 1.4),
		CFrame = base * CFrame.new(0, height, 0),
		Color = FENCE.CAP_COLOR,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = parent,
	})
end

local function buildWalls(area: Areas.AreaDefinition, parent: Folder, hasWestBridge: boolean)
	local half = Layout.halfSize(area)
	local bridgeGap = WORLD.BRIDGE_WIDTH

	buildWallSide(area, parent, "North", Vector3.new(0, 0, half), "x", 0)
	buildWallSide(area, parent, "South", Vector3.new(0, 0, -half), "x", 0)
	buildWallSide(area, parent, "West", Vector3.new(-half, 0, 0), "z", if hasWestBridge then bridgeGap else 0)
	buildWallSide(area, parent, "East", Vector3.new(half, 0, 0), "z", if area.bridgeTo then bridgeGap else 0)
end

local function buildFence(area: Areas.AreaDefinition, parent: Folder, step: (() -> ())?)
	local half = Layout.halfSize(area)
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = parent

	local edge = half - FENCE.INSET
	local y = WORLD.TERRAIN_TOP
	local corners = {
		area.origin + Vector3.new(-edge, y, -edge),
		area.origin + Vector3.new(edge, y, -edge),
		area.origin + Vector3.new(edge, y, edge),
		area.origin + Vector3.new(-edge, y, edge),
	}
	for index, from in corners do
		buildFenceRun(fence, from, corners[index % #corners + 1], step)
	end

	buildFenceGate(fence, area.origin + Vector3.new(0, y, -edge), 0)
end

local function buildGate(bridge: Layout.Bridge, parent: Folder)
	local target = Areas.get(bridge.toId)
	if not target then
		return
	end

	local width = WORLD.BRIDGE_WIDTH
	local height = WORLD.GATE_HEIGHT
	local pillar = WORLD.GATE_PILLAR
	local base = bridge.gateCFrame.Position
	local gate = Instance.new("Folder")
	gate.Name = `Gate_{target.id}`
	gate:SetAttribute("RegionId", target.id)
	gate.Parent = parent

	for _, side in { -1, 1 } do
		part({
			Name = "Pillar",
			Size = Vector3.new(pillar, height, pillar),
			Position = base + Vector3.new(0, height / 2 - 1, side * (width / 2 + pillar / 2)),
			Color = Color3.fromRGB(214, 206, 192),
			Material = Enum.Material.Concrete,
			Parent = gate,
		})
	end

	local lintel = part({
		Name = "Lintel",
		Size = Vector3.new(pillar, pillar * 1.2, width + pillar * 2),
		Position = base + Vector3.new(0, height - 1, 0),
		Color = Color3.fromRGB(226, 218, 204),
		Material = Enum.Material.Concrete,
		Parent = gate,
	})

	UI.sign(lintel, {
		name = "Banner",
		title = target.name,
		subtitle = target.flavour,
		offset = Vector3.new(0, 12, 0),
		extent = UDim2.fromScale(46, 12),
		maxDistance = 900,
	})

	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(2, height - 2, width),
		Position = base + Vector3.new(0, height / 2 - 1, 0),
		Color = target.palette.sky,
		Material = Enum.Material.ForceField,
		Transparency = 0.55,
		CanCollide = collisionGroupsReady,
		CanQuery = false,
		Parent = gate,
	})

	if collisionGroupsReady then
		barrier.CollisionGroup = GATE_PREFIX .. target.id
	end

	for _, side in { -1, 1 } do
		part({
			Name = "BridgeRail",
			Size = Vector3.new(bridge.size.X, WORLD.WALL_HEIGHT, WORLD.WALL_THICKNESS),
			Position = bridge.centre + Vector3.new(
				0,
				WORLD.TERRAIN_TOP + WORLD.WALL_HEIGHT / 2,
				side * (width / 2 + WORLD.WALL_THICKNESS / 2)
			),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false,
			Parent = gate,
		})
		part({
			Name = "BridgeHedge",
			Size = Vector3.new(bridge.size.X, WORLD.HEDGE_HEIGHT, WORLD.WALL_THICKNESS),
			Position = bridge.centre + Vector3.new(
				0,
				WORLD.TERRAIN_TOP + WORLD.HEDGE_HEIGHT / 2,
				side * (width / 2 + WORLD.WALL_THICKNESS / 2)
			),
			Color = target.palette.prop,
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = gate,
		})
	end
end

local function buildPlaza(area: Areas.AreaDefinition, parent: Folder)
	local diameter = Layout.plazaDiameter(area)

	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(WORLD.PLATFORM_THICKNESS, diameter, diameter),
		CFrame = Layout.plazaCFrame(area) * CFrame.Angles(0, 0, math.rad(90)),
		Color = area.palette.ground,
		Material = Enum.Material.Cobblestone,
		Parent = parent,
	})

	regionSpawns[area.id] = Layout.spawnCFrame(area)
end

local function decorateArea(area: Areas.AreaDefinition, parent: Folder, step: (() -> ())?)
	if not area.decorate then
		return
	end

	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = parent

	local zones = Layout.reservedZones(area)
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = { scenery }
	groundParams.FilterDescendantsInstances = ignored

	local groundCache: { [string]: number } = {}

	local function groundY(x: number, z: number): number
		local key = `{math.floor(x / 8)}:{math.floor(z / 8)}`
		local cached = groundCache[key]
		if cached then
			return cached
		end

		local origin = area.origin + Vector3.new(x, 160, z)
		local y = WORLD.TERRAIN_TOP + 1.5

		for _ = 1, 4 do
			local hit = Workspace:Raycast(origin, Vector3.new(0, -320, 0), groundParams)
			if not hit then
				break
			end

			local instance = hit.Instance
			if instance == Workspace.Terrain or instance.Anchored then
				y = hit.Position.Y
				break
			end

			table.insert(ignored, instance:FindFirstAncestorOfClass("Model") or instance)
			groundParams.FilterDescendantsInstances = ignored
		end

		groundCache[key] = y
		return y
	end

	local ctx = {
		area = area,
		origin = area.origin,
		parent = scenery,
		rng = Random.new(area.id * 7919),
		groundY = groundY,

		plazaRadius = Layout.plazaDiameter(area) / 2,

		isReserved = function(x: number, z: number): boolean
			return Layout.isReserved(zones, x, z)
		end,
		helpers = Areas.helpers,
		UI = UI,
		step = step,

		model = function(key: string): Model?
			return AssetService.clone(key)
		end,
	}

	local ok, err = pcall(area.decorate, ctx)
	if not ok then
		warn(`[WorldService] area "{area.key}" decorate() failed: {err}`)
	end
end

local function configureLighting()
	local surface = Cave.SURFACE_LIGHT

	Lighting.ClockTime = 15.5
	Lighting.Brightness = surface.brightness
	Lighting.ExposureCompensation = -0.1
	Lighting.GlobalShadows = true
	Lighting.Ambient = surface.ambient
	Lighting.OutdoorAmbient = surface.outdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.15
	Lighting.FogEnd = surface.fogEnd
	Lighting.FogStart = 2200
	Lighting.FogColor = surface.fogColor

	local existingAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmosphere then
		existingAtmosphere:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.2
	atmosphere.Haze = 0.8
	atmosphere.Glare = 0.05
	atmosphere.Color = Color3.fromRGB(190, 198, 204)
	atmosphere.Decay = Color3.fromRGB(140, 155, 170)
	atmosphere.Parent = Lighting

	local existingSky = Lighting:FindFirstChildOfClass("Sky")
	if existingSky then
		existingSky:Destroy()
	end
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting

	local existingBloom = Lighting:FindFirstChild("SoftBloom") :: BloomEffect?
	if existingBloom then
		existingBloom:Destroy()
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SoftBloom"
	bloom.Intensity = 0.25
	bloom.Size = 16
	bloom.Threshold = 2.2
	bloom.Parent = Lighting

	local existingGrade = Lighting:FindFirstChild("WarmGrade") :: ColorCorrectionEffect?
	if existingGrade then
		existingGrade:Destroy()
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "WarmGrade"
	grade.Brightness = 0.01
	grade.Contrast = 0.02
	grade.Saturation = 0.02
	grade.TintColor = Color3.fromRGB(250, 242, 235)
	grade.Parent = Lighting
end

local function nearestSpawn(position: Vector3): CFrame
	local best, bestDistance = regionSpawns[Areas.STARTING_AREA], math.huge
	for _, region in Areas.ALL do
		local spawnCFrame = regionSpawns[region.id]
		if spawnCFrame then
			local distance = (position - region.origin).Magnitude
			if distance < bestDistance then
				best, bestDistance = spawnCFrame, distance
			end
		end
	end
	return best or CFrame.new(0, 5, 0)
end

local function startVoidCatch()
	local accumulator = 0
	local INTERVAL = 0.5

	RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator < INTERVAL then
			return
		end
		accumulator = 0

		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end

			if root.Position.Y < WORLD.VOID_Y then
				root.CFrame = nearestSpawn(root.Position)
				root.AssemblyLinearVelocity = Vector3.zero
				NotifyService.send(player, "Careful! Here, back on solid ground.", "info")
			end
		end
	end)
end

function WorldService.getSpawnCFrame(regionId: number): CFrame?
	return regionSpawns[regionId]
end

function WorldService.setSpawnCFrame(regionId: number, cframe: CFrame)
	regionSpawns[regionId] = cframe
end

function WorldService.getRegionFolder(regionId: number): Folder?
	return worldFolder and worldFolder:FindFirstChild(`Region_{regionId}`) :: Folder?
end

local function applyOptionalWorkspaceSettings()
	local ok = pcall(function()
		Workspace.StreamingIntegrityMode = Enum.StreamingIntegrityMode.Default
	end)

	if not ok then
		warn(
			"[WorldService] StreamingIntegrityMode is not available on this Roblox build - skipping it. "
				.. "Streaming itself still works; fast travel may briefly outrun the ground loading in."
		)
	end
end

local function dressWorld()
	TerrainBuilder.awaitReady()

	local start = os.clock()
	local step = Budget.stepper()

	for _, region in Areas.ALL do
		local folder = WorldService.getRegionFolder(region.id)
		if not folder then
			continue
		end

		if region.id ~= Areas.STARTING_AREA then
			local fenced, fenceErr = pcall(buildFence, region, folder, step)
			if not fenced then
				warn(`[WorldService] area "{region.key}" fence failed: {fenceErr}`)
			end
		end

		local ok, err = pcall(decorateArea, region, folder, step)
		if not ok then
			warn(`[WorldService] area "{region.key}" scenery failed: {err}`)
		end
	end

	print(`[WorldService] scenery dressed in {string.format("%.2f", os.clock() - start)}s`)
	dressed = true
	dressedSignal:Fire()
end

function WorldService.init()
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	configureCollisionGroups()

	TerrainBuilder.init()

	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = Workspace

	local hasWestBridge: { [number]: boolean } = {}
	for _, area in Areas.ALL do
		local neighbour = Areas.eastOf(area)
		if neighbour then
			hasWestBridge[neighbour.id] = true
		end
	end

	for _, region in Areas.ALL do
		local folder = Instance.new("Folder")
		folder.Name = `Region_{region.id}`
		folder:SetAttribute("RegionName", region.name)
		folder.Parent = worldFolder

		buildPlaza(region, folder)

		local walled, wallErr = pcall(buildWalls, region, folder, hasWestBridge[region.id] == true)
		if not walled then
			warn(`[WorldService] area "{region.key}" boundary failed: {wallErr}`)
		end
	end

	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = worldFolder
	for _, bridge in Layout.bridges() do
		buildGate(bridge, bridges)
	end

	configureLighting()
	startVoidCatch()

	applyOptionalWorkspaceSettings()

	task.spawn(dressWorld)
end

return WorldService

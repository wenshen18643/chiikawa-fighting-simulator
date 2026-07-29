--[[
	Builds the physical world: plazas, boundaries, area gates, lighting, and the
	safety net that makes falling off impossible.

	See docs/GAME.md §7 and §2.

	Everything here is generated from Areas and Layout, so §15's config-as-data
	rule still holds — a seventh area is a table row and its ground, plaza,
	fence, bridge and gate appear with it.

	SPEC DEVIATION — §7 describes six regions reached by travel. They are now
	six DISTRICTS OF ONE LANDMASS, joined edge to edge by land bridges you walk
	across. The travel menu survives as fast travel rather than as the only way
	to move. A region you have not unlocked is closed by a gate you can see and
	walk up to, not by the absence of a road.

	Fall protection is three layers, because one is never enough:
	  1. Terrain with a shore skirt, so the ground extends past the walkable
	     area (TerrainBuilder).
	  2. An invisible wall ring around each area's footprint — with openings
	     where the land bridges leave — and a visible hedge in front of it so the
	     boundary is legible rather than an invisible shove.
	  3. A void catch below the world. Anything that gets past 1 and 2 is
	     teleported back to the nearest plaza — NOT killed. §2 rule 2: nothing is
	     lost, so falling costs the player nothing but a moment.
]]

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
local Layout = require(Shared.Modules.Config.Layout)
local UI = require(Shared.UI)

local AssetService = require(script.Parent.AssetService)
local NotifyService = require(script.Parent.NotifyService)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

local WorldService = {}

local WORLD = Constants.WORLD

local regionSpawns: { [number]: CFrame } = {}
local worldFolder: Folder

--------------------------------------------------------------------------------
-- Collision groups
--------------------------------------------------------------------------------

--[[
	Gating a walkable world needs a barrier that is solid for one player and not
	for another, which Roblox cannot express on a part. Collision GROUPS can:
	each player's character is put in `Access_k`, where k is the highest area
	they have unlocked, and a gate barrier in `Gate_j` is collidable with
	`Access_k` exactly when j > k.

	All Access groups are also non-collidable WITH EACH OTHER, so players pass
	through each other everywhere. That started as anti-griefing for the safe
	zone — nobody should be able to body-block your own front door — but it is
	the right call generally: §2's tone charter has no room for shoving.
]]
local ACCESS_PREFIX = "Access_"
local GATE_PREFIX = "Gate_"

--[[
	False when this Roblox build does not have the collision-group API, or when
	registering the groups failed for any other reason.

	Gates then FAIL OPEN: the barrier is left non-collidable and a player can
	walk into an area they have not unlocked. That is deliberately the safe
	direction. The area gate is still enforced server-side in
	WorksiteService.canUse, so arriving somewhere early pays out nothing — while
	failing CLOSED would mean an impassable wall with no way through it, which
	ends the game for that player.
]]
local collisionGroupsReady = false

function WorldService.accessGroupFor(highestUnlocked: number): string
	return ACCESS_PREFIX .. math.clamp(highestUnlocked, 1, #Areas.ALL)
end

--[[
	Puts a character in the collision group matching the furthest area they have
	unlocked, which is what decides whether each gate is solid to them.

	Called by RegionService — on spawn and again whenever an area opens, so a
	gate becomes passable the moment it is earned rather than on the next
	respawn. Applied to every BasePart because a character's limbs collide
	independently of its root.
]]
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
	-- Registering twice throws, and Studio re-runs this on every play session.
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

		-- Players never collide with players.
		for _, other in Areas.ALL do
			PhysicsService:CollisionGroupSetCollidable(accessGroup, ACCESS_PREFIX .. other.id, false)
		end

		-- A gate is solid until you have unlocked what is behind it.
		for _, gated in Areas.ALL do
			if gated.id > 1 then
				PhysicsService:CollisionGroupSetCollidable(accessGroup, GATE_PREFIX .. gated.id, gated.id > access.id)
			end
		end
	end
end

--[[
	Registers the groups, and records whether it worked.

	Guarded because `RegisterCollisionGroup` / `IsCollisionGroupRegistered` are
	the post-2022 PhysicsService API and are not present on every Roblox build.
	An error here used to propagate out of WorldService.init and take the entire
	world with it — see the note on init() below.
]]
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

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Boundary
--------------------------------------------------------------------------------

--[[
	One side of an area's fence. `gapWidth` punches a hole in the middle for a
	land bridge; the two remaining stubs are built either side of it.

	`axis` is "x" for the north/south sides (which run along X) and "z" for the
	east/west sides.
]]
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

	-- Either the whole side, or the two stubs left after the gap.
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

--[[
	The picket fence you can actually see, in front of the invisible wall.

	Same fence as the safe zone garden (SafeZoneService.buildFence): posts with
	round caps and two rails. A world edge that is only an invisible wall reads
	as a bug the first time you walk into it — the fence turns "you cannot go
	there" into "the town ends here", which is a different feeling entirely.

	Drawn a little inside the wall so you bump the fence, not the air in front
	of it, and left non-collidable itself: the wall is the rule, this is the
	sign. Posts are far enough apart that a whole 2,600-stud side is a few
	hundred parts rather than a few thousand, and streaming only ever loads the
	stretch you are standing next to.
]]
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
	local posts = math.floor(length / FENCE.SPACING)

	for index = 0, posts do
		local at = from + direction * (index * FENCE.SPACING)
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

	--[[
		Rails in segments, not one part per side.

		A Town side is 2,588 studs and a Part cannot exceed 2,048, so the first
		version of this asked for a size the engine will not give — and a rail
		that long would also be streamed in from anywhere on the map, which is
		the opposite of what the fence is for. Segments are capped well under
		the limit so each one streams with the stretch of fence it belongs to.
	]]
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

--[[
	A gate in the fence: two taller posts, a lintel across them, and the two
	leaves standing open.

	Open rather than closed, and non-collidable: it marks the way in, it does
	not ask to be used. A gate you have to interact with at the edge of a lawn
	is a door to nowhere.
]]
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

		-- A leaf swung back against the fence, so the opening stays walkable.
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

--[[
	Walls an area's footprint, leaving openings wherever a land bridge meets it.

	This is per-area rather than one rectangle around the whole landmass because
	the areas are different sizes: a single perimeter at the outermost bound
	would leave Town's northern edge unfenced by 1,700 studs of nothing.

	Four parts, and the only thing between a player and the void, so it is built
	on the boot path. The fence in front of it is a sign, not a rule — see below.
]]
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

	-- One gate on the south side, where the road out of the plaza runs.
	buildFenceGate(fence, area.origin + Vector3.new(0, y, -edge), 0)
end

--------------------------------------------------------------------------------
-- Land bridges and gates
--------------------------------------------------------------------------------

--[[
	The gate standing on an isthmus: two pillars, a lintel, a banner naming what
	is beyond, and a barrier that is solid only for players who have not unlocked
	it (see configureCollisionGroups).

	The barrier is left slightly visible so it reads as a closed way rather than
	as the game refusing to let you walk. WorldController on the client clears it
	to fully transparent once the area is open, so a player who has earned their
	way through does not keep seeing a door.
]]
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

	--[[
		The barrier is only solid when collision groups are available to make it
		solid PER PLAYER. Without them it stays visible but passable — see the
		note on `collisionGroupsReady`: a wall that is solid to everyone forever
		is far worse than one that is solid to nobody.
	]]
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

	-- Side rails, so the bridge itself cannot be walked off.
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

--------------------------------------------------------------------------------
-- Plaza
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Area scenery
--------------------------------------------------------------------------------

--[[
	Each area dresses itself. WorldService owns the ground, the fence, the gates
	and the plaza — the things every area must have — and then hands over to the
	area file for everything that makes it look like somewhere in particular.

	The RNG is seeded per area so the world is identical on every server, which
	matters the moment two players try to describe a place to each other.

	`isReserved` is handed over as a closure rather than as a zone list so that
	Areas never has to require Layout — see Areas/Area.lua.
]]
local function decorateArea(area: Areas.AreaDefinition, parent: Folder, step: (() -> ())?)
	if not area.decorate then
		return
	end

	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = parent

	local zones = Layout.reservedZones(area)

	--[[
		One rng for pack picks, built once per area rather than per call. A fresh
		Random.new(seed) inside the closure would return the same first value
		every time, so every prop in the area would be the same pack item.
	]]
	local packRng = Random.new(area.id * 104729)

	--[[
		Real surface height, terrain rounding included. Smooth terrain renders a
		stud or two above its nominal fill top, so anything seated at
		TERRAIN_TOP is buried by that much — which is where the sunk paths and
		half-buried shops came from. Raycasts against everything EXCEPT the
		scenery being placed (so plazas and pads count as ground, props do not),
		memoised per 8-stud cell so a scatter of hundreds stays cheap.
	]]
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

		--[[
			Terrain and ANCHORED geometry are ground; nothing else is. The world
			is dressed after the first NPCs, mobs and players exist, so a cast can
			land on somebody walking past — and a prop seated on a head stays on
			that head forever. A live hit is filtered out rather than merely
			skipped, so each character costs one wasted cast for the whole pass
			rather than one per sample.
		]]
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
		--[[
			The measurements an area file needs to place anything relative to
			the town rather than to a number somebody typed.

			Handed in for the same reason isReserved is: Layout is required
			here already, and an area file that computed the plaza radius itself
			would be a second copy of that formula waiting to disagree with the
			first the next time an island is resized.
		]]
		plazaRadius = Layout.plazaDiameter(area) / 2,
		districtRadius = Layout.districtRadius(area),
		padSpacing = Layout.padSpacing(area),
		isReserved = function(x: number, z: number): boolean
			return Layout.isReserved(zones, x, z)
		end,
		helpers = Areas.helpers,
		UI = UI,
		-- Called between props so a scatter of thousands never holds the frame.
		step = step,
		-- Handed in for the same reason isReserved is: AssetService is a server
		-- service and Areas is shared, so this keeps the module graph a tree.
		model = function(key: string): Model?
			return AssetService.clone(key)
		end,
		packItem = function(key: string, match: string?): Model?
			return AssetService.clonePackItem(key, packRng, match)
		end,
	}

	-- One bad area file must not take the whole world down with it.
	local ok, err = pcall(area.decorate, ctx)
	if not ok then
		warn(`[WorldService] area "{area.key}" decorate() failed: {err}`)
	end
end

--------------------------------------------------------------------------------
-- Lighting
--------------------------------------------------------------------------------

local function configureLighting()
	-- Soft, dimmed outdoor lighting.
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 1.1
	Lighting.ExposureCompensation = -0.1
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(60, 60, 65)
	Lighting.OutdoorAmbient = Color3.fromRGB(75, 75, 80)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.15
	-- Pushed well out from the old 2,200: at that distance the far side of an
	-- area was solid fog, which made a large world read as a small one in bad
	-- weather rather than as somewhere with a view.
	Lighting.FogEnd = 6500
	Lighting.FogStart = 2200
	Lighting.FogColor = Color3.fromRGB(180, 188, 196)

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

--------------------------------------------------------------------------------
-- Safety net
--------------------------------------------------------------------------------

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

--[[
	Catches anything below the world and puts it back. Deliberately NOT a kill
	brick: §2 rule 2 says nothing is lost, and a death here would drop the
	player's stamina state and interrupt their work for no reason.
]]
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

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function WorldService.getSpawnCFrame(regionId: number): CFrame?
	return regionSpawns[regionId]
end

-- SafeZoneService calls this so arriving in Town lands you on your own doorstep
-- rather than on the plaza the cottage is standing on.
function WorldService.setSpawnCFrame(regionId: number, cframe: CFrame)
	regionSpawns[regionId] = cframe
end

function WorldService.getRegionFolder(regionId: number): Folder?
	return worldFolder and worldFolder:FindFirstChild(`Region_{regionId}`) :: Folder?
end

--[[
	Workspace settings that are nice to have and must NEVER be load-bearing.

	`StreamingIntegrityMode` pauses a player whose surroundings have not streamed
	in yet, which is worth having in a world this size. It also does not exist on
	every Roblox build, and assigning to a property that is not there is a hard
	error rather than a no-op.

	This used to be the first statement in `init()`. On a build without the
	property that error propagated out of the whole service, so no region folders
	were ever created — and WorksiteService then reported six missing regions in
	a row and laid no worksites at all. The player got an empty world because of
	a rendering hint.

	So it is attempted, tolerated, and done LAST, after everything real exists.
]]
local function applyOptionalWorkspaceSettings()
	local ok = pcall(function()
		--[[
			MinimumRadiusPause used to be set here, and it is what the running-
			around stutter actually was: it freezes the character whenever the
			full min radius has not arrived, so sprinting across an area at 30
			studs/s hard-stops every time streaming falls behind. Default still
			refuses to drop you through unloaded ground, without the hitching.
		]]
		Workspace.StreamingIntegrityMode = Enum.StreamingIntegrityMode.Default
	end)

	if not ok then
		warn(
			"[WorldService] StreamingIntegrityMode is not available on this Roblox build - skipping it. "
				.. "Streaming itself still works; fast travel may briefly outrun the ground loading in."
		)
	end
end

--[[
	Everything an area wears rather than stands on: the picket fence and the
	scatter of several thousand scenery parts.

	OFF THE BOOT PATH, and this is the whole reason a play session used to open
	with a freeze. Terrain, plazas, walls, gates and pads are load-bearing and
	are built before anybody can join; scenery is not, and building it in the
	same breath meant the server spent seconds unable to answer anything —
	which in Studio, where the client shares the process, is the hitch you see
	the moment you press Play.

	Waits on terrain because every prop is seated by a raycast against the
	ground it stands on, then hands the frame back between props.
]]
local function dressWorld()
	TerrainBuilder.awaitReady()

	local start = os.clock()
	local step = Budget.stepper()

	for _, region in Areas.ALL do
		local folder = WorldService.getRegionFolder(region.id)
		if not folder then
			continue
		end

		local fenced, fenceErr = pcall(buildFence, region, folder, step)
		if not fenced then
			warn(`[WorldService] area "{region.key}" fence failed: {fenceErr}`)
		end

		decorateArea(region, folder, step)
	end

	print(`[WorldService] scenery dressed in {string.format("%.2f", os.clock() - start)}s`)
end

--[[
	Builds the world.

	ORDER IS DEFENSIVE, not just dependent. Everything that touches an API which
	might not exist on a given Roblox build is either guarded or deferred to the
	end, because a failure in this function means there is no world — and a world
	that fails to generate looks like a hundred gameplay bugs rather than like
	one missing property.
]]
function WorldService.init()
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	-- Guarded: sets `collisionGroupsReady`, never throws. Must run before
	-- buildGate, which reads that flag.
	configureCollisionGroups()

	-- Lays the ground synchronously and schedules the relief; see TerrainBuilder.
	TerrainBuilder.init()

	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = Workspace

	-- Which areas are reached by a bridge from the west, so their west wall
	-- gets an opening rather than a solid face.
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

		--[[
			Guarded for the same reason decorateArea is, and learned the hard
			way: the fence threw once and took the REST of init with it — no
			decor, no bridges, no lighting, no streaming settings — while
			terrain, pads and NPCs still appeared because those come from other
			services that only need the region folder. The result was a world
			that looked half-built rather than broken, which is a much harder
			thing to diagnose than a warning.
		]]
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

	-- Guarded: nothing above may depend on this succeeding.
	applyOptionalWorkspaceSettings()

	task.spawn(dressWorld)
end

return WorldService

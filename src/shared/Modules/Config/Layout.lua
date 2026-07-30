--[[
	Where everything physically sits. See docs/GAME.md §5 and §7.

	This module is PURE: given the area and worksite config, it returns world
	positions. It never touches an Instance, never reads Workspace, and never
	yields — so the server can build from it and the client can draw a map from
	it, and the two cannot disagree.

	That property is load-bearing rather than tidy. The world runs with
	StreamingEnabled, so most of it does not exist on the client at any given
	moment. An earlier version of the guide arrow scanned Workspace for parts
	tagged with a WorksiteId; under streaming it can only ever find the handful
	nearby, so the arrow went blind exactly when the player most needed it. The
	minimap has the same problem in a stronger form: it has to be right about
	places 20,000 studs away that will never be loaded.

	The shape of an area:

	                       ·  grit        subjugation  ·
	                            ╲              │
	                 craft ·─────╲─────────────│──── ·  weeding
	                              ╲            │
	          ◄── gate ═══════[  P L A Z A  ]═══════ gate ──►
	          (bridge west)       ╱            │      (bridge east)
	                 cooking ·───╱─────────────│──── ·  charm
	                            ╱              │

	Six skill districts fan out around a central plaza, arranged so the ±X
	corridor between the two land bridges stays clear. Within a district the
	pads run OUTWARD in tier order: tier 1 sits just off the plaza, and every
	tier after it is further from home. Climbing the ladder is a walk.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local SausageForest = require(Shared.Modules.Config.SausageForest)
local Sections = require(Shared.Modules.Config.Sections)
local Farming = require(Shared.Modules.Config.Farming)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)

local Layout = {}

local WORLD = Constants.WORLD

-- The B5 kitchen is a landmark rather than section scatter. Its XZ placement
-- lives here so terrain reservation, world construction and any future map UI
-- share one streaming-safe source of truth.
Layout.KITCHEN_CELL = "B5"
Layout.KITCHEN_FOOTPRINT = Vector2.new(52, 42)
Layout.KITCHEN_SIZE = Vector3.new(Layout.KITCHEN_FOOTPRINT.X, 30, Layout.KITCHEN_FOOTPRINT.Y)

export type Zone = {
	kind: string, -- "circle" | "rect" | "strip"
	x: number,
	z: number,
	radius: number?,
	halfX: number?,
	halfZ: number?,
	dirX: number?, -- strip: unit direction of its long axis
	dirZ: number?,
	halfLength: number?,
	halfWidth: number?,
}

export type District = {
	skillId: string,
	angle: number,
	direction: Vector3,
	worksites: { Worksites.WorksiteDefinition },
	innerRadius: number,
	spacing: number,
	plateCFrame: CFrame,
	plateSize: Vector3,
	archCFrame: CFrame,
}

export type Bridge = {
	fromId: number,
	toId: number,
	centre: Vector3,
	size: Vector3,
	gateCFrame: CFrame,
}

--------------------------------------------------------------------------------
-- District bearings
--------------------------------------------------------------------------------

--[[
	Degrees measured from +X, counter-clockwise in the XZ plane, in Skills.ORDER.

	Three districts in the +Z half and three in -Z, with nothing within 40° of
	the X axis: that corridor is where the land bridges and their gates land, and
	a district sitting in it would put worksite pads across the only road out of
	the area.
]]
--[[
	District bearings, indexed by Skills.ORDER. 230 is retired for worksites:
	it points into the sausage forest block, and the examprep district that
	lived there wiped the forest floor with its reserved zone. 310 lands in
	the snow/rocky corner instead - the least-built ground a district fits.
]]
local ANGLES = { 50, 90, 130, 310, 270, 230 }

Layout.SKILL_ANGLE = {} :: { [string]: number }
Layout.SKILL_INDEX = {} :: { [string]: number }
for index, skillId in Skills.ORDER do
	local angle = ANGLES[index]
	assert(angle, `Layout: no district bearing for skill "{skillId}" at index {index}`)
	Layout.SKILL_ANGLE[skillId] = angle
	Layout.SKILL_INDEX[skillId] = index
end

local function directionOf(angleDegrees: number): Vector3
	local radians = math.rad(angleDegrees)
	return Vector3.new(math.cos(radians), 0, math.sin(radians))
end

-- World-space centre of a forage zone. Both the runtime spawner and the world
-- dressing reservation use this, so moving a configured field cannot leave its
-- collision-free footprint behind.
function Layout.forageZoneCentre(area: Areas.AreaDefinition, zone: Ingredients.ZoneDefinition): Vector3
	return area.origin + directionOf(zone.angle) * zone.distance
end

--------------------------------------------------------------------------------
-- Area metrics
--------------------------------------------------------------------------------

function Layout.plazaDiameter(area: Areas.AreaDefinition): number
	return math.max(area.terrain.islandSize * WORLD.PLAZA_DIAMETER_FRACTION, WORLD.PLAZA_MIN_DIAMETER)
end

-- Plaza centre to the tier-1 pad. See Constants for why this is base + fraction
-- rather than a pure fraction.
function Layout.districtRadius(area: Areas.AreaDefinition): number
	return WORLD.DISTRICT_INNER_RADIUS + area.terrain.islandSize * WORLD.DISTRICT_RADIUS_FRACTION
end

function Layout.padSpacing(area: Areas.AreaDefinition): number
	return WORLD.DISTRICT_PAD_SPACING + area.terrain.islandSize * WORLD.DISTRICT_SPACING_FRACTION
end

function Layout.halfSize(area: Areas.AreaDefinition): number
	return area.terrain.islandSize / 2
end

-- Y of the CENTRE of anything whose top face should present PLATFORM_TOP.
local function surfaceCentreY(thickness: number): number
	return WORLD.PLATFORM_TOP - thickness / 2
end

function Layout.plazaCFrame(area: Areas.AreaDefinition): CFrame
	return CFrame.new(area.origin + Vector3.new(0, surfaceCentreY(WORLD.PLATFORM_THICKNESS), 0))
end

-- Where a player arriving in this area is put down. Town overrides this with the
-- safe-zone cottage's doorstep; every other area uses its plaza.
function Layout.spawnCFrame(area: Areas.AreaDefinition): CFrame
	return CFrame.new(area.origin + Vector3.new(0, WORLD.PLATFORM_TOP + 5, 0))
end

-- Centre of the kitchen footprint, facing the Town plaza. Y is the area's
-- nominal origin; the server builder raycasts only to seat the configured XZ
-- position on the rendered terrain surface.
function Layout.kitchenCFrame(area: Areas.AreaDefinition): CFrame
	local cell = Sections.byCoord(Layout.KITCHEN_CELL)
	assert(cell, `Layout: kitchen cell "{Layout.KITCHEN_CELL}" is invalid`)

	local centre = area.origin + Vector3.new(cell.cx, 0, cell.cz)
	local plaza = Vector3.new(area.origin.X, centre.Y, area.origin.Z)
	return CFrame.lookAt(centre, plaza)
end

-- The farm is an axis-aligned 3 x 5 grid centred in C5. Plot ids run
-- west-to-east inside each row, then south-to-north across rows.
function Layout.farmFieldCFrame(area: Areas.AreaDefinition): CFrame
	local cell = Sections.byCoord(Farming.CELL_COORD)
	assert(cell, `Layout: farm cell "{Farming.CELL_COORD}" is invalid`)
	return CFrame.new(area.origin + Vector3.new(cell.cx, surfaceCentreY(Farming.PLOT_THICKNESS), cell.cz))
end

function Layout.farmPlotCFrame(area: Areas.AreaDefinition, plotId: number): CFrame?
	local grid = Farming.gridPosition(plotId)
	if not grid then
		return nil
	end
	local x = (grid.column - (Farming.COLUMNS + 1) / 2) * Farming.PLOT_STRIDE
	local z = (grid.row - (Farming.ROWS + 1) / 2) * Farming.PLOT_STRIDE
	return Layout.farmFieldCFrame(area) * CFrame.new(x, 0, z)
end

function Layout.farmEntranceCFrame(area: Areas.AreaDefinition): CFrame
	local cell = Sections.byCoord(Farming.CELL_COORD)
	assert(cell, `Layout: farm cell "{Farming.CELL_COORD}" is invalid`)
	local position = area.origin + Vector3.new(cell.cx, WORLD.PLATFORM_TOP, cell.minZ + 8)
	local plaza = Vector3.new(area.origin.X, position.Y, area.origin.Z)
	return CFrame.lookAt(position, plaza)
end

export type FarmRouteSegment = {
	id: string,
	from: Vector3,
	to: Vector3,
}

-- Both public farm routes start at the plaza-facing edge of Kusatori tier 1.
-- The kitchen endpoint is its existing approach rather than the building
-- centre, so the stones stop at the door instead of running through the room.
function Layout.farmRouteSegments(area: Areas.AreaDefinition): { FarmRouteSegment }
	local kusatori = Layout.padCFrame(area, "kusatori", 1)
	local start = kusatori:PointToWorldSpace(Vector3.new(0, 0, WORLD.WORKSITE_SIZE.Z / 2 + 5))
	local kitchenApproach = Layout.kitchenCFrame(area):PointToWorldSpace(Vector3.new(0, 0, -44.5))
	return {
		{ id = "KusatoriToFarm", from = start, to = Layout.farmEntranceCFrame(area).Position },
		{ id = "KusatoriToKitchen", from = start, to = kitchenApproach },
	}
end

--------------------------------------------------------------------------------
-- Districts and pads
--------------------------------------------------------------------------------

--[[
	How far from the area origin the pad for `worksite` sits.

	`tierIndex` is its position among the tiers PRESENT IN THIS AREA (1-based),
	not its absolute tier. Every area's district starts at the same comfortable
	distance from the plaza whether it holds two tiers or seven.
]]
function Layout.padDistance(area: Areas.AreaDefinition, tierIndex: number): number
	return Layout.districtRadius(area) + (tierIndex - 1) * Layout.padSpacing(area)
end

function Layout.padCFrame(area: Areas.AreaDefinition, skillId: string, tierIndex: number): CFrame
	local direction = directionOf(Layout.SKILL_ANGLE[skillId])
	local distance = Layout.padDistance(area, tierIndex)
	local centre = area.origin + direction * distance + Vector3.new(0, surfaceCentreY(WORLD.WORKSITE_SIZE.Y), 0)
	-- Squared up with the district rather than the world axes, so a district
	-- reads as one laid-out place instead of six rotated tiles on a lawn.
	return CFrame.lookAt(centre, centre + direction)
end

function Layout.districtFor(area: Areas.AreaDefinition, skillId: string): District
	local angle = Layout.SKILL_ANGLE[skillId]
	local direction = directionOf(angle)
	local worksites = Worksites.getInRegionForSkill(area.id, skillId)

	local innerRadius = Layout.districtRadius(area)
	local spacing = Layout.padSpacing(area)
	local margin = WORLD.DISTRICT_PLATE_MARGIN
	local padHalf = WORLD.WORKSITE_SIZE.X / 2

	local run = math.max(#worksites - 1, 0) * spacing
	local plateLength = run + WORLD.WORKSITE_SIZE.Z + margin * 2
	local plateCentre = area.origin
		+ direction * (innerRadius + run / 2)
		-- Sits just under the pads so they read as proud of it rather than
		-- z-fighting with it.
		+ Vector3.new(0, surfaceCentreY(WORLD.PLATFORM_THICKNESS) - 0.5, 0)

	local archCentre = area.origin
		+ direction * (innerRadius - padHalf - WORLD.DISTRICT_ARCH_SETBACK)
		+ Vector3.new(0, WORLD.PLATFORM_TOP, 0)

	return {
		skillId = skillId,
		angle = angle,
		direction = direction,
		worksites = worksites,
		innerRadius = innerRadius,
		spacing = spacing,
		plateCFrame = CFrame.lookAt(plateCentre, plateCentre + direction),
		plateSize = Vector3.new(WORLD.WORKSITE_SIZE.X + margin * 2, WORLD.PLATFORM_THICKNESS, plateLength),
		-- Banner faces back toward the plaza: you read it on the way in.
		archCFrame = CFrame.lookAt(archCentre, archCentre - direction),
	}
end

--[[
	All six districts of an area.

	MEMOISED, because this is a pure function of static config and it is called
	on a timer: the guide arrow re-picks a target several times a second, the
	minimap redraws on a border crossing, and each call was rebuilding six
	records and six CFrames to produce a byte-identical answer.

	Safe to cache precisely because nothing here reads mutable state. Callers
	must treat the result as read-only — it is shared, not a copy.
]]
local districtCache: { [number]: { District } } = {}

function Layout.districts(area: Areas.AreaDefinition): { District }
	local cached = districtCache[area.id]
	if cached then
		return cached
	end

	local result = {}
	for _, skillId in Skills.ORDER do
		table.insert(result, Layout.districtFor(area, skillId))
	end

	districtCache[area.id] = result
	return result
end

--[[
	Every pad in an area, with the CFrame to build it at. The single source both
	WorksiteService (to place parts) and the client (to point at them) use.
]]
function Layout.padsFor(
	area: Areas.AreaDefinition
): { { worksite: Worksites.WorksiteDefinition, cframe: CFrame, tierIndex: number } }
	local result = {}
	for _, district in Layout.districts(area) do
		for tierIndex, worksite in district.worksites do
			table.insert(result, {
				worksite = worksite,
				cframe = Layout.padCFrame(area, district.skillId, tierIndex),
				tierIndex = tierIndex,
			})
		end
	end
	return result
end

-- Position of one specific pad, for the guide arrow and the minimap. Returns nil
-- when the area does not carry that worksite.
function Layout.padPosition(area: Areas.AreaDefinition, worksiteId: string): Vector3?
	local worksite = Worksites.get(worksiteId)
	if not worksite or worksite.homeRegion > area.id then
		return nil
	end
	local available = Worksites.getInRegionForSkill(area.id, worksite.skill)
	for tierIndex, candidate in available do
		if candidate.id == worksiteId then
			return Layout.padCFrame(area, worksite.skill, tierIndex).Position
		end
	end
	return nil
end

-- Deterministic habitat slots around the area's configured centre. Mob
-- placement stays in the same config-derived coordinate system as the world.
function Layout.mobSpawnCFrames(
	area: Areas.AreaDefinition,
	population: number,
	radius: number,
	angleOffsetDegrees: number?
): { CFrame }
	local centre = area.origin
	local result = {}
	local angleOffset = math.rad(angleOffsetDegrees or 0)

	for index = 1, population do
		local angle = angleOffset + (index - 1) / population * math.pi * 2
		local position = Vector3.new(
			centre.X + math.cos(angle) * radius,
			area.origin.Y + WORLD.PLATFORM_TOP,
			centre.Z + math.sin(angle) * radius
		)
		table.insert(result, CFrame.lookAt(position, Vector3.new(centre.X, position.Y, centre.Z)))
	end

	return result
end

function Layout.isFarmPosition(area: Areas.AreaDefinition, position: Vector3, padding: number?): boolean
	if area.id ~= Areas.STARTING_AREA then
		return false
	end
	local farmCell = Sections.byCoord(Farming.CELL_COORD)
	if not farmCell then
		return false
	end
	local localPosition = position - area.origin
	local margin = padding or 0
	return localPosition.X >= farmCell.minX - margin
		and localPosition.X <= farmCell.maxX + margin
		and localPosition.Z >= farmCell.minZ - margin
		and localPosition.Z <= farmCell.maxZ + margin
end

--------------------------------------------------------------------------------
-- Reserved ground
--------------------------------------------------------------------------------

--[[
	Where an area file's `scatter` must not drop scenery: on top of the plaza, on
	top of a district, or across the road between the two land bridges.

	Passed to area files through the decorate context rather than required by
	them, so Areas never has to know about Layout and the module graph stays a
	tree.
]]
function Layout.reservedZones(area: Areas.AreaDefinition): { Zone }
	local zones: { Zone } = {}

	table.insert(zones, {
		kind = "circle",
		x = 0,
		z = 0,
		radius = Layout.plazaDiameter(area) / 2 + 60,
	})

	local farmCell = Sections.byCoord(Farming.CELL_COORD)
	if area.id == Areas.STARTING_AREA and farmCell then
		table.insert(zones, {
			kind = "rect",
			x = farmCell.cx,
			z = farmCell.cz,
			halfX = Sections.SIZE / 2,
			halfZ = Sections.SIZE / 2,
		})
	end

	if area.id == Areas.STARTING_AREA then
		for _, forageZone in Ingredients.ZONES do
			if forageZone.reserveDecor then
				local centre = Layout.forageZoneCentre(area, forageZone) - area.origin
				table.insert(zones, {
					kind = "circle",
					x = centre.X,
					z = centre.Z,
					radius = forageZone.radius + Constants.FORAGE.CLUMP_SPREAD,
				})
			end
		end
	end

	--[[
		The home plot. The plaza circle above does not reach its corners (the
		garden fence sits at ~172 studs on the diagonal against the circle's
		145), and scatter — now dense, with sections planting whole farms —
		was free to grow a tilled row inside the player's own garden.
	]]
	table.insert(zones, {
		kind = "rect",
		x = SafeZone.VOLUME.centreOffset.X,
		z = SafeZone.VOLUME.centreOffset.Z,
		halfX = SafeZone.VOLUME.size.X / 2 + 10,
		halfZ = SafeZone.VOLUME.size.Z / 2 + 10,
	})

	if area.id == Areas.STARTING_AREA then
		local kitchenFrame = Layout.kitchenCFrame(area)
		local kitchenOffset = kitchenFrame.Position - area.origin
		local half = Layout.KITCHEN_SIZE / 2
		table.insert(zones, {
			kind = "circle",
			x = kitchenOffset.X,
			z = kitchenOffset.Z,
			-- The rotated rectangular cottage plus room for its porch and eaves.
			radius = math.sqrt(half.X * half.X + half.Z * half.Z) + 10,
		})

		-- Keep the final stretch of the district path clear too. SectionDressing's
		-- B5 path ends sixty studs before the cell centre; the builder's stones
		-- bridge that exact gap to the porch.
		local approach = kitchenFrame:PointToWorldSpace(Vector3.new(0, 0, -44.5)) - area.origin
		table.insert(zones, {
			kind = "circle",
			x = approach.X,
			z = approach.Z,
			radius = 20,
		})
	end

	--[[
		A strip along the plate, not a circle around it. A district plate is a
		124-stud-wide strip up to ~400 long; the circle that contained one wiped
		out a 237-stud radius — most of the sausage forest sat inside the
		examprep district's circle, which is why the forest floor came up bare.
	]]
	for _, district in Layout.districts(area) do
		local offset = district.plateCFrame.Position - area.origin
		table.insert(zones, {
			kind = "strip",
			x = offset.X,
			z = offset.Z,
			dirX = district.direction.X,
			dirZ = district.direction.Z,
			halfLength = district.plateSize.Z / 2 + 40, -- room for the arch and the walk in
			-- Tight on the sides: where a strip crosses the forest, the gap it
			-- cuts should read as the path to the pads, not as a firebreak.
			halfWidth = district.plateSize.X / 2 + 16,
		})
	end

	--[[
		The fighting clearing around each BIG sausage tree. Reserved for two
		reasons at once: the dressing pass leaves the arena bare, and the relief
		mask flattens it, so nobody fights a boss on a hillside behind a bush.
	]]
	for _, entry in SausageForest.CELLS do
		local cell = Sections.byCoord(entry.coord)
		if cell then
			local arena = SausageForest.arena(cell)
			table.insert(zones, {
				kind = "circle",
				x = arena.X,
				z = arena.Y,
				radius = SausageForest.CLEARING_RADIUS,
			})
		end
	end

	-- The east-west road. Kept clear the full width of the area so the walk
	-- between land bridges is never blocked by scenery.
	table.insert(zones, {
		kind = "rect",
		x = 0,
		z = 0,
		halfX = Layout.halfSize(area),
		halfZ = WORLD.BRIDGE_WIDTH / 2 + 70,
	})

	return zones
end

-- `x` and `z` are offsets from the area origin, matching the area helpers.
function Layout.isReserved(zones: { Zone }, x: number, z: number): boolean
	for _, zone in zones do
		if zone.kind == "circle" then
			local dx, dz = x - zone.x, z - zone.z
			if dx * dx + dz * dz <= (zone.radius or 0) ^ 2 then
				return true
			end
		elseif zone.kind == "rect" then
			if math.abs(x - zone.x) <= (zone.halfX or 0) and math.abs(z - zone.z) <= (zone.halfZ or 0) then
				return true
			end
		elseif zone.kind == "strip" then
			local dx, dz = x - zone.x, z - zone.z
			local along = dx * (zone.dirX or 0) + dz * (zone.dirZ or 0)
			local across = dx * (zone.dirZ or 0) - dz * (zone.dirX or 0)
			if math.abs(along) <= (zone.halfLength or 0) and math.abs(across) <= (zone.halfWidth or 0) then
				return true
			end
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Bridges between areas
--------------------------------------------------------------------------------

--[[
	The isthmus joining two neighbouring areas. `bridgeTo` on an area names the
	area it reaches east; this turns that into terrain to fill and a gate to
	stand on it.

	Overlaps both islands by a little so the terrain has no seam at the join —
	marching cubes will not produce a flat butt joint between two separate fills.
]]
local BRIDGE_OVERLAP = 60

function Layout.bridgeBetween(from: Areas.AreaDefinition, to: Areas.AreaDefinition): Bridge
	local fromEdge = from.origin.X + Layout.halfSize(from)
	local toEdge = to.origin.X - Layout.halfSize(to)
	local centreX = (fromEdge + toEdge) / 2
	local length = (toEdge - fromEdge) + BRIDGE_OVERLAP * 2

	return {
		fromId = from.id,
		toId = to.id,
		centre = Vector3.new(centreX, 0, 0),
		size = Vector3.new(length, WORLD.ISLAND_DEPTH, WORLD.BRIDGE_WIDTH),
		gateCFrame = CFrame.new(centreX, WORLD.PLATFORM_TOP, 0),
	}
end

function Layout.bridges(): { Bridge }
	local result = {}
	for _, area in Areas.ALL do
		local neighbour = area.bridgeTo and Areas.BY_KEY[area.bridgeTo]
		if neighbour then
			table.insert(result, Layout.bridgeBetween(area, neighbour))
		end
	end
	return result
end

--------------------------------------------------------------------------------
-- World-level queries
--------------------------------------------------------------------------------

--[[
	The bounding box of the whole landmass, for the minimap's coordinate
	transform. Computed once at load: areas are static config.
]]
local function computeBounds(): (Vector3, Vector3)
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for _, area in Areas.ALL do
		local half = Layout.halfSize(area) + WORLD.SHORE_FALLOFF / 2
		minX = math.min(minX, area.origin.X - half)
		maxX = math.max(maxX, area.origin.X + half)
		minZ = math.min(minZ, area.origin.Z - half)
		maxZ = math.max(maxZ, area.origin.Z + half)
	end

	return Vector3.new(minX, 0, minZ), Vector3.new(maxX, 0, maxZ)
end

Layout.BOUNDS_MIN, Layout.BOUNDS_MAX = computeBounds()
Layout.BOUNDS_SIZE = Layout.BOUNDS_MAX - Layout.BOUNDS_MIN

-- 0..1 across the landmass, for drawing. X maps to X, Z maps to Y on screen.
function Layout.toMapFraction(position: Vector3): Vector2
	local size = Layout.BOUNDS_SIZE
	return Vector2.new(
		if size.X > 0 then math.clamp((position.X - Layout.BOUNDS_MIN.X) / size.X, 0, 1) else 0.5,
		if size.Z > 0 then math.clamp((position.Z - Layout.BOUNDS_MIN.Z) / size.Z, 0, 1) else 0.5
	)
end

function Layout.contains(area: Areas.AreaDefinition, position: Vector3): boolean
	local half = Layout.halfSize(area)
	return math.abs(position.X - area.origin.X) <= half and math.abs(position.Z - area.origin.Z) <= half
end

--[[
	Which area a point is in. Falls back to nearest centre rather than nil,
	because a player standing on a land bridge is genuinely between two areas and
	every caller wants an answer rather than a special case.
]]
function Layout.areaAt(position: Vector3): Areas.AreaDefinition
	for _, area in Areas.ALL do
		if Layout.contains(area, position) then
			return area
		end
	end

	local best, bestDistance = Areas.BY_ID[Areas.STARTING_AREA], math.huge
	for _, area in Areas.ALL do
		local distance = (Vector3.new(position.X, 0, position.Z) - area.origin).Magnitude
		if distance < bestDistance then
			best, bestDistance = area, distance
		end
	end
	return best
end

return Layout

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Market = require(Shared.Modules.Config.Market)
local Perimeter = require(Shared.Modules.Config.Perimeter)
local Quarry = require(Shared.Modules.Config.Quarry)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local SausageForest = require(Shared.Modules.Config.SausageForest)
local Sections = require(Shared.Modules.Config.Sections)
local Streets = require(Shared.Modules.Config.Streets)
local Farming = require(Shared.Modules.Config.Farming)
local Layout = {}
local WORLD = Constants.WORLD

Layout.BUILDING_MARGIN = 10
Layout.APPROACH_LENGTH = 38
Layout.APPROACH_WIDTH = 20

local BRANCH_END = Streets.RING.halfX + Streets.BRANCH_LENGTH

Layout.KITCHEN_CELL = "C4"
Layout.KITCHEN_FACING = Vector3.new(1, 0, 0)
Layout.KITCHEN_FOOTPRINT = Vector2.new(52, 42)
Layout.KITCHEN_SIZE = Vector3.new(Layout.KITCHEN_FOOTPRINT.X, 30, Layout.KITCHEN_FOOTPRINT.Y)
Layout.KITCHEN_OFFSET =
	Vector3.new(-(BRANCH_END + Layout.KITCHEN_FOOTPRINT.Y / 2), 0, Streets.RING.gateZ)

Layout.LIBRARY_CELL = "D4"
Layout.LIBRARY_FACING = Vector3.new(-1, 0, 0)
Layout.LIBRARY_FOOTPRINT = Vector2.new(84, 62)
Layout.LIBRARY_SIZE = Vector3.new(Layout.LIBRARY_FOOTPRINT.X, 27, Layout.LIBRARY_FOOTPRINT.Y)
Layout.LIBRARY_OFFSET = Vector3.new(BRANCH_END + Layout.LIBRARY_FOOTPRINT.Y / 2, 0, Streets.RING.gateZ)

export type Zone = {
	kind: string,
	x: number,
	z: number,
	radius: number?,
	halfX: number?,
	halfZ: number?,
	dirX: number?,
	dirZ: number?,
	halfLength: number?,
	halfWidth: number?,
}

export type Bridge = {
	fromId: number,
	toId: number,
	centre: Vector3,
	size: Vector3,
	gateCFrame: CFrame,
}

local function directionOf(angleDegrees: number): Vector3
	local radians = math.rad(angleDegrees)
	return Vector3.new(math.cos(radians), 0, math.sin(radians))
end

function Layout.forageZoneCentre(area: Areas.AreaDefinition, zone: Ingredients.ZoneDefinition): Vector3
	return area.origin + directionOf(zone.angle) * zone.distance
end

function Layout.plotCentre(area: Areas.AreaDefinition, plot: Ingredients.PlotDefinition): Vector3?
	local cell = Sections.byCoord(plot.cell)
	if not cell then
		return nil
	end
	return area.origin + Vector3.new(cell.cx, 0, cell.cz)
end

function Layout.plazaDiameter(area: Areas.AreaDefinition): number
	return math.max(area.terrain.islandSize * WORLD.PLAZA_DIAMETER_FRACTION, WORLD.PLAZA_MIN_DIAMETER)
end

function Layout.halfSize(area: Areas.AreaDefinition): number
	return area.terrain.islandSize / 2
end

local function surfaceCentreY(thickness: number): number
	return WORLD.PLATFORM_TOP - thickness / 2
end

function Layout.plazaCFrame(area: Areas.AreaDefinition): CFrame
	return CFrame.new(area.origin + Vector3.new(0, surfaceCentreY(WORLD.PLATFORM_THICKNESS), 0))
end

function Layout.spawnCFrame(area: Areas.AreaDefinition): CFrame
	return CFrame.new(area.origin + Vector3.new(0, WORLD.PLATFORM_TOP + 5, 0))
end

function Layout.kitchenCFrame(area: Areas.AreaDefinition): CFrame
	local centre = area.origin + Layout.KITCHEN_OFFSET
	return CFrame.lookAt(centre, centre + Layout.KITCHEN_FACING)
end

function Layout.libraryCFrame(area: Areas.AreaDefinition): CFrame
	local centre = area.origin + Layout.LIBRARY_OFFSET + Vector3.new(0, WORLD.TERRAIN_TOP, 0)
	return CFrame.lookAt(centre, centre + Layout.LIBRARY_FACING)
end

function Layout.farmFieldCFrame(area: Areas.AreaDefinition): CFrame
	local cell = Sections.byCoord(Farming.CELL_COORD)
	assert(cell, `Layout: farm cell "{Farming.CELL_COORD}" is invalid`)
	return CFrame.new(area.origin + Vector3.new(
		cell.cx + Farming.FIELD_OFFSET.X,
		surfaceCentreY(Farming.PLOT_THICKNESS),
		cell.cz + Farming.FIELD_OFFSET.Y
	))
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
	local field = Layout.farmFieldCFrame(area).Position
	local centre = Vector3.new(field.X, area.origin.Y + WORLD.PLATFORM_TOP, field.Z)
	local mouth = centre - Vector3.new(0, 0, Farming.FIELD_LENGTH / 2 + Farming.FIELD_MARGIN)
	return CFrame.lookAt(mouth, centre)
end

function Layout.mobSpawnCFrames(
	area: Areas.AreaDefinition,
	population: number,
	radius: number,
	angleOffsetDegrees: number?,
	centreOffset: Vector3?
): { CFrame }
	local centre = area.origin + (centreOffset or Vector3.zero)
	local result = {}
	local angleOffset = math.rad(angleOffsetDegrees or 0)

	for index = 1, population do
		local angle = angleOffset + (index - 1) / population * math.pi * 2
		local position = Vector3.new(
			centre.X + math.cos(angle) * radius,
			area.origin.Y + WORLD.PLATFORM_TOP,
			centre.Z + math.sin(angle) * radius
		)
		if not Layout.isTownPosition(area, position) then
			table.insert(result, CFrame.lookAt(position, Vector3.new(centre.X, position.Y, centre.Z)))
		end
	end

	return result
end

function Layout.mobSpawnCFramesInCells(
	area: Areas.AreaDefinition,
	population: number,
	cells: { string },
	seed: number,
	roamRadius: number?
): { CFrame }
	local MOB = Constants.MOB
	local reserved = Layout.reservedZones(area)
	local rng = Random.new(seed)
	local y = area.origin.Y + WORLD.PLATFORM_TOP
	local clearance = math.min(roamRadius or 0, MOB.SPAWN_MAX_CLEARANCE)
	local chosen: { Vector2 } = {}
	local result = {}

	local function farEnough(x: number, z: number): boolean
		for _, taken in chosen do
			if (Vector2.new(x, z) - taken).Magnitude < MOB.SPAWN_MIN_SPACING then
				return false
			end
		end
		return true
	end

	local function standsClear(x: number, z: number): boolean
		if Layout.isTownPoint(x, z, MOB.TOWN_MARGIN) or Layout.isReserved(reserved, x, z) then
			return false
		end
		return clearance <= 0
			or (
				not Layout.isReserved(reserved, x + clearance, z)
				and not Layout.isReserved(reserved, x - clearance, z)
				and not Layout.isReserved(reserved, x, z + clearance)
				and not Layout.isReserved(reserved, x, z - clearance)
			)
	end

	local function sampleCell(coord: string): (number?, number?)
		local cell = Sections.byCoord(coord)
		if not cell then
			warn(`[Layout] mob spawn cell "{coord}" is invalid`)
			return nil, nil
		end

		for _ = 1, MOB.SPAWN_PLACEMENT_ATTEMPTS do
			local x = rng:NextNumber(cell.minX + MOB.SPAWN_CELL_MARGIN, cell.maxX - MOB.SPAWN_CELL_MARGIN)
			local z = rng:NextNumber(cell.minZ + MOB.SPAWN_CELL_MARGIN, cell.maxZ - MOB.SPAWN_CELL_MARGIN)
			if standsClear(x, z) and farEnough(x, z) then
				return x, z
			end
		end

		return nil, nil
	end

	for index = 1, population do
		local start = math.floor((index - 1) * #cells / population)
		local x: number?, z: number? = nil, nil

		for step = 0, #cells - 1 do
			x, z = sampleCell(cells[(start + step) % #cells + 1])
			if x then
				break
			end
		end

		if not x or not z then
			warn(
				`[Layout] no free mob spawn point in any of the {#cells} configured cells; `
					.. `slot {index} was dropped. Reserved zones have swallowed the whole set.`
			)
			continue
		end

		table.insert(chosen, Vector2.new(x, z))
		local position = Vector3.new(area.origin.X + x, y, area.origin.Z + z)
		table.insert(result, CFrame.lookAt(position, Vector3.new(area.origin.X, y, area.origin.Z)))
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

function Layout.isTownPoint(x: number, z: number, padding: number?): boolean
	return Perimeter.outwardDistance(x, z) <= (padding or 0)
end

function Layout.isTownPosition(area: Areas.AreaDefinition, position: Vector3, padding: number?): boolean
	if area.id ~= Areas.STARTING_AREA then
		return false
	end
	local localPosition = position - area.origin
	return Layout.isTownPoint(localPosition.X, localPosition.Z, padding)
end

function Layout.isHomePosition(area: Areas.AreaDefinition, position: Vector3): boolean
	return Layout.isTownPosition(area, position)
end

local function addBuildingZones(zones: { Zone }, area: Areas.AreaDefinition, frame: CFrame, footprint: Vector2)
	local offset = frame.Position - area.origin
	local halfWidth, halfDepth = footprint.X / 2, footprint.Y / 2

	table.insert(zones, {
		kind = "circle",
		x = offset.X,
		z = offset.Z,
		radius = math.sqrt(halfWidth * halfWidth + halfDepth * halfDepth) + Layout.BUILDING_MARGIN,
	})

	local direction = frame.LookVector
	local approach = frame:PointToWorldSpace(Vector3.new(0, 0, -(halfDepth + Layout.APPROACH_LENGTH / 2)))
		- area.origin
	table.insert(zones, {
		kind = "strip",
		x = approach.X,
		z = approach.Z,
		dirX = direction.X,
		dirZ = direction.Z,
		halfLength = Layout.APPROACH_LENGTH / 2,
		halfWidth = Layout.APPROACH_WIDTH / 2,
	})
end

local reservedCache: { [number]: { Zone } } = {}

function Layout.reservedZones(area: Areas.AreaDefinition): { Zone }
	local cached = reservedCache[area.id]
	if cached then
		return cached
	end

	local zones: { Zone } = {}

	table.insert(zones, {
		kind = "circle",
		x = 0,
		z = 0,
		radius = Layout.plazaDiameter(area) / 2 + 20,
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
		for _, plot in Ingredients.PLOTS do
			local cell = Sections.byCoord(plot.cell)
			if cell then
				table.insert(zones, {
					kind = "circle",
					x = cell.cx,
					z = cell.cz,
					radius = Ingredients.plotHalfSpan(plot) + Constants.FORAGE.CLUMP_SPREAD,
				})
			end
		end
	end

	table.insert(zones, {
		kind = "rect",
		x = SafeZone.VOLUME.centreOffset.X,
		z = SafeZone.VOLUME.centreOffset.Z,
		halfX = SafeZone.VOLUME.size.X / 2 + 10,
		halfZ = SafeZone.VOLUME.size.Z / 2 + 10,
	})

	if area.id == Areas.STARTING_AREA then
		addBuildingZones(zones, area, Layout.kitchenCFrame(area), Layout.KITCHEN_FOOTPRINT)
		addBuildingZones(zones, area, Layout.libraryCFrame(area), Layout.LIBRARY_FOOTPRINT)
	end
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

	if area.id == Areas.STARTING_AREA then
		local pit = Quarry.centre()
		if pit then
			table.insert(zones, {
				kind = "circle",
				x = pit.X,
				z = pit.Y,
				radius = Quarry.PIT.reserveRadius,
			})
		end
	end

	if area.id == Areas.STARTING_AREA then
		for _, zone in Streets.reservedZones() do
			table.insert(zones, zone :: Zone)
		end

		for _, zone in Perimeter.reservedZones() do
			table.insert(zones, zone :: Zone)
		end

		table.insert(zones, {
			kind = "rect",
			x = Market.CENTRE.X,
			z = Market.CENTRE.Y,
			halfX = Market.HALF.X + Market.TERRACE + 4,
			halfZ = Market.HALF.Y + Market.TERRACE + 4,
		})
	end

	reservedCache[area.id] = zones
	return zones
end

local RESERVED_GRID = 64
local reservedIndexCache = (setmetatable({}, { __mode = "k" }) :: any) :: { [any]: { [number]: { Zone } } }

local function zoneHalfExtents(zone: Zone): (number, number)
	if zone.kind == "circle" then
		local radius = zone.radius or 0
		return radius, radius
	elseif zone.kind == "rect" then
		return zone.halfX or 0, zone.halfZ or 0
	end
	local reach = (zone.halfLength or 0) + (zone.halfWidth or 0)
	return reach, reach
end

local function gridKey(gx: number, gz: number): number
	return gx * 8192 + gz
end

local function buildReservedIndex(zones: { Zone }): { [number]: { Zone } }
	local grid: { [number]: { Zone } } = {}
	for _, zone in zones do
		local halfX, halfZ = zoneHalfExtents(zone)
		for gx = math.floor((zone.x - halfX) / RESERVED_GRID), math.floor((zone.x + halfX) / RESERVED_GRID) do
			for gz = math.floor((zone.z - halfZ) / RESERVED_GRID), math.floor((zone.z + halfZ) / RESERVED_GRID) do
				local key = gridKey(gx, gz)
				local bucket = grid[key]
				if not bucket then
					bucket = {}
					grid[key] = bucket
				end
				table.insert(bucket, zone)
			end
		end
	end
	return grid
end

function Layout.isReserved(zones: { Zone }, x: number, z: number): boolean
	local grid = reservedIndexCache[zones]
	if not grid then
		grid = buildReservedIndex(zones)
		reservedIndexCache[zones] = grid
	end

	local bucket = grid[gridKey(math.floor(x / RESERVED_GRID), math.floor(z / RESERVED_GRID))]
	if not bucket then
		return false
	end

	for _, zone in bucket do
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

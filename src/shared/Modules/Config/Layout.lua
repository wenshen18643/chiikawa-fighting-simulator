local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Fishing = require(Shared.Modules.Config.Fishing)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Quarry = require(Shared.Modules.Config.Quarry)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local SausageForest = require(Shared.Modules.Config.SausageForest)
local Sections = require(Shared.Modules.Config.Sections)
local Streets = require(Shared.Modules.Config.Streets)
local Farming = require(Shared.Modules.Config.Farming)
local Layout = {}
local WORLD = Constants.WORLD

Layout.KITCHEN_CELL = "C4"
Layout.KITCHEN_OFFSET = Vector3.new(-150, 0, 90)
Layout.KITCHEN_FACING = Vector3.new(1, 0, 0)
Layout.KITCHEN_FOOTPRINT = Vector2.new(52, 42)
Layout.KITCHEN_SIZE = Vector3.new(Layout.KITCHEN_FOOTPRINT.X, 30, Layout.KITCHEN_FOOTPRINT.Y)

Layout.LIBRARY_CELL = "D4"
Layout.LIBRARY_OFFSET = Vector3.new(150, 0, 90)
Layout.LIBRARY_FACING = Vector3.new(-1, 0, 0)
Layout.LIBRARY_FOOTPRINT = Vector2.new(84, 62)
Layout.LIBRARY_SIZE = Vector3.new(Layout.LIBRARY_FOOTPRINT.X, 27, Layout.LIBRARY_FOOTPRINT.Y)
Layout.LIBRARY_RESERVED_RADIUS = 66
Layout.LIBRARY_APPROACH_LENGTH = 38
Layout.LIBRARY_APPROACH_WIDTH = 20

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

function Layout.reservedZones(area: Areas.AreaDefinition): { Zone }
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

			radius = math.sqrt(half.X * half.X + half.Z * half.Z) + 10,
		})

		local approach = kitchenFrame:PointToWorldSpace(Vector3.new(0, 0, -44.5)) - area.origin
		table.insert(zones, {
			kind = "circle",
			x = approach.X,
			z = approach.Z,
			radius = 20,
		})
	end

	if area.id == Areas.STARTING_AREA then
		local libraryFrame = Layout.libraryCFrame(area)
		local libraryOffset = libraryFrame.Position - area.origin
		table.insert(zones, {
			kind = "circle",
			x = libraryOffset.X,
			z = libraryOffset.Z,
			radius = Layout.LIBRARY_RESERVED_RADIUS,
		})

		local direction = libraryFrame.LookVector
		local approachCentre = libraryFrame:PointToWorldSpace(
			Vector3.new(0, 0, -(Layout.LIBRARY_FOOTPRINT.Y / 2 + Layout.LIBRARY_APPROACH_LENGTH / 2))
		) - area.origin
		table.insert(zones, {
			kind = "strip",
			x = approachCentre.X,
			z = approachCentre.Z,
			dirX = direction.X,
			dirZ = direction.Z,
			halfLength = Layout.LIBRARY_APPROACH_LENGTH / 2,
			halfWidth = Layout.LIBRARY_APPROACH_WIDTH / 2,
		})
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
		local lake = Fishing.centre()
		if lake then
			table.insert(zones, {
				kind = "circle",
				x = lake.X,
				z = lake.Y,
				radius = Fishing.LAKE.reserveRadius,
			})
		end

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
	end

	return zones
end

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

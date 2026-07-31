--[[
	Fills the ground. See docs/GAME.md §7.

	The world is one continuous landmass roughly 27,000 studs long and 114
	million square studs in area. That breaks the naive approach in two separate
	ways, and this module exists for both:

	  1. Terrain:FillBlock is bounded by how many voxels a single call may touch.
	     The Ruins alone is 6,000 studs square; at the old fill depth that is
	     around nine million voxels in one call. So every fill is TILED at
	     TERRAIN_TILE studs a side.

	  2. Even tiled, filling the whole world takes long enough to matter. Doing
	     it synchronously in WorldService.init would hold the server — and every
	     joining player — for the duration.

	So: Town is filled SYNCHRONOUSLY and everything else runs on a background
	task that yields every few tiles. A player can spawn in their cottage and
	start working while the far end of the world is still arriving. Nothing east
	of Town is reachable in the seconds that takes; it is gated behind a skill
	total nobody has on their first frame.

	The ground is a SHELL, not a solid: ISLAND_DEPTH is the thickness of the
	crust, and no part of the game ever sees the inside of it. At this surface
	area that choice is worth several million voxels.
]]

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Budget = require(Shared.Modules.Budget)
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Sections = require(Shared.Modules.Config.Sections)

local TerrainBuilder = {}

local WORLD = Constants.WORLD

-- Set once the background pass has filled every area. Nothing gates on it
-- today; it exists so a future service that must not run against half a world
-- has something to wait on.
TerrainBuilder.ready = false

local readySignal = Instance.new("BindableEvent")
local filled = 0

--------------------------------------------------------------------------------
-- Relief
--------------------------------------------------------------------------------

--[[
	The island used to be a flat slab and read like one. Now it has a height
	field: gentle rolling noise everywhere, and a rim of mountains around the
	shore that frames the world and gives the eye somewhere to go.

	Everything that must stay flat — plaza, districts, the east-west road, the
	safe-zone plot — is protected by a mask built from Layout.reservedZones:
	inside a zone the height is 0, and it ramps up over MASK_FADE studs so pads
	get a sloped approach rather than a cliff through their middle.

	Props do not care: WorldService seats them by raycast, so decoration
	follows whatever ground this builds.
]]
local MASK_FADE = 70

local MOUNTAINS = {
	{ x = -540, z = 540, h = 42, r = 150 },
	{ x = 545, z = 505, h = 36, r = 120 },
	{ x = -520, z = -545, h = 48, r = 160 },
	{ x = 520, z = -540, h = 30, r = 110 },
	{ x = 0, z = 595, h = 22, r = 130 },
	{ x = -605, z = 60, h = 26, r = 120 },
	{ x = 610, z = -40, h = 24, r = 110 },
}

local function edgeDistance(zones: { Layout.Zone }, x: number, z: number): number
	local best = math.huge
	for _, zone in zones do
		local distance
		if zone.kind == "circle" then
			local dx, dz = x - zone.x, z - zone.z
			distance = math.sqrt(dx * dx + dz * dz) - (zone.radius or 0)
		elseif zone.kind == "strip" then
			local dx, dz = x - zone.x, z - zone.z
			distance = math.max(
				math.abs(dx * (zone.dirX or 0) + dz * (zone.dirZ or 0)) - (zone.halfLength or 0),
				math.abs(dx * (zone.dirZ or 0) - dz * (zone.dirX or 0)) - (zone.halfWidth or 0)
			)
		else
			distance = math.max(math.abs(x - zone.x) - (zone.halfX or 0), math.abs(z - zone.z) - (zone.halfZ or 0))
		end
		best = math.min(best, distance)
	end
	return best
end

local function heightAt(zones: { Layout.Zone }, x: number, z: number): number
	local mask = math.clamp(edgeDistance(zones, x, z) / MASK_FADE, 0, 1)
	if mask <= 0 then
		return 0
	end

	local rolling = math.noise(x / 260, z / 260, 7) * 5 + math.noise(x / 95, z / 95, 13) * 2.5
	local hills = 0
	for _, mountain in MOUNTAINS do
		local dx, dz = x - mountain.x, z - mountain.z
		hills += mountain.h * math.exp(-(dx * dx + dz * dz) / (2 * mountain.r * mountain.r))
	end

	-- Only ever RAISE. Digging would undermine the plaza, the pads and the shore.
	return math.max(0, rolling + hills) * mask
end

local function materialOf(name: string): Enum.Material
	local material = (Enum.Material :: any)[name]
	if not material then
		warn(`[TerrainBuilder] unknown terrain material "{name}", falling back to Grass`)
		return Enum.Material.Grass
	end
	return material
end

--[[
	One tiled fill of an axis-aligned box. `step` is nil for the base island,
	which must be on the ground before the first player is, and a frame-budget
	stepper for everything after.

	Tiles overlap by a stud so marching cubes does not leave a seam between them.
]]
type Step = (() -> ())?

local function fillBox(centre: Vector3, size: Vector3, material: Enum.Material, step: Step)
	local terrain = Workspace.Terrain
	local tile = WORLD.TERRAIN_TILE
	local overlap = 1

	local countX = math.max(1, math.ceil(size.X / tile))
	local countZ = math.max(1, math.ceil(size.Z / tile))
	local stepX = size.X / countX
	local stepZ = size.Z / countZ

	for ix = 1, countX do
		for iz = 1, countZ do
			local offsetX = -size.X / 2 + (ix - 0.5) * stepX
			local offsetZ = -size.Z / 2 + (iz - 0.5) * stepZ

			terrain:FillBlock(
				CFrame.new(centre + Vector3.new(offsetX, 0, offsetZ)),
				Vector3.new(stepX + overlap, size.Y, stepZ + overlap),
				material
			)

			filled += 1
			if step then
				step()
			end
		end
	end
end

--[[
	Any tiled fill, for a caller that owns its own volume.

	Exported because the cave carves under the board and needs exactly this: a
	FillBlock that respects the voxel-per-call bound and hands the frame back
	between tiles. A second copy of that loop is a second place to get it wrong.
]]
TerrainBuilder.fill = fillBox

--[[
	An area's ground: a rock core with the area's own surface material laid on
	top, both positioned from their TOP edge so the surface lands exactly on
	TERRAIN_TOP. The rock is what makes a cut edge read as ground rather than as
	a floating slab of grass.

	The surface extends a skirt past the walkable area so the shoreline is
	terrain rather than a cliff at the boundary.
]]
function TerrainBuilder.buildGround(area: Areas.AreaDefinition, step: Step)
	local size = area.terrain.islandSize
	local skirt = WORLD.SHORE_FALLOFF
	local top = WORLD.TERRAIN_TOP
	local surfaceDepth = WORLD.ISLAND_DEPTH / 2
	local coreDepth = WORLD.ISLAND_DEPTH

	fillBox(
		area.origin + Vector3.new(0, top - surfaceDepth - coreDepth / 2, 0),
		Vector3.new(size + skirt * 2, coreDepth, size + skirt * 2),
		Enum.Material.Rock,
		step
	)

	fillBox(
		area.origin + Vector3.new(0, top - surfaceDepth / 2, 0),
		Vector3.new(size + skirt, surfaceDepth, size + skirt),
		materialOf(area.terrain.material),
		step
	)
end

--[[
	Section ground. Each themed square gets its own terrain material laid over
	the base surface — farm is turned earth, the thicket is snow, the knoll is
	rock — and then the relief pass raises hills and mountains on top of that.
	The patchwork IS the section grid, readable from any hill.

	Cosmetic on top of buildGround, so it runs on the background pass.
]]
function TerrainBuilder.paintSections(area: Areas.AreaDefinition, step: Step)
	if not Sections.THEMES[area.key] and area.key ~= "town" then
		return
	end

	local zones = Layout.reservedZones(area)
	for _, cell in Sections.cells() do
		TerrainBuilder.paintCell(area, cell, zones, step)
	end
end

function TerrainBuilder.buildArea(area: Areas.AreaDefinition, step: Step)
	-- Animated blades on Grass and LeafyGrass. Stated rather than inherited:
	-- the forest floor depends on it.
	Workspace.Terrain.Decoration = true
	TerrainBuilder.buildGround(area, step)
	TerrainBuilder.paintSections(area, step)
end

--------------------------------------------------------------------------------
-- Per cell
--------------------------------------------------------------------------------

local SUB = 4
local CLEAR_HEIGHT = 200

function TerrainBuilder.paintCell(area: Areas.AreaDefinition, cell: Sections.Cell, zones: { Layout.Zone }, step: Step)
	local top = WORLD.TERRAIN_TOP
	local theme = Sections.THEMES[cell.theme]
	local baseMaterial = materialOf(area.terrain.material)
	local material = materialOf(if theme then theme.material else area.terrain.material)

	Workspace.Terrain:FillBlock(
		CFrame.new(area.origin + Vector3.new(cell.cx, top - 0.8, cell.cz)),
		Vector3.new(Sections.SIZE + 1, 1.6, Sections.SIZE + 1),
		material
	)

	--[[
		A themed cell may subdivide further and add its own relief. The default
		grid is 53 studs a step, which is fine under a farm and reads as a flat
		table under a forest: the ground between trees is what sells the trees.
	]]
	local relief = theme and theme.relief
	local divisions = if relief then relief.subdivide else SUB
	local subSize = Sections.SIZE / divisions

	for ti = 1, divisions do
		for tj = 1, divisions do
			local sx = cell.minX + (ti - 0.5) * subSize
			local sz = cell.minZ + (tj - 0.5) * subSize
			local h = heightAt(zones, sx, sz)
			if relief then
				local mask = math.clamp(edgeDistance(zones, sx, sz) / MASK_FADE, 0, 1)
				h += math.max(0, math.noise(sx / relief.scale, sz / relief.scale, 31) + 0.28)
					* relief.amp
					* mask
			end
			if h > 0.5 then
				Workspace.Terrain:FillBlock(
					CFrame.new(area.origin + Vector3.new(sx, top + h / 2, sz)),
					Vector3.new(subSize + 1, h, subSize + 1),
					if h > 16 then Enum.Material.Rock elseif theme then material else baseMaterial
				)
				filled += 1
				if step then
					step()
				end
			end
		end
	end
end

function TerrainBuilder.clearCell(area: Areas.AreaDefinition, cell: Sections.Cell)
	Workspace.Terrain:FillBlock(
		CFrame.new(area.origin + Vector3.new(cell.cx, WORLD.TERRAIN_TOP + CLEAR_HEIGHT / 4, cell.cz)),
		Vector3.new(Sections.SIZE, CLEAR_HEIGHT, Sections.SIZE),
		Enum.Material.Air
	)
end

function TerrainBuilder.buildCell(area: Areas.AreaDefinition, cell: Sections.Cell, step: Step)
	local top = WORLD.TERRAIN_TOP
	local surfaceDepth = WORLD.ISLAND_DEPTH / 2
	local coreDepth = WORLD.ISLAND_DEPTH
	local size = Sections.SIZE + 1

	fillBox(
		area.origin + Vector3.new(cell.cx, top - surfaceDepth - coreDepth / 2, cell.cz),
		Vector3.new(size, coreDepth, size),
		Enum.Material.Rock,
		step
	)
	fillBox(
		area.origin + Vector3.new(cell.cx, top - surfaceDepth / 2, cell.cz),
		Vector3.new(size, surfaceDepth, size),
		materialOf(area.terrain.material),
		step
	)

	TerrainBuilder.paintCell(area, cell, Layout.reservedZones(area), step)
end

--[[
	The isthmus between two areas — the road you physically walk to get from one
	to the next, and the thing that makes this a world rather than six teleport
	destinations.

	Surfaced in the material of the area to its west, so the ground changes
	underfoot as you cross rather than at an invisible line.
]]
function TerrainBuilder.buildBridge(bridge: Layout.Bridge, step: Step)
	local from = Areas.get(bridge.fromId)
	if not from then
		return
	end

	local top = WORLD.TERRAIN_TOP
	local surfaceDepth = WORLD.ISLAND_DEPTH / 2
	local coreDepth = WORLD.ISLAND_DEPTH

	fillBox(
		bridge.centre + Vector3.new(0, top - surfaceDepth - coreDepth / 2, 0),
		Vector3.new(bridge.size.X, coreDepth, bridge.size.Z + 40),
		Enum.Material.Rock,
		step
	)

	fillBox(
		bridge.centre + Vector3.new(0, top - surfaceDepth / 2, 0),
		Vector3.new(bridge.size.X, surfaceDepth, bridge.size.Z),
		materialOf(from.terrain.material),
		step
	)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Yields until the background pass has filled every area. WorldService's
-- scenery pass waits on this: props are seated by raycast against the ground.
function TerrainBuilder.awaitReady()
	if TerrainBuilder.ready then
		return
	end
	readySignal.Event:Wait()
end

--[[
	Lays the ground everyone stands on and returns. Section relief, the other
	areas and the bridges are all cosmetic on top of that, so they run on a
	background task that hands the frame back between fills.
]]
function TerrainBuilder.init()
	Workspace.Terrain:Clear()
	filled = 0
	TerrainBuilder.ready = false

	local start = os.clock()
	local town = Areas.BY_ID[Areas.STARTING_AREA]
	TerrainBuilder.buildGround(town, nil)
	print(`[TerrainBuilder] {town.name} ground in {string.format("%.2f", os.clock() - start)}s ({filled} tiles)`)

	task.spawn(function()
		local step = Budget.stepper()

		--[[
			Guarded so that `ready` is reached whatever happens in here. Anything
			waiting on it is waiting to DRESS a world that already exists; losing
			the relief to a bad fill must not also lose the scenery.
		]]
		local ok, err = pcall(function()
			TerrainBuilder.paintSections(town, step)

			for _, area in Areas.ALL do
				if area.id ~= Areas.STARTING_AREA then
					TerrainBuilder.buildArea(area, step)
				end
			end

			for _, bridge in Layout.bridges() do
				TerrainBuilder.buildBridge(bridge, step)
			end
		end)

		if not ok then
			warn(`[TerrainBuilder] relief pass failed: {err}`)
		end

		TerrainBuilder.ready = true
		readySignal:Fire()
		print(
			`[TerrainBuilder] whole world ready in {string.format("%.2f", os.clock() - start)}s ({filled} tiles total)`
		)
	end)
end

return TerrainBuilder

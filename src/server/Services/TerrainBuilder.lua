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

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)

local TerrainBuilder = {}

local WORLD = Constants.WORLD

-- Set once the background pass has filled every area. Nothing gates on it
-- today; it exists so a future service that must not run against half a world
-- has something to wait on.
TerrainBuilder.ready = false

local filled = 0

local function materialOf(name: string): Enum.Material
	local material = (Enum.Material :: any)[name]
	if not material then
		warn(`[TerrainBuilder] unknown terrain material "{name}", falling back to Grass`)
		return Enum.Material.Grass
	end
	return material
end

--[[
	One tiled fill of an axis-aligned box. `yield` is false for Town, which must
	be on the ground before the first player is, and true for everything after.

	Tiles overlap by a stud so marching cubes does not leave a seam between them.
]]
local function fillBox(centre: Vector3, size: Vector3, material: Enum.Material, yield: boolean)
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
			if yield and filled % WORLD.TERRAIN_YIELD_EVERY == 0 then
				RunService.Heartbeat:Wait()
			end
		end
	end
end

--[[
	An area's ground: a rock core with the area's own surface material laid on
	top, both positioned from their TOP edge so the surface lands exactly on
	TERRAIN_TOP. The rock is what makes a cut edge read as ground rather than as
	a floating slab of grass.

	The surface extends a skirt past the walkable area so the shoreline is
	terrain rather than a cliff at the boundary.
]]
function TerrainBuilder.buildArea(area: Areas.AreaDefinition, yield: boolean)
	local size = area.terrain.islandSize
	local skirt = WORLD.SHORE_FALLOFF
	local top = WORLD.TERRAIN_TOP
	local surfaceDepth = WORLD.ISLAND_DEPTH / 2
	local coreDepth = WORLD.ISLAND_DEPTH

	fillBox(
		area.origin + Vector3.new(0, top - surfaceDepth - coreDepth / 2, 0),
		Vector3.new(size + skirt * 2, coreDepth, size + skirt * 2),
		Enum.Material.Rock,
		yield
	)

	fillBox(
		area.origin + Vector3.new(0, top - surfaceDepth / 2, 0),
		Vector3.new(size + skirt, surfaceDepth, size + skirt),
		materialOf(area.terrain.material),
		yield
	)
end

--[[
	The isthmus between two areas — the road you physically walk to get from one
	to the next, and the thing that makes this a world rather than six teleport
	destinations.

	Surfaced in the material of the area to its west, so the ground changes
	underfoot as you cross rather than at an invisible line.
]]
function TerrainBuilder.buildBridge(bridge: Layout.Bridge, yield: boolean)
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
		yield
	)

	fillBox(
		bridge.centre + Vector3.new(0, top - surfaceDepth / 2, 0),
		Vector3.new(bridge.size.X, surfaceDepth, bridge.size.Z),
		materialOf(from.terrain.material),
		yield
	)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

--[[
	Fills the starting area and returns. Everything else is scheduled on a
	background task, so this is what the boot sequence actually waits for.
]]
function TerrainBuilder.init()
	Workspace.Terrain:Clear()
	filled = 0
	TerrainBuilder.ready = false

	local start = os.clock()
	local town = Areas.BY_ID[Areas.STARTING_AREA]
	TerrainBuilder.buildArea(town, false)
	print(`[TerrainBuilder] {town.name} ready in {string.format("%.2f", os.clock() - start)}s ({filled} tiles)`)

	task.spawn(function()
		for _, area in Areas.ALL do
			if area.id ~= Areas.STARTING_AREA then
				TerrainBuilder.buildArea(area, true)
			end
		end

		for _, bridge in Layout.bridges() do
			TerrainBuilder.buildBridge(bridge, true)
		end

		TerrainBuilder.ready = true
		print(
			`[TerrainBuilder] whole world ready in {string.format("%.2f", os.clock() - start)}s ({filled} tiles total)`
		)
	end)
end

return TerrainBuilder

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

TerrainBuilder.ready = false

local readySignal = Instance.new("BindableEvent")
local filled = 0

local MASK_FADE = 70

local MOUNTAINS = {
	{ x = -540, z = 540, h = 42, r = 150 },
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
			local along = math.abs(dx * (zone.dirX or 0) + dz * (zone.dirZ or 0)) - (zone.halfLength or 0)
			local across = math.abs(dx * (zone.dirZ or 0) - dz * (zone.dirX or 0)) - (zone.halfWidth or 0)
			distance = math.max(along, across)
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

TerrainBuilder.fill = fillBox

function TerrainBuilder.fillCylinder(
	centre: Vector3,
	height: number,
	radius: number,
	material: Enum.Material,
	step: Step
)
	if radius <= 0 or height <= 0 then
		return
	end

	local slabs = math.max(1, math.ceil(height / WORLD.TERRAIN_TILE))
	local slabHeight = height / slabs

	for index = 1, slabs do
		local offsetY = -height / 2 + (index - 0.5) * slabHeight
		Workspace.Terrain:FillCylinder(
			CFrame.new(centre + Vector3.new(0, offsetY, 0)),
			slabHeight + 1,
			radius,
			material
		)
		filled += 1
		if step then
			step()
		end
	end
end

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
	Workspace.Terrain.Decoration = true
	TerrainBuilder.buildGround(area, step)
	TerrainBuilder.paintSections(area, step)
end

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
				h += math.max(0, math.noise(sx / relief.scale, sz / relief.scale, 31) + 0.28) * relief.amp * mask
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

function TerrainBuilder.awaitReady()
	if TerrainBuilder.ready then
		return
	end
	readySignal.Event:Wait()
end

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

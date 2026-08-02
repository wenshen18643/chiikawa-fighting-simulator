--!strict

local Sections = require(script.Parent.Sections)
local SausageForest = {}

SausageForest.CELLS = {
	{ coord = "C2", tier = 1 },
	{ coord = "B2", tier = 2 },
	{ coord = "C1", tier = 3 },
	{ coord = "B1", tier = 4 },
}

SausageForest.SPECIES = {
	{ id = "pinkSausage", weight = 6 },
	{ id = "goldSausage", weight = 1 },
}

SausageForest.SIZES = {
	{ id = "small", height = 8, extraClicks = 0, yield = 2, weight = 5 },
	{ id = "medium", height = 13, extraClicks = 4, yield = 5, weight = 4 },
	{ id = "large", height = 20, extraClicks = 9, yield = 10, weight = 2 },
}

SausageForest.FALLEN = {
	length = { 5, 10 },
	sink = 0.32,
	clicksOff = 3,
	minClicks = 2,
	yield = 1,
}

SausageForest.TREES_PER_CELL = 120
SausageForest.FALLEN_PER_CELL = 110
SausageForest.GROVES_PER_CELL = 16
SausageForest.GROVE_GAP = 34
SausageForest.GROVE_SPREAD = { 10, 22 }
SausageForest.GROVE_TREES = { 5, 11 }
SausageForest.MIN_GAP = 9
SausageForest.EDGE_FADE = 26
SausageForest.EDGE_DENSITY = 0.45
SausageForest.CLEARING_FADE = 16
SausageForest.FALLEN_DRIFT = { 3, 10 }

SausageForest.TREE_INSET = 8
SausageForest.CLEARING_RADIUS = 32
SausageForest.ARENA_OFFSET = 52
SausageForest.GUARDIAN_RING = 24
SausageForest.ALERT_RADIUS = 45
SausageForest.ALERT_INTERVAL = 0.5
SausageForest.RESPAWN_SECONDS = 420
SausageForest.BOSS_REWARD = { id = "goldSausage", count = 25 }

function SausageForest.pick(entries: { any }, rng: Random): any
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

local blockCentre: Vector2? = nil

local function block(): Vector2
	if not blockCentre then
		local sum, count = Vector2.new(0, 0), 0
		for _, entry in SausageForest.CELLS do
			local cell = Sections.byCoord(entry.coord)
			if cell then
				sum += Vector2.new(cell.cx, cell.cz)
				count += 1
			end
		end
		blockCentre = if count > 0 then sum / count else Vector2.new(0, 0)
	end
	return blockCentre :: Vector2
end

function SausageForest.arena(cell: Sections.Cell): Vector2
	local at = Vector2.new(cell.cx, cell.cz)
	local out = at - block()
	if out.Magnitude < 1 then
		return at
	end
	return at + out.Unit * SausageForest.ARENA_OFFSET
end

function SausageForest.bounds(cell: Sections.Cell): { minX: number, maxX: number, minZ: number, maxZ: number }
	local seam = SausageForest.MIN_GAP / 2

	local function pad(x: number, z: number): number
		return if Sections.isWild(x, z) then seam else SausageForest.TREE_INSET
	end
	local probe = 4
	return {
		minX = cell.minX + pad(cell.minX - probe, cell.cz),
		maxX = cell.maxX - pad(cell.maxX + probe, cell.cz),
		minZ = cell.minZ + pad(cell.cx, cell.minZ - probe),
		maxZ = cell.maxZ - pad(cell.cx, cell.maxZ + probe),
	}
end

function SausageForest.guardianId(tier: number): string
	return `sausage_guardian_{tier}`
end

function SausageForest.bossId(tier: number): string
	return `sausage_boss_{tier}`
end

return SausageForest

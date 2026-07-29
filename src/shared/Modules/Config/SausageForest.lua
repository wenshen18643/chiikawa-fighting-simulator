--!strict

--[[
	The sausage forest: four sections of the board, ordered by how far they sit
	from the plaza. Tier 1 is the edge you walk in through, tier 4 the deepest
	corner. Everything that scales with depth reads its tier from here.
]]

local Sections = require(script.Parent.Sections)

local SausageForest = {}

SausageForest.CELLS = {
	{ coord = "C2", tier = 1 },
	{ coord = "B2", tier = 2 },
	{ coord = "C1", tier = 3 },
	{ coord = "B1", tier = 4 },
}

-- Pink is the forest, gold is the prize hiding in it.
SausageForest.SPECIES = {
	{ id = "pinkSausage", weight = 6 },
	{ id = "goldSausage", weight = 1 },
}

--[[
	A tree's size is its whole difficulty curve: taller costs more clicks and
	pays more sausages. Three readable steps rather than a continuous scale, so
	a player can tell across a clearing which tree is worth walking to.

	The smallest is 7 studs, above a default R15 avatar: nothing in the forest
	should read as something you could step over.
]]
SausageForest.SIZES = {
	{ id = "small", height = 8, extraClicks = 0, yield = 2, weight = 5 },
	{ id = "medium", height = 13, extraClicks = 4, yield = 5, weight = 4 },
	{ id = "large", height = 20, extraClicks = 9, yield = 10, weight = 2 },
}

--[[
	Fallen sausages: already on the floor, so cheap to pick up and barely worth
	it. They are what makes the forest floor read as a forest, and the reason to
	keep walking to a standing tree.
]]
SausageForest.FALLEN = {
	length = { 5, 10 },
	sink = 0.32,
	clicksOff = 3, -- taken off the ingredient's own minClicks
	minClicks = 2,
	yield = 1,
}

--[[
	How the forest is laid out, which is the whole of how it feels to walk into.

	Trees come in GROVES, not in an even sprinkle. An even sprinkle reads as an
	orchard: every gap the same, nothing to walk towards. Clumps leave GLADES
	between them, and a glade is the thing a player actually walks along, so the
	forest steers without a path being drawn on the floor.

	Three rules shape a walk from the treeline to the BIG tree:

	  - EDGE_FADE thins the outermost band, so the forest starts rather than
	    beginning at a wall.
	  - CLEARING_FADE thickens it towards the arena, then stops dead at its rim,
	    so the trees close in and then open out.
	  - MIN_GAP is never violated, so there is always a way through. A forest
	    you have to fight is a corridor, not a forest.
]]
SausageForest.TREES_PER_CELL = 120 -- cap; groves decide the real count
SausageForest.FALLEN_PER_CELL = 110
SausageForest.GROVES_PER_CELL = 16
SausageForest.GROVE_GAP = 34 -- between grove centres: this is the glade width
SausageForest.GROVE_SPREAD = { 10, 22 }
SausageForest.GROVE_TREES = { 5, 11 }
SausageForest.MIN_GAP = 9 -- between trunks: a player is ~4 studs across
SausageForest.EDGE_FADE = 26 -- the thinning band at the treeline
SausageForest.EDGE_DENSITY = 0.45
SausageForest.CLEARING_FADE = 16 -- ramp from the arena rim into the trees
SausageForest.FALLEN_DRIFT = { 3, 10 } -- how far litter lies from the tree it fell off

SausageForest.TREE_INSET = 8 -- off the treeline only; inner seams stay planted
SausageForest.CLEARING_RADIUS = 32 -- the arena: nothing grows this close to the BIG one
--[[
	The arena sits off-centre, pushed away from the middle of the four-cell
	block. Four arenas each on their own cell centre punch four holes in a 2x2
	square and leave the deep middle -- the one part of the map you have to walk
	furthest for -- as the emptiest ground in the forest. Pushed outward, the
	holes land in the outer quarters and the middle closes over.
]]
SausageForest.ARENA_OFFSET = 52
SausageForest.GUARDIAN_RING = 24 -- how far the guardians stand from the BIG tree
SausageForest.ALERT_RADIUS = 45 -- step inside this and the whole ring wakes up
SausageForest.ALERT_INTERVAL = 0.5
SausageForest.RESPAWN_SECONDS = 420 -- after the BIG tree falls, before the grove returns
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

--[[
	Plantable bounds. TREE_INSET is a treeline rule, not a cell rule: held off
	every side would leave a bald cross through the middle of the block, because
	four sausage cells share three inner seams and nothing else stops there. A
	seam between two forest cells only needs the trunks on either side to keep
	MIN_GAP apart, so each cell gives up half of it.
]]
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

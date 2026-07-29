--!strict

--[[
	The sausage forest: four sections of the board, ordered by how far they sit
	from the plaza. Tier 1 is the edge you walk in through, tier 4 the deepest
	corner. Everything that scales with depth reads its tier from here.
]]

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
	{ id = "small", height = 7, extraClicks = 0, yield = 1, weight = 6 },
	{ id = "medium", height = 12, extraClicks = 4, yield = 3, weight = 3 },
	{ id = "large", height = 18, extraClicks = 9, yield = 7, weight = 1 },
}

--[[
	Fallen sausages. Not pullable and not scenery from another biome: the brief
	is a forest with nothing in it but sausages, so the litter on the floor is
	the same asset lying down at ankle height.
]]
SausageForest.LITTER = { length = { 4, 9 }, sink = 0.35 }

SausageForest.TREES_PER_CELL = 64
SausageForest.LITTER_PER_CELL = 70
SausageForest.TREE_INSET = 14 -- keep trunks off the section seam
SausageForest.CLEARING_RADIUS = 40 -- the arena: nothing grows this close to the BIG one
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

function SausageForest.guardianId(tier: number): string
	return `sausage_guardian_{tier}`
end

function SausageForest.bossId(tier: number): string
	return `sausage_boss_{tier}`
end

return SausageForest

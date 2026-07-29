--!strict

export type BaseMobDefinition = {
	id: string,
	name: string,
	modelName: string,
	assetKey: string,
	rigProfile: string,
	animProfile: string,
	regionId: number,
	population: number,
	height: number,
	spawnRadius: number,
	roamRadius: number,
	leashRadius: number,
	roamSpeed: number,
	playerAttackRange: number,
	playerFacingMinimum: number,
	maxHealth: number,
	hitGainMultiplier: number,
	damageStatScale: number,
	respawn: boolean?, -- nil is yes; the forest respawns its own on its own clock
}

export type FightMobDefinition = BaseMobDefinition & {
	behavior: "fight",
	chaseSpeed: number,
	attackRange: number,
	attackDamage: number,
	attackCooldown: number,
}

export type FleeMobDefinition = BaseMobDefinition & {
	behavior: "flee",
	fleeSpeed: number,
	fleeDistance: number,
	fleeSafeDistance: number,
	fleeDuration: number,
}

--[[
	A mob that is planted. It never paths anywhere: it turns to face whoever
	walked into reach and hits them. Its reach is longer than a player's so
	standing at the edge of your own swing is not a free kill.
]]
export type RootMobDefinition = BaseMobDefinition & {
	behavior: "root",
	attackRange: number,
	attackDamage: number,
	attackCooldown: number,
}

export type MobDefinition = FightMobDefinition | FleeMobDefinition | RootMobDefinition

local Mobs = {}

Mobs.ORDER = { "mushroom_frog", "duck", "wolf" }

Mobs.DEFINITIONS = {
	mushroom_frog = {
		id = "mushroom_frog",
		name = "Mushroom Frog",
		modelName = "MushroomFrog",
		assetKey = "mushroomFrog",
		rigProfile = "mushroomFrog",
		animProfile = "mushroomFrog",
		behavior = "fight",
		regionId = 1,
		population = 6,
		height = 5.5,
		spawnRadius = 72,
		roamRadius = 35,
		leashRadius = 90,
		roamSpeed = 6,
		chaseSpeed = 12,
		playerAttackRange = 14,
		playerFacingMinimum = 0.35,
		attackRange = 7.5,
		attackDamage = 2,
		attackCooldown = 2,
		maxHealth = 10,
		hitGainMultiplier = 2,
		damageStatScale = 0.01,
	},
	duck = {
		id = "duck",
		name = "Duck",
		modelName = "Duck",
		assetKey = "duck",
		rigProfile = "duck",
		animProfile = "duck",
		behavior = "flee",
		regionId = 1,
		population = 4,
		height = 4.5,
		spawnRadius = 95,
		roamRadius = 35,
		leashRadius = 100,
		roamSpeed = 6,
		fleeSpeed = 15,
		fleeDistance = 48,
		fleeSafeDistance = 38,
		fleeDuration = 4,
		playerAttackRange = 14,
		playerFacingMinimum = 0.35,
		maxHealth = 8,
		hitGainMultiplier = 1.5,
		damageStatScale = 0.01,
	},
	wolf = {
		id = "wolf",
		name = "Wolf",
		modelName = "Wolf",
		assetKey = "wolf",
		rigProfile = "wolf",
		animProfile = "wolf",
		behavior = "fight",
		regionId = 1,
		population = 3,
		height = 4.5,
		spawnRadius = 320,
		roamRadius = 110,
		leashRadius = 190,
		roamSpeed = 9,
		chaseSpeed = 17,
		playerAttackRange = 14,
		playerFacingMinimum = 0.35,
		attackRange = 7.5,
		attackDamage = 4,
		attackCooldown = 1.6,
		maxHealth = 30,
		hitGainMultiplier = 3,
		damageStatScale = 0.01,
	},
} :: { [string]: MobDefinition }

--[[
	The sausage forest, one entry per board section, shallowest first. The
	guardians ring the BIG tree of their section and the BIG tree cannot be cut
	until they are down, so a tier's real difficulty is its whole row.

	Populations and spawn points come from SausageForestService, not from the
	ring spawner, which is why these are absent from Mobs.ORDER.
]]
local FOREST_TIERS = {
	{ guardians = 4, guardianHealth = 45, guardianDamage = 4, guardianHeight = 7, bossHealth = 320, bossDamage = 7, bossHeight = 24 },
	{ guardians = 5, guardianHealth = 80, guardianDamage = 6, guardianHeight = 8, bossHealth = 620, bossDamage = 10, bossHeight = 27 },
	{ guardians = 6, guardianHealth = 140, guardianDamage = 8, guardianHeight = 9, bossHealth = 1200, bossDamage = 14, bossHeight = 30 },
	{ guardians = 7, guardianHealth = 240, guardianDamage = 11, guardianHeight = 10, bossHealth = 2400, bossDamage = 19, bossHeight = 34 },
}

local function forestMob(fields: { [string]: any }): MobDefinition
	local definition = {
		rigProfile = "sausageGuardian",
		animProfile = "sausageGuardian",
		regionId = 1,
		spawnRadius = 0,
		playerAttackRange = 14,
		playerFacingMinimum = 0.35,
		attackCooldown = 2,
		hitGainMultiplier = 4,
		damageStatScale = 0.01,
		respawn = false,
	}
	for key, value in fields do
		definition[key] = value
	end
	return definition :: any
end

for tier, spec in FOREST_TIERS do
	--[[
		Guardians walk, but their home is the BIG tree rather than their own
		spawn point (SausageForestService passes it), so `leashRadius` is the
		edge of the clearing: they patrol it and will not be baited out of it.
	]]
	Mobs.DEFINITIONS[`sausage_guardian_{tier}`] = forestMob({
		id = `sausage_guardian_{tier}`,
		name = "Sausage Guardian",
		modelName = "SausageGuardian",
		assetKey = "pinkSausageTree",
		behavior = "fight",
		population = spec.guardians,
		height = spec.guardianHeight,
		maxHealth = spec.guardianHealth,
		attackDamage = spec.guardianDamage,
		attackRange = 8,
		roamSpeed = 5,
		chaseSpeed = 13,
		roamRadius = 20,
		leashRadius = 55,
	})
	-- The BIG tree is a tree: it is rooted, and only its reach defends it.
	Mobs.DEFINITIONS[`sausage_boss_{tier}`] = forestMob({
		id = `sausage_boss_{tier}`,
		name = "Great Sausage",
		modelName = "GreatSausage",
		assetKey = "yellowSausageTree",
		behavior = "root",
		population = 1,
		height = spec.bossHeight,
		maxHealth = spec.bossHealth,
		attackDamage = spec.bossDamage,
		attackRange = 22,
		attackCooldown = 2.6,
		hitGainMultiplier = 12,
		roamSpeed = 0,
		roamRadius = 0,
		leashRadius = 60,
	})
end

function Mobs.get(id: string): MobDefinition?
	return Mobs.DEFINITIONS[id]
end

return Mobs

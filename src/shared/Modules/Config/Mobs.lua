--!strict

export type MobDrop = {
	id: string,
	min: number,
	max: number,
}

export type BaseMobDefinition = {
	id: string,
	name: string,
	modelName: string,
	assetKey: string,
	build: string?,
	palette: { [string]: Color3 }?,
	rigProfile: string,
	animProfile: string,
	regionId: number,
	population: number,
	height: number,
	spawnRadius: number,
	spawnAngleOffset: number?,
	spawnCentreOffset: Vector3?,
	spawnCells: { string }?,
	roamRadius: number,
	leashRadius: number,
	roamSpeed: number,
	playerAttackRange: number,
	playerFacingMinimum: number,
	maxHealth: number,
	hitGainMultiplier: number,
	damageStatScale: number,
	respawn: boolean?,
	respawnSeconds: number?,
	drop: MobDrop?,
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

export type RootMobDefinition = BaseMobDefinition & {
	behavior: "root",
	attackRange: number,
	attackDamage: number,
	attackCooldown: number,
}

export type MobDefinition = FightMobDefinition | FleeMobDefinition | RootMobDefinition

local Mobs = {}

Mobs.ORDER = { "mushroom_frog", "duck", "wolf" }

Mobs.RING_INNER = { "C2", "D2", "E3", "E4", "D5", "B4", "B3" }

Mobs.RING_MID = { "B2", "B5", "E5", "E2" }

Mobs.RING_OUTER = {
	"A1", "B1", "C1", "D1", "E1", "F1",
	"F2", "F3", "F4", "F5",
	"F6", "E6", "D6", "C6", "B6", "A6",
	"A5", "A4", "A3", "A2",
}

local DEFINITIONS: { [string]: MobDefinition } = {
	mushroom_frog = {
		id = "mushroom_frog",
		name = "Mushroom Frog",
		modelName = "MushroomFrog",
		assetKey = "mushroomFrog",
		rigProfile = "mushroomFrog",
		animProfile = "mushroomFrog",
		behavior = "fight" :: "fight",
		regionId = 1,
		population = 16,
		height = 5.5,
		spawnRadius = 44,
		spawnCells = Mobs.RING_INNER,
		roamRadius = 22,
		leashRadius = 90,
		roamSpeed = 6,
		chaseSpeed = 12,
		playerAttackRange = 16,
		playerFacingMinimum = 0.35,
		attackRange = 13,
		attackDamage = 14,
		attackCooldown = 2,
		maxHealth = 110,
		hitGainMultiplier = 2,
		damageStatScale = 0.01,
		respawnSeconds = 20,
		drop = { id = "frogMeat", min = 1, max = 2 },
	},
	duck = {
		id = "duck",
		name = "Duck",
		modelName = "Duck",
		assetKey = "duck",
		rigProfile = "duck",
		animProfile = "duck",
		behavior = "flee" :: "flee",
		regionId = 1,
		population = 10,
		height = 4.5,
		spawnRadius = 95,
		spawnCells = Mobs.RING_MID,
		roamRadius = 35,
		leashRadius = 100,
		roamSpeed = 6,
		fleeSpeed = 15,
		fleeDistance = 48,
		fleeSafeDistance = 38,
		fleeDuration = 4,
		playerAttackRange = 16,
		playerFacingMinimum = 0.35,
		maxHealth = 85,
		hitGainMultiplier = 1.5,
		damageStatScale = 0.01,
		respawnSeconds = 30,
		drop = { id = "duckMeat", min = 1, max = 2 },
	},
	wolf = {
		id = "wolf",
		name = "Wolf",
		modelName = "Wolf",
		assetKey = "wolf",
		rigProfile = "wolf",
		animProfile = "wolf",
		behavior = "fight" :: "fight",
		regionId = 1,
		population = 18,
		height = 4.5,
		spawnRadius = 320,
		spawnAngleOffset = 60,
		spawnCells = Mobs.RING_OUTER,
		roamRadius = 110,
		leashRadius = 190,
		roamSpeed = 9,
		chaseSpeed = 17,
		playerAttackRange = 18,
		playerFacingMinimum = 0.35,
		attackRange = 15,
		attackDamage = 45,
		attackCooldown = 1.6,
		maxHealth = 550,
		hitGainMultiplier = 3,
		damageStatScale = 0.01,
		respawnSeconds = 45,
		drop = { id = "wolfMeat", min = 1, max = 2 },
	},
}

Mobs.DEFINITIONS = DEFINITIONS

local CAVE_CREAM = Color3.fromRGB(228, 217, 200)
local CAVE_VIOLET = Color3.fromRGB(146, 112, 156)
local CAVE_SLATE = Color3.fromRGB(112, 116, 126)
local CAVE_GOLD = Color3.fromRGB(248, 218, 142)

Mobs.DEFINITIONS.cave_sporeling = {
	id = "cave_sporeling",
	name = "Sporeling",
	modelName = "Sporeling",
	assetKey = "",
	build = "sporeling",
	palette = {
		body = CAVE_CREAM,
		cap = CAVE_VIOLET,
		accent = Color3.fromRGB(240, 232, 218),
		eye = Color3.fromRGB(42, 32, 46),
	},
	rigProfile = "caveSporeling",
	animProfile = "caveSporeling",
	behavior = "fight",
	regionId = 1,
	population = 0,
	height = 5.5,
	spawnRadius = 0,
	roamRadius = 14,
	leashRadius = 52,
	roamSpeed = 6,
	chaseSpeed = 11,
	playerAttackRange = 16,
	playerFacingMinimum = 0.35,
	attackRange = 13,
	attackDamage = 32,
	attackCooldown = 2,
	maxHealth = 420,
	hitGainMultiplier = 3,
	damageStatScale = 0.01,
	respawnSeconds = 45,
} :: any

Mobs.DEFINITIONS.cave_pebblejaw = {
	id = "cave_pebblejaw",
	name = "Pebblejaw",
	modelName = "Pebblejaw",
	assetKey = "",
	build = "pebblejaw",
	palette = {
		body = CAVE_SLATE,
		cap = Color3.fromRGB(84, 88, 98),
		accent = Color3.fromRGB(160, 164, 172),
		eye = Color3.fromRGB(226, 138, 96),
	},
	rigProfile = "cavePebblejaw",
	animProfile = "cavePebblejaw",
	behavior = "fight",
	regionId = 1,
	population = 0,
	height = 5,
	spawnRadius = 0,
	roamRadius = 16,
	leashRadius = 62,
	roamSpeed = 7,
	chaseSpeed = 15,
	playerAttackRange = 18,
	playerFacingMinimum = 0.35,
	attackRange = 15,
	attackDamage = 76,
	attackCooldown = 1.8,
	maxHealth = 1400,
	hitGainMultiplier = 5,
	damageStatScale = 0.01,
	respawnSeconds = 60,
} :: any

Mobs.DEFINITIONS.cave_wisp = {
	id = "cave_wisp",
	name = "Lantern Wisp",
	modelName = "LanternWisp",
	assetKey = "",
	build = "wisp",
	palette = {
		glow = CAVE_GOLD,
		cap = Color3.fromRGB(196, 178, 224),
		accent = Color3.fromRGB(255, 244, 206),
		eye = Color3.fromRGB(58, 44, 30),
	},
	rigProfile = "caveWisp",
	animProfile = "caveWisp",
	behavior = "flee",
	regionId = 1,
	population = 0,
	height = 4,
	spawnRadius = 0,
	roamRadius = 22,
	leashRadius = 70,
	roamSpeed = 7,
	fleeSpeed = 16,
	fleeDistance = 40,
	fleeSafeDistance = 30,
	fleeDuration = 3.5,
	playerAttackRange = 16,
	playerFacingMinimum = 0.35,
	maxHealth = 500,
	hitGainMultiplier = 4,
	damageStatScale = 0.01,
	respawnSeconds = 40,
} :: any

Mobs.DEFINITIONS.cave_mycelia = {
	id = "cave_mycelia",
	name = "Mycelia, the Cap Mother",
	modelName = "Mycelia",
	assetKey = "",
	build = "mycelia",
	palette = {
		body = Color3.fromRGB(206, 192, 176),
		cap = Color3.fromRGB(112, 78, 128),
		accent = Color3.fromRGB(232, 216, 236),
		glow = Color3.fromRGB(180, 240, 200),
	},
	rigProfile = "caveMycelia",
	animProfile = "caveMycelia",
	behavior = "root",
	regionId = 1,
	population = 1,
	height = 26,
	spawnRadius = 0,
	roamRadius = 0,
	leashRadius = 60,
	roamSpeed = 0,
	playerAttackRange = 26,
	playerFacingMinimum = 0.3,
	attackRange = 34,
	attackDamage = 220,
	attackCooldown = 2.4,
	maxHealth = 37000,
	hitGainMultiplier = 14,
	damageStatScale = 0.01,
	respawn = false,
} :: any

local FOREST_TIERS = {
	{ guardians = 5, guardianHealth = 750, guardianDamage = 44, guardianHeight = 7, bossHealth = 7000, bossDamage = 100, bossHeight = 24 },
	{ guardians = 6, guardianHealth = 1325, guardianDamage = 64, guardianHeight = 8, bossHealth = 13600, bossDamage = 144, bossHeight = 27 },
	{ guardians = 7, guardianHealth = 2300, guardianDamage = 86, guardianHeight = 9, bossHealth = 26400, bossDamage = 202, bossHeight = 30 },
	{ guardians = 8, guardianHealth = 3950, guardianDamage = 118, guardianHeight = 10, bossHealth = 52800, bossDamage = 274, bossHeight = 34 },
}

local function forestMob(fields: { [string]: any }): MobDefinition
	local definition = {
		rigProfile = "sausageGuardian",
		animProfile = "sausageGuardian",
		regionId = 1,
		spawnRadius = 0,
		playerAttackRange = 18,
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
		attackRange = 14,
		roamSpeed = 5,
		chaseSpeed = 13,
		roamRadius = 20,
		leashRadius = 55,
	})
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
		attackRange = 32,
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

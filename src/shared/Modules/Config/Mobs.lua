--!strict

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
	roamRadius: number,
	leashRadius: number,
	roamSpeed: number,
	playerAttackRange: number,
	playerFacingMinimum: number,
	maxHealth: number,
	hitGainMultiplier: number,
	damageStatScale: number,
	respawn: boolean?,
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
		population = 6,
		height = 5.5,
		spawnCentreOffset = Vector3.new(0, 0, -139),
		spawnRadius = 44,
		roamRadius = 22,
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
		behavior = "flee" :: "flee",
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
		behavior = "fight" :: "fight",
		regionId = 1,
		population = 3,
		height = 4.5,
		spawnRadius = 320,
		spawnAngleOffset = 60,
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
	playerAttackRange = 14,
	playerFacingMinimum = 0.35,
	attackRange = 7.5,
	attackDamage = 3,
	attackCooldown = 2,
	maxHealth = 26,
	hitGainMultiplier = 3,
	damageStatScale = 0.01,
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
	playerAttackRange = 14,
	playerFacingMinimum = 0.35,
	attackRange = 8.5,
	attackDamage = 7,
	attackCooldown = 1.8,
	maxHealth = 85,
	hitGainMultiplier = 5,
	damageStatScale = 0.01,
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
	playerAttackRange = 14,
	playerFacingMinimum = 0.35,
	maxHealth = 30,
	hitGainMultiplier = 4,
	damageStatScale = 0.01,
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
	playerAttackRange = 16,
	playerFacingMinimum = 0.3,
	attackRange = 24,
	attackDamage = 16,
	attackCooldown = 2.4,
	maxHealth = 1800,
	hitGainMultiplier = 14,
	damageStatScale = 0.01,
	respawn = false,
} :: any

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

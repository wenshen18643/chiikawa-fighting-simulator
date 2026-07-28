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

export type MobDefinition = FightMobDefinition | FleeMobDefinition

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

function Mobs.get(id: string): MobDefinition?
	return Mobs.DEFINITIONS[id]
end

return Mobs

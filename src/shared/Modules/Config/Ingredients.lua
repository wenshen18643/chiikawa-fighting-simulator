export type IngredientDefinition = {
	id: string,
	name: string,
	asset: string,
	rarity: string,
	gateExponent: number,
	minClicks: number,
	xpMultiplier: number,
	regrowSeconds: number,
	clip: string,
	glyph: string,
	ground: boolean?,
	height: number?,
	skill: string?,
	material: boolean?,
	yen: number?,
	meat: boolean?,
}

export type ZoneLifecycle = "node-regrow" | "clump-reroll"

export type ZoneDefinition = {
	id: string,
	name: string,
	angle: number,
	distance: number,
	radius: number,
	clumps: number,
	perClump: number,
	lifecycle: ZoneLifecycle,
	minClumpSpacing: number?,
	reserveDecor: boolean?,
	ingredients: { { id: string, weight: number } },
}

export type ClumpDefinition = {
	perClump: number,
	yieldScale: number,
	glow: boolean?,
	ingredients: { { id: string, weight: number } },
}

local Ingredients = {}

Ingredients.WEED_ID = "weed"

Ingredients.RARITY = {
	common = { order = 1, color = Color3.fromRGB(126, 226, 96), label = "Common" },
	rare = { order = 2, color = Color3.fromRGB(96, 186, 255), label = "Rare" },
	super = { order = 3, color = Color3.fromRGB(178, 132, 255), label = "Super" },
	legendary = { order = 4, color = Color3.fromRGB(255, 198, 64), label = "Legendary" },
}

Ingredients.ORDER = {
	Ingredients.WEED_ID,
	"carrot",
	"potato",
	"rice",
	"blueBerry",
	"purpleBerry",
	"brownMushroom",
	"blackBerry",
	"whiteMushroom",
	"pinkSausage",
	"whiteBerry",
	"goldSausage",
	"moonlightCap",
	"chalkStone",
	"ironOre",
	"copperOre",
	"quartzOre",
	"moonOre",
	"frogMeat",
	"duckMeat",
	"wolfMeat",
}

Ingredients.DEFINITIONS = {
	weed = {
		id = Ingredients.WEED_ID,
		name = "Weed",
		asset = "",
		rarity = "common",
		gateExponent = 0,
		minClicks = 0,
		xpMultiplier = 0,
		regrowSeconds = 0,
		clip = "farm_carrot",
		glyph = "leaf",
	},
	carrot = {
		id = "carrot",
		name = "Carrot",
		asset = "carrot",
		rarity = "common",
		gateExponent = 0,
		minClicks = 3,
		xpMultiplier = 6,
		regrowSeconds = 45,
		clip = "farm_carrot",
		glyph = "carrot",
		ground = true,
		height = 1.8,
	},
	potato = {
		id = "potato",
		name = "Potato",
		asset = "potato",
		rarity = "common",
		gateExponent = 0,
		minClicks = 3,
		xpMultiplier = 6,
		regrowSeconds = 45,
		clip = "farm_potato",
		glyph = "potato",
		ground = true,
		height = 1.6,
	},
	rice = {
		id = "rice",
		name = "Rice",
		asset = "rice",
		rarity = "common",
		gateExponent = 0,
		minClicks = 4,
		xpMultiplier = 8,
		regrowSeconds = 60,
		clip = "farm_rice",
		glyph = "rice",
		height = 3.2,
	},
	blueBerry = {
		id = "blueBerry",
		name = "Blue Berry",
		asset = "blueBerryBush",
		rarity = "common",
		gateExponent = 4,
		minClicks = 4,
		xpMultiplier = 12,
		regrowSeconds = 60,
		clip = "farm_berry_shake",
		glyph = "berry",
		height = 3.6,
	},
	purpleBerry = {
		id = "purpleBerry",
		name = "Purple Berry",
		asset = "purpleBerryBush",
		rarity = "common",
		gateExponent = 4,
		minClicks = 4,
		xpMultiplier = 12,
		regrowSeconds = 60,
		clip = "farm_berry_pick",
		glyph = "berry",
		height = 3.6,
	},
	brownMushroom = {
		id = "brownMushroom",
		name = "Brown Mushroom",
		asset = "brownMushroom",
		rarity = "rare",
		gateExponent = 5,
		minClicks = 5,
		xpMultiplier = 50,
		regrowSeconds = 90,
		clip = "farm_mushroom_twist",
		glyph = "mushroom",
		height = 2.4,
	},
	blackBerry = {
		id = "blackBerry",
		name = "Black Berry",
		asset = "blackBerryBush",
		rarity = "rare",
		gateExponent = 5,
		minClicks = 5,
		xpMultiplier = 50,
		regrowSeconds = 90,
		clip = "farm_berry_pluck",
		glyph = "berry",
		height = 3.8,
	},
	whiteMushroom = {
		id = "whiteMushroom",
		name = "White Mushroom",
		asset = "whiteMushroom",
		rarity = "rare",
		gateExponent = 6,
		minClicks = 6,
		xpMultiplier = 120,
		regrowSeconds = 120,
		clip = "farm_mushroom_pull",
		glyph = "mushroom",
		height = 3.0,
	},
	pinkSausage = {
		id = "pinkSausage",
		name = "Pink Sausage",
		asset = "pinkSausageTree",
		rarity = "super",
		gateExponent = 7,
		minClicks = 7,
		xpMultiplier = 500,
		regrowSeconds = 180,
		clip = "farm_sausage_pull",
		glyph = "sausage",
		height = 7,
	},
	whiteBerry = {
		id = "whiteBerry",
		name = "White Berry",
		asset = "whiteBerryBush",
		rarity = "super",
		gateExponent = 8,
		minClicks = 7,
		xpMultiplier = 1000,
		regrowSeconds = 240,
		clip = "farm_berry_reach",
		glyph = "berry",
		height = 4.0,
	},
	goldSausage = {
		id = "goldSausage",
		name = "Gold Sausage",
		asset = "yellowSausageTree",
		rarity = "legendary",
		gateExponent = 9,
		minClicks = 8,
		xpMultiplier = 5000,
		regrowSeconds = 300,
		clip = "farm_sausage_yank",
		glyph = "sausage",
		height = 8,
	},

	moonlightCap = {
		id = "moonlightCap",
		name = "Moonlight Cap",
		asset = "whiteMushroom",
		rarity = "legendary",
		gateExponent = 8,
		minClicks = 8,
		xpMultiplier = 3200,
		regrowSeconds = 260,
		clip = "farm_mushroom_pull",
		glyph = "mushroom",
		height = 3.4,
	},
	chalkStone = {
		id = "chalkStone",
		name = "Chalk Stone",
		asset = "oreChunk",
		rarity = "common",
		gateExponent = 0,
		minClicks = 6,
		xpMultiplier = 9,
		regrowSeconds = 60,
		clip = "farm_potato",
		glyph = "ore",
		skill = "tobatsu",
		material = true,
		height = 2,
		yen = 40,
	},
	ironOre = {
		id = "ironOre",
		name = "Iron Ore",
		asset = "oreChunk",
		rarity = "common",
		gateExponent = 0,
		minClicks = 7,
		xpMultiplier = 18,
		regrowSeconds = 75,
		clip = "farm_potato",
		glyph = "ore",
		skill = "tobatsu",
		material = true,
		height = 2.2,
		yen = 85,
	},
	copperOre = {
		id = "copperOre",
		name = "Copper Ore",
		asset = "oreChunk",
		rarity = "rare",
		gateExponent = 2,
		minClicks = 9,
		xpMultiplier = 110,
		regrowSeconds = 95,
		clip = "farm_potato",
		glyph = "ore",
		skill = "tobatsu",
		material = true,
		height = 2.4,
		yen = 340,
	},
	quartzOre = {
		id = "quartzOre",
		name = "Quartz",
		asset = "oreChunk",
		rarity = "super",
		gateExponent = 4,
		minClicks = 11,
		xpMultiplier = 700,
		regrowSeconds = 120,
		clip = "farm_potato",
		glyph = "ore",
		skill = "tobatsu",
		material = true,
		height = 2.6,
		yen = 1650,
	},
	moonOre = {
		id = "moonOre",
		name = "Moonstone Ore",
		asset = "oreChunk",
		rarity = "legendary",
		gateExponent = 7,
		minClicks = 15,
		xpMultiplier = 4800,
		regrowSeconds = 210,
		clip = "farm_potato",
		glyph = "ore",
		skill = "tobatsu",
		material = true,
		height = 3,
		yen = 11000,
	},
	frogMeat = {
		id = "frogMeat",
		name = "Frog Cut",
		asset = "",
		rarity = "common",
		gateExponent = 0,
		minClicks = 0,
		xpMultiplier = 0,
		regrowSeconds = 0,
		clip = "farm_carrot",
		glyph = "meat",
		skill = "tobatsu",
		height = 1.4,
		meat = true,
	},
	duckMeat = {
		id = "duckMeat",
		name = "Duck Cut",
		asset = "",
		rarity = "rare",
		gateExponent = 0,
		minClicks = 0,
		xpMultiplier = 0,
		regrowSeconds = 0,
		clip = "farm_carrot",
		glyph = "meat",
		skill = "tobatsu",
		height = 1.6,
		meat = true,
	},
	wolfMeat = {
		id = "wolfMeat",
		name = "Wolf Cut",
		asset = "",
		rarity = "super",
		gateExponent = 0,
		minClicks = 0,
		xpMultiplier = 0,
		regrowSeconds = 0,
		clip = "farm_carrot",
		glyph = "meat",
		skill = "tobatsu",
		height = 1.8,
		meat = true,
	},
} :: { [string]: IngredientDefinition }

Ingredients.ZONES = {
	{
		id = "home_fields",
		name = "Home Fields",

		angle = 102,
		distance = 511,
		radius = 45,
		clumps = 6,
		perClump = 5,
		lifecycle = "clump-reroll",
		minClumpSpacing = 20,
		reserveDecor = true,
		ingredients = {
			{ id = "carrot", weight = 3 },
			{ id = "potato", weight = 3 },
			{ id = "rice", weight = 2 },
		},
	},
	{
		id = "berry_grove",
		name = "Berry Grove",
		angle = 180,
		distance = 300,
		radius = 78,
		clumps = 8,
		perClump = 4,
		lifecycle = "node-regrow",
		ingredients = {
			{ id = "blueBerry", weight = 3 },
			{ id = "purpleBerry", weight = 3 },
			{ id = "blackBerry", weight = 1 },
		},
	},
	{
		id = "mushroom_hollow",
		name = "Mushroom Hollow",
		angle = 300,
		distance = 345,
		radius = 74,
		clumps = 7,
		perClump = 4,
		lifecycle = "node-regrow",
		ingredients = {
			{ id = "brownMushroom", weight = 3 },
			{ id = "whiteMushroom", weight = 2 },
		},
	},
	{
		id = "bramble_hollow",
		name = "Bramble Hollow",
		angle = 205,
		distance = 450,
		radius = 68,
		clumps = 5,
		perClump = 4,
		lifecycle = "node-regrow",
		ingredients = {
			{ id = "blackBerry", weight = 3 },
			{ id = "purpleBerry", weight = 1 },
		},
	},

	{
		id = "snow_thicket",
		name = "Snow Berry Thicket",
		angle = 320,
		distance = 548,
		radius = 66,
		clumps = 4,
		perClump = 4,
		lifecycle = "node-regrow",
		ingredients = {
			{ id = "whiteBerry", weight = 3 },
			{ id = "whiteMushroom", weight = 1 },
		},
	},
} :: { ZoneDefinition }

Ingredients.CLUMPS = {
	cave_glowcap = {
		perClump = 5,
		yieldScale = 2,
		glow = true,
		ingredients = {
			{ id = "brownMushroom", weight = 3 },
			{ id = "whiteMushroom", weight = 2 },
		},
	},
	cave_mooncap = {
		perClump = 4,
		yieldScale = 2,
		glow = true,
		ingredients = {
			{ id = "moonlightCap", weight = 1 },
		},
	},
} :: { [string]: ClumpDefinition }

function Ingredients.get(id: string): IngredientDefinition?
	return Ingredients.DEFINITIONS[id]
end

function Ingredients.isMeat(id: string): boolean
	local def = Ingredients.DEFINITIONS[id]
	return def ~= nil and def.meat == true
end

function Ingredients.rollIngredient(zone: ZoneDefinition, rng: Random): string?
	local total = 0
	for _, entry in zone.ingredients do
		if entry.weight > 0 then
			total += entry.weight
		end
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local running = 0
	local fallback: string? = nil
	for _, entry in zone.ingredients do
		if entry.weight > 0 then
			running += entry.weight
			fallback = entry.id
			if roll < running then
				return entry.id
			end
		end
	end

	return fallback
end

function Ingredients.clumpPlan(zone: ZoneDefinition): { string }
	local plan = {}
	local total = 0
	for _, entry in zone.ingredients do
		total += entry.weight
	end
	if total <= 0 then
		return plan
	end

	for index = 1, zone.clumps do
		local step = math.floor((index - 0.5) * total / zone.clumps) + 1
		local running = 0
		for _, entry in zone.ingredients do
			running += entry.weight
			if step <= running then
				table.insert(plan, entry.id)
				break
			end
		end
	end

	return plan
end

return Ingredients

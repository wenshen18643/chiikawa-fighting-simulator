local Constants = require(script.Parent.Parent.Constants)
local Boosts = require(script.Parent.Parent.Boosts)

export type FoodDefinition = {
	id: string,
	name: string,
	asset: string,
	height: number,
	clicks: number,
	wageMinutes: number,
	weight: number,
	buff: Boosts.FoodBuff,
}

local Feast = {}

Feast.TICK = 15
Feast.SPAWN_CHANCE = 0.08
Feast.MAX_ALIVE = 3
Feast.LIFETIME = 900
Feast.BITE_RADIUS = 18
Feast.MIN_GAP = 200
Feast.PLACE_ATTEMPTS = 30
Feast.CELL_MARGIN = 30
Feast.ANNOUNCE_RADIUS = 140

Feast.PROP_TAG = "FeastProp"
Feast.PROP_RESPAWN = 600

Feast.XP_PER_BITE = 1
Feast.FINISH_XP_PER_CLICK = 2

Feast.ORDER = { "onigiri", "dango", "pancakes", "yogurtBerry", "yogurtVanilla", "dangoPlatter", "ramen" }

Feast.DEFINITIONS = {
	onigiri = {
		id = "onigiri",
		name = "Giant Onigiri",
		asset = "onigiri",
		height = 18,
		clicks = 40,
		wageMinutes = 8,
		weight = 5,
		buff = { id = "feast_onigiri", skill = "resilience", bonus = Constants.FOOD.BONUS_MEAT },
	},
	dango = {
		id = "dango",
		name = "Giant Dango",
		asset = "dango",
		height = 20,
		clicks = 55,
		wageMinutes = 12,
		weight = 5,
		buff = { id = "feast_dango", skill = "kusatori", bonus = Constants.FOOD.BONUS_MEAT },
	},
	pancakes = {
		id = "pancakes",
		name = "Pancake Stack",
		asset = "pancakes",
		height = 22,
		clicks = 70,
		wageMinutes = 18,
		weight = 4,
		buff = { id = "feast_pancakes", skill = "tobatsu", bonus = Constants.FOOD.BONUS_MEAT },
	},
	yogurtBerry = {
		id = "yogurtBerry",
		name = "Berry Yogurt Tub",
		asset = "yogurtBerry",
		height = 22,
		clicks = 70,
		wageMinutes = 18,
		weight = 4,
		buff = { id = "feast_yogurt_berry", skill = "examprep", bonus = Constants.FOOD.BONUS_MEAT },
	},
	yogurtVanilla = {
		id = "yogurtVanilla",
		name = "Vanilla Yogurt Tub",
		asset = "yogurtVanilla",
		height = 24,
		clicks = 85,
		wageMinutes = 25,
		weight = 3,
		buff = { id = "feast_yogurt_vanilla", skill = "resilience", bonus = Constants.FOOD.BONUS_MEAT },
	},
	dangoPlatter = {
		id = "dangoPlatter",
		name = "Dango Platter",
		asset = "dangoPlatter",
		height = 26,
		clicks = 110,
		wageMinutes = 40,
		weight = 2,
		buff = { id = "feast_dango_platter", skill = "tobatsu", bonus = Constants.FOOD.BONUS_MEAT },
	},
	ramen = {
		id = "ramen",
		name = "Enormous Ramen",
		asset = "ramen",
		height = 28,
		clicks = 140,
		wageMinutes = 60,
		weight = 1,
		buff = { id = "feast_ramen", stat = "yen", bonus = Constants.FOOD.BONUS_MEAT },
	},
} :: { [string]: FoodDefinition }

function Feast.get(id: string): FoodDefinition?
	return Feast.DEFINITIONS[id]
end

function Feast.roll(rng: Random): FoodDefinition
	local total = 0
	for _, id in Feast.ORDER do
		total += Feast.DEFINITIONS[id].weight
	end

	local pick = rng:NextNumber() * total
	for _, id in Feast.ORDER do
		local def = Feast.DEFINITIONS[id]
		pick -= def.weight
		if pick <= 0 then
			return def
		end
	end
	return Feast.DEFINITIONS[Feast.ORDER[1]]
end

return Feast

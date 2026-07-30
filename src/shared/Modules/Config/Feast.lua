local Boosts = require(script.Parent.Parent.Boosts)

export type FoodDefinition = {
	id: string,
	name: string,
	asset: string,
	height: number,
	clicks: number,
	wageMinutes: number,
	weight: number,
	buff: Boosts.Boost,
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

-- Food the dressing pass put in the map, rather than food a plane dropped. It
-- has no lifetime: eaten, it grows back in its own spot after a wait.
Feast.PROP_TAG = "FeastProp"
Feast.PROP_RESPAWN = 600

-- Chewing is endurance, so a bite trains resilience the way a stir does
-- (Constants.COOKING). Paid per bite rather than in a lump at the end: a bowl
-- somebody else finishes must still have been worth the clicks you put in.
Feast.XP_PER_BITE = 1
-- On top of that, the last click is paid for the whole bowl again, twice over.
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
		buff = { id = "feast_onigiri", multiplier = 3, stat = "staminaRegen", duration = 120 },
	},
	dango = {
		id = "dango",
		name = "Giant Dango",
		asset = "dango",
		height = 20,
		clicks = 55,
		wageMinutes = 12,
		weight = 5,
		buff = { id = "feast_dango", multiplier = 3, skill = "kusatori", duration = 120 },
	},
	pancakes = {
		id = "pancakes",
		name = "Pancake Stack",
		asset = "pancakes",
		height = 22,
		clicks = 70,
		wageMinutes = 18,
		weight = 4,
		buff = { id = "feast_pancakes", multiplier = 3, skill = "tobatsu", duration = 180 },
	},
	yogurtBerry = {
		id = "yogurtBerry",
		name = "Berry Yogurt Tub",
		asset = "yogurtBerry",
		height = 22,
		clicks = 70,
		wageMinutes = 18,
		weight = 4,
		buff = { id = "feast_yogurt_berry", multiplier = 3, skill = "examprep", duration = 180 },
	},
	yogurtVanilla = {
		id = "yogurtVanilla",
		name = "Vanilla Yogurt Tub",
		asset = "yogurtVanilla",
		height = 24,
		clicks = 85,
		wageMinutes = 25,
		weight = 3,
		buff = { id = "feast_yogurt_vanilla", multiplier = 2, duration = 180 },
	},
	dangoPlatter = {
		id = "dangoPlatter",
		name = "Dango Platter",
		asset = "dangoPlatter",
		height = 26,
		clicks = 110,
		wageMinutes = 40,
		weight = 2,
		buff = { id = "feast_dango_platter", multiplier = 3, duration = 240 },
	},
	ramen = {
		id = "ramen",
		name = "Enormous Ramen",
		asset = "ramen",
		height = 28,
		clicks = 140,
		wageMinutes = 60,
		weight = 1,
		buff = { id = "feast_ramen", multiplier = 3, stat = "yen", duration = 300 },
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

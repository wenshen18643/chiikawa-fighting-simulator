--[[
	Seasonings: what a weed sometimes leaves behind.

	Pulling a weed has a small chance of turning one up. They are NOT a cooking
	input — a recipe you cannot start because the drop refused to happen is a
	wall built out of luck. Instead a seasoning is used straight from the
	inventory for a short, sharp buff, so a lucky pull is a good next two
	minutes rather than a permission slip.

	Buffs use the same shape as Config/Recipes: one skill, one stat, or neither
	(everything). Applied through the same upsert, so eating a dish and using a
	seasoning cannot stack two copies of the same id.
]]

export type SeasoningDefinition = {
	id: string,
	name: string,
	glyph: string,
	color: Color3,
	weight: number, -- relative chance among seasonings, once one drops
	buff: {
		id: string,
		multiplier: number,
		skill: string?,
		stat: string?,
		duration: number,
	},
}

local Seasonings = {}

-- Chance that a weed pull turns one up at all.
Seasonings.DROP_CHANCE = 0.05

Seasonings.ORDER = { "salt", "pepper", "chilli", "sugar" }

Seasonings.DEFINITIONS = {
	salt = {
		id = "salt",
		name = "Salt",
		glyph = "spark",
		color = Color3.fromRGB(238, 242, 250),
		weight = 4,
		buff = { id = "season_salt", multiplier = 1.5, stat = "staminaRegen", duration = 45 },
	},
	pepper = {
		id = "pepper",
		name = "Pepper",
		glyph = "spark",
		color = Color3.fromRGB(120, 128, 150),
		weight = 3,
		buff = { id = "season_pepper", multiplier = 1.5, skill = "kusatori", duration = 45 },
	},
	chilli = {
		id = "chilli",
		name = "Chilli",
		glyph = "carrot",
		color = Color3.fromRGB(255, 84, 72),
		weight = 2,
		buff = { id = "season_chilli", multiplier = 1.5, skill = "tobatsu", duration = 45 },
	},
	sugar = {
		id = "sugar",
		name = "Sugar",
		glyph = "dango",
		color = Color3.fromRGB(255, 198, 64),
		weight = 1,
		buff = { id = "season_sugar", multiplier = 1.5, stat = "yen", duration = 60 },
	},
} :: { [string]: SeasoningDefinition }

function Seasonings.get(id: string): SeasoningDefinition?
	return Seasonings.DEFINITIONS[id]
end

-- Which seasoning a drop turns out to be. Weighted, so sugar stays a treat.
function Seasonings.roll(rng: Random): SeasoningDefinition?
	local total = 0
	for _, id in Seasonings.ORDER do
		local def = Seasonings.get(id)
		total += if def then def.weight else 0
	end
	if total <= 0 then
		return nil
	end

	local pick = rng:NextNumber() * total
	local running = 0
	for _, id in Seasonings.ORDER do
		local def = Seasonings.get(id)
		if def then
			running += def.weight
			if pick <= running then
				return def
			end
		end
	end
	return nil
end

return Seasonings

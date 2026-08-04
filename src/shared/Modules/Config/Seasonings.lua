export type SeasoningDefinition = {
	id: string,
	name: string,
	glyph: string,
	color: Color3,
	weight: number,
	buff: {
		id: string,
		multiplier: number,
		skill: string?,
		stat: string?,
		duration: number,
	},
}

local Seasonings = {}

Seasonings.DROP_CHANCE = 0.05

Seasonings.ORDER = { "salt", "pepper", "chilli", "sugar" }

Seasonings.DEFINITIONS = {
	salt = {
		id = "salt",
		name = "Salt",
		glyph = "spark",
		color = Color3.fromRGB(238, 242, 250),
		weight = 4,
		buff = { id = "season_salt", multiplier = 1.5, skill = "resilience", duration = 45 },
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

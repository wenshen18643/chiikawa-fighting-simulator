export type RecipeBuff = {
	id: string,
	multiplier: number,
	skill: string?,
	stat: string?,
	duration: number,
}

export type RecipeDefinition = {
	id: string,
	name: string,
	model: string,
	ingredients: { { id: string, count: number } },
	baseClicks: number,
	buff: RecipeBuff,
	glyph: string,
	description: string,
	locked: boolean?,
}

local Ingredients = require(script.Parent.Ingredients)
local Recipes = {}

Recipes.ORDER = {
	"onigiri",
	"dango",
	"yogurtBerry",
	"forestTea",
	"ramen",
	"pancakes",
	"yogurtVanilla",
	"meatSkewer",
	"huntersStew",
	"championPlatter",
	"glowcapStew",
}

Recipes.DEFINITIONS = {
	onigiri = {
		id = "onigiri",
		name = "Onigiri",
		model = "onigiri",
		ingredients = { { id = "rice", count = 2 } },
		baseClicks = 8,
		buff = { id = "dish_onigiri", multiplier = 2, stat = "staminaRegen", duration = 60 },
		glyph = "onigiri",
		description = "Rice balls that put a spring back in your step.",
	},
	dango = {
		id = "dango",
		name = "Dango",
		model = "dango",
		ingredients = { { id = "blueBerry", count = 1 }, { id = "purpleBerry", count = 1 } },
		baseClicks = 10,
		buff = { id = "dish_dango", multiplier = 2, skill = "kusatori", duration = 60 },
		glyph = "dango",
		description = "Sweet skewers that make weeds fear you.",
	},
	yogurtBerry = {
		id = "yogurtBerry",
		name = "Berry Yogurt",
		model = "yogurtBerry",
		ingredients = { { id = "blackBerry", count = 2 } },
		baseClicks = 12,
		buff = { id = "dish_yogurt_berry", multiplier = 2, skill = "examprep", duration = 90 },
		glyph = "yogurt",
		description = "The lottery company approves of this study snack.",
	},
	forestTea = {
		id = "forestTea",
		name = "Forest Tea",
		model = "teaCup",
		ingredients = { { id = "brownMushroom", count = 1 }, { id = "carrot", count = 1 } },
		baseClicks = 12,
		buff = { id = "dish_forest_tea", multiplier = 2, skill = "resilience", duration = 90 },
		glyph = "tea",
		description = "Warmth that teaches you to endure. Cooks make tougher cooks.",
	},
	ramen = {
		id = "ramen",
		name = "Ramen",
		model = "ramen",
		ingredients = { { id = "pinkSausage", count = 1 }, { id = "rice", count = 1 }, { id = "potato", count = 1 } },
		baseClicks = 14,
		buff = { id = "dish_ramen", multiplier = 2, skill = "tobatsu", duration = 90 },
		glyph = "ramen",
		description = "The bowl. Sausage tree sausage, obviously.",
	},
	pancakes = {
		id = "pancakes",
		name = "Pancakes",
		model = "pancakes",
		ingredients = { { id = "whiteBerry", count = 2 }, { id = "rice", count = 1 } },
		baseClicks = 16,
		buff = { id = "dish_pancakes", multiplier = 2, stat = "yen", duration = 120 },
		glyph = "pancakes",
		description = "Stacked high enough to attract paying customers.",
	},
	yogurtVanilla = {
		id = "yogurtVanilla",
		name = "Vanilla Yogurt",
		model = "yogurtVanilla",
		ingredients = { { id = "whiteMushroom", count = 1 }, { id = "whiteBerry", count = 1 } },
		baseClicks = 16,
		buff = { id = "dish_yogurt_vanilla", multiplier = 1.5, duration = 120 },
		glyph = "yogurt",
		description = "Plain, perfect, and quietly improves everything.",
	},
	meatSkewer = {
		id = "meatSkewer",
		name = "Meat Skewer",
		model = "dango",
		ingredients = { { id = "frogMeat", count = 2 }, { id = "potato", count = 1 } },
		baseClicks = 12,
		buff = { id = "dish_meat_skewer", multiplier = 2, skill = "tobatsu", duration = 90 },
		glyph = "meat",
		description = "Whatever you caught, over the fire. Sharpens the hunt.",
	},
	huntersStew = {
		id = "huntersStew",
		name = "Hunter's Stew",
		model = "ramen",
		ingredients = {
			{ id = "wolfMeat", count = 1 },
			{ id = "duckMeat", count = 1 },
			{ id = "carrot", count = 1 },
		},
		baseClicks = 20,
		buff = { id = "dish_hunters_stew", multiplier = 3, skill = "resilience", duration = 120 },
		glyph = "meat",
		description = "Everything you outlasted, in one pot. It makes you harder to kill.",
	},
	championPlatter = {
		id = "championPlatter",
		name = "Champion Platter",
		model = "dangoPlatter",
		ingredients = {
			{ id = "goldSausage", count = 1 },
			{ id = "pinkSausage", count = 1 },
			{ id = "whiteBerry", count = 1 },
		},
		baseClicks = 20,
		buff = { id = "dish_champion", multiplier = 2, duration = 180 },
		glyph = "platter",
		description = "A legendary feast. Everything you do shines for a while.",
	},
	glowcapStew = {
		id = "glowcapStew",
		name = "Glowcap Stew",
		model = "ramen",
		ingredients = {
			{ id = "whiteMushroom", count = 3 },
			{ id = "brownMushroom", count = 2 },
		},
		baseClicks = 16,
		buff = { id = "dish_glowcap", multiplier = 3, skill = "tobatsu", duration = 120 },
		glyph = "mushroom",
		description = "Faintly luminous. The cook swears that part is fine.",
		locked = true,
	},
} :: { [string]: RecipeDefinition }

function Recipes.get(id: string): RecipeDefinition?
	return Recipes.DEFINITIONS[id]
end

function Recipes.isUnlocked(def: RecipeDefinition, profile: any): boolean
	if not def.locked then
		return true
	end
	return profile ~= nil and profile.recipes ~= nil and profile.recipes[def.id] == true
end

function Recipes.rarity(def: RecipeDefinition): string
	local rarest, order = "common", 0
	for _, entry in def.ingredients do
		local ingredient = Ingredients.get(entry.id)
		local tier = ingredient and Ingredients.RARITY[ingredient.rarity]
		if tier and tier.order > order then
			rarest, order = ingredient.rarity, tier.order
		end
	end
	return rarest
end

return Recipes

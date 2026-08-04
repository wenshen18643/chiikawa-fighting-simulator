export type RecipeBuff = {
	id: string,
	skill: string?,
	stat: string?,
	bonus: number,
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
	amplifier: boolean?,
}

local Constants = require(script.Parent.Parent.Constants)
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
	"duckGreens",
	"scholarsJerky",
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
		buff = { id = "dish_onigiri", skill = "resilience", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "onigiri",
		description = "Rice balls that put a spring back in your step. You last longer for it.",
	},
	dango = {
		id = "dango",
		name = "Dango",
		model = "dango",
		ingredients = { { id = "carrot", count = 1 }, { id = "rice", count = 1 } },
		baseClicks = 10,
		buff = { id = "dish_dango", skill = "kusatori", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "dango",
		description = "Sweet skewers that make weeds fear you.",
	},
	yogurtBerry = {
		id = "yogurtBerry",
		name = "Berry Yogurt",
		model = "yogurtBerry",
		ingredients = { { id = "brownMushroom", count = 2 } },
		baseClicks = 12,
		buff = { id = "dish_yogurt_berry", skill = "examprep", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "yogurt",
		description = "The lottery company approves of this study snack.",
	},
	forestTea = {
		id = "forestTea",
		name = "Forest Tea",
		model = "teaCup",
		ingredients = { { id = "brownMushroom", count = 1 }, { id = "carrot", count = 1 } },
		baseClicks = 12,
		buff = { id = "dish_forest_tea", skill = "resilience", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "tea",
		description = "Warmth that teaches you to endure. Cooks make tougher cooks.",
	},
	ramen = {
		id = "ramen",
		name = "Ramen",
		model = "ramen",
		ingredients = { { id = "pinkSausage", count = 1 }, { id = "rice", count = 1 }, { id = "potato", count = 1 } },
		baseClicks = 14,
		buff = { id = "dish_ramen", skill = "tobatsu", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "ramen",
		description = "The bowl. Sausage tree sausage, obviously.",
	},
	pancakes = {
		id = "pancakes",
		name = "Pancakes",
		model = "pancakes",
		ingredients = { { id = "whiteBerry", count = 2 }, { id = "rice", count = 1 } },
		baseClicks = 16,
		buff = { id = "dish_pancakes", stat = "yen", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "pancakes",
		description = "Stacked high enough to attract paying customers.",
	},
	yogurtVanilla = {
		id = "yogurtVanilla",
		name = "Vanilla Yogurt",
		model = "yogurtVanilla",
		ingredients = { { id = "whiteMushroom", count = 1 }, { id = "whiteBerry", count = 1 } },
		baseClicks = 16,
		buff = { id = "dish_yogurt_vanilla", skill = "kusatori", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "yogurt",
		description = "Plain, perfect, and quietly improves everything.",
	},
	meatSkewer = {
		id = "meatSkewer",
		name = "Meat Skewer",
		model = "dango",
		ingredients = { { id = "frogMeat", count = 2 }, { id = "potato", count = 1 } },
		baseClicks = 12,
		buff = { id = "dish_meat_skewer", skill = "tobatsu", bonus = Constants.FOOD.BONUS_MEAT },
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
		buff = { id = "dish_hunters_stew", skill = "resilience", bonus = Constants.FOOD.BONUS_MEAT },
		glyph = "meat",
		description = "Everything you outlasted, in one pot. It makes you harder to kill.",
	},
	duckGreens = {
		id = "duckGreens",
		name = "Duck & Greens",
		model = "ramen",
		ingredients = { { id = "duckMeat", count = 1 }, { id = "carrot", count = 1 }, { id = "brownMushroom", count = 1 } },
		baseClicks = 18,
		buff = { id = "dish_duck_greens", skill = "kusatori", bonus = Constants.FOOD.BONUS_MEAT },
		glyph = "meat",
		description = "Duck over field greens. The weeds never see you coming.",
	},
	scholarsJerky = {
		id = "scholarsJerky",
		name = "Scholar's Jerky",
		model = "dango",
		ingredients = { { id = "frogMeat", count = 2 }, { id = "brownMushroom", count = 1 } },
		baseClicks = 16,
		buff = { id = "dish_scholars_jerky", skill = "examprep", bonus = Constants.FOOD.BONUS_MEAT },
		glyph = "meat",
		description = "Chewy enough to keep you awake through the whole textbook.",
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
		buff = { id = Constants.FOOD.AMPLIFIER_ID, stat = Constants.FOOD.AMPLIFIER_STAT, bonus = 0 },
		glyph = "platter",
		description = "Eat before a cook-off. Every food buff you are running lasts half again as long.",
		amplifier = true,
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
		buff = { id = "dish_glowcap", skill = "tobatsu", bonus = Constants.FOOD.BONUS_PLAIN },
		glyph = "mushroom",
		description = "Faintly luminous. The cook swears that part is fine.",
		locked = true,
	},
} :: { [string]: RecipeDefinition }

function Recipes.hasMeat(def: RecipeDefinition): boolean
	for _, entry in def.ingredients do
		if Ingredients.isMeat(entry.id) then
			return true
		end
	end
	return false
end

function Recipes.isAmplifier(def: RecipeDefinition): boolean
	return def.amplifier == true
end

function Recipes.duration(def: RecipeDefinition): number
	if Recipes.hasMeat(def) then
		return Constants.FOOD.DURATION_TIER
	end
	local tier = Ingredients.RARITY[Recipes.rarity(def)]
	if tier and tier.order >= Constants.FOOD.TIER_RARITY_ORDER then
		return Constants.FOOD.DURATION_TIER
	end
	return Constants.FOOD.DURATION_BASE
end

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

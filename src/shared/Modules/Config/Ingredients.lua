--[[
	Forage ingredients and the zones they grow in.

	Every ingredient is a clickable clump out in Town (Config/Assets holds the
	models). Pulling one is click-gated: `gateExponent` is the kusatori log10 at
	which it opens at `minClicks`, and every exponent you are short adds
	Constants.FORAGE.CLICKS_PER_EXPONENT_BEHIND clicks. Fixed nodes regrow after
	`regrowSeconds`; dynamic clumps use that delay after the whole clump is clear.

	Ingredients are cooked into dishes at the kitchen (Config/Recipes.lua).
]]

export type IngredientDefinition = {
	id: string,
	name: string,
	asset: string, -- Assets.lua key for the node model
	rarity: string, -- key into Ingredients.RARITY
	gateExponent: number, -- kusatori log10 needed to pluck at minClicks
	minClicks: number,
	xpMultiplier: number, -- kusatori gain per pluck
	regrowSeconds: number,
	clip: string, -- PlayerAnims clip played while plucking
	glyph: string,
	ground: boolean?, -- grows under the soil: dug out of a dirt patch
	height: number?, -- studs tall once placed; nil keeps the authored size
}

export type ZoneLifecycle = "node-regrow" | "clump-reroll"

--[[
	A patch of ground where one set of ingredients grows, as a bearing and a
	distance from the plaza.

	Zones rather than a scatter over the whole island: an ingredient you can
	find anywhere is an ingredient with no address, and "the sausage forest is
	east past the weed field" is a thing one player can tell another.

	`weight` drives either the fixed clump plan or each independent dynamic roll,
	so a grove reads as mostly one thing with a few others mixed into it.
]]
export type ZoneDefinition = {
	id: string,
	name: string,
	angle: number, -- degrees from +X, same convention as Layout.SKILL_ANGLE
	distance: number, -- studs from the plaza centre
	radius: number, -- how far the clumps spread from the zone centre
	clumps: number,
	perClump: number,
	lifecycle: ZoneLifecycle,
	minClumpSpacing: number?, -- only used by randomly positioned clumps
	reserveDecor: boolean?, -- keeps world dressing out of the zone footprint
	ingredients: { { id: string, weight: number } },
}

local Ingredients = {}

--[[
	Rarity tiers, cheapest to rarest. Colors come from the same saturated
	arcade family as UI/Theme.lua so the chips read as lit on the dark panels.
]]
Ingredients.RARITY = {
	common = { order = 1, color = Color3.fromRGB(126, 226, 96), label = "Common" },
	rare = { order = 2, color = Color3.fromRGB(96, 186, 255), label = "Rare" },
	super = { order = 3, color = Color3.fromRGB(178, 132, 255), label = "Super" },
	legendary = { order = 4, color = Color3.fromRGB(255, 198, 64), label = "Legendary" },
}

Ingredients.ORDER = {
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
}

Ingredients.DEFINITIONS = {
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
} :: { [string]: IngredientDefinition }

--[[
	Where each thing grows, in walking order out from the plaza.

	The Home Fields sit on the old resilience district, which has had no pads
	since cooking took the skill over: the nearest empty ground to spawn is
	exactly where a beginner's crops should be. Everything rarer is further out,
	so the map itself tells you the order to learn it in.
]]
Ingredients.ZONES = {
	{
		id = "home_fields",
		name = "Home Fields",
		angle = 90,
		distance = 150,
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
	-- Sausages have no zone: they grow across whole board sections instead, laid
	-- out by SausageForestService from Config/SausageForest.
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

function Ingredients.get(id: string): IngredientDefinition?
	return Ingredients.DEFINITIONS[id]
end

-- One independent weighted roll. Dynamic clumps use this when they first
-- appear and every time a cleared clump is replaced; fixed zones keep using
-- clumpPlan so their authored mix stays deterministic.
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

--[[
	One ingredient id per clump, weighted.

	Built as a flat list and then walked in order rather than rolled per clump:
	a roll can hand a six-clump grove six of the same bush, and "mostly pink
	sausage with a gold one in it" has to be true on every server, not on
	average across them.
]]
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
		-- Position in the weighted cycle, so entries interleave instead of
		-- arriving in one block per ingredient.
		local step = ((index - 1) % total) + 1
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

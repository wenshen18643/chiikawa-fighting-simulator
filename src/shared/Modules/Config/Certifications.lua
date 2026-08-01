--[[
	Certification grades. See docs/GAME.md §6.

	Canon runs Grade 5 (lowest) down to Grade 1 (highest), then the design
	extends past canon into uncapped Special Grade (特級) star tiers.

	Because "grade 5 is worse than grade 1" reads backwards in code, profiles
	store an ORDER instead: 0 = uncertified, 1 = Grade 5, ... 5 = Grade 1,
	6+ = Special Grade with (order - 5) stars. `Certifications.describe` turns an
	order back into the label the player sees.

	Every skill runs its own ladder, and Exam Prep's order is the ceiling on all
	the others: Exam Prep Grade 3 means nothing else can pass Grade 3.
]]

local Certifications = {}

Certifications.MAX_CANON_ORDER = 5 -- order 5 == Grade 1, the top canon grade

-- Skill gain multiplier granted by holding this order in that skill.
Certifications.GAIN_MULTIPLIER_PER_ORDER = 1.5

-- Each order held in ANY skill adds this to the passive wage multiplier.
Certifications.WAGE_BONUS_PER_ORDER = 0.5

Certifications.CAP_SKILL = "examprep"

--[[
	Exam Prep is the only ladder with an item cost, and it takes one thing from
	each pillar so the ceiling can never be raised without a lap of the world.
	Tiers move up every three grades, which keeps the legendaries out of reach
	until the stat value that unlocks them is long passed.
]]
local ITEM_TIERS = {
	{ "ironOre", "crucian", "carrot" },
	{ "copperOre", "sweetfish", "blueBerry" },
	{ "quartzOre", "koi", "brownMushroom" },
	{ "moonOre", "moonScale", "moonlightCap" },
}

local ITEMS_PER_TIER = 3

function Certifications.gainMultiplier(order: number): number
	if order <= 0 then
		return 1
	end
	return Certifications.GAIN_MULTIPLIER_PER_ORDER ^ order
end

function Certifications.describe(order: number): string
	if order <= 0 then
		return "Uncertified"
	end
	if order <= Certifications.MAX_CANON_ORDER then
		return `Grade {Certifications.MAX_CANON_ORDER + 1 - order}`
	end
	return `Special Grade {string.rep("★", order - Certifications.MAX_CANON_ORDER)}`
end

-- Skill value needed to sit the exam for the next order up. Geometric, so the
-- ladder keeps going after canon runs out.
function Certifications.requirementForOrder(order: number): { m: number, e: number }
	return { m = 1, e = order + 1 }
end

-- The highest order any skill other than Exam Prep may hold.
function Certifications.capFor(profile: any): number
	return profile.certifications[Certifications.CAP_SKILL] or 0
end

function Certifications.isCapped(profile: any, skillId: string, order: number): boolean
	if skillId == Certifications.CAP_SKILL then
		return false
	end
	return order > Certifications.capFor(profile)
end

-- Ingredient cost of the Exam Prep exam at `order`, as {ingredientId = count}.
function Certifications.itemsForOrder(order: number): { [string]: number }
	local tier = ITEM_TIERS[math.min(math.ceil(order / ITEMS_PER_TIER), #ITEM_TIERS)]
	local count = (order - 1) % ITEMS_PER_TIER + 1

	local cost = {}
	for _, ingredientId in tier do
		cost[ingredientId] = count
	end
	return cost
end

return Certifications

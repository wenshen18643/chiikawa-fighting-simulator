local Certifications = {}

Certifications.MAX_CANON_ORDER = 5

Certifications.GAIN_MULTIPLIER_PER_ORDER = 1.5

Certifications.WAGE_BONUS_PER_ORDER = 0.5

Certifications.CAP_SKILL = "examprep"

local ITEM_TIERS = {
	{ "ironOre", "carrot", "potato" },
	{ "copperOre", "blueBerry", "purpleBerry" },
	{ "quartzOre", "brownMushroom", "blackBerry" },
	{ "moonOre", "moonlightCap", "goldSausage" },
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

function Certifications.requirementForOrder(order: number): { m: number, e: number }
	return { m = 1, e = order + 1 }
end

function Certifications.capFor(profile: any): number
	return profile.certifications[Certifications.CAP_SKILL] or 0
end

function Certifications.isCapped(profile: any, skillId: string, order: number): boolean
	if skillId == Certifications.CAP_SKILL then
		return false
	end
	return order > Certifications.capFor(profile)
end

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

--[[
	Certification grades. See docs/GAME.md §6.

	Canon runs Grade 5 (lowest) down to Grade 1 (highest), then the design
	extends past canon into uncapped Special Grade (特級) star tiers.

	Because "grade 5 is worse than grade 1" reads backwards in code, profiles
	store an ORDER instead: 0 = uncertified, 1 = Grade 5, ... 5 = Grade 1,
	6+ = Special Grade with (order - 5) stars. `Certifications.describe` turns an
	order back into the label the player sees.

	Slice 3 builds the exam loop on top of this. Slices 1-2 only read the
	multipliers, which are 1x at order 0 — so this is live but inert until then.
]]

local Certifications = {}

Certifications.MAX_CANON_ORDER = 5 -- order 5 == Grade 1, the top canon grade

-- Skill gain multiplier granted by holding this order in that skill.
Certifications.GAIN_MULTIPLIER_PER_ORDER = 2

-- Each order held in ANY skill adds this to the passive wage multiplier.
Certifications.WAGE_BONUS_PER_ORDER = 0.5

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
	return { m = 1, e = 2 + (order - 1) * 2 }
end

return Certifications

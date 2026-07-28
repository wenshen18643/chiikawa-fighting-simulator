--[[
	Timed multipliers, and the one sentence that describes one.

	Dishes and seasonings both grant these, and the HUD, the kitchen, the
	inventory and two server services all have to agree on what a boost means.
	That agreement lives here rather than being written out five times: the
	upsert rule (same id refreshes rather than stacks) is a game rule, not a
	detail of whichever service happened to grant it.

	`skill` scopes a boost to one skill, `stat` to a non-skill number ("yen" or
	"staminaRegen", see Formulas.boostStatMultiplier), and neither means all
	skills.
]]

local Skills = require(script.Parent.Config.Skills)

export type Boost = {
	id: string,
	multiplier: number,
	skill: string?,
	stat: string?,
	duration: number,
}

local Boosts = {}

function Boosts.apply(profile: any, boost: Boost)
	local expiresAt = os.time() + boost.duration

	for _, active in profile.boosts do
		if active.id == boost.id then
			active.multiplier = boost.multiplier
			active.skill = boost.skill
			active.stat = boost.stat
			active.expiresAt = expiresAt
			return
		end
	end

	table.insert(profile.boosts, {
		id = boost.id,
		multiplier = boost.multiplier,
		skill = boost.skill,
		stat = boost.stat,
		expiresAt = expiresAt,
	})
end

function Boosts.describe(boost: Boost): string
	local skill = boost.skill and Skills.get(boost.skill)
	if skill then
		return `{skill.name} gain x{boost.multiplier}`
	end
	if boost.stat == "yen" then
		return `Yen gain x{boost.multiplier}`
	end
	if boost.stat == "staminaRegen" then
		return `Stamina regen x{boost.multiplier}`
	end
	return `All skill gain x{boost.multiplier}`
end

return Boosts

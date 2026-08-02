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

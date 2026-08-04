local Constants = require(script.Parent.Constants)
local Skills = require(script.Parent.Config.Skills)

export type Boost = {
	id: string,
	multiplier: number,
	skill: string?,
	stat: string?,
	duration: number,
}

export type FoodBuff = {
	id: string,
	skill: string?,
	stat: string?,
	bonus: number,
}

export type FoodStack = {
	id: string,
	skill: string?,
	stat: string?,
	bonus: number,
	expiries: { number },
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

local function stacksOf(profile: any): { FoodStack }
	local stacks = profile.foodBuffs
	if stacks == nil then
		stacks = {}
		profile.foodBuffs = stacks
	end
	return stacks
end

local function insertSorted(expiries: { number }, value: number)
	local index = #expiries
	while index > 0 and expiries[index] > value do
		index -= 1
	end
	table.insert(expiries, index + 1, value)
end

local function dropExpired(expiries: { number }, now: number)
	local first = 1
	while expiries[first] ~= nil and expiries[first] <= now do
		first += 1
	end
	if first == 1 then
		return
	end
	local remaining = #expiries - first + 1
	if remaining > 0 then
		table.move(expiries, first, #expiries, 1)
	end
	for index = #expiries, remaining + 1, -1 do
		expiries[index] = nil
	end
end

function Boosts.pruneFood(profile: any, now: number?)
	local stacks = profile.foodBuffs
	if stacks == nil then
		return
	end
	local timestamp = now or os.time()
	for index = #stacks, 1, -1 do
		local entry = stacks[index]
		dropExpired(entry.expiries, timestamp)
		if #entry.expiries == 0 then
			table.remove(stacks, index)
		end
	end
end

function Boosts.foodDurationFactor(profile: any, now: number?): number
	local timestamp = now or os.time()
	local factor = 1
	for _, active in profile.boosts do
		if active.stat == Constants.FOOD.AMPLIFIER_STAT and (active.expiresAt or 0) > timestamp then
			factor *= active.multiplier or 1
		end
	end
	return factor
end

function Boosts.applyFood(profile: any, food: FoodBuff, baseDuration: number, now: number?): number
	local timestamp = now or os.time()
	local stacks = stacksOf(profile)
	Boosts.pruneFood(profile, timestamp)

	local entry: FoodStack? = nil
	for _, active in stacks do
		if active.id == food.id then
			entry = active
			break
		end
	end

	local target: FoodStack
	if entry then
		target = entry
		target.skill = food.skill
		target.stat = food.stat
		target.bonus = food.bonus
	else
		target = {
			id = food.id,
			skill = food.skill,
			stat = food.stat,
			bonus = food.bonus,
			expiries = {},
		}
		table.insert(stacks, target)
	end

	if #target.expiries >= Constants.FOOD.MAX_STACKS_PER_DISH then
		table.remove(target.expiries, 1)
	end

	local duration = baseDuration * Boosts.foodDurationFactor(profile, timestamp)
	insertSorted(target.expiries, timestamp + duration)
	return duration
end

function Boosts.extendFood(profile: any, factor: number, now: number?)
	local timestamp = now or os.time()
	Boosts.pruneFood(profile, timestamp)
	for _, entry in stacksOf(profile) do
		for index, expiresAt in entry.expiries do
			entry.expiries[index] = timestamp + (expiresAt - timestamp) * factor
		end
	end
end

function Boosts.foodStacks(entry: FoodStack, now: number): number
	local live = 0
	for index = #entry.expiries, 1, -1 do
		if entry.expiries[index] > now then
			live += 1
		else
			break
		end
	end
	return live
end

function Boosts.foodBonus(profile: any, key: string, isStat: boolean, now: number?): number
	local stacks = profile.foodBuffs
	if stacks == nil then
		return 0
	end
	local timestamp = now or os.time()
	local canonical = if isStat then key else Skills.canonicalize(key)
	local bonus = 0
	for _, entry in stacks do
		local matches = if isStat
			then entry.stat == canonical
			else entry.skill ~= nil and Skills.canonicalize(entry.skill) == canonical
		if matches then
			bonus += Boosts.foodStacks(entry, timestamp) * entry.bonus
		end
	end
	return bonus
end

local function statLabel(stat: string?): string?
	if stat == "yen" then
		return "Yen gain"
	end
	if stat == Constants.FOOD.AMPLIFIER_STAT then
		return "Food buff duration"
	end
	return nil
end

function Boosts.describe(boost: Boost): string
	local skill = boost.skill and Skills.get(boost.skill)
	if skill then
		return `{skill.name} gain x{boost.multiplier}`
	end
	local label = statLabel(boost.stat)
	if label then
		return `{label} x{boost.multiplier}`
	end
	return `All skill gain x{boost.multiplier}`
end

function Boosts.describeFood(food: FoodBuff): string
	local skill = food.skill and Skills.get(food.skill)
	if skill then
		return `+{food.bonus} {skill.name} gain per stack`
	end
	local label = statLabel(food.stat)
	if label then
		return `+{food.bonus} {label} per stack`
	end
	return `+{food.bonus} gain per stack`
end

return Boosts

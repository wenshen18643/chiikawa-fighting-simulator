local BigNumber = require(script.Parent.Parent.BigNumber)
local Skills = require(script.Parent.Skills)
local Upgrades = {}

export type Definition = {
	id: string,
	name: string,
	sub: string,
	baseCost: number,
	tierGrowth: number,
	stepGrowth: number,
	perLevel: number,
	skill: string?,
}

Upgrades.LEGACY_GAIN = "gain"

Upgrades.TIER_SIZE = 10

Upgrades.GAIN = {
	baseCost = 1000,
	tierGrowth = 12,
	stepGrowth = 0.22,
	perLevel = 0.15,
}

function Upgrades.gainIdFor(skillId: string): string
	local canonical = Skills.canonicalize(skillId)
	return "gain" .. canonical:sub(1, 1):upper() .. canonical:sub(2)
end

Upgrades.ORDER = {}
Upgrades.DEFS = {} :: { [string]: Definition }

for _, skillId in Skills.ORDER do
	local definition = Skills.get(skillId)
	local id = Upgrades.gainIdFor(skillId)
	table.insert(Upgrades.ORDER, id)
	Upgrades.DEFS[id] = {
		id = id,
		name = if definition then definition.name else skillId,
		sub = "every gain in this stat, multiplied",
		baseCost = Upgrades.GAIN.baseCost,
		tierGrowth = Upgrades.GAIN.tierGrowth,
		stepGrowth = Upgrades.GAIN.stepGrowth,
		perLevel = Upgrades.GAIN.perLevel,
		skill = Skills.canonicalize(skillId),
	}
end

Upgrades.GAIN_IDS = table.clone(Upgrades.ORDER)

Upgrades.DEFS.yen = {
	id = "yen",
	name = "Wages",
	sub = "more yen a second, forever",
	baseCost = 1500,
	tierGrowth = 12,
	stepGrowth = 0.22,
	perLevel = 0.12,
}

table.insert(Upgrades.ORDER, "yen")

function Upgrades.get(id: string): Definition?
	return Upgrades.DEFS[id]
end

function Upgrades.level(profile: any, id: string): number
	local levels = profile.upgrades
	if type(levels) ~= "table" or not Upgrades.DEFS[id] then
		return 0
	end
	return math.max(math.floor(tonumber(levels[id]) or 0), 0)
end

function Upgrades.tierProgress(level: number): number
	return (level % Upgrades.TIER_SIZE) / Upgrades.TIER_SIZE
end

function Upgrades.cost(id: string, level: number): BigNumber.BigNum?
	local definition = Upgrades.DEFS[id]
	if not definition then
		return nil
	end

	local tier = math.floor(level / Upgrades.TIER_SIZE)
	local step = level % Upgrades.TIER_SIZE
	local base = BigNumber.mulNumber(
		BigNumber.fromNumber(definition.baseCost),
		1 + definition.stepGrowth * step
	)

	return BigNumber.mul(base, BigNumber.pow(BigNumber.fromNumber(definition.tierGrowth), tier))
end

function Upgrades.multiplierAt(id: string, level: number): number
	local definition = Upgrades.DEFS[id]
	if not definition then
		return 1
	end
	return (1 + definition.perLevel) ^ math.max(level, 0)
end

function Upgrades.multiplier(profile: any, id: string): number
	return Upgrades.multiplierAt(id, Upgrades.level(profile, id))
end

function Upgrades.gainMultiplier(profile: any, skillId: string): number
	return Upgrades.multiplier(profile, Upgrades.gainIdFor(skillId))
end

return Upgrades

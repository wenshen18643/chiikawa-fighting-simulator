--[[
	The market's upgrade ladders: the game's first yen sink.

	Yen has been earnable since the wage loop existed and spendable almost
	nowhere -- two call sites, both on the farm. These are permanent, levelled
	multipliers bought one step at a time, which is the sink that makes the
	passive wage mean something.

	Deliberately multiplicative rather than additive, and deliberately plugged
	into Formulas' existing multiplier chain rather than forking it: a level here
	behaves exactly like a certification or a comfort bonus, so nothing
	downstream has to learn about upgrades to respect them.

	Cost is geometric. `baseCost * costGrowth ^ level` at growth 1.55 means the
	twenty-fifth level of anything is roughly 130,000 times the first, which is
	the point -- the ladder has to outrun a wage that is itself multiplied by the
	ladder or it stops being a decision after an hour.
]]

local Upgrades = {}

export type Definition = {
	id: string,
	name: string,
	sub: string,
	maxLevel: number,
	baseCost: number,
	costGrowth: number,
	perLevel: number,
}

Upgrades.ORDER = { "gain", "yen", "stamina" }

Upgrades.DEFS = {
	gain = {
		id = "gain",
		name = "Training",
		sub = "every skill gain, multiplied",
		maxLevel = 25,
		baseCost = 500,
		costGrowth = 1.55,
		perLevel = 0.15,
	},
	yen = {
		id = "yen",
		name = "Wages",
		sub = "more yen a minute, forever",
		maxLevel = 25,
		baseCost = 750,
		costGrowth = 1.6,
		perLevel = 0.12,
	},
	stamina = {
		id = "stamina",
		name = "Stamina",
		sub = "work longer before you stop",
		maxLevel = 15,
		baseCost = 1200,
		costGrowth = 1.7,
		perLevel = 0.1,
	},
} :: { [string]: Definition }

function Upgrades.get(id: string): Definition?
	return Upgrades.DEFS[id]
end

function Upgrades.level(profile: any, id: string): number
	local levels = profile.upgrades
	if type(levels) ~= "table" then
		return 0
	end
	local level = tonumber(levels[id]) or 0
	local definition = Upgrades.DEFS[id]
	return math.clamp(math.floor(level), 0, if definition then definition.maxLevel else 0)
end

-- The price of the NEXT level, or nil when there is not one.
function Upgrades.cost(id: string, level: number): number?
	local definition = Upgrades.DEFS[id]
	if not definition or level >= definition.maxLevel then
		return nil
	end
	return math.floor(definition.baseCost * definition.costGrowth ^ level)
end

function Upgrades.multiplierAt(id: string, level: number): number
	local definition = Upgrades.DEFS[id]
	if not definition then
		return 1
	end
	return 1 + definition.perLevel * math.clamp(level, 0, definition.maxLevel)
end

function Upgrades.multiplier(profile: any, id: string): number
	return Upgrades.multiplierAt(id, Upgrades.level(profile, id))
end

return Upgrades

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Boosts = require(Shared.Modules.Boosts)
local Constants = require(Shared.Modules.Constants)
local Certifications = require(Shared.Modules.Config.Certifications)
local Gear = require(Shared.Modules.Config.Gear)
local Skills = require(Shared.Modules.Config.Skills)
local Upgrades = require(Shared.Modules.Config.Upgrades)

type BigNum = BigNumber.BigNum

local Formulas = {}

function Formulas.gainMultiplier(profile: any, skillId: string): BigNum
	local multiplier = BigNumber.one()
	local canonical = Skills.canonicalize(skillId)
	local order = profile.certifications[canonical] or profile.certifications[skillId] or 0
	multiplier = BigNumber.mulNumber(multiplier, Certifications.gainMultiplier(order))

	if profile.seasons > 0 then
		multiplier = BigNumber.mul(multiplier, BigNumber.pow10(profile.seasons))
	end

	multiplier = BigNumber.mulNumber(multiplier, Formulas.comfortMultiplier(profile))
	multiplier = BigNumber.mulNumber(multiplier, Formulas.boostMultiplier(profile, canonical))
	multiplier = BigNumber.mulNumber(multiplier, Upgrades.gainMultiplier(profile, canonical))

	multiplier = BigNumber.mulNumber(multiplier, 1 + Boosts.foodBonus(profile, canonical, false))

	return multiplier
end

function Formulas.gainPerAction(profile: any, skillId: string): BigNum
	local base = BigNumber.fromNumber(Constants.WORK.BASE_GAIN)
	return BigNumber.mul(base, Formulas.gainMultiplier(profile, skillId))
end

function Formulas.comfortMultiplier(profile: any): number
	return math.max(Constants.HOME.BASE_COMFORT, profile.home.comfort or Constants.HOME.BASE_COMFORT)
end

function Formulas.boostMultiplier(profile: any, skillId: string): number
	local now = os.time()
	local multiplier = 1
	local canonical = Skills.canonicalize(skillId)
	for _, boost in profile.boosts do
		if
			boost.expiresAt > now
			and boost.stat == nil
			and (boost.skill == nil or Skills.canonicalize(boost.skill) == canonical)
		then
			multiplier *= boost.multiplier
		end
	end
	return multiplier
end

function Formulas.boostStatMultiplier(profile: any, stat: string): number
	local now = os.time()
	local multiplier = 1
	for _, boost in profile.boosts do
		if boost.expiresAt > now and boost.stat == stat then
			multiplier *= boost.multiplier or 1
		end
	end
	return multiplier
end

function Formulas.maxActionsPerSecond(profile: any): number
	local passId = Constants.WORK.NO_LIMIT_GAMEPASS_ID
	if passId ~= 0 and profile.gamepasses[passId] then
		return Constants.WORK.MAX_ACTIONS_PER_SECOND_GAMEPASS
	end
	return Constants.WORK.MAX_ACTIONS_PER_SECOND
end

function Formulas.resilienceLog(profile: any): number
	local resilienceVal = profile.skills.resilience or profile.skills.grit or profile.skills.durability
	return if BigNumber.isValid(resilienceVal) then math.max(BigNumber.log10(resilienceVal), 0) else 0
end

function Formulas.cookClicks(profile: any, baseClicks: number): number
	local exponents = Formulas.resilienceLog(profile)
	local penalty = 1
		+ (Constants.COOKING.UNTRAINED_CLICK_PENALTY - 1)
			* math.clamp(1 - exponents / Constants.COOKING.PENALTY_EXPONENTS, 0, 1)
	local trained = Constants.COOKING.CLICKS_PER_RESILIENCE_EXPONENT
		* math.max(math.floor(exponents - Constants.COOKING.PENALTY_EXPONENTS), 0)

	return math.max(
		math.ceil(baseClicks * Constants.COOKING.MIN_CLICKS_FRACTION),
		math.ceil(baseClicks * penalty - trained)
	)
end

function Formulas.maxHealth(profile: any): number
	return Constants.HEALTH.BASE_MAX + Formulas.resilienceLog(profile) * Constants.HEALTH.MAX_PER_RESILIENCE_LOG
end

function Formulas.yenPerSecond(profile: any): BigNum
	local certificationBonus = 1
	for _, order in profile.certifications do
		certificationBonus += order * Certifications.WAGE_BONUS_PER_ORDER
	end

	local kusatoriVal = profile.skills.kusatori or profile.skills.weeding or profile.skills.agility
	local weedingLog = if BigNumber.isValid(kusatoriVal) then math.max(BigNumber.log10(kusatoriVal), 0) else 0
	local multiplier = certificationBonus
		* (1 + weedingLog)
		* Formulas.boostStatMultiplier(profile, "yen")
		* Upgrades.multiplier(profile, "yen")
		* (1 + Boosts.foodBonus(profile, "yen", true))

	return BigNumber.mulNumber(BigNumber.fromNumber(Constants.CURRENCY.BASE_YEN_PER_SECOND), multiplier)
end

function Formulas.yenForGain(skillId: string, gain: BigNum): BigNum
	local canonical = Skills.canonicalize(skillId)
	if canonical ~= "kusatori" and canonical ~= "weeding" and canonical ~= "agility" then
		return BigNumber.zero()
	end
	return BigNumber.mulNumber(gain, Constants.CURRENCY.WEEDING_YEN_PER_GAIN)
end

function Formulas.totalSkill(profile: any): BigNum
	local total = BigNumber.zero()
	for _, skillId in Skills.ORDER do
		local val = profile.skills[skillId]
		if BigNumber.isValid(val) then
			total = BigNumber.add(total, val)
		end
	end
	return total
end

function Formulas.totalCertificationOrders(profile: any): number
	local total = 0
	for _, order in profile.certifications do
		total += order
	end
	return total
end

function Formulas.gearTier(profile: any, slot: string): number
	return Gear.tier(profile, slot)
end

function Formulas.harvestYield(profile: any, slot: string): number
	return math.max(1, math.floor(Gear.yieldMultiplier(profile, slot)))
end

function Formulas.harvestClicks(profile: any, slot: string, baseClicks: number): number
	return math.max(2, math.ceil(baseClicks * Gear.effortScale(profile, slot)))
end

function Formulas.oreYield(profile: any): number
	return Formulas.harvestYield(profile, "pickaxe")
end

function Formulas.oreSwings(profile: any, baseSwings: number): number
	return Formulas.harvestClicks(profile, "pickaxe", baseSwings)
end

return Formulas

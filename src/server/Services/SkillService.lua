local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Skills = require(Shared.Modules.Config.Skills)

type BigNum = BigNumber.BigNum

local SkillService = {}

function SkillService.get(profile: any, skillId: string): BigNum
	local canonical = Skills.canonicalize(skillId)
	return profile.skills[canonical] or BigNumber.zero()
end

function SkillService.award(_player: Player, profile: any, skillId: string, amount: BigNum)
	local canonical = Skills.canonicalize(skillId)
	if not Skills.exists(canonical) then
		warn(`[SkillService] award for unknown skill "{skillId}"`)
		return
	end
	if BigNumber.isZero(amount) then
		return
	end

	profile.skills[canonical] = BigNumber.add(profile.skills[canonical] or BigNumber.zero(), amount)
end

function SkillService.resetForSeason(profile: any)
	for _, skillId in Skills.ORDER do
		profile.skills[skillId] = BigNumber.zero()
	end
end

return SkillService

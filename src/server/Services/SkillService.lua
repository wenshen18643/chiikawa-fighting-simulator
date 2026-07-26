--[[
	Owns skill values. See docs/GAME.md §4.

	Nothing outside this module writes profile.skills. Everything that grants
	skill goes through award(), so worksite unlocking and region unlocking have
	exactly one place to hook.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Formulas = require(Shared.Modules.Formulas)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)

type BigNum = BigNumber.BigNum

local SkillService = {}

local unlockCallbacks: { (player: Player, profile: any, worksiteId: string) -> () } = {}

function SkillService.onWorksiteUnlocked(callback: (player: Player, profile: any, worksiteId: string) -> ())
	table.insert(unlockCallbacks, callback)
end

function SkillService.get(profile: any, skillId: string): BigNum
	local canonical = Skills.canonicalize(skillId)
	return profile.skills[canonical] or BigNumber.zero()
end

--[[
	Newly-crossed worksite requirements are recorded so the client can be told
	"you can work at the Public Park now" exactly once, rather than the HUD
	silently changing colour.
]]
local function checkUnlocks(player: Player, profile: any, skillId: string)
	for _, worksite in Worksites.getLadder(skillId) do
		if not profile.unlockedWorksites[worksite.id] and Formulas.meetsWorksiteRequirement(profile, worksite.id) then
			profile.unlockedWorksites[worksite.id] = true
			for _, callback in unlockCallbacks do
				local ok, err = pcall(callback, player, profile, worksite.id)
				if not ok then
					warn(`[SkillService] unlock callback errored: {err}`)
				end
			end
		end
	end
end

function SkillService.award(player: Player, profile: any, skillId: string, amount: BigNum)
	local canonical = Skills.canonicalize(skillId)
	if not Skills.exists(canonical) then
		warn(`[SkillService] award for unknown skill "{skillId}"`)
		return
	end
	if BigNumber.isZero(amount) then
		return
	end

	profile.skills[canonical] = BigNumber.add(profile.skills[canonical] or BigNumber.zero(), amount)
	checkUnlocks(player, profile, canonical)
end

-- §9.7 New Season: skills and worksite unlocks reset, everything else survives.
function SkillService.resetForSeason(profile: any)
	for _, skillId in Skills.ORDER do
		profile.skills[skillId] = BigNumber.zero()
	end
	profile.unlockedWorksites = {}
end

return SkillService

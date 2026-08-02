local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Certifications = require(Shared.Modules.Config.Certifications)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local DataService = require(script.Parent.DataService)
local RegionService = require(script.Parent.RegionService)
local StaminaService = require(script.Parent.StaminaService)
local StudyService = require(script.Parent.StudyService)

local ReplicationService = {
	remote = nil :: RemoteEvent?,
}

local function buildSnapshot(player: Player, profile: any)
	local skills = {}
	for _, skillId in Skills.ORDER do
		skills[skillId] = profile.skills[skillId] or BigNumber.zero()
	end

	local selected = profile.selectedSkill
	local gainPerAction = Formulas.gainPerAction(
		profile,
		if type(selected) == "string" and Skills.exists(selected) then selected else Skills.ORDER[1]
	)

	return {
		skills = skills,
		yen = profile.currencies.yen,
		stamps = profile.currencies.stamps,
		ingredients = profile.currencies.ingredients,
		seasonings = profile.currencies.seasonings,
		dishes = profile.dishes,
		boosts = profile.boosts,
		upgrades = profile.upgrades,
		stamina = { current = profile.stamina.current, max = profile.stamina.max },
		resting = StaminaService.isResting(player),
		seasons = profile.seasons,
		certifications = profile.certifications,
		certificationCap = Certifications.capFor(profile),
		study = StudyService.snapshot(player, profile),
		selectedSkill = profile.selectedSkill,
		gainPerAction = gainPerAction,
		yenPerMinute = Formulas.yenPerMinute(profile),
		regionId = RegionService.getCurrentRegion(player),
		unlockedRegions = profile.unlockedRegions,
		highestUnlockedRegion = RegionService.getHighestUnlocked(profile),
		showIntro = profile.meta.introShown ~= true,
	}
end

function ReplicationService.pushTo(player: Player)
	local profile = DataService.get(player)
	if not profile or not ReplicationService.remote then
		return
	end
	ReplicationService.remote:FireClient(player, buildSnapshot(player, profile))
end

function ReplicationService.init()
	ReplicationService.remote = Remotes.event("State", "Snapshot")

	DataService.onLoaded(function(player)
		task.defer(ReplicationService.pushTo, player)
	end)

	task.spawn(function()
		while true do
			task.wait(Constants.REPLICATION.SNAPSHOT_INTERVAL)
			for _, player in Players:GetPlayers() do
				ReplicationService.pushTo(player)
			end
		end
	end)
end

return ReplicationService

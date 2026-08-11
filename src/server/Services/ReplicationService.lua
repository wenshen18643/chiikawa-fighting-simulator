local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Boosts = require(Shared.Modules.Boosts)
local Certifications = require(Shared.Modules.Config.Certifications)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local RegionService = require(script.Parent.RegionService)
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

	Boosts.pruneFood(profile)

	return {
		skills = skills,
		yen = profile.currencies.yen,
		unlimitedYen = CurrencyService.isUnlimited("yen"),
		stamps = profile.currencies.stamps,
		ingredients = profile.currencies.ingredients,
		seasonings = profile.currencies.seasonings,
		dishes = profile.dishes,
		boosts = profile.boosts,
		foodBuffs = profile.foodBuffs,
		upgrades = profile.upgrades,
		seasons = profile.seasons,
		certifications = profile.certifications,
		trainTier = (profile.workOrders and profile.workOrders.trainTier) or {},
		certificationCap = Certifications.capFor(profile),
		study = StudyService.snapshot(player, profile),
		selectedSkill = profile.selectedSkill,
		gainPerAction = gainPerAction,
		yenPerSecond = Formulas.yenPerSecond(profile),
		regionId = RegionService.getCurrentRegion(player),
		unlockedRegions = profile.unlockedRegions,
		discovered = profile.discovered,
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

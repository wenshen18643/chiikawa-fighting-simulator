--[[
	Pushes the authoritative display state to each client. See docs/GAME.md §13.

	This is one-way. The snapshot is what the client DRAWS; it is never what the
	client is trusted to have. Nothing here is accepted back.

	The payload is small — six {m, e} pairs plus a handful of scalars — so a
	fixed-rate full snapshot is cheaper than diffing would be, and it means a
	dropped packet self-heals on the next tick instead of leaving the HUD stale.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)

local DataService = require(script.Parent.DataService)
local RegionService = require(script.Parent.RegionService)
local StaminaService = require(script.Parent.StaminaService)
local StudyService = require(script.Parent.StudyService)

local ReplicationService = {
	remote = nil :: RemoteEvent?, -- resolved in init()
}

local function buildSnapshot(player: Player, profile: any)
	local skills = {}
	for _, skillId in Skills.ORDER do
		skills[skillId] = profile.skills[skillId] or BigNumber.zero()
	end

	--[[
		What one click is worth right now.

		Used to be sent only while stood on a pad, and nil everywhere else, so
		the number the HUD could show was the one place a player was least
		likely to be. It is the selected skill's rate now, which is true
		wherever they happen to be standing.
	]]
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
		stamina = { current = profile.stamina.current, max = profile.stamina.max },
		resting = StaminaService.isResting(player),
		seasons = profile.seasons,
		certifications = profile.certifications,
		study = StudyService.snapshot(player, profile),
		-- Which skill a click raises. Drives the HUD's selected-row highlight
		-- and the work core's copy.
		selectedSkill = profile.selectedSkill,
		gainPerAction = gainPerAction,
		yenPerMinute = Formulas.yenPerMinute(profile),
		regionId = RegionService.getCurrentRegion(player),
		unlockedRegions = profile.unlockedRegions,
		highestUnlockedRegion = RegionService.getHighestUnlocked(profile),
		-- Drives the first-run Field Guide. Stays true until the client
		-- acknowledges, so a dropped packet cannot lose the onboarding.
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

	-- Push immediately on load so the HUD is never empty while waiting for the
	-- first scheduled tick.
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

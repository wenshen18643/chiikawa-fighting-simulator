local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local Companions = require(Shared.Modules.Config.Companions)
local Seasonings = require(Shared.Modules.Config.Seasonings)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local FeastService = require(script.Parent.FeastService)
local FishingService = require(script.Parent.FishingService)
local ForagingService = require(script.Parent.ForagingService)
local MobService = require(script.Parent.MobService)
local NotifyService = require(script.Parent.NotifyService)
local QuarryService = require(script.Parent.QuarryService)
local SkillService = require(script.Parent.SkillService)
local StaminaService = require(script.Parent.StaminaService)
local WeedService = require(script.Parent.WeedService)
local WorksiteService = require(script.Parent.WorksiteService)

local WorkService = {
	perform = nil :: RemoteEvent?,
	feedback = nil :: RemoteEvent?,
}

local limiters: { [Player]: RateLimiter.RateLimiter } = {}

local function limiterFor(player: Player, profile: any): RateLimiter.RateLimiter
	local limiter = limiters[player]
	local rate = Formulas.maxActionsPerSecond(profile)
	if not limiter then
		limiter = RateLimiter.new(rate, Constants.WORK.ACTION_BURST)
		limiters[player] = limiter
	else
		limiter:setRate(rate, Constants.WORK.ACTION_BURST)
	end
	return limiter
end

local function credit(
	player: Player,
	profile: any,
	skillId: string,
	worksiteId: string?,
	actions: number,
	actionMultiplier: number?,
	grantYen: boolean?
)
	if not Skills.exists(skillId) then
		return nil
	end

	local perAction = Formulas.gainPerAction(profile, skillId, worksiteId)
	if not worksiteId then
		perAction = BigNumber.mulNumber(perAction, Constants.WORK.OFF_PAD_MULTIPLIER)
	end

	local gain = BigNumber.mulNumber(perAction, actions)
	if actionMultiplier then
		gain = BigNumber.mulNumber(gain, actionMultiplier)
	end

	SkillService.award(player, profile, skillId, gain)

	if grantYen ~= false then
		local yen = Formulas.yenForGain(skillId, gain)
		if not BigNumber.isZero(yen) then
			CurrencyService.award(profile, "yen", yen)
		end
	end

	local bonus: any = nil
	local companions = profile.companions
	local selected = if type(companions) == "table" then companions.selected else nil
	local spec = if type(selected) == "string" then Companions.get(selected) else nil
	if spec and spec.skill and Skills.canonicalize(spec.skill) == Skills.canonicalize(skillId) then
		local candidate = BigNumber.mulNumber(gain, 0.5)
		if not BigNumber.isZero(candidate) then
			bonus = candidate
			SkillService.award(player, profile, skillId, bonus)
		end
	end

	return gain, bonus
end

local function freeformSkill(player: Player, profile: any): string
	local blockedSpot = WorksiteService.getBlocked(player)
	if blockedSpot then
		local worksite = Worksites.get(blockedSpot.worksiteId)
		if worksite then
			return Skills.canonicalize(worksite.skill)
		end
	end

	local selected = profile.selectedSkill
	if type(selected) == "string" and Skills.exists(selected) then
		local canonical = Skills.canonicalize(selected)

		if canonical == "resilience" then
			return Skills.ORDER[1]
		end
		return canonical
	end
	return Skills.ORDER[1]
end

local lastExplained: { [Player]: number } = {}
local EXPLAIN_COOLDOWN = 4

local function explain(player: Player, message: string)
	local now = os.clock()
	if now - (lastExplained[player] or -math.huge) < EXPLAIN_COOLDOWN then
		return
	end
	lastExplained[player] = now
	NotifyService.send(player, message, "info")
end

local seasoningRng = Random.new()

local function rollSeasoning(player: Player, profile: any)
	if seasoningRng:NextNumber() > Seasonings.DROP_CHANCE then
		return
	end
	local def = Seasonings.roll(seasoningRng)
	if not def then
		return
	end

	local seasonings = profile.currencies.seasonings
	seasonings[def.id] = (seasonings[def.id] or 0) + 1
	NotifyService.send(player, `Found {def.name} in the weeds!`, "reward")
end

local function pullSomething(player: Player, profile: any): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local section = WeedService.nearestPullable(root.Position, WeedService.PULL_RADIUS)
	local node = ForagingService.nearestPullable(root.Position, ForagingService.PULL_RADIUS)

	if section and node then
		local weedDist = (Vector3.new(section.center.X, 0, section.center.Z) - Vector3.new(
			root.Position.X,
			0,
			root.Position.Z
		)).Magnitude
		local nodeDist = (Vector3.new(node.center.X, 0, node.center.Z) - Vector3.new(
			root.Position.X,
			0,
			root.Position.Z
		)).Magnitude
		if nodeDist <= weedDist then
			section = nil
		else
			node = nil
		end
	end

	if node then
		return ForagingService.pull(player, profile, node)
	end
	if section then
		WeedService.pull(section)
		rollSeasoning(player, profile)
		return true
	end
	return false
end

local WORKING_ATTRIBUTE = "WorkingSkill"

local TIER_ATTRIBUTE = "WorkTier"
local WORKING_LINGER = 1.2

local workingUntil: { [Player]: number } = {}

local function markWorking(player: Player, skillId: string, tier: number)
	workingUntil[player] = os.clock() + WORKING_LINGER

	local character = player.Character
	if not character then
		return
	end
	if character:GetAttribute(WORKING_ATTRIBUTE) ~= skillId then
		character:SetAttribute(WORKING_ATTRIBUTE, skillId)
	end
	if character:GetAttribute(TIER_ATTRIBUTE) ~= tier then
		character:SetAttribute(TIER_ATTRIBUTE, tier)
	end
end

local function expireWorkingFlags()
	while true do
		task.wait(0.4)
		local now = os.clock()
		for player, deadline in workingUntil do
			if now >= deadline then
				workingUntil[player] = nil
				local character = player.Character
				if character then
					character:SetAttribute(WORKING_ATTRIBUTE, nil)
					character:SetAttribute(TIER_ATTRIBUTE, nil)
				end
			end
		end
	end
end

local function onPerform(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	if MobService.canAttack(player) then
		if not limiterFor(player, profile):consume() then
			return
		end
		if not StaminaService.tryConsume(player, profile) then
			explain(player, "Catching your breath for a moment. You are still earning.")
			return
		end

		local currentTobatsu = SkillService.get(profile, "tobatsu")
		local hitDefinition = MobService.tryAttack(player, BigNumber.toNumber(currentTobatsu))
		if not hitDefinition then
			return
		end

		local gain, bonus = credit(player, profile, "tobatsu", nil, 1, hitDefinition.hitGainMultiplier, false)
		if not gain then
			return
		end
		markWorking(player, "tobatsu", 1)
		WorkService.feedback:FireClient(player, "tobatsu", gain, nil, nil, bonus)
		return
	end

	local spot = WorksiteService.getOccupied(player)

	if spot and not WorksiteService.validate(player, profile, spot) then
		spot = nil
	end

	local worksite = if spot then Worksites.get(spot.worksiteId) else nil
	local skillId = if worksite then (worksite :: any).skill else freeformSkill(player, profile)

	if Skills.canonicalize(skillId) == "examprep" then
		return
	end

	if not limiterFor(player, profile):consume() then
		return
	end

	local bit = FeastService.bite(player, profile)

	if FishingService.reel(player, profile) then
		skillId = "resilience"
	elseif QuarryService.swing(player, profile) then
		skillId = "tobatsu"
	elseif Skills.canonicalize(skillId) == "kusatori" then
		if not pullSomething(player, profile) and not bit then
			explain(player, "Nothing to pull here — find weeds or something growing.")
			return
		end
	end

	if not StaminaService.tryConsume(player, profile) then
		explain(player, "Catching your breath for a moment. You are still earning.")
		return
	end

	local gain, bonus = credit(player, profile, skillId, spot and spot.worksiteId or nil, 1, nil)
	if not gain then
		return
	end

	markWorking(player, skillId, if worksite then (worksite :: any).tier else 1)

	if not spot then
		local blockedSpot = WorksiteService.getBlocked(player)
		if blockedSpot then
			explain(player, WorksiteService.explain(profile, blockedSpot) or "Practising here for now.")
		end
	end

	WorkService.feedback:FireClient(
		player,
		skillId,
		gain,
		spot and spot.worksiteId or nil,
		spot and spot.regionId or nil,
		bonus
	)
end

local function onSelectSkill(player: Player, skillId: any)
	if type(skillId) ~= "string" or not Skills.exists(skillId) then
		return
	end

	if Skills.canonicalize(skillId) == "resilience" then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	profile.selectedSkill = Skills.canonicalize(skillId)
end

local function afkLoop()
	local interval = Constants.WORK.AFK_TICK_INTERVAL

	while true do
		task.wait(interval)

		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			if not profile then
				continue
			end

			local spot = WorksiteService.getOccupied(player)
			if not spot then
				continue
			end
			if not WorksiteService.validate(player, profile, spot) then
				continue
			end

			local worksite = Worksites.get(spot.worksiteId)
			if not worksite then
				continue
			end

			if Skills.canonicalize(worksite.skill) == "examprep" then
				continue
			end

			local actions = Formulas.afkActionsPerSecond(profile) * interval
			credit(player, profile, worksite.skill, spot.worksiteId, actions)
		end
	end
end

function WorkService.init()
	WorkService.perform = Remotes.event("Work", "Perform")
	WorkService.feedback = Remotes.event("Work", "Feedback")

	WorkService.selectSkill = Remotes.event("Work", "SelectSkill")

	WorkService.perform.OnServerEvent:Connect(function(player)
		onPerform(player)
	end)

	WorkService.selectSkill.OnServerEvent:Connect(onSelectSkill)

	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
		lastExplained[player] = nil
		workingUntil[player] = nil
	end)

	task.spawn(afkLoop)
	task.spawn(expireWorkingFlags)
end

return WorkService

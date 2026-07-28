--[[
	Handles work actions. See docs/GAME.md §4 and §13.

	This is the single place a player's input turns into a number going up, so
	it is where the anti-exploit rules concentrate:

	  - The client sends INTENT ONLY. Work.Perform carries no arguments at all;
	    the server already knows where the player is standing and what that
	    worksite trains, so there is nothing for a client to lie about.
	  - Every credited action re-validates occupancy and the skill requirement.
	  - The action rate is capped by a token bucket. Excess is dropped, never
	    queued and never credited.
	  - AFK ticks credit at AFK_RATE_FRACTION of the cap, cost no stamina, and
	    require the same occupancy validation as an active action.

	ONE CLICK IS ONE ACTION. Nothing in this file changed to make that true —
	the server was always crediting per received intent — but it is worth saying
	here, because the rate cap is now sized for a human clicking rather than for
	a held button, and the two want very different numbers. See Constants.WORK.
]]

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
local ForagingService = require(script.Parent.ForagingService)
local MobService = require(script.Parent.MobService)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)
local StaminaService = require(script.Parent.StaminaService)
local WeedService = require(script.Parent.WeedService)
local WorksiteService = require(script.Parent.WorksiteService)

local WorkService = {
	perform = nil :: RemoteEvent?, -- resolved in init()
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
		-- A gamepass can be bought mid-session; keep the cap current without
		-- resetting the bucket (which would hand out a free burst per purchase).
		limiter:setRate(rate, Constants.WORK.ACTION_BURST)
	end
	return limiter
end

--[[
	Credits `actions` worth of work.

	`worksiteId` is OPTIONAL. With one, the pad's multiplier applies; without
	one, this is free-form training on open ground and only OFF_PAD_MULTIPLIER
	does — every other multiplier (certifications, season, comfort, boosts) is
	the same either way, because Formulas.gainMultiplier was already written to
	take the worksite as optional.

	Returns the skill gain applied, or nil if nothing was credited.
]]
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

--[[
	Which skill a click off a pad raises.

	Standing on a pad you have NOT unlocked trains that pad's skill rather than
	your selected one. You are at the workbench; practising badly at the
	workbench is what you would be doing. It also means walking to a district
	you cannot use yet is never wasted, which is the whole point of letting a
	locked pad be visible in the first place.
]]
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
		-- Old profiles may still have resilience selected; it is trained by
		-- cooking now, so fall back to the first skill instead.
		if canonical == "resilience" then
			return Skills.ORDER[1]
		end
		return canonical
	end
	return Skills.ORDER[1]
end

--[[
	Refusals are explained, not swallowed — but at most once every few seconds,
	because the client sends up to ~10 actions a second and a message per
	dropped action would be a wall of toast.
]]
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

--------------------------------------------------------------------------------
-- Pulling
--------------------------------------------------------------------------------

local seasoningRng = Random.new()

--[[
	A weed sometimes leaves a seasoning behind.

	Rolled here rather than in WeedService because WeedService knows about
	geometry and regrow timers, not about profiles: it answers "is this patch
	pulled", and what the pull was worth is this service's question.
]]
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

--[[
	One Kusatori click, spent on whatever is nearest: a weed or something
	growing. Returns false when there is nothing in reach, which is the only
	case that refuses the click.

	Nearest of either rather than weeds-first, because the two grow side by
	side and "why did that click pull the grass instead of the carrot I was
	standing on" is not a question the player should have to ask.
]]
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

--[[
	Publishes "this player is working, at this skill" as a character attribute so
	OTHER clients can animate them (see GestureController).

	An attribute rather than a remote per click. Attributes replicate on change,
	and this one changes when a player starts or stops working — perhaps twice a
	minute — where firing a remote for each of fourteen clicks a second per
	player would be a broadcast storm to animate somebody in the middle distance.

	Cleared on a timer rather than on a "stopped" event, because there is no such
	event: a player stops working by not clicking, which is not observable.
]]
local WORKING_ATTRIBUTE = "WorkingSkill"
--[[
	The tier of the pad being worked, published for the same reason and by the
	same mechanism. GestureController scales the held tool by it, so a tier-7
	Sasumata is visibly bigger than a tier-1 one to everybody, not only its
	owner. Free-form training off a pad publishes tier 1.
]]
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

	-- A mob in the server-validated strike cone wins over pads and free-form
	-- training. The client still sends no target, stat, or damage value.
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

	--[[
		A pad is a MULTIPLIER, not a gate.

		This used to return early unless the player was stood on a usable
		worksite, which meant a click anywhere else did nothing but produce a
		toast telling them to go somewhere. That made it impossible to top up a
		neglected skill on the move, and a character could only be built in the
		shape the nearest district happened to allow.

		Now a click always trains something. On a pad it is that pad's skill at
		its multiplier (x2 up to x5000); off one it is the player's selected
		skill at base rate. The pad is worth between two and five thousand times
		open ground, which never needed a wall to enforce.
	]]
	local spot = WorksiteService.getOccupied(player)

	-- Re-validate rather than trusting the throttled occupancy tick. A player
	-- who has stepped off since the last tick falls through to free-form rather
	-- than being refused.
	if spot and not WorksiteService.validate(player, profile, spot) then
		spot = nil
	end

	local worksite = if spot then Worksites.get(spot.worksiteId) else nil
	local skillId = if worksite then (worksite :: any).skill else freeformSkill(player, profile)

	-- Exam Prep is earned only by page flips inside StudySession. A normal Work
	-- click must not grant it (or consume stamina for an action that cannot pay).
	if Skills.canonicalize(skillId) == "examprep" then
		return
	end

	-- Over the rate cap: drop it silently. This is the one refusal that needs
	-- no message, because it only happens when the player is already clicking
	-- faster than the game credits.
	if not limiterFor(player, profile):consume() then
		return
	end

	if Skills.canonicalize(skillId) == "kusatori" then
		if not pullSomething(player, profile) then
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

	--[[
		Still explained, just no longer INSTEAD of paying. Standing on a locked
		pad tells you what it wants; the click is credited to that skill anyway.
	]]
	if not spot then
		local blockedSpot = WorksiteService.getBlocked(player)
		if blockedSpot then
			explain(player, WorksiteService.explain(profile, blockedSpot) or "Practising here for now.")
		end
	end

	-- The region travels with the feedback so the client can put its ripple on
	-- the right pad: the same worksite id exists in up to six areas. Both are
	-- nil for free-form training, and the client draws no ripple.
	WorkService.feedback:FireClient(
		player,
		skillId,
		gain,
		spot and spot.worksiteId or nil,
		spot and spot.regionId or nil,
		bonus
	)
end

--[[
	Sets which skill free-form training raises.

	Server-owned rather than sent with each click, so Work.Perform still carries
	no arguments (§13) and a client cannot pick a different skill per action to
	launder gains through whichever one is currently cheapest.
]]
local function onSelectSkill(player: Player, skillId: any)
	if type(skillId) ~= "string" or not Skills.exists(skillId) then
		return
	end

	-- Resilience is trained by cooking now, not selectable for click-training.
	if Skills.canonicalize(skillId) == "resilience" then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	profile.selectedSkill = Skills.canonicalize(skillId)
end

--[[
	§4: AFK ticks. Standing in a valid worksite earns at half the active cap,
	costs no stamina, and keeps paying while the player is resting.

	Deliberately NOT extended to free-form training. Clicking anywhere is a
	choice the player makes; standing anywhere is not, and paying for it would
	mean the whole world idles at once and the districts stop mattering even to
	an AFK player. A pad is still the only place idling earns.
]]
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
			-- Reading is never passive. The player has to turn the page in the
			-- full-screen book for every Exam Prep gain.
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
		-- Any extra arguments a client sends are ignored: intent carries no data.
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

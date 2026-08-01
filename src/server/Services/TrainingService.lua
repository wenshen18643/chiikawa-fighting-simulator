--[[
	Movement raises Grit. See docs/GAME.md §4 and §10.

	§4 defines Grit as endurance — "enduring a long shift, working while tired" —
	and it governs max stamina and regen. The world is 27,000 studs long, so
	running across it IS enduring a long shift, and it should pay something.

	Before this, travel was the only activity in the game that produced nothing.
	A player crossing the map spent minutes going backwards relative to someone
	stood still clicking, which is a strange thing for a game about doing an
	honest day's work to say.

	--------------------------------------------------------------------------
	THE EXPLOIT, AND WHY THIS IS MEASURED RATHER THAN REPORTED
	--------------------------------------------------------------------------

	Character position in Roblox is replicated FROM the client, so it is exactly
	the kind of number §13 says never to trust. This service therefore never asks
	how far the player ran; it samples where they are and takes the difference,
	and it discards any sample implying a speed a sprint could not produce.

	That single check covers both halves of the problem: a client teleporting
	around to farm distance is rejected, and so is the legitimate case of fast
	travel moving someone 20,000 studs between ticks. Neither pays.

	Stamina is not spent, matching the decision that sprinting is free — see
	Constants.MOVEMENT. Charging travel to the work-rate limiter would mean
	crossing your own world costs income.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local SkillService = require(script.Parent.SkillService)

local TrainingService = {}

local MOVEMENT = Constants.MOVEMENT
local SKILL = "grit"

local lastPosition: { [Player]: Vector3 } = {}
-- Studs run but not yet worth a whole unit. Carried rather than dropped, so a
-- player who walks in short bursts is not quietly earning nothing.
local carry: { [Player]: number } = {}
local lastJump: { [Player]: number } = {}

--------------------------------------------------------------------------------
-- Awarding
--------------------------------------------------------------------------------

local function award(player: Player, units: number)
	if units <= 0 then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	local gain = BigNumber.mulNumber(Formulas.gainPerAction(profile, SKILL), units)

	SkillService.award(player, profile, SKILL, gain)

	local yen = Formulas.yenForGain(SKILL, gain)
	if not BigNumber.isZero(yen) then
		CurrencyService.award(profile, "yen", yen)
	end
end

--------------------------------------------------------------------------------
-- Distance
--------------------------------------------------------------------------------

local function sampleDistance(player: Player, elapsed: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		lastPosition[player] = nil
		return
	end

	local position = root.Position
	local previous = lastPosition[player]
	lastPosition[player] = position

	if not previous then
		return
	end

	-- Flat distance only: falling down a hill is not running.
	local delta = position - previous
	local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude

	local plausible = MOVEMENT.SPRINT_SPEED * elapsed * MOVEMENT.MAX_PLAUSIBLE_SPEED_FACTOR
	if distance > plausible then
		-- A teleport: fast travel, a void-catch rescue, or a client lying about
		-- where it is. None of them are a run.
		return
	end

	local total = (carry[player] or 0) + distance
	local units = math.floor(total / MOVEMENT.STUDS_PER_GRIT_UNIT)
	carry[player] = total - units * MOVEMENT.STUDS_PER_GRIT_UNIT

	award(player, units)
end

--------------------------------------------------------------------------------
-- Jumping
--------------------------------------------------------------------------------

--[[
	A jump is worth a fixed amount, on a cooldown.

	The cooldown is the whole design: without it, jumping on the spot beats
	running, because a jump costs no distance. With it, hopping is a garnish on
	moving around rather than a way to play the game standing still.
]]
local function watchJumps(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	humanoid.StateChanged:Connect(function(_old, new)
		if new ~= Enum.HumanoidStateType.Jumping then
			return
		end

		local now = os.clock()
		if now - (lastJump[player] or -math.huge) < MOVEMENT.JUMP_COOLDOWN then
			return
		end
		lastJump[player] = now

		award(player, MOVEMENT.JUMP_GRIT_UNITS)
	end)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function TrainingService.init()
	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- A fresh character is somewhere else entirely; carrying the old
			-- position over would bank a respawn as a very long run.
			lastPosition[player] = nil
			carry[player] = 0
			watchJumps(player, character)
		end)

		if player.Character then
			watchJumps(player, player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerAdded:Connect(bind)

	Players.PlayerRemoving:Connect(function(player)
		lastPosition[player] = nil
		carry[player] = nil
		lastJump[player] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator < MOVEMENT.TRAINING_TICK then
			return
		end
		local elapsed = accumulator
		accumulator = 0

		for _, player in Players:GetPlayers() do
			sampleDistance(player, elapsed)
		end
	end)
end

return TrainingService

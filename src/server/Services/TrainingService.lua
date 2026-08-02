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
local SKILL = "resilience"
local lastPosition: { [Player]: Vector3 } = {}
local carry: { [Player]: number } = {}
local lastJump: { [Player]: number } = {}

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

	local delta = position - previous
	local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local plausible = MOVEMENT.SPRINT_SPEED * elapsed * MOVEMENT.MAX_PLAUSIBLE_SPEED_FACTOR
	if distance > plausible then
		return
	end

	local total = (carry[player] or 0) + distance
	local units = math.floor(total / MOVEMENT.STUDS_PER_GRIT_UNIT)
	carry[player] = total - units * MOVEMENT.STUDS_PER_GRIT_UNIT

	award(player, units)
end

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

function TrainingService.init()
	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
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

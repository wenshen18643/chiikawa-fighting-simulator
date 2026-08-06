local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local DataService = require(script.Parent.DataService)
local SkillService = require(script.Parent.SkillService)
local HealthService = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function apply(player: Player, profile: any, fullHeal: boolean)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local maxHealth = Formulas.maxHealth(profile)
	local granted = math.max(maxHealth - humanoid.MaxHealth, 0)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = if fullHeal then maxHealth else math.min(maxHealth, humanoid.Health + granted)
end

function HealthService.init()
	local function bindCharacter(player: Player, character: Model)
		if not character:FindFirstChildOfClass("Humanoid") then
			character:WaitForChild("Humanoid", 10)
		end
		local profile = DataService.await(player, 10)
		if profile and player.Character == character then
			apply(player, profile, true)
		end
	end

	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(bindCharacter, player, character)
		end)
		if player.Character then
			task.spawn(bindCharacter, player, player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerAdded:Connect(bind)

	SkillService.onAward(function(player, profile, skillId)
		if skillId == "resilience" then
			apply(player, profile, false)
		end
	end)
end

return HealthService

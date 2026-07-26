--[[
	Stamina. See docs/GAME.md §4 and §2 rule 3.

	Stamina is the cozy version of a rate limit. Running out does not stop the
	player earning and does not take anything away — the character sits down for
	a few seconds and keeps earning at the AFK rate, then gets up. There is no
	failure state here and there must never be one.

	Deliberately NOT monetised: §14 rules out selling stamina refills, because
	charging for rest inverts the tone the whole game is built on.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)

local DataService = require(script.Parent.DataService)

local StaminaService = {}

local restingUntil: { [Player]: number } = {}

function StaminaService.isResting(player: Player): boolean
	return (restingUntil[player] or 0) > os.clock()
end

--[[
	Tries to pay the stamina cost of one work action.
	Returns false when the player is resting or too tired — the caller then
	credits nothing for this action, but the AFK tick keeps paying out.
]]
function StaminaService.tryConsume(player: Player, profile: any): boolean
	if StaminaService.isResting(player) then
		return false
	end

	local cost = Constants.STAMINA.COST_PER_ACTION
	if profile.stamina.current < cost then
		restingUntil[player] = os.clock() + Constants.STAMINA.REST_DURATION
		profile.stamina.current = 0
		return false
	end

	profile.stamina.current -= cost
	return true
end

function StaminaService.init()
	local accumulator = 0
	local INTERVAL = 0.25

	RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator < INTERVAL then
			return
		end
		local elapsed = accumulator
		accumulator = 0

		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			if not profile then
				continue
			end

			-- Max stamina tracks Grit, which changes constantly, so it is
			-- recomputed rather than stored as a source of truth.
			profile.stamina.max = Formulas.maxStamina(profile)

			if profile.stamina.current < profile.stamina.max then
				local regen = Formulas.staminaRegenPerSecond(profile) * elapsed
				profile.stamina.current = math.min(profile.stamina.max, profile.stamina.current + regen)
			elseif profile.stamina.current > profile.stamina.max then
				profile.stamina.current = profile.stamina.max
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		restingUntil[player] = nil
	end)
end

return StaminaService

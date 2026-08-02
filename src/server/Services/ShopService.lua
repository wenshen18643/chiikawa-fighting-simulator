--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local Upgrades = require(Shared.Modules.Config.Upgrades)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local ReplicationService = require(script.Parent.ReplicationService)
local ShopService = {}
local PROMPT_NAME = "ShopPrompt"
local BUY_RATE = 4
local BUY_BURST = 6
local COUNTER_REACH = 28
local openRemote: RemoteEvent
local buyRemote: RemoteEvent
local eventRemote: RemoteEvent
local counter: BasePart? = nil
local limiters: { [Player]: RateLimiter.RateLimiter } = {}

local function limiterFor(player: Player): RateLimiter.RateLimiter
	local limiter = limiters[player]
	if not limiter then
		limiter = RateLimiter.new(BUY_RATE, BUY_BURST)
		limiters[player] = limiter
	end
	return limiter
end

local function withinReach(player: Player): boolean
	if not counter then
		return true
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - counter.Position).Magnitude <= COUNTER_REACH
end

type Row = {
	id: string,
	name: string,
	sub: string,
	skill: string?,
	level: number,
	maxLevel: number,
	multiplier: number,
	nextMultiplier: number,
	cost: BigNumber.BigNum?,
}

local function rowFor(profile: any, id: string): Row?
	local definition = Upgrades.get(id)
	if not definition then
		return nil
	end

	local level = Upgrades.level(profile, id)
	local cost = Upgrades.cost(id, level)

	return {
		id = id,
		name = definition.name,
		sub = definition.sub,
		skill = definition.skill,
		level = level,
		maxLevel = definition.maxLevel,
		multiplier = Upgrades.multiplierAt(id, level),
		nextMultiplier = Upgrades.multiplierAt(id, level + 1),
		cost = if cost then BigNumber.fromNumber(cost) else nil,
	}
end

local function board(profile: any)
	local rows = {}
	for _, id in Upgrades.ORDER do
		local row = rowFor(profile, id)
		if row then
			table.insert(rows, row)
		end
	end
	return { rows = rows, yen = profile.currencies.yen }
end

function ShopService.open(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	openRemote:FireClient(player, board(profile))
end

function ShopService.buy(player: Player, id: any): boolean
	if type(id) ~= "string" then
		return false
	end

	if not limiterFor(player):consume() then
		return false
	end

	if not withinReach(player) then
		NotifyService.send(player, "Step up to the upgrade counter first.", "locked")
		return false
	end

	local profile = DataService.get(player)
	local definition = Upgrades.get(id)
	if not profile or not definition then
		return false
	end

	local level = Upgrades.level(profile, id)
	local cost = Upgrades.cost(id, level)
	if not cost then
		NotifyService.send(player, `{definition.name} is fully upgraded.`, "info")
		return false
	end

	if not CurrencyService.spend(profile, "yen", BigNumber.fromNumber(cost)) then
		NotifyService.send(player, `Not enough yen for {definition.name}.`, "locked")
		eventRemote:FireClient(player, { kind = "denied", id = id, board = board(profile) })
		return false
	end

	if type(profile.upgrades) ~= "table" then
		profile.upgrades = {}
	end
	profile.upgrades[id] = level + 1
	NotifyService.send(player, `{definition.name} is now level {level + 1}.`, "reward")
	eventRemote:FireClient(player, { kind = "bought", id = id, board = board(profile) })
	ReplicationService.pushTo(player)
	return true
end

function ShopService.init()
	openRemote = Remotes.event("Shop", "Open")
	buyRemote = Remotes.event("Shop", "Buy")
	eventRemote = Remotes.event("Shop", "Event")

	buyRemote.OnServerEvent:Connect(function(player, id)
		ShopService.buy(player, id)
	end)

	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
	end)

	task.spawn(function()
		local market = Workspace:WaitForChild("Market", 60)
		local prompt = if market then (market :: Instance):FindFirstChild(PROMPT_NAME, true) else nil
		if not (prompt and prompt:IsA("ProximityPrompt")) then
			warn("[ShopService] no ShopPrompt found; the upgrade counter cannot be reached")
			return
		end

		local anchor = prompt.Parent
		if anchor and anchor:IsA("BasePart") then
			counter = anchor
		end

		prompt.Triggered:Connect(function(player)
			ShopService.open(player)
		end)
	end)
end

return ShopService

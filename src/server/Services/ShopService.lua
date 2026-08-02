--!strict

--[[
	The market's upgrade counter.

	Same trust shape as the work order booth: the client sends an id and nothing
	else. The level is read off the profile here, the price is computed here, and
	CurrencyService.spend is the only thing that can move a balance -- so a
	client that lies about what it can afford gets a false and no upgrade.

	The prompt is found by name in Workspace.Market rather than wired in by
	MarketService, so this module and the builder do not have to require each
	other.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Remotes = require(Shared.Modules.Remotes)
local Upgrades = require(Shared.Modules.Config.Upgrades)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local ReplicationService = require(script.Parent.ReplicationService)

local ShopService = {}

local PROMPT_NAME = "ShopPrompt"

local openRemote: RemoteEvent
local buyRemote: RemoteEvent
local eventRemote: RemoteEvent

type Row = {
	id: string,
	name: string,
	sub: string,
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

	task.spawn(function()
		local market = Workspace:WaitForChild("Market", 60)
		local prompt = if market then (market :: Instance):FindFirstChild(PROMPT_NAME, true) else nil
		if not (prompt and prompt:IsA("ProximityPrompt")) then
			warn("[ShopService] no ShopPrompt found; the upgrade counter cannot be reached")
			return
		end
		prompt.Triggered:Connect(function(player)
			ShopService.open(player)
		end)
	end)
end

return ShopService

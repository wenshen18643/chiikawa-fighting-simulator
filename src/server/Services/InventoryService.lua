local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Modules.Boosts)
local Recipes = require(Shared.Modules.Config.Recipes)
local Remotes = require(Shared.Modules.Remotes)
local Seasonings = require(Shared.Modules.Config.Seasonings)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local InventoryService = {}

local function spend(counts: { [string]: number }, id: string): boolean
	local owned = counts[id] or 0
	if owned <= 0 then
		return false
	end
	counts[id] = if owned == 1 then nil else owned - 1
	return true
end

local function onEat(player: Player, dishId: any)
	if type(dishId) ~= "string" then
		return
	end
	local def = Recipes.get(dishId)
	local profile = DataService.get(player)
	if not def or not profile then
		return
	end
	if not spend(profile.dishes, dishId) then
		return
	end

	Boosts.apply(profile, def.buff)
	NotifyService.send(player, `You eat {def.name}. {Boosts.describe(def.buff)} for {def.buff.duration}s.`, "reward")
end

local function onUseSeasoning(player: Player, seasoningId: any)
	if type(seasoningId) ~= "string" then
		return
	end
	local def = Seasonings.get(seasoningId)
	local profile = DataService.get(player)
	if not def or not profile then
		return
	end
	if not spend(profile.currencies.seasonings, seasoningId) then
		return
	end

	Boosts.apply(profile, def.buff)
	NotifyService.send(player, `A pinch of {def.name}. {Boosts.describe(def.buff)} for {def.buff.duration}s.`, "reward")
end

function InventoryService.init()
	Remotes.event("Inventory", "Eat").OnServerEvent:Connect(onEat)
	Remotes.event("Inventory", "UseSeasoning").OnServerEvent:Connect(onUseSeasoning)
end

return InventoryService

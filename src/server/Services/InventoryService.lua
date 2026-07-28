--[[
	Using what you are carrying: eating a dish, using a seasoning.

	Separate from CookingService because making a thing and consuming it are
	different jobs with different rules. Cooking cares about the station, the
	stir count and the distance you stand from the pot; this cares only that
	you own the item, and it can be done anywhere — which is the whole point of
	carrying it.

	Both actions are a decrement plus a boost, so they share one path. The
	client sends an id and nothing else; ownership and the buff are decided
	here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Modules.Boosts)
local Recipes = require(Shared.Modules.Config.Recipes)
local Remotes = require(Shared.Modules.Remotes)
local Seasonings = require(Shared.Modules.Config.Seasonings)

local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)

local InventoryService = {}

--[[
	Spend one of `id` from `counts`, or say it was not there.

	Owning nothing is a shrug rather than an error: an inventory panel can be a
	click behind the authoritative count, and the player did not do anything
	wrong by pressing a button that was true a moment ago.
]]
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

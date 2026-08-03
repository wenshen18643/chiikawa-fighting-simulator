local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ingredients = require(Shared.Modules.Config.Ingredients)
local DataService = require(script.Parent.DataService)
local MobService = require(script.Parent.MobService)
local NotifyService = require(script.Parent.NotifyService)
local MobLootService = {}
local rng = Random.new()

function MobLootService.init()
	MobService.onKilled(function(definition, _slot, killer)
		local drop = definition.drop
		if not drop or not killer then
			return
		end

		local profile = DataService.get(killer)
		if not profile then
			return
		end

		local count = rng:NextInteger(drop.min, drop.max)
		if count <= 0 then
			return
		end

		local ingredients = profile.currencies.ingredients
		ingredients[drop.id] = (ingredients[drop.id] or 0) + count

		local def = Ingredients.get(drop.id)
		NotifyService.send(killer, `{definition.name} drops {def and def.name or drop.id} x{count}.`, "reward")
	end)
end

return MobLootService

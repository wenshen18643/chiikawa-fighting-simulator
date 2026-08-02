local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local UI = require(Shared.UI)

local ProgressBillboard = require(script.Parent.Parent.UI.ProgressBillboard)

local ForageProgressController = {}

function ForageProgressController.init()
	local board = ProgressBillboard.new("ForageProgress", { color = UI.color.kusatori })

	Remotes.event("Forage", "Event").OnClientEvent:Connect(function(kind, ingredientId, a, b, at)
		if kind == "progress" and typeof(at) == "Vector3" then
			local definition = Ingredients.get(ingredientId)
			board:show(
				if definition then definition.name else ingredientId,
				a,
				b,
				at,
				if definition and definition.rarity == "legendary" then UI.color.examprep else UI.color.kusatori
			)
		elseif kind == "success" then
			board:dismiss()
		end
	end)
end

return ForageProgressController

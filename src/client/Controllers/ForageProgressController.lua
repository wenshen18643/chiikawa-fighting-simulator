--[[
	How far along the tree you are pulling is.

	A forage node takes several clicks and the tree gives no sign of it, so a
	big sausage and a small one look identical mid-pull. This puts the count
	over the node being worked, in world space rather than on the HUD: the
	answer to "is this one nearly out" belongs on the tree, not in a corner.
]]

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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local Feast = require(Shared.Modules.Config.Feast)
local UI = require(Shared.UI)
local ProgressBillboard = require(script.Parent.Parent.UI.ProgressBillboard)
local FeastProgressController = {}

function FeastProgressController.init()
	local board = ProgressBillboard.new("FeastProgress", {
		color = UI.color.gold,
		lifetime = 2.4,
		lift = 12,
		maxDistance = 260,
		size = UDim2.fromOffset(200, 62),
	})

	Remotes.event("Feast", "Event").OnClientEvent:Connect(function(kind, foodId, current, needed, at)
		if kind == "progress" and typeof(at) == "Vector3" then
			local definition = Feast.get(foodId)
			board:show(if definition then definition.name else foodId, current, needed, at)
		elseif kind == "done" then
			board:dismiss()
		end
	end)
end

return FeastProgressController

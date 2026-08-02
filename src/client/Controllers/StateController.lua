local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)

local StateController = {}

StateController.snapshot = nil :: any?

local listeners: { (snapshot: any) -> () } = {}

function StateController.onChanged(callback: (snapshot: any) -> ()): () -> ()
	table.insert(listeners, callback)
	if StateController.snapshot then
		task.spawn(callback, StateController.snapshot)
	end

	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function StateController.init()
	Remotes.event("State", "Snapshot").OnClientEvent:Connect(function(snapshot)
		StateController.snapshot = snapshot
		for _, callback in listeners do
			local ok, err = pcall(callback, snapshot)
			if not ok then
				warn(`[StateController] listener errored: {err}`)
			end
		end
	end)
end

return StateController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)
local StateController = {}
local snapshot: any? = nil
local listeners: { (snapshot: any) -> () } = {}

function StateController.onChanged(callback: (snapshot: any) -> ()): () -> ()
	table.insert(listeners, callback)
	if snapshot then
		task.spawn(callback, snapshot)
	end

	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function StateController.getSnapshot(): any?
	return snapshot
end

function StateController.init()
	Remotes.event("State", "Snapshot").OnClientEvent:Connect(function(nextSnapshot)
		snapshot = nextSnapshot
		for _, callback in listeners do
			local ok, err = pcall(callback, nextSnapshot)
			if not ok then
				warn(`[StateController] listener errored: {err}`)
			end
		end
	end)
end

return StateController

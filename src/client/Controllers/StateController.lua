--[[
	Client-side mirror of the server snapshot. See docs/GAME.md §13.

	This is display state and nothing else. Nothing in the client may treat it
	as authoritative — if the HUD and the server disagree, the server is right
	and the next snapshot corrects the HUD.
]]

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

function StateController.isWorking(): boolean
	local snapshot = StateController.snapshot
	return snapshot ~= nil and snapshot.currentWorksite ~= nil
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

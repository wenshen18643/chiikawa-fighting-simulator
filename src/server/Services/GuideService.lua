--[[
	Onboarding state. See docs/GAME.md §2 rule 3.

	Tiny on purpose: the only thing the server needs to remember is whether the
	player has already been shown how to play, so the Field Guide stops
	opening itself on every join.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)

local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)

local GuideService = {
	acknowledge = nil :: RemoteEvent?, -- resolved in init()
}

function GuideService.init()
	GuideService.acknowledge = Remotes.event("Guide", "Acknowledge")

	GuideService.acknowledge.OnServerEvent:Connect(function(player)
		local profile = DataService.get(player)
		if not profile or profile.meta.introShown then
			return
		end
		profile.meta.introShown = true
		NotifyService.send(player, "Field Guide saved. Choose a skill on the bar and get to work.", "info")
	end)

	DataService.onLoaded(function(player, profile)
		if DataService.getBackend() == "memory" then
			task.delay(4, function()
				if player:IsDescendantOf(game:GetService("Players")) then
					NotifyService.send(player, "Test session: progress will not be saved.", "info")
				end
			end)
		end

		if profile.meta.introShown then
			-- Returning player: a short reminder rather than the full panel.
			task.delay(2, function()
				if player:IsDescendantOf(game:GetService("Players")) then
					NotifyService.send(player, "Welcome back. Press H to open the Field Guide.", "info")
				end
			end)
		end
	end)
end

return GuideService

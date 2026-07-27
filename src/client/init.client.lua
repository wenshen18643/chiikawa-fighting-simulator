--[[
	Client entry point.

	Waits for the remote tree the server builds, then boots the controllers in
	dependency order: state mirror first, then anything that reads it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)
Remotes.get()

--[[
	Ordered by dependency, not by folder.

	StateController first: everything else reads its snapshot. WorkController
	before FeedbackController, which subscribes to its local click signal. HUD
	after both, because it builds WorkCore, Minimap and Atlas, and those query
	GuideController.
]]
local BOOT_ORDER = {
	{ container = script.Controllers, name = "StateController" },
	{ container = script.Controllers, name = "MovementController" },
	{ container = script.Controllers, name = "WorkController" },
	{ container = script.Controllers, name = "GuideController" },
	-- All three subscribe to WorkController's local click signal, so they boot
	-- after it. Order among themselves does not matter.
	{ container = script.Controllers, name = "FeedbackController" },
	{ container = script.Controllers, name = "GestureController" },
	{ container = script.Controllers, name = "CompanionAnimController" },
	{ container = script.Controllers, name = "SoundController" },
	{ container = script.Controllers, name = "WorldController" },
	{ container = script.UI, name = "HUD" },
	{ container = script.UI, name = "ControlsPanel" },
	-- Independent of the rest: it only listens for the friend stand's remote.
	{ container = script.UI, name = "CompanionMenu" },
}

for _, entry in BOOT_ORDER do
	local module = entry.container:FindFirstChild(entry.name)
	if not module then
		warn(`[Client] boot order lists "{entry.name}" but no such module exists`)
		continue
	end

	local controller = require(module)
	if type(controller) == "table" and type(controller.init) == "function" then
		local ok, err = pcall(controller.init)
		if not ok then
			warn(`[Client] {entry.name}.init() failed: {err}`)
		end
	end
end

print("[Client] game-3 booted")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)
Remotes.get()

local BOOT_ORDER = {
	{ container = script.Controllers, name = "StateController" },
	{ container = script.Controllers, name = "MovementController" },
	{ container = script.Controllers, name = "WorkController" },
	{ container = script.Controllers, name = "FeedbackController" },
	{ container = script.Controllers, name = "GestureController" },
	{ container = script.Controllers, name = "CompanionAnimController" },
	{ container = script.Controllers, name = "MobAnimController" },
	{ container = script.Controllers, name = "ForageProgressController" },
	{ container = script.Controllers, name = "FeastProgressController" },
	{ container = script.Controllers, name = "CompanionShelfController" },
	{ container = script.Controllers, name = "SafeZoneAnimController" },
	{ container = script.Controllers, name = "CaveController" },
	{ container = script.Controllers, name = "SoundController" },
	{ container = script.Controllers, name = "WorldController" },
	{ container = script.Controllers, name = "FarmController" },
	{ container = script.UI, name = "HUD" },
	{ container = script.UI, name = "InventoryMenu" },
	{ container = script.UI, name = "CookingMenu" },
	{ container = script.UI, name = "FarmMenu" },
	{ container = script.UI, name = "LibraryMenu" },
	{ container = script.UI, name = "StudySession" },
	{ container = script.UI, name = "ExamCounter" },
	{ container = script.UI, name = "ControlsPanel" },
	{ container = script.UI, name = "ControlTutorial" },
	{ container = script.UI, name = "CompanionMenu" },
	{ container = script.UI, name = "OrderBoard" },
	{ container = script.UI, name = "OrderTracker" },
	{ container = script.UI, name = "ShopMenu" },
	{ container = script.UI, name = "GachaMenu" },
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
Remotes.init()

local Services = script.Services

local BOOT_ORDER = {
	"NotifyService",
	"DataService",

	"AssetService",

	"WorldService",
	"LibraryService",
	"WeedService",
	"SafeZoneService",
	"MarketService",
	"NpcService",

	"MobService",

	"AssetProbeService",

	"CompanionService",

	"ForagingService",

	"SausageForestService",

	"CaveService",

	"QuarryService",
	"CookingService",
	"InventoryService",
	"StaminaService",
	"CurrencyService",

	"FarmMailboxService",
	"FarmingService",
	"RegionService",

	"FeastService",
	"WorkService",

	"StudyService",
	"ExamService",

	"TrainingService",
	"GuideService",

	"WorkOrderService",
	"ShopService",
	"ReplicationService",

	"BoardService",
}

local failures: { string } = {}

for _, name in BOOT_ORDER do
	local module = Services:FindFirstChild(name)
	if not module then
		warn(`[Server] boot order lists "{name}" but no such service module exists`)
		continue
	end

	local service = require(module)
	if type(service) == "table" and type(service.init) == "function" then
		local ok, err = pcall(service.init)
		if not ok then
			table.insert(failures, `{name}: {err}`)
			warn(`[Server] {name}.init() FAILED: {err}`)
		end
	end
end

if #failures > 0 then
	warn("========================================================================")
	warn(`[Server] game-3 booted with {#failures} FAILED SERVICE(S).`)
	warn("[Server] The game will look broken in ways that are not gameplay bugs:")
	for _, failure in failures do
		warn(`[Server]   - {failure}`)
	end
	warn("========================================================================")
else
	print("[Server] game-3 booted, all services healthy")
end

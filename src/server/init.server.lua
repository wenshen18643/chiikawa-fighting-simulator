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
	"MobLootService",
	"HealthService",
	"CurrencyService",

	"FarmMailboxService",
	"FarmingService",
	"RegionService",

	"FeastService",
	"WorkService",

	"StudyService",
	"ExamService",

	"GuideService",

	"WorkOrderService",
	"ShopService",
	"ReplicationService",
	"GachaService",
	"WeaponGachaService",

	"PerimeterService",
	"BoardService",
}

local failures: { string } = {}
local timings: { { name: string, seconds: number } } = {}
local bootStart = os.clock()

for _, name in BOOT_ORDER do
	local module = Services:FindFirstChild(name)
	if not module then
		warn(`[Server] boot order lists "{name}" but no such service module exists`)
		continue
	end

	local service = require(module)
	if type(service) == "table" and type(service.init) == "function" then
		local started = os.clock()
		local ok, err = pcall(service.init)
		table.insert(timings, { name = name, seconds = os.clock() - started })
		if not ok then
			table.insert(failures, `{name}: {err}`)
			warn(`[Server] {name}.init() FAILED: {err}`)
		end
	end
end

table.sort(timings, function(a, b)
	return a.seconds > b.seconds
end)

local slowest = {}
for index = 1, math.min(5, #timings) do
	local entry = timings[index]
	table.insert(slowest, `{entry.name} {string.format("%.2f", entry.seconds)}s`)
end
print(
	`[Server] boot blocked for {string.format("%.2f", os.clock() - bootStart)}s. `
		.. `Slowest: {table.concat(slowest, ", ")}`
)

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

--[[
	Server entry point.

	Boot order matters: the remote tree must exist before any service tries to
	resolve a remote from it, and DataService must be listening for PlayerAdded
	before anything that reads a profile on join.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
Remotes.init()

local Services = script.Services

-- Ordered, not alphabetical. Each entry may depend on the ones above it.
local BOOT_ORDER = {
	"NotifyService",
	"DataService",
	-- Before WorldService: it starts the decor model downloads, which the world
	-- then uses as they arrive. It does not block on them, so booting it early
	-- costs nothing and booting it late would mean Town builds before any of
	-- them exist.
	"AssetService",
	-- WorldService owns terrain, fences, gates and region folders;
	-- SafeZoneService puts the cottage on Town's plaza and overrides its spawn;
	-- WorksiteService lays pads into the region folders. The order here is
	-- load-bearing in all three directions.
	"WorldService",
	"SafeZoneService",
	"NpcService",
	-- Owns the first hostile-capable actors before WorkService resolves attacks.
	"MobService",
	-- After SafeZoneService, which is what moves Town's spawn onto the cottage
	-- doorstep: the probes are placed relative to the FINAL spawn.
	"AssetProbeService",
	-- Binds PlayerAdded, so it wants to be up before anybody can join. Its own
	-- spawning waits on the AssetService download.
	"CompanionService",
	"WorksiteService",
	-- After WorksiteService: the groves stand on the retired resilience pad
	-- spots, and the kitchen needs Town's region folder and the pot asset.
	"ForagingService",
	"CookingService",
	"InventoryService",
	"StaminaService",
	"CurrencyService",
	"RegionService",
	"WorkService",
	-- Layers visual recall and the Kusatori Grade 5 exam over completed Exam
	-- Prep gestures; depends on WorksiteService and profile state.
	"StudyService",
	-- After WorkService: both credit skills, and TrainingService reuses the
	-- Work.Feedback remote WorkService resolves.
	"TrainingService",
	"GuideService",
	"ReplicationService",
	-- Studio-only section grid overlay. Last: it reads the world, nothing reads it.
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

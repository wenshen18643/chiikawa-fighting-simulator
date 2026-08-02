local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Formulas = require(Shared.Modules.Formulas)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Remotes = require(Shared.Modules.Remotes)

local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

local RegionService = {}

local CHECK_INTERVAL = 2

local lastKnownRegion: { [Player]: number } = {}

function RegionService.isUnlocked(profile: any, regionId: number): boolean
	return profile.unlockedRegions[tostring(regionId)] == true
end

function RegionService.getHighestUnlocked(profile: any): number
	local highest = Areas.STARTING_AREA
	for _, area in Areas.ALL do
		if RegionService.isUnlocked(profile, area.id) and area.id > highest then
			highest = area.id
		end
	end
	return highest
end

local function meetsGate(profile: any, region: Areas.AreaDefinition): boolean
	local total = Formulas.totalSkill(profile)
	return BigNumber.gte(total, BigNumber.coerce(region.gate.skillTotal))
end

local function applyAccess(player: Player, profile: any)
	local character = player.Character
	if character then
		WorldService.setCharacterAccess(character, RegionService.getHighestUnlocked(profile))
	end
end

function RegionService.refresh(player: Player, profile: any)
	local opened = false

	for _, region in Areas.ALL do
		if not RegionService.isUnlocked(profile, region.id) and meetsGate(profile, region) then
			profile.unlockedRegions[tostring(region.id)] = true
			opened = true
			NotifyService.send(player, `{region.name} is open to you now. The gate east is unlocked.`, "unlock")
		end
	end

	if opened then
		applyAccess(player, profile)
	end
end

function RegionService.getCurrentRegion(player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return Areas.STARTING_AREA
	end
	return Layout.areaAt(root.Position).id
end

local function watchBorders()
	local remote = Remotes.event("Region", "Entered")

	while true do
		task.wait(0.4)
		for _, player in Players:GetPlayers() do
			local current = RegionService.getCurrentRegion(player)
			if lastKnownRegion[player] ~= current then
				lastKnownRegion[player] = current
				remote:FireClient(player, current)
			end
		end
	end
end

local function onRequestTravel(player: Player, regionId: any)
	if type(regionId) ~= "number" then
		return
	end

	local region = Areas.get(regionId)
	if not region then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	if not RegionService.isUnlocked(profile, regionId) then
		NotifyService.send(player, `{region.name} is not open to you yet.`, "locked")
		return
	end

	local spawnCFrame = WorldService.getSpawnCFrame(regionId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not spawnCFrame or not root then
		return
	end

	root.CFrame = spawnCFrame
	NotifyService.send(player, `Welcome to {region.name}.`, "travel")
end

function RegionService.init()
	RegionService.requestTravel = Remotes.event("Region", "RequestTravel")
	RegionService.requestTravel.OnServerEvent:Connect(onRequestTravel)

	DataService.onLoaded(function(player, profile)
		RegionService.refresh(player, profile)
		applyAccess(player, profile)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local profile = DataService.get(player)
			if profile then
				applyAccess(player, profile)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKnownRegion[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile then
					RegionService.refresh(player, profile)
				end
			end
		end
	end)

	task.spawn(watchBorders)
end

return RegionService

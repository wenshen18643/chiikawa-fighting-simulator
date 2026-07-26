--[[
	Area unlocking, gates, and fast travel. See docs/GAME.md §7.

	Areas unlock automatically the moment the gate is met — there is nothing
	to buy and nothing to claim, because a gate the player can forget to open is
	a gate that reads as a punishment (§2 rule 3).

	SPEC DEVIATION: §7's areas were separate places reached by teleport. They are
	now districts of one landmass joined by land bridges, so "unlocked" has to
	mean something PHYSICAL as well as something in the profile — otherwise a new
	player simply walks east until they run out of world.

	That physical meaning is a collision group. Each character sits in
	`Access_k`, where k is the furthest area they have unlocked, and each gate
	barrier is solid to exactly those groups below it (WorldService owns the
	matrix). This service's job is to keep k current: on spawn, and again the
	instant an area opens, so a gate becomes passable the moment it is earned
	rather than on the next respawn.

	Travel survives as FAST travel rather than as the only way to move. The
	client asks; the server checks the unlock and moves the character. Walking
	is always available and is the intended way to see the world.
]]

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

-- Last area we told each client they were in, so walking across a border fires
-- the title card exactly once.
local lastKnownRegion: { [Player]: number } = {}

function RegionService.isUnlocked(profile: any, regionId: number): boolean
	return profile.unlockedRegions[tostring(regionId)] == true
end

-- The furthest area open to this profile. Drives the collision group, so it has
-- to be the MAXIMUM rather than a count: unlocks are ordered, but a future
-- migration or a manual grant could leave a hole.
function RegionService.getHighestUnlocked(profile: any): number
	local highest = Areas.STARTING_AREA
	for _, area in Areas.ALL do
		if RegionService.isUnlocked(profile, area.id) and area.id > highest then
			highest = area.id
		end
	end
	return highest
end

--[[
	SPEC NOTE: §7 gates on total CERTIFICATION level; certifications land in
	Slice 3. Until then this reads `gate.skillTotal`. Swapping to
	`gate.certificationTotal` is a one-line change here — see Areas/Area.lua for
	why an area carries both.
]]
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

	-- Only re-stamp the collision group when something actually changed: this
	-- walks every part of the character and runs on a 2-second poll for every
	-- player in the server.
	if opened then
		applyAccess(player, profile)
	end
end

--[[
	Which area the player is physically standing in. Delegates to Layout so that
	the answer is the same one the client's minimap computes — and so a player on
	a land bridge gets the nearest area rather than nothing.
]]
function RegionService.getCurrentRegion(player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return Areas.STARTING_AREA
	end
	return Layout.areaAt(root.Position).id
end

-- Fires the area title card when the player crosses a border on foot. The world
-- is continuous, so nothing else marks the moment.
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

	-- A fresh character is a fresh set of parts, all of them back in the default
	-- collision group. Without this, respawning re-closes every gate you have
	-- earned.
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

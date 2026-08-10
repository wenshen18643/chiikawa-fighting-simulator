--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local Sections = require(Shared.Modules.Config.Sections)
local DataService = require(script.Parent.DataService)
local DiscoveryService = {}
local REACH = 120
local MAX_PER_REPORT = 9
local limiters: { [Player]: RateLimiter.RateLimiter } = {}

local function limiterFor(player: Player): RateLimiter.RateLimiter
	local limiter = limiters[player]
	if not limiter then
		limiter = RateLimiter.new(3, 12)
		limiters[player] = limiter
	end
	return limiter
end

function DiscoveryService.key(areaKey: string, coord: string): string
	return `{areaKey}:{coord}`
end

local function standsNear(player: Player, area: Areas.AreaDefinition, cell: Sections.Cell): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end

	local at = root.Position - area.origin
	return at.X >= cell.minX - REACH
		and at.X <= cell.maxX + REACH
		and at.Z >= cell.minZ - REACH
		and at.Z <= cell.maxZ + REACH
end

local function accept(player: Player, profile: any, key: string): boolean
	if type(key) ~= "string" or #key > 24 or profile.discovered[key] then
		return false
	end

	local areaKey, coord = key:match("^(%a+):(%a%d+)$")
	if not areaKey or not coord then
		return false
	end

	local area = Areas.BY_KEY[areaKey]
	local cell = Sections.byCoord(coord)
	if not area or not cell or not standsNear(player, area, cell) then
		return false
	end

	profile.discovered[key] = true
	return true
end

function DiscoveryService.init()
	local remote = Remotes.event("Discovery", "Report")

	remote.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or not limiterFor(player):consume() then
			return
		end

		local profile = DataService.get(player)
		if not profile then
			return
		end

		for index, key in payload :: { any } do
			if index > MAX_PER_REPORT then
				break
			end
			accept(player, profile, key)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
	end)
end

return DiscoveryService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)

local AssetService = require(script.Parent.AssetService)
local WorldService = require(script.Parent.WorldService)

local AssetProbeService = {}

local ENABLED = false

local PROBES: { { key: string, offset: Vector3, faceSpawn: boolean? } } = {
	{ key = "hachiware", offset = Vector3.new(10, 0, -8), faceSpawn = true },
}

local LOAD_TIMEOUT = 12

function AssetProbeService.init()
	if not ENABLED or #PROBES == 0 then
		return
	end

	local spawnCFrame = WorldService.getSpawnCFrame(Areas.STARTING_AREA)
	if not spawnCFrame then
		warn("[AssetProbeService] no spawn for the starting area - did WorldService run first?")
		return
	end

	local existing = Workspace:FindFirstChild("AssetProbes")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "AssetProbes"
	folder.Parent = Workspace

	task.spawn(function()
		for _, probe in PROBES do
			if not AssetService.waitFor(probe.key, LOAD_TIMEOUT) then
				warn(
					`[AssetProbeService] "{probe.key}" did not load within {LOAD_TIMEOUT}s. `
						.. `See the [AssetService] report above for the reason.`
				)
				continue
			end

			local model = AssetService.clone(probe.key)
			if not model then
				continue
			end

			local base = spawnCFrame * CFrame.new(probe.offset)
			local ground = Vector3.new(base.Position.X, Constants.WORLD.PLATFORM_TOP, base.Position.Z)

			local yaw = math.atan2(-spawnCFrame.LookVector.X, -spawnCFrame.LookVector.Z)
			AssetService.place(model, ground, if probe.faceSpawn then yaw + math.pi else yaw)

			model.Parent = folder
			print(`[AssetProbeService] "{probe.key}" standing at the Town spawn: {AssetService.describe(model)}`)
		end
	end)
end

return AssetProbeService

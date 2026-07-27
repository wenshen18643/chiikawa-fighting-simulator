--[[
	Stands one copy of an uploaded model next to the Town spawn and reports what
	arrived.

	--------------------------------------------------------------------------
	WHY THIS EXISTS
	--------------------------------------------------------------------------

	Whether an asset id is usable is not knowable from this repo: LoadAsset only
	serves public assets or assets owned by the place owner, and what is INSIDE
	the container -- rig or prop, one mesh or forty, 3 studs tall or 300 -- is
	not knowable either. docs/ASSETS.md records that four ids fail for exactly
	this reason, and both of those questions were previously answered by wiring
	an asset into gameplay and seeing whether the world looked wrong.

	This is the cheap version of that: load the id, put it where the player
	already is on join, print its measurements. No gameplay depends on it, so a
	dead id costs a warning line.

	--------------------------------------------------------------------------
	NOT A GAMEPLAY SERVICE
	--------------------------------------------------------------------------

	Probes are anchored, non-colliding and non-queryable (AssetService.prepare
	does all three), have no prompt and no behaviour. They are scenery you can
	walk through. Set ENABLED = false, or empty PROBES, to remove them entirely.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)

local AssetService = require(script.Parent.AssetService)
local WorldService = require(script.Parent.WorldService)

local AssetProbeService = {}

--[[
	Off. CompanionService now spawns the same rig as a follower and prints the
	same `AssetService.describe` line for it, so leaving this on would put an
	identical statue next to the Town spawn and report the model twice.

	Kept, not deleted: this is the cheap first step for the NEXT unknown id, and
	the next one is likelier to be scenery than a companion.
]]
local ENABLED = false

--[[
	Keys from Config/Assets.lua, laid out left to right in front of the spawn.

	`offset` is in studs from the spawn point: +Z is behind the spawn CFrame's
	look direction and X spreads them apart, so a probe stands beside the
	doorstep rather than on top of the player.
]]
local PROBES: { { key: string, offset: Vector3, faceSpawn: boolean? } } = {
	{ key = "hachiware", offset = Vector3.new(10, 0, -8), faceSpawn = true },
}

--[[
	How long to wait for a probe's download.

	Loads start in AssetService.init and run off the boot path, so a probe asked
	for immediately after boot would usually lose the race and report a failure
	that is really just "not yet". Generous, because being wrong here means
	printing the opposite of the thing this service exists to answer.
]]
local LOAD_TIMEOUT = 12

function AssetProbeService.init()
	if not ENABLED or #PROBES == 0 then
		return
	end

	--[[
		SafeZoneService moves Town's spawn onto the cottage doorstep during its
		own init, and this service boots after it, so this reads the final spawn
		rather than the plaza centre WorldService set first.
	]]
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

	--[[
		Spawned on a background task so a slow or dead download cannot hold up
		the rest of the boot sequence for LOAD_TIMEOUT seconds. Nothing waits on
		a probe.
	]]
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

			--[[
				Placed on the ground plane rather than at the spawn's own Y.
				AssetService.place lifts a model by half its height so it stands
				ON the given Y, and every surface a player can be standing on
				here presents PLATFORM_TOP.
			]]
			local base = spawnCFrame * CFrame.new(probe.offset)
			local ground = Vector3.new(base.Position.X, Constants.WORLD.PLATFORM_TOP, base.Position.Z)

			--[[
				Uploaded models face their own -Z. Rotating by the spawn's yaw
				plus a half turn points the probe back at whoever just spawned,
				which is the difference between inspecting a face and inspecting
				the back of a head.
			]]
			local yaw = math.atan2(-spawnCFrame.LookVector.X, -spawnCFrame.LookVector.Z)
			AssetService.place(model, ground, if probe.faceSpawn then yaw + math.pi else yaw)

			model.Parent = folder
			print(`[AssetProbeService] "{probe.key}" standing at the Town spawn: {AssetService.describe(model)}`)
		end
	end)
end

return AssetProbeService

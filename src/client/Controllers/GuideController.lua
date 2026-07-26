--[[
	"Where should I go?" — the answer, with no UI attached.

	This used to draw its own card. It does not any more: the bottom-centre of
	the screen is now one control (UI/WorkCore) that shows either the pad you are
	standing on or the one you should walk to, and having two separate panels
	competing for that spot was the reason the old HUD had a prompt and a guide
	that could both be visible at once saying different things.

	The important change is where the positions come from. The old version
	scanned Workspace for parts tagged with a WorksiteId. Under StreamingEnabled
	that finds only what is already loaded — a few hundred studs of a 27,000-stud
	world — so the arrow went blind for anything worth walking to. Positions now
	come from Config/Layout, the same pure function the server built the world
	from, so a target is found whether or not its part exists on this machine.

	Usability is computed CLIENT-SIDE here purely to pick a target. The server
	still decides what gets credited (docs/GAME.md §13); the worst a wrong guess
	can do is point at a pad that then refuses to pay, which WorkCore makes
	obvious the moment you stand on it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Worksites = require(Shared.Modules.Config.Worksites)

local StateController = require(script.Parent.StateController)

local GuideController = {}

export type Target = {
	worksite: Worksites.WorksiteDefinition,
	area: Areas.AreaDefinition,
	position: Vector3,
	distance: number,
	-- Degrees to turn from where the camera is looking. Positive is to the right.
	bearing: number,
}

--[[
	Signed angle from where the camera is looking to where the target is, on the
	ground plane, so an arrow driven by this reads as "turn this way" rather than
	as a compass needle.
]]
local function bearingTo(from: Vector3, to: Vector3): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end

	local forward = camera.CFrame.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	local flatTo = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flatForward.Magnitude < 0.01 or flatTo.Magnitude < 0.01 then
		return 0
	end

	flatForward = flatForward.Unit
	flatTo = flatTo.Unit
	return math.deg(math.atan2(flatForward:Cross(flatTo).Y, flatForward:Dot(flatTo)))
end

local function canUse(snapshot: any, area: Areas.AreaDefinition, worksite: Worksites.WorksiteDefinition): boolean
	if snapshot.unlockedRegions[tostring(area.id)] ~= true then
		return false
	end
	local value = snapshot.skills[worksite.skill]
	return value ~= nil and not BigNumber.lt(value, BigNumber.coerce(worksite.requirement))
end

--[[
	The best pad the player can currently stand on: highest multiplier among
	those they qualify for, nearest wins ties.

	Searches the CURRENT AREA ONLY. Under the cumulative ladder every area
	carries every tier the player has earned, so the best available pad is always
	within a short walk — and pointing at an identical pad 8,000 studs away in
	another area would be technically correct and useless.
]]
function GuideController.getTarget(): Target?
	local snapshot = StateController.snapshot
	if not snapshot then
		return nil
	end

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	local from = root.Position
	local area = Layout.areaAt(from)

	local best: Target? = nil
	local bestMultiplier, bestDistance = -1, math.huge

	for _, entry in Layout.padsFor(area) do
		local worksite = entry.worksite
		if not canUse(snapshot, area, worksite) then
			continue
		end

		local position = entry.cframe.Position
		local distance = (position - from).Magnitude

		if
			worksite.multiplier > bestMultiplier or (worksite.multiplier == bestMultiplier and distance < bestDistance)
		then
			bestMultiplier, bestDistance = worksite.multiplier, distance
			best = {
				worksite = worksite,
				area = area,
				position = position,
				distance = distance,
				bearing = 0,
			}
		end
	end

	if best then
		best.bearing = bearingTo(from, best.position)
	end
	return best
end

-- Cheap enough to call every frame for a smooth arrow: no search, just the
-- angle to a target the caller already has.
function GuideController.bearingToTarget(target: Target): number
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return target.bearing
	end
	return bearingTo(root.Position, target.position)
end

function GuideController.init()
	-- Nothing to set up: this module is a pure query over StateController and
	-- Layout. `init` exists so the client boot list can treat every controller
	-- the same way.
end

return GuideController

--[[
	Drives the rigged residents of the safe zone.

	CompanionAnimController does the same job for Workspace.Companions, and the
	two are deliberately separate rather than one controller over both folders.
	A companion is owned by a player, echoes their clicks, and is created and
	destroyed constantly; a resident is scenery that happens to breathe. Sharing
	a controller would mean every one of those rules growing an "unless it is
	furniture" branch.

	What they DO share is everything below the controller: Skeleton resolves the
	joints, CompanionAnims supplies the clips, Machine plays them. Adding another
	animated fixture to the safe zone is a profile, a clip set, and a
	SetAttribute on the server -- no change here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionAnims = require(Shared.Modules.Config.CompanionAnims)
local Machine = require(Shared.Modules.Anim.Machine)
local Skeleton = require(Shared.Modules.Anim.Skeleton)

local SafeZoneAnimController = {}

local FOLDER_TIMEOUT = 60
local BIND_TIMEOUT = 15

local machines: { [Model]: any } = {}

local function unbind(model: Model)
	local machine = machines[model]
	if machine then
		machine:destroy()
		machines[model] = nil
	end
end

local function bind(model: Model)
	--[[
		The folder is mostly parts, plus a few dozen decor models. Only a rigged
		resident carries the profile attribute, and the server writes it before
		parenting, so its absence here is an answer and not a race.
	]]
	if machines[model] or model:GetAttribute(Skeleton.PROFILE_ATTRIBUTE) == nil then
		return
	end

	task.spawn(function()
		local deadline = os.clock() + BIND_TIMEOUT
		local joints, profileId

		--[[
			Retried rather than resolved once. The attribute replicates
			independently of the parts it describes, so on a slow join the model
			can be present and correctly tagged several frames before its
			Motor6Ds have arrived.
		]]
		while os.clock() < deadline do
			if model.Parent == nil then
				return
			end
			joints, profileId = Skeleton.resolve(model)
			if joints then
				break
			end
			task.wait(0.15)
		end

		if not joints or not profileId then
			warn(`[SafeZoneAnim] {model.Name} exposed no animatable joints`)
			return
		end

		local set = CompanionAnims.get(profileId)
		if not set then
			warn(`[SafeZoneAnim] profile "{profileId}" has no clip set`)
			return
		end

		if model.Parent == nil or machines[model] then
			return
		end
		machines[model] = Machine.new(model, joints, set)
	end)
end

--[[
	Watched folders, not one folder.

	Yoroi-san moved out to the market square when the town grew around the plot,
	and is the only rigged resident that was ever in here. Watching both is a
	smaller change than splitting a second controller off for one model, and the
	bind rule is unchanged: only something carrying the profile attribute is a
	resident, wherever it happens to stand.

	Each is awaited on its own thread. Sequential WaitForChild would make a folder
	that never arrives cost the next one its whole timeout.
]]
local WATCHED = { "SafeZone", "Market" }

local function watch(name: string)
	local folder = Workspace:WaitForChild(name, FOLDER_TIMEOUT)
	if not folder then
		warn(`[SafeZoneAnim] Workspace.{name} never appeared - its residents will not animate`)
		return
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			bind(child)
		end
	end

	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			bind(child)
		end
	end)

	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			unbind(child)
		end
	end)
end

function SafeZoneAnimController.init()
	for _, name in WATCHED do
		task.spawn(watch, name)
	end

	--[[
		One step behind Character priority, matching CompanionAnimController.
		Motor6D.Transform is overwritten by the animation stack each frame, so
		anything writing it has to run after that pass or it is writing into a
		value that is about to be thrown away.
	]]
	RunService:BindToRenderStep("SafeZoneAnim", Enum.RenderPriority.Character.Value + 1, function(dt)
		local now = os.clock()
		for model, machine in machines do
			if model.Parent then
				machine:update(dt, now)
			else
				unbind(model)
			end
		end
	end)
end

return SafeZoneAnimController

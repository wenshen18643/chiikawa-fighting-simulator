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
	if machines[model] or model:GetAttribute(Skeleton.PROFILE_ATTRIBUTE) == nil then
		return
	end

	task.spawn(function()
		local deadline = os.clock() + BIND_TIMEOUT
		local joints, profileId

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

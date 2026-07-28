--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Machine = require(Shared.Modules.Anim.Machine)
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local MobAnims = require(Shared.Modules.Config.MobAnims)

local MobAnimController = {}

local ACTION_ATTRIBUTE = "MobAction"
local ACTION_SERIAL_ATTRIBUTE = "MobActionSerial"
local FOLDER_TIMEOUT = 60
local BIND_TIMEOUT = 15

local machines: { [Model]: any } = {}
local connections: { [Model]: RBXScriptConnection } = {}

local function unbind(model: Model)
	local machine = machines[model]
	if machine then
		machine:destroy()
		machines[model] = nil
	end
	local connection = connections[model]
	if connection then
		connection:Disconnect()
		connections[model] = nil
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
			warn(`[MobAnim] {model.Name} exposed no animatable joints`)
			return
		end

		local set = MobAnims.get(profileId)
		if not set then
			warn(`[MobAnim] profile "{profileId}" has no clip set`)
			return
		end
		if model.Parent == nil or machines[model] then
			return
		end

		local motors: { [string]: Motor6D } = {}
		for name, joint in joints do
			if joint:IsA("Motor6D") then
				motors[name] = joint
			end
		end
		if next(motors) == nil then
			warn(`[MobAnim] {model.Name} exposed no Motor6D joints`)
			return
		end

		local machine = Machine.new(model, motors, set)
		machines[model] = machine
		connections[model] = model:GetAttributeChangedSignal(ACTION_SERIAL_ATTRIBUTE):Connect(function()
			local action = model:GetAttribute(ACTION_ATTRIBUTE)
			if type(action) == "string" and action ~= "" then
				machine:play(action, os.clock())
			end
		end)
	end)
end

function MobAnimController.init()
	local mobFolder = Workspace:WaitForChild("Mobs", FOLDER_TIMEOUT)
	if not mobFolder then
		warn("[MobAnim] Workspace.Mobs never appeared - mobs will not animate")
		return
	end

	for _, child in mobFolder:GetChildren() do
		if child:IsA("Model") then
			bind(child)
		end
	end
	mobFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			bind(child)
		end
	end)
	mobFolder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			unbind(child)
		end
	end)

	RunService:BindToRenderStep("MobAnim", Enum.RenderPriority.Character.Value + 1, function(dt)
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

return MobAnimController

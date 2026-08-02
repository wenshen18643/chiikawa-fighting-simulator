local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionAnims = require(Shared.Modules.Config.CompanionAnims)
local Machine = require(Shared.Modules.Anim.Machine)
local Remotes = require(Shared.Modules.Remotes)
local Skeleton = require(Shared.Modules.Anim.Skeleton)

local WorkController = require(script.Parent.WorkController)

local CompanionAnimController = {}

local ACTION_ATTRIBUTE = "AnimAction"
local SKILL_ATTRIBUTE = "AnimSkill"
local OWNER_ATTRIBUTE = "AnimOwner"
local ECHO_WINDOW = 0.75
local BIND_TIMEOUT = 20
local FOLDER_TIMEOUT = 60

local machines: { [Model]: any } = {}
local connections: { [Model]: RBXScriptConnection } = {}
local localPlayedAt = 0

local function ownMachine()
	local userId = Players.LocalPlayer.UserId
	for model, machine in machines do
		if model:GetAttribute(OWNER_ATTRIBUTE) == userId then
			return machine
		end
	end
	return nil
end

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
	if machines[model] then
		return
	end

	if model:GetAttribute(Skeleton.PROFILE_ATTRIBUTE) == nil then
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
			warn(`[CompanionAnim] {model.Name} exposed no animatable joints`)
			return
		end

		local set = CompanionAnims.get(profileId)
		if not set then
			warn(`[CompanionAnim] profile "{profileId}" has no clip set`)
			return
		end

		if model.Parent == nil or machines[model] then
			return
		end

		local machine = Machine.new(model, joints, set)
		machines[model] = machine

		connections[model] = model:GetAttributeChangedSignal(ACTION_ATTRIBUTE):Connect(function()
			local owned = model:GetAttribute(OWNER_ATTRIBUTE) == Players.LocalPlayer.UserId
			if owned and os.clock() - localPlayedAt < ECHO_WINDOW then
				return
			end
			machine:playAction(model:GetAttribute(SKILL_ATTRIBUTE), os.clock())
		end)
	end)
end

function CompanionAnimController.init()
	local folder = Workspace:WaitForChild("Companions", FOLDER_TIMEOUT)
	if not folder then
		warn("[CompanionAnim] Workspace.Companions never appeared - companions will not animate")
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

	RunService:BindToRenderStep("CompanionAnim", Enum.RenderPriority.Character.Value + 1, function(dt)
		local now = os.clock()
		for model, machine in machines do
			if model.Parent then
				machine:update(dt, now)
			else
				unbind(model)
			end
		end
	end)

	local act = Remotes.event("Companion", "Act")

	WorkController.onClick(function(skillId)
		local machine = ownMachine()
		if not machine then
			return
		end

		local skill = skillId or WorkController.getTrainingSkill()
		local now = os.clock()
		if machine:playAction(skill, now) then
			localPlayedAt = now
			act:FireServer(skill)
		end
	end)
end

return CompanionAnimController

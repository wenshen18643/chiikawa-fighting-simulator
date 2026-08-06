--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinLook = require(Shared.Modules.SkinLook)
local SkinFxController = {}
local CULL_DISTANCE = 140
local CULL_INTERVAL = 0.5
local TAU = math.pi * 2

type Spinner = {
	part: BasePart,
	motor: Motor6D?,
	rate: number,
	angle: number,
}

local spinners: { [BasePart]: Spinner } = {}
local visible: { Spinner } = {}
local sinceCull = math.huge

local function resolveMotor(spinner: Spinner): Motor6D?
	local existing = spinner.motor
	if existing and existing.Parent then
		return existing
	end

	local model = spinner.part.Parent
	if not model then
		return nil
	end

	local found = model:FindFirstChild(`SkinSpin_{spinner.part.Name}`, true)
	if found and found:IsA("Motor6D") then
		spinner.motor = found
		return found
	end
	return nil
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or spinners[instance] then
		return
	end

	local rate = instance:GetAttribute(SkinLook.SPIN_ATTRIBUTE)
	if type(rate) ~= "number" or rate == 0 then
		return
	end

	spinners[instance] = { part = instance, motor = nil, rate = rate, angle = 0 }
	sinceCull = math.huge
end

local function forget(instance: Instance)
	if instance:IsA("BasePart") and spinners[instance] then
		spinners[instance] = nil
		sinceCull = math.huge
	end
end

local function rebuildVisible()
	table.clear(visible)

	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero

	for part, spinner in spinners do
		if not part.Parent then
			spinners[part] = nil
			continue
		end
		if (part.Position - eye).Magnitude > CULL_DISTANCE then
			continue
		end
		if resolveMotor(spinner) then
			table.insert(visible, spinner)
		end
	end
end

function SkinFxController.init()
	for _, tagged in CollectionService:GetTagged(SkinLook.DECORATION_TAG) do
		track(tagged)
	end
	CollectionService:GetInstanceAddedSignal(SkinLook.DECORATION_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(SkinLook.DECORATION_TAG):Connect(forget)

	RunService.Heartbeat:Connect(function(delta)
		sinceCull += delta
		if sinceCull >= CULL_INTERVAL then
			sinceCull = 0
			rebuildVisible()
		end

		for _, spinner in visible do
			local motor = spinner.motor
			if not motor then
				continue
			end
			spinner.angle = (spinner.angle + math.rad(spinner.rate) * delta) % TAU
			motor.Transform = CFrame.Angles(0, spinner.angle, 0)
		end
	end)
end

return SkinFxController

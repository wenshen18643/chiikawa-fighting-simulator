local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skeleton = require(ReplicatedStorage.Shared.Modules.Anim.Skeleton)
local YoroiRig = {}

YoroiRig.PROFILE = "yoroi"

local JOINTS = {
	Head = "Neck",
	["Left Arm"] = "Left Shoulder",
	["Right Arm"] = "Right Shoulder",
	["Left Leg"] = "Left Hip",
	["Right Leg"] = "Right Hip",
}

function YoroiRig.rig(model: Model, height: number): BasePart?
	local extents = model:GetExtentsSize()
	if extents.Y > 0.01 then
		model:ScaleTo(model:GetScale() * (height / extents.Y))
	end

	local torso = model:FindFirstChild("Torso", true)
	if not (torso and torso:IsA("BasePart")) then
		warn("[YoroiRig] model has no Torso; leaving it unrigged")
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant.ClassName ~= "Motor" and descendant.ClassName ~= "Snap" then
			continue
		end

		local legacy = descendant :: any
		local part0, part1 = legacy.Part0, legacy.Part1
		local c0, c1 = legacy.C0, legacy.C1
		legacy:Destroy()

		if not (part0 and part1) then
			continue
		end

		if part1 == torso then
			part0, part1 = part1, part0
			c0, c1 = c1, c0
		end

		local named = JOINTS[part1.Name]
		if not named then
			continue
		end

		local motor = Instance.new("Motor6D")
		motor.Name = named
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = c0
		motor.C1 = c1
		motor.Parent = part0
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = torso.Size
	root.CFrame = torso.CFrame
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.Parent = model

	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = root
	rootJoint.Part1 = torso
	rootJoint.C0 = CFrame.new()
	rootJoint.C1 = CFrame.new()
	rootJoint.Parent = root

	local jointed: { [BasePart]: boolean } = { [root] = true, [torso] = true }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 then
			jointed[descendant.Part1] = true
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local isRoot = descendant == root
			descendant.Anchored = isRoot
			descendant.CanCollide = not isRoot
			descendant.CanQuery = not isRoot
			descendant.CanTouch = false
			if not jointed[descendant] then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = torso
				weld.Part1 = descendant
				weld.Parent = torso
			end
		end
	end

	model.PrimaryPart = root
	model:SetAttribute(Skeleton.PROFILE_ATTRIBUTE, YoroiRig.PROFILE)
	return root
end

return YoroiRig

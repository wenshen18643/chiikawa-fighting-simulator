--[[
	Make the yoroiKnight model animatable.

	Lifted out of SafeZoneService when the job booth moved to the market. It was
	never safe-zone logic -- it is model surgery on one asset, and it now has two
	callers' worth of reason to live on its own.

	The model is a legacy R6 rig: the right six parts with the right names, held
	together by `Motor` and `Snap`. Those are the pre-Motor6D joint classes and
	nothing in Roblox's animation stack -- or in Anim/Machine -- will touch them,
	which is why it arrives as a statue and not as a character.

	Converting the classes is the easy half. The rig underneath them is wrong in
	three separate ways, and all three are silent:

	  BOTH SHOULDERS ARE BACKWARDS. `Right Shoulder` has Part0 = Right Arm and
	  Part1 = Torso. A Motor6D moves its Part1, so driving that joint swings the
	  BODY around a stationary arm. Every joint is therefore re-pointed away from
	  the Torso, swapping C0 and C1 with it so the rest pose is unchanged.

	  THE NECK IS A DECOY. There are two Snaps: one named "Neck" with Part0 and
	  Part1 both null, and one named "Snap" that actually holds the head on.
	  Joints are dropped if either part is missing and renamed afterwards from
	  JOINTS, so the profile binds to the joint that exists rather than to the one
	  with the right name.

	  THERE IS NO ROOT. No HumanoidRootPart means no joint for a root track to
	  drive, and the whole body would be rigid while its limbs moved.

	Order matters. ScaleTo runs FIRST, because it rewrites Motor6D offsets to
	match and any joint built afterwards would be measured against parts that have
	already moved.

	Note `ClassName` and not `IsA` on the conversion. Motor6D inherits from Motor,
	so `IsA("Motor")` is true of the very objects being created and the loop would
	eat its own output.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skeleton = require(ReplicatedStorage.Shared.Modules.Anim.Skeleton)

local YoroiRig = {}

YoroiRig.PROFILE = "yoroi"

-- R6 joint names, keyed by the limb the joint drives. Derived from the child
-- part rather than trusted from the file, which is the only version of this that
-- cannot be lied to.
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

	--[[
		Anything the rig left loose -- the two shoulder plates -- is welded to the
		torso so it travels with the animation instead of hanging in the air where
		the model was authored.

		Everything except the root is unanchored. An anchored part ignores its
		joints, so a rig anchored part-by-part animates nothing; anchoring only the
		root holds the whole assembly in place through the joints while leaving
		Motor6D.Transform free to move it.
	]]
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

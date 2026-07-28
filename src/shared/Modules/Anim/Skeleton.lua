local Skeleton = {}

export type Joint = Motor6D | AnimationConstraint

export type Joints = { [string]: Joint }

export type AttachRule = { pattern: string, to: string }

export type Profile = {
	build: boolean?,
	joints: { [string]: string },
	attach: { AttachRule }?,
	nearest: { string }?,
	fallback: string?,
}

Skeleton.PROFILE_ATTRIBUTE = "AnimProfile"

local BUILT = {
	root = "AnimRoot",
	head = "AnimHead",
	earL = "AnimEarL",
	earR = "AnimEarR",
	armL = "AnimArmL",
	armR = "AnimArmR",
	legL = "AnimLegL",
	legR = "AnimLegR",
}

Skeleton.PROFILES = {
	chiikawa = {
		build = true,
		joints = BUILT,
	},
	hachiware = {
		joints = {
			root = "RootJoint",
			armL = "Left Shoulder",
			armR = "Right Shoulder",
			legL = "Left Hip",
			legR = "Right Hip",
		},
		fallback = "Torso",
	},
	usagi = {
		joints = {
			root = "Body",
			earL = "BaseEar",
			earR = "BaseEar2",
			armL = "LeftArm",
			armR = "RightArm",
			legL = "LeftLeg",
			legR = "RightLeg",
		},
		attach = {
			{ pattern = "^Head$", to = "Body" },
			{ pattern = "^Tail$", to = "Body" },
			{ pattern = "^BaseEarLeft", to = "LeftHead" },
			{ pattern = "^BaseEarRight", to = "RightHead" },
			{ pattern = "^RightEarBase", to = "RightHead" },
			{ pattern = "^LeftEarBase", to = "LeftHead" },
			{ pattern = "^LE", to = "LeftHead" },
			{ pattern = "^RE", to = "RightHead" },
		},
		nearest = { "Body", "LeftHead", "RightHead" },
		fallback = "Body",
	},
	--[[
		The job-booth Yoroi-san. A legacy R6 rig -- correct part names, wrong
		joint classes -- so SafeZoneService.rigYoroi rebuilds its `Motor` and
		`Snap` joints as Motor6D and hangs a RootJoint off an invisible root
		before this profile can find anything.

		`build` stays false. buildRig() infers limbs from part heights and would
		reassign a rig that already has the joints named correctly.
	]]
	yoroi = {
		joints = {
			root = "RootJoint",
			head = "Neck",
			armL = "Left Shoulder",
			armR = "Right Shoulder",
			legL = "Left Hip",
			legR = "Right Hip",
		},
		fallback = "Torso",
	},
	mushroomFrog = {
		joints = {
			root = "RootJoint",
			head = "Neck",
			armL = "LeftShoulder",
			armR = "RightShoulder",
			legL = "LeftHip",
			legR = "RightHip",
			hat = "HatJoint",
		},
		fallback = "Torso",
	},
	duck = {
		joints = {
			root = "RootJoint",
			head = "Neck",
			armL = "Left Shoulder",
			armR = "Right Shoulder",
			legL = "Left Hip",
			legR = "Right Hip",
		},
		fallback = "Torso",
	},
	spider = {
		joints = {
			root = "RootJoint",
		},
		fallback = "Spider",
	},
} :: { [string]: Profile }

Skeleton.PLAYER_PROFILES = {
	R15 = {
		root = "RootJoint",
		waist = "Waist",
		neck = "Neck",
		shoulderL = "LeftShoulder",
		shoulderR = "RightShoulder",
		elbowL = "LeftElbow",
		elbowR = "RightElbow",
		wristL = "LeftWrist",
		wristR = "RightWrist",
		hipL = "LeftHip",
		hipR = "RightHip",
		kneeL = "LeftKnee",
		kneeR = "RightKnee",
	},
	R6 = {
		root = "RootJoint",
		neck = "Neck",
		shoulderL = "Left Shoulder",
		shoulderR = "Right Shoulder",
		hipL = "Left Hip",
		hipR = "Right Hip",
	},
} :: { [string]: { [string]: string } }

Skeleton.JOINT_ALIASES = {
	RootJoint = { "Root" },
} :: { [string]: { string } }

function Skeleton.isJoint(instance: Instance): boolean
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

local function attachmentPart(attachment: Attachment?): BasePart?
	local parent = attachment and attachment.Parent
	if parent and parent:IsA("BasePart") then
		return parent
	end
	return nil
end

function Skeleton.jointParts(joint: Joint): (BasePart?, BasePart?)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1
	end
	return attachmentPart(joint.Attachment0), attachmentPart(joint.Attachment1)
end

function Skeleton.jointOffsets(joint: Joint): (CFrame, CFrame)
	if joint:IsA("Motor6D") then
		return joint.C0, joint.C1
	end
	local a0, a1 = joint.Attachment0, joint.Attachment1
	return (if a0 then a0.CFrame else CFrame.identity), (if a1 then a1.CFrame else CFrame.identity)
end

function Skeleton.rigKind(character: Model): string
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		return "R6"
	end
	return "R15"
end

function Skeleton.resolveCharacter(character: Model): (Joints?, string)
	local kind = Skeleton.rigKind(character)
	local names = Skeleton.PLAYER_PROFILES[kind]

	local available: { [string]: Joint } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			available[descendant.Name] = descendant
		elseif descendant:IsA("AnimationConstraint") and descendant.Attachment0 and descendant.Attachment1 then
			local existing = available[descendant.Name]
			if not (existing and existing:IsA("Motor6D")) then
				available[descendant.Name] = descendant
			end
		end
	end

	local joints: Joints = {}
	local found = false
	for canonical, actual in names do
		local joint = available[actual]
		if not joint then
			for _, alias in Skeleton.JOINT_ALIASES[actual] or {} do
				joint = available[alias]
				if joint then
					break
				end
			end
		end
		if joint then
			joints[canonical] = joint
			found = true
		end
	end

	if not found then
		return nil, kind
	end
	return joints, kind
end

--[[
	Rotations are authored once in the character's own root frame and mapped
	onto whatever axes a given rig actually uses.

	Returns basis and its inverse per joint, so a pose P is applied as
	`inverse * P * basis`. That is what lets one clip drive an R6 shoulder, an
	R15 shoulder and a hand-built Motor6D without per-rig sign tables.
]]
function Skeleton.basisFor(
	model: Instance,
	joints: Joints,
	root: BasePart
): ({ [string]: CFrame }, { [string]: CFrame })
	local jointsByChild: { [BasePart]: Joint } = {}
	for _, descendant in model:GetDescendants() do
		if Skeleton.isJoint(descendant) then
			local _, part1 = Skeleton.jointParts(descendant :: Joint)
			if part1 then
				jointsByChild[part1] = descendant :: Joint
			end
		end
	end

	local function restToRoot(part: BasePart): CFrame
		local cframe = CFrame.identity
		local current: BasePart? = part
		local guard = 0
		while current and current ~= root and guard < 12 do
			local joint = jointsByChild[current]
			if not joint then
				break
			end
			local part0 = Skeleton.jointParts(joint)
			if not part0 then
				break
			end
			local c0, c1 = Skeleton.jointOffsets(joint)
			cframe = (c0 * c1:Inverse()) * cframe
			current = part0
			guard += 1
		end
		return cframe
	end

	local basis: { [string]: CFrame } = {}
	local inverse: { [string]: CFrame } = {}

	for name, joint in joints do
		local part0 = Skeleton.jointParts(joint)
		if part0 then
			local parentRest = restToRoot(part0)
			local parentRotation = parentRest - parentRest.Position
			local c0 = Skeleton.jointOffsets(joint)
			local value = parentRotation * (c0 - c0.Position)
			basis[name] = value
			inverse[name] = value:Inverse()
		end
	end

	return basis, inverse
end

local function volumeOf(part: BasePart): number
	local size = part.Size
	return size.X * size.Y * size.Z
end

local function isFaced(part: BasePart): boolean
	for _, child in part:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			return true
		end
	end
	return false
end

local function partsOf(model: Model): { BasePart }
	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function endOf(part: BasePart, sign: number): Vector3
	return (part.CFrame * CFrame.new(0, sign * part.Size.Y / 2, 0)).Position
end

local function connect(part0: BasePart, part1: BasePart, name: string, pivotPosition: Vector3, frame: CFrame): Motor6D
	local pivot = CFrame.new(pivotPosition) * (frame - frame.Position)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:Inverse() * pivot
	motor.C1 = part1.CFrame:Inverse() * pivot
	motor.Parent = part0
	return motor
end

local function weld(part0: BasePart, part1: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part0
end

local LIMBS = {
	ear = { names = { BUILT.earL, BUILT.earR }, pivotSign = -1 },
	arm = { names = { BUILT.armL, BUILT.armR }, pivotSign = 1 },
	leg = { names = { BUILT.legL, BUILT.legR }, pivotSign = 1 },
}

local function buildRig(model: Model): BasePart?
	local parts = partsOf(model)
	if #parts < 2 then
		return nil
	end

	table.sort(parts, function(a, b)
		return volumeOf(a) > volumeOf(b)
	end)

	local head: BasePart? = nil
	for _, part in parts do
		if isFaced(part) then
			head = part
			break
		end
	end
	head = head or parts[1]

	local body: BasePart? = nil
	for _, part in parts do
		if part ~= head then
			body = part
			break
		end
	end
	if not body or not head then
		return nil
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = body.Size
	root.CFrame = body.CFrame
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = body.Anchored
	root.Parent = model

	connect(root, body, BUILT.root, root.Position, root.CFrame)
	connect(body, head, BUILT.head, endOf(head, -1), body.CFrame)

	local buckets: { [string]: { BasePart } } = { ear = {}, arm = {}, leg = {} }
	for _, part in parts do
		if part == head or part == body then
			continue
		end
		local y = part.Position.Y
		local role
		if y > head.Position.Y then
			role = "ear"
		elseif y < body.Position.Y then
			role = "leg"
		else
			role = "arm"
		end
		table.insert(buckets[role], part)
	end

	for role, list in buckets do
		local spec = LIMBS[role]
		local parent = if role == "ear" then head else body
		table.sort(list, function(a, b)
			return body.CFrame:PointToObjectSpace(a.Position).X < body.CFrame:PointToObjectSpace(b.Position).X
		end)
		for index, part in list do
			local name = spec.names[index]
			if name then
				connect(parent, part, name, endOf(part, spec.pivotSign), parent.CFrame)
			else
				weld(parent, part)
			end
		end
	end

	return root
end

local function findRoot(model: Model): BasePart?
	local named = model:FindFirstChild("HumanoidRootPart", true)
	if named and named:IsA("BasePart") then
		return named
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local best: BasePart? = nil
	local bestVolume = 0
	for _, part in partsOf(model) do
		local volume = volumeOf(part)
		if volume > bestVolume then
			best, bestVolume = part, volume
		end
	end
	return best
end

local function namedPart(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function attachLoose(model: Model, profile: Profile, root: BasePart)
	local jointed: { [BasePart]: boolean } = { [root] = true }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") or descendant:IsA("WeldConstraint") then
			local part0, part1 = descendant.Part0, descendant.Part1
			if part0 then
				jointed[part0] = true
			end
			if part1 then
				jointed[part1] = true
			end
		end
	end

	local candidates: { BasePart } = {}
	if profile.nearest then
		for _, name in profile.nearest do
			local found = namedPart(model, name)
			if found then
				table.insert(candidates, found)
			end
		end
	end

	local function targetFor(part: BasePart): BasePart
		if profile.attach then
			for _, rule in profile.attach do
				if string.match(part.Name, rule.pattern) then
					local found = namedPart(model, rule.to)
					if found and found ~= part then
						return found
					end
				end
			end
		end

		local best: BasePart? = nil
		local bestDistance = math.huge
		for _, candidate in candidates do
			if candidate ~= part then
				local distance = (candidate.Position - part.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = candidate, distance
				end
			end
		end
		if best then
			return best
		end

		if profile.fallback then
			local found = namedPart(model, profile.fallback)
			if found and found ~= part then
				return found
			end
		end
		return root
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not jointed[descendant] then
			local target = targetFor(descendant)
			if target ~= descendant then
				weld(target, descendant)
			end
		end
	end
end

local function realign(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local part0, part1 = descendant.Part0, descendant.Part1
			if part0 and part1 then
				descendant.C0 = part0.CFrame:Inverse() * part1.CFrame * descendant.C1
				descendant.Transform = CFrame.new()
			end
		end
	end
end

local function flattenAccessories(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Accessory") then
			local handle = descendant:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Parent = model
			end
			descendant:Destroy()
		end
	end
end

function Skeleton.prepare(model: Model, profileId: string): BasePart?
	local profile = Skeleton.PROFILES[profileId]
	if not profile then
		return nil
	end

	flattenAccessories(model)

	if profile.build then
		buildRig(model)
	end

	local root = findRoot(model)
	if not root then
		return nil
	end

	realign(model)
	attachLoose(model, profile, root)

	model.PrimaryPart = root
	model:SetAttribute(Skeleton.PROFILE_ATTRIBUTE, profileId)
	return root
end

function Skeleton.resolve(model: Model): (Joints?, string?)
	local profileId = model:GetAttribute(Skeleton.PROFILE_ATTRIBUTE)
	if type(profileId) ~= "string" then
		return nil, nil
	end

	local profile = Skeleton.PROFILES[profileId]
	if not profile then
		return nil, profileId
	end

	local motors: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end

	local joints: Joints = {}
	local found = false
	for canonical, actual in profile.joints do
		local motor = motors[actual]
		if motor then
			joints[canonical] = motor
			found = true
		end
	end

	if not found then
		return nil, profileId
	end
	return joints, profileId
end

return Skeleton

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local ModelUtil = require(Shared.Modules.ModelUtil)
local Mobs = require(Shared.Modules.Config.Mobs)

local MobRig = {}

local ACTION_ATTRIBUTE = "MobAction"
local ACTION_SERIAL_ATTRIBUTE = "MobActionSerial"

local function namedPart(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

local function topOf(part: BasePart): Vector3
	return (part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)).Position
end

local function bottomOf(part: BasePart): Vector3
	return (part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)).Position
end

local function connectAt(part0: BasePart, part1: BasePart, name: string, pivotPosition: Vector3): Motor6D
	local pivot = CFrame.new(pivotPosition) * part0.CFrame.Rotation
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(pivot)
	motor.C1 = part1.CFrame:ToObjectSpace(pivot)
	motor.Parent = part0
	return motor
end

local function weld(part0: BasePart, part1: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part0
end

local function clearInheritedBehavior(model: Model)
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("AnimationController")
			or descendant:IsA("Humanoid")
			or descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
		then
			descendant:Destroy()
		end
	end
end

local function flattenFrog(model: Model)
	local wrapper = model:FindFirstChild("Frog")
	if wrapper and wrapper:IsA("Model") then
		for _, child in wrapper:GetChildren() do
			child.Parent = model
		end
		wrapper:Destroy()
	end
end

local function configureRoot(root: BasePart, centre: BasePart, groundY: number, width: number?, depth: number?)
	root.Size = Vector3.new(math.max(width or root.Size.X, 3), 2, math.max(depth or root.Size.Z, 3))
	root.CFrame = CFrame.new(centre.Position.X, groundY + root.Size.Y / 2, centre.Position.Z) * centre.CFrame.Rotation
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = false
	root.RootPriority = 127
end

local function nearestArticulatedAncestor(
	part: BasePart,
	articulated: { [BasePart]: boolean },
	fallback: BasePart
): BasePart
	local current = part.Parent
	while current do
		if current:IsA("BasePart") and articulated[current] then
			return current
		end
		current = current.Parent
	end
	return fallback
end

local function weldLoose(
	model: Model,
	articulated: { [BasePart]: boolean },
	fallback: BasePart,
	overrides: { [string]: BasePart }?
)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not articulated[descendant] then
			local target = if overrides then overrides[descendant.Name] else nil
			target = target or nearestArticulatedAncestor(descendant, articulated, fallback)
			if target ~= descendant then
				weld(target, descendant)
			end
		end
	end
end

local function rigMushroomFrog(model: Model): (BasePart?, BasePart?)
	local root = namedPart(model, "HumanoidRootPart")
	local torso = namedPart(model, "Torso")
	local head = namedPart(model, "Head")
	local leftHand = namedPart(model, "LeftHand")
	local rightHand = namedPart(model, "RightHand")
	local leftFoot = namedPart(model, "LeftFoot")
	local rightFoot = namedPart(model, "RightFoot")
	local hat = namedPart(model, "Handle")
	if not (root and torso and head and leftHand and rightHand and leftFoot and rightFoot and hat) then
		return nil, nil
	end

	local feetBottom = math.min(bottomOf(leftFoot).Y, bottomOf(rightFoot).Y)
	configureRoot(root, torso, feetBottom)
	connectAt(root, torso, "RootJoint", torso.Position)
	connectAt(torso, head, "Neck", bottomOf(head))
	connectAt(torso, leftHand, "LeftShoulder", topOf(leftHand))
	connectAt(torso, rightHand, "RightShoulder", topOf(rightHand))
	connectAt(torso, leftFoot, "LeftHip", topOf(leftFoot))
	connectAt(torso, rightFoot, "RightHip", topOf(rightFoot))
	connectAt(head, hat, "HatJoint", bottomOf(hat))

	local articulated = {
		[root] = true,
		[torso] = true,
		[head] = true,
		[leftHand] = true,
		[rightHand] = true,
		[leftFoot] = true,
		[rightFoot] = true,
		[hat] = true,
	}
	weldLoose(model, articulated, torso, { Eyes = head, DisplayEyes = head })
	return root, head
end

local function rigDuck(model: Model): (BasePart?, BasePart?)
	local root = namedPart(model, "HumanoidRootPart")
	local torso = namedPart(model, "Torso")
	local head = namedPart(model, "Head")
	local leftArm = namedPart(model, "Left Arm")
	local rightArm = namedPart(model, "Right Arm")
	local leftLeg = namedPart(model, "Left Leg")
	local rightLeg = namedPart(model, "Right Leg")
	if not (root and torso and head and leftArm and rightArm and leftLeg and rightLeg) then
		return nil, nil
	end

	local feetBottom = math.min(bottomOf(leftLeg).Y, bottomOf(rightLeg).Y)
	configureRoot(root, torso, feetBottom)
	connectAt(root, torso, "RootJoint", torso.Position)
	connectAt(torso, head, "Neck", bottomOf(head))
	connectAt(torso, leftArm, "Left Shoulder", topOf(leftArm))
	connectAt(torso, rightArm, "Right Shoulder", topOf(rightArm))
	connectAt(torso, leftLeg, "Left Hip", topOf(leftLeg))
	connectAt(torso, rightLeg, "Right Hip", topOf(rightLeg))

	local articulated = {
		[root] = true,
		[torso] = true,
		[head] = true,
		[leftArm] = true,
		[rightArm] = true,
		[leftLeg] = true,
		[rightLeg] = true,
	}
	weldLoose(model, articulated, torso)
	return root, head
end

local function rigWolf(model: Model): (BasePart?, BasePart?)
	local root = namedPart(model, "HumanoidRootPart")
	local torso = namedPart(model, "Torso")
	local head = namedPart(model, "Head")
	local frontLeft = namedPart(model, "LeftHand")
	local frontRight = namedPart(model, "RightHand")
	local backLeft = namedPart(model, "LeftFoot")
	local backRight = namedPart(model, "RightFoot")
	local tail = namedPart(model, "Tail")
	local leftEar = namedPart(model, "LeftEar")
	local rightEar = namedPart(model, "RightEar")
	if
		not root
		or not torso
		or not head
		or not frontLeft
		or not frontRight
		or not backLeft
		or not backRight
		or not tail
		or not leftEar
		or not rightEar
	then
		return nil, nil
	end

	local feetBottom = math.min(
		bottomOf(frontLeft).Y,
		bottomOf(frontRight).Y,
		bottomOf(backLeft).Y,
		bottomOf(backRight).Y
	)
	configureRoot(root, torso, feetBottom, torso.Size.X, torso.Size.Z)
	connectAt(root, torso, "RootJoint", torso.Position)
	connectAt(torso, head, "Neck", (torso.Position + head.Position) / 2)
	connectAt(torso, frontLeft, "FrontLeftJoint", topOf(frontLeft))
	connectAt(torso, frontRight, "FrontRightJoint", topOf(frontRight))
	connectAt(torso, backLeft, "BackLeftJoint", topOf(backLeft))
	connectAt(torso, backRight, "BackRightJoint", topOf(backRight))
	connectAt(torso, tail, "TailJoint", (torso.Position + tail.Position) / 2)
	connectAt(head, leftEar, "LeftEarJoint", bottomOf(leftEar))
	connectAt(head, rightEar, "RightEarJoint", bottomOf(rightEar))

	local articulated = {
		[root] = true,
		[torso] = true,
		[head] = true,
		[frontLeft] = true,
		[frontRight] = true,
		[backLeft] = true,
		[backRight] = true,
		[tail] = true,
		[leftEar] = true,
		[rightEar] = true,
	}
	weldLoose(model, articulated, torso, {
		Nose = head,
		Eyes = head,
		DisplayEyes = head,
		Tounge = head,
	})
	return root, head
end

--[[
	The guardian is the plain sausage asset with a temper: three primitives, no
	joints and no face. Everything that makes it a creature is added here, so
	the same capsule serves as scenery, as a guardian and as the BIG tree.
]]
local function blackPart(model: Model, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = Color3.fromRGB(28, 22, 24)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = model
	return part
end

-- Features sit just proud of the skin so they read from any angle without the
-- z-fighting of a decal on a curved surface.
local function buildAngryFace(model: Model, at: CFrame, radius: number)
	local skin = radius * 0.94
	local eye = radius * 0.34
	for _, side in { -1, 1 } do
		local across = side * radius * 0.38
		local sphere = blackPart(model, "Eye", Vector3.new(eye, eye, eye), at * CFrame.new(across, 0, -skin))
		sphere.Shape = Enum.PartType.Ball
		-- Brows tilted in towards the nose: the whole expression is these two.
		blackPart(
			model,
			"Brow",
			Vector3.new(radius * 0.5, radius * 0.13, radius * 0.13),
			at * CFrame.new(across, radius * 0.36, -skin) * CFrame.Angles(0, 0, math.rad(-side * 24))
		)
	end
	blackPart(
		model,
		"Mouth",
		Vector3.new(radius * 0.55, radius * 0.13, radius * 0.13),
		at * CFrame.new(0, -radius * 0.44, -skin)
	)
end

--[[
	One stubby arm, its inner cap buried in the body so the shoulder never shows
	a gap. Returns the arm and the world point the shoulder pivots on.
]]
local function buildArm(model: Model, body: BasePart, at: CFrame, radius: number, side: number): (BasePart, Vector3)
	local length = radius * 1.4
	local arm = Instance.new("Part")
	arm.Name = if side < 0 then "LeftArm" else "RightArm"
	arm.Shape = Enum.PartType.Cylinder
	arm.Size = Vector3.new(length, radius * 0.34, radius * 0.34)
	arm.CFrame = at * CFrame.new(side * (radius * 0.6 + length / 2), 0, 0)
	arm.Color = body.Color
	arm.Material = body.Material
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CanTouch = false
	arm.Parent = model
	return arm, (at * CFrame.new(side * radius * 0.6, 0, 0)).Position
end

local function rigSausageGuardian(model: Model): (BasePart?, BasePart?)
	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		return nil, nil
	end
	table.sort(parts, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)

	local body = parts[1]
	body.Name = "Torso"

	local centre, size = ModelUtil.worldBox(model)
	local radius = math.max(math.min(size.X, size.Z) / 2, 0.1)

	-- Identity rotation, so the face is always on the root's LookVector side and
	-- turning to face a player turns the face with it.
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(math.max(radius * 2, 2), 2, math.max(radius * 2, 2))
	root.CFrame = CFrame.new(centre.X, centre.Y - size.Y / 2 + 1, centre.Z)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	root.CanTouch = false
	root.RootPriority = 127
	root.Parent = model

	buildAngryFace(model, CFrame.new(centre.X, centre.Y + size.Y * 0.28, centre.Z), radius)

	local shoulders = CFrame.new(centre.X, centre.Y + size.Y * 0.06, centre.Z)
	local armL, pivotL = buildArm(model, body, shoulders, radius, -1)
	local armR, pivotR = buildArm(model, body, shoulders, radius, 1)

	connectAt(root, body, "RootJoint", body.Position)
	connectAt(body, armL, "Left Shoulder", pivotL)
	connectAt(body, armR, "Right Shoulder", pivotR)

	weldLoose(model, { [root] = true, [body] = true, [armL] = true, [armR] = true }, body)
	return root, body
end

local function addHealthDisplay(model: Model, adornee: BasePart, definition: Mobs.MobDefinition): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "MobHealth"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(150, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, definition.height * 0.9, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Parent = model

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.new(1, 0, 0, 24)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.Text = definition.name
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.35
	name.TextScaled = true
	name.Parent = gui

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Position = UDim2.fromOffset(10, 29)
	background.Size = UDim2.new(1, -20, 0, 10)
	background.BackgroundColor3 = Color3.fromRGB(72, 55, 58)
	background.BorderSizePixel = 0
	background.Parent = gui

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(1, 0)
	backgroundCorner.Parent = background

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(126, 205, 116)
	fill.BorderSizePixel = 0
	fill.Parent = background

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	return fill
end

local function configurePhysics(model: Model, root: BasePart, collisionGroup: string?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if collisionGroup then
				descendant.CollisionGroup = collisionGroup
			end
			descendant.Anchored = false
			if descendant ~= root then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
			end
		end
	end
end

function MobRig.rig(
	model: Model,
	definition: Mobs.MobDefinition,
	collisionGroup: string?
): (BasePart?, Humanoid?, Frame?)
	clearInheritedBehavior(model)
	if definition.rigProfile == "mushroomFrog" then
		flattenFrog(model)
	elseif definition.rigProfile == "sausageGuardian" then
		-- Authored lying down, and height scaling measures Y: stand it first or
		-- the guardian is scaled by its own girth.
		ModelUtil.standUpright(model)
	end
	if not ModelUtil.scaleToHeight(model, definition.height) then
		return nil, nil, nil
	end

	local root: BasePart?
	local displayPart: BasePart?
	if definition.rigProfile == "mushroomFrog" then
		root, displayPart = rigMushroomFrog(model)
	elseif definition.rigProfile == "duck" then
		root, displayPart = rigDuck(model)
	elseif definition.rigProfile == "wolf" then
		root, displayPart = rigWolf(model)
	elseif definition.rigProfile == "sausageGuardian" then
		root, displayPart = rigSausageGuardian(model)
	end
	if not root or not displayPart then
		return nil, nil, nil
	end

	configurePhysics(model, root, collisionGroup)

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = definition.maxHealth
	humanoid.Health = definition.maxHealth
	humanoid.WalkSpeed = definition.roamSpeed
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute(Skeleton.PROFILE_ATTRIBUTE, definition.animProfile)
	model:SetAttribute("MobId", definition.id)
	model:SetAttribute(ACTION_ATTRIBUTE, "")
	model:SetAttribute(ACTION_SERIAL_ATTRIBUTE, 0)

	return root, humanoid, addHealthDisplay(model, displayPart, definition)
end

return MobRig

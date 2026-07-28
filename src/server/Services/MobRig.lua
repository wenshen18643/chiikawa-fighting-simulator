--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skeleton = require(Shared.Modules.Anim.Skeleton)
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

local function scaleToHeight(model: Model, height: number): boolean
	local extents = model:GetExtentsSize()
	if extents.Y <= 0.01 then
		return false
	end
	model:ScaleTo(model:GetScale() * (height / extents.Y))
	return true
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

local function largestPart(model: Model): BasePart?
	local largest: BasePart? = nil
	local largestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > largestVolume then
				largest, largestVolume = descendant, volume
			end
		end
	end
	return largest
end

local function rigSpider(model: Model): (BasePart?, BasePart?)
	local body = largestPart(model)
	if not body then
		return nil, nil
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = model
	configureRoot(root, body, bottomOf(body).Y, body.Size.X * 0.7, body.Size.Z * 0.7)
	connectAt(root, body, "RootJoint", body.Position)
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
	end
	if not scaleToHeight(model, definition.height) then
		return nil, nil, nil
	end

	local root: BasePart?
	local displayPart: BasePart?
	if definition.rigProfile == "mushroomFrog" then
		root, displayPart = rigMushroomFrog(model)
	elseif definition.rigProfile == "duck" then
		root, displayPart = rigDuck(model)
	elseif definition.rigProfile == "spider" then
		root, displayPart = rigSpider(model)
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

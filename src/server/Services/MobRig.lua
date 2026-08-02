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
			local override = if overrides then overrides[descendant.Name] else nil
			local target = override or nearestArticulatedAncestor(descendant, articulated, fallback)
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

local function buildAngryFace(model: Model, at: CFrame, radius: number)
	local skin = radius * 0.94
	local eye = radius * 0.34
	for _, side in { -1, 1 } do
		local across = side * radius * 0.38
		local sphere = blackPart(model, "Eye", Vector3.new(eye, eye, eye), at * CFrame.new(across, 0, -skin))
		sphere.Shape = Enum.PartType.Ball
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

local CAVE_DEFAULT_PALETTE: { [string]: Color3 } = {
	body = Color3.fromRGB(226, 214, 198),
	cap = Color3.fromRGB(150, 116, 158),
	accent = Color3.fromRGB(236, 226, 210),
	eye = Color3.fromRGB(38, 30, 40),
	glow = Color3.fromRGB(244, 214, 140),
}

local function paletteOf(definition: Mobs.MobDefinition): { [string]: Color3 }
	local palette = (definition :: any).palette
	local resolved: { [string]: Color3 } = {}
	for key, value in CAVE_DEFAULT_PALETTE do
		resolved[key] = if palette and palette[key] then palette[key] else value
	end
	return resolved
end

type PieceOptions = {
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
}

local function piece(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: PieceOptions?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if options and options.shape then options.shape else Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = if options and options.material then options.material else Enum.Material.SmoothPlastic
	part.Transparency = if options and options.transparency then options.transparency else 0
	part.Anchored = true
	part.CanCollide = if options then options.collide == true else false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function buildRoot(model: Model, name: string, width: number, groundY: number, at: Vector3): Part
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(math.max(width, 2), 2, math.max(width, 2))
	root.CFrame = CFrame.new(at.X, groundY + 1, at.Z)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	root.CanTouch = false
	root.RootPriority = 127
	root.Parent = model
	model.Name = name
	return root
end

local function addEyes(model: Model, face: CFrame, spread: number, size: number, color: Color3)
	for _, side in { -1, 1 } do
		piece(
			model,
			"Eye",
			Vector3.new(size, size, size),
			face * CFrame.new(side * spread, 0, 0),
			color,
			{ shape = Enum.PartType.Ball }
		)
	end
end

local function buildSporeling(model: Model, definition: Mobs.MobDefinition): (BasePart, BasePart)
	local palette = paletteOf(definition)
	local h = definition.height
	local capRadius = h * 0.42
	local stalkHeight = h * 0.42
	local legHeight = h * 0.18
	local stalkY = legHeight + stalkHeight / 2
	local stalk = piece(
		model,
		"Torso",
		Vector3.new(h * 0.34, stalkHeight, h * 0.34),
		CFrame.new(0, stalkY, 0),
		palette.body,
		{ shape = Enum.PartType.Cylinder }
	)
	stalk.CFrame = CFrame.new(0, stalkY, 0) * CFrame.Angles(0, 0, math.rad(90))
	stalk.Size = Vector3.new(stalkHeight, h * 0.34, h * 0.34)

	local capY = legHeight + stalkHeight + capRadius * 0.18
	local cap = piece(
		model,
		"Cap",
		Vector3.new(capRadius * 2, capRadius * 2, capRadius * 2),
		CFrame.new(0, capY, 0),
		palette.cap,
		{ shape = Enum.PartType.Ball }
	)

	local spotRng = Random.new(7)
	for index = 1, 4 do
		local angle = math.rad(index * 84 + 20)
		local tilt = math.rad(spotRng:NextNumber(24, 58))
		local spot = capRadius * spotRng:NextNumber(0.16, 0.24)
		piece(
			model,
			"Spot",
			Vector3.new(spot, spot, spot),
			CFrame.new(0, capY, 0)
				* CFrame.Angles(0, angle, 0)
				* CFrame.Angles(-tilt, 0, 0)
				* CFrame.new(0, 0, -capRadius * 0.94),
			palette.accent,
			{ shape = Enum.PartType.Ball }
		)
	end

	addEyes(model, CFrame.new(0, stalkY + stalkHeight * 0.16, -h * 0.16), h * 0.08, h * 0.09, palette.eye)

	local legs = {}
	for _, side in { -1, 1 } do
		local leg = piece(
			model,
			if side < 0 then "LegLeft" else "LegRight",
			Vector3.new(h * 0.11, legHeight, h * 0.11),
			CFrame.new(side * h * 0.11, legHeight / 2, 0),
			palette.body,
			{ shape = Enum.PartType.Cylinder }
		)
		leg.Size = Vector3.new(legHeight, h * 0.11, h * 0.11)
		leg.CFrame = CFrame.new(side * h * 0.11, legHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(legs, leg)
	end

	local root = buildRoot(model, definition.modelName, h * 0.5, 0, Vector3.zero)
	connectAt(root, stalk, "RootJoint", stalk.Position)
	connectAt(stalk, cap, "Neck", Vector3.new(0, legHeight + stalkHeight, 0))
	connectAt(stalk, legs[1], "LeftHip", Vector3.new(-h * 0.11, legHeight, 0))
	connectAt(stalk, legs[2], "RightHip", Vector3.new(h * 0.11, legHeight, 0))

	weldLoose(
		model,
		{ [root] = true, [stalk] = true, [cap] = true, [legs[1]] = true, [legs[2]] = true },
		stalk,
		{ Spot = cap, Eye = stalk } :: { [string]: BasePart }
	)
	return root, cap
end

local function buildPebblejaw(model: Model, definition: Mobs.MobDefinition): (BasePart, BasePart)
	local palette = paletteOf(definition)
	local h = definition.height
	local bodyHeight = h * 0.44
	local legHeight = h * 0.26
	local length = h * 1.5
	local width = h * 0.9
	local bodyY = legHeight + bodyHeight / 2
	local body = piece(
		model,
		"Torso",
		Vector3.new(width, bodyHeight, length),
		CFrame.new(0, bodyY, 0),
		palette.body
	)

	for index = 1, 3 do
		local along = (index - 2) * length * 0.28
		local plate = h * (0.62 - index * 0.06)
		piece(
			model,
			"Plate",
			Vector3.new(plate, h * 0.1, plate * 0.55),
			CFrame.new(0, bodyY + bodyHeight * 0.42, along) * CFrame.Angles(math.rad(-16), 0, 0),
			palette.accent
		)
	end

	local jaw = piece(
		model,
		"Jaw",
		Vector3.new(width * 0.86, h * 0.3, h * 0.42),
		CFrame.new(0, bodyY - bodyHeight * 0.1, -length * 0.56),
		palette.cap
	)

	for index = 1, 4 do
		piece(
			model,
			"Tooth",
			Vector3.new(h * 0.07, h * 0.11, h * 0.07),
			CFrame.new(
				(index - 2.5) * width * 0.2,
				bodyY - bodyHeight * 0.24,
				-length * 0.56 - h * 0.19
			),
			palette.accent
		)
	end

	addEyes(model, CFrame.new(0, bodyY + bodyHeight * 0.2, -length * 0.5), width * 0.24, h * 0.09, palette.eye)

	local legs = {}
	for _, along in { -0.32, 0.3 } do
		for _, side in { -1, 1 } do
			local leg = piece(
				model,
				"Leg",
				Vector3.new(h * 0.12, legHeight, h * 0.12),
				CFrame.new(side * width * 0.46, legHeight / 2, along * length),
				palette.cap,
				{ shape = Enum.PartType.Cylinder }
			)
			leg.Size = Vector3.new(legHeight, h * 0.12, h * 0.12)
			leg.CFrame = CFrame.new(side * width * 0.46, legHeight / 2, along * length)
				* CFrame.Angles(0, 0, math.rad(90))
			table.insert(legs, leg)
		end
	end

	local root = buildRoot(model, definition.modelName, width, 0, Vector3.zero)
	connectAt(root, body, "RootJoint", body.Position)
	connectAt(body, jaw, "Neck", Vector3.new(0, bodyY, -length * 0.4))
	connectAt(body, legs[1], "FrontLeftJoint", topOf(legs[1]))
	connectAt(body, legs[2], "FrontRightJoint", topOf(legs[2]))
	connectAt(body, legs[3], "BackLeftJoint", topOf(legs[3]))
	connectAt(body, legs[4], "BackRightJoint", topOf(legs[4]))

	local articulated: { [BasePart]: boolean } = { [root] = true, [body] = true, [jaw] = true }
	for _, leg in legs do
		articulated[leg] = true
	end
	weldLoose(model, articulated, body, { Tooth = jaw, Eye = jaw } :: { [string]: BasePart })
	return root, body
end

local function buildWisp(model: Model, definition: Mobs.MobDefinition): (BasePart, BasePart)
	local palette = paletteOf(definition)
	local h = definition.height
	local coreRadius = h * 0.3
	local hover = h * 0.62

	local core = piece(
		model,
		"Torso",
		Vector3.new(coreRadius * 2, coreRadius * 2, coreRadius * 2),
		CFrame.new(0, hover, 0),
		palette.glow,
		{ shape = Enum.PartType.Ball, material = Enum.Material.Neon }
	)

	piece(
		model,
		"Shell",
		Vector3.new(coreRadius * 3, coreRadius * 3, coreRadius * 3),
		CFrame.new(0, hover, 0),
		palette.cap,
		{ shape = Enum.PartType.Ball, material = Enum.Material.ForceField, transparency = 0.6 }
	)

	local light = Instance.new("PointLight")
	light.Brightness = 2.4
	light.Range = 34
	light.Color = palette.glow
	light.Shadows = false
	light.Parent = core

	local motes = {}
	for index = 1, 3 do
		local angle = math.rad(index * 120)
		local mote = piece(
			model,
			"Mote",
			Vector3.new(h * 0.1, h * 0.1, h * 0.1),
			CFrame.new(0, hover, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -coreRadius * 2.1),
			palette.accent,
			{ shape = Enum.PartType.Ball, material = Enum.Material.Neon }
		)
		table.insert(motes, mote)
	end

	addEyes(model, CFrame.new(0, hover, -coreRadius * 0.94), coreRadius * 0.34, h * 0.07, palette.eye)

	local root = buildRoot(model, definition.modelName, coreRadius * 2, 0, Vector3.zero)
	connectAt(root, core, "RootJoint", core.Position)
	connectAt(core, motes[1], "LeftShoulder", core.Position)
	connectAt(core, motes[2], "RightShoulder", core.Position)
	connectAt(core, motes[3], "Neck", core.Position)

	weldLoose(
		model,
		{ [root] = true, [core] = true, [motes[1]] = true, [motes[2]] = true, [motes[3]] = true },
		core,
		{ Shell = core, Eye = core } :: { [string]: BasePart }
	)
	return root, core
end

local function buildMycelia(model: Model, definition: Mobs.MobDefinition): (BasePart, BasePart)
	local palette = paletteOf(definition)
	local h = definition.height
	local trunkHeight = h * 0.52
	local capRadius = h * 0.46

	local trunk = piece(
		model,
		"Torso",
		Vector3.new(h * 0.3, trunkHeight, h * 0.3),
		CFrame.new(0, trunkHeight / 2, 0),
		palette.body,
		{ shape = Enum.PartType.Cylinder }
	)
	trunk.Size = Vector3.new(trunkHeight, h * 0.3, h * 0.3)
	trunk.CFrame = CFrame.new(0, trunkHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90))

	local capY = trunkHeight + capRadius * 0.16
	local cap = piece(
		model,
		"Cap",
		Vector3.new(capRadius * 2, capRadius * 2, capRadius * 2),
		CFrame.new(0, capY, 0),
		palette.cap,
		{ shape = Enum.PartType.Ball }
	)

	for index = 1, 8 do
		local angle = math.rad(index * 45)
		piece(
			model,
			"Gill",
			Vector3.new(capRadius * 0.14, h * 0.06, capRadius * 1.3),
			CFrame.new(0, trunkHeight + h * 0.02, 0) * CFrame.Angles(0, angle, 0),
			palette.accent
		)
	end

	for index = 1, 6 do
		local angle = math.rad(index * 60 + 18)
		local rootLength = h * 0.36
		local tendril = piece(
			model,
			"Tendril",
			Vector3.new(rootLength, h * 0.11, h * 0.11),
			CFrame.new(0, h * 0.06, 0)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, -h * 0.2)
				* CFrame.Angles(math.rad(66), 0, 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			palette.body,
			{ shape = Enum.PartType.Cylinder }
		)
		tendril.Name = if index == 1 then "ArmLeft" elseif index == 4 then "ArmRight" else "Tendril"
	end

	local eyeRng = Random.new(11)
	for index = 1, 5 do
		local angle = math.rad(index * 26 - 78)
		local size = h * eyeRng:NextNumber(0.045, 0.075)
		piece(
			model,
			"Eye",
			Vector3.new(size, size, size),
			CFrame.new(0, trunkHeight * eyeRng:NextNumber(0.5, 0.82), 0)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, -h * 0.16),
			palette.glow,
			{ shape = Enum.PartType.Ball, material = Enum.Material.Neon }
		)
	end

	local armL = model:FindFirstChild("ArmLeft") :: BasePart
	local armR = model:FindFirstChild("ArmRight") :: BasePart
	local root = buildRoot(model, definition.modelName, h * 0.44, 0, Vector3.zero)
	connectAt(root, trunk, "RootJoint", trunk.Position)
	connectAt(trunk, cap, "Neck", Vector3.new(0, trunkHeight, 0))
	connectAt(trunk, armL, "Left Shoulder", Vector3.new(0, h * 0.12, 0))
	connectAt(trunk, armR, "Right Shoulder", Vector3.new(0, h * 0.12, 0))

	weldLoose(
		model,
		{ [root] = true, [trunk] = true, [cap] = true, [armL] = true, [armR] = true },
		trunk,
		{ Gill = cap, Eye = trunk, Tendril = trunk } :: { [string]: BasePart }
	)
	return root, cap
end

local BUILDERS: { [string]: (Model, Mobs.MobDefinition) -> (BasePart, BasePart) } = {
	sporeling = buildSporeling,
	pebblejaw = buildPebblejaw,
	wisp = buildWisp,
	mycelia = buildMycelia,
}

function MobRig.build(definition: Mobs.MobDefinition): Model?
	local builderId = (definition :: any).build
	local builder = if type(builderId) == "string" then BUILDERS[builderId] else nil
	if not builder then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = definition.modelName
	local root, display = builder(model, definition)
	model.PrimaryPart = root
	model:SetAttribute("BuiltDisplay", display.Name)
	return model
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

local function finishRig(
	model: Model,
	root: BasePart,
	displayPart: BasePart,
	definition: Mobs.MobDefinition
): (BasePart?, Humanoid?, Frame?)
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

function MobRig.rig(
	model: Model,
	definition: Mobs.MobDefinition,
	collisionGroup: string?
): (BasePart?, Humanoid?, Frame?)
	local root: BasePart?
	local displayPart: BasePart?
	local builtDisplay = model:GetAttribute("BuiltDisplay")
	if type(builtDisplay) == "string" then
		local found = model:FindFirstChild("HumanoidRootPart")
		root = if found and found:IsA("BasePart") then found else nil
		displayPart = namedPart(model, builtDisplay)
		if not root or not displayPart then
			return nil, nil, nil
		end
		configurePhysics(model, root, collisionGroup)
		return finishRig(model, root, displayPart, definition)
	end

	clearInheritedBehavior(model)
	if definition.rigProfile == "mushroomFrog" then
		flattenFrog(model)
	elseif definition.rigProfile == "sausageGuardian" then
		ModelUtil.standUpright(model)
	end
	if not ModelUtil.scaleToHeight(model, definition.height) then
		return nil, nil, nil
	end

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
	return finishRig(model, root, displayPart, definition)
end

return MobRig

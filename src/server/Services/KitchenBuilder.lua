--!strict

--[[
	Builds the B5 storybook kitchen and returns the one piece of geometry the
	gameplay service needs: the cooking-pot root and its actual world position.

	Everything else here is presentation. CookingService remains the authority
	for prompts, recipes, distance, spending, rate limits and rewards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Layout = require(Shared.Modules.Config.Layout)

local AssetService = require(script.Parent.AssetService)

local KitchenBuilder = {}

export type BuildResult = {
	model: Model,
	stationRoot: BasePart?,
	stationPosition: Vector3?,
}

type PartOptions = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
	canQuery: boolean?,
	castShadow: boolean?,
}

local WHITE = Color3.fromRGB(253, 250, 246)
local CREAM = Color3.fromRGB(246, 238, 224)
local PEACH = Color3.fromRGB(244, 186, 190)
local PEACH_LIGHT = Color3.fromRGB(250, 218, 207)
local WOOD = Color3.fromRGB(170, 134, 100)
local WOOD_DARK = Color3.fromRGB(128, 94, 72)
local METAL = Color3.fromRGB(190, 196, 198)
local GLASS = Color3.fromRGB(214, 238, 244)
local WARM = Color3.fromRGB(255, 226, 174)

local SIZE = Layout.KITCHEN_SIZE
local FLOOR_HEIGHT = 1
local WALL_HEIGHT = 18
local WALL_THICKNESS = 1.5
local DOOR_WIDTH = 14
local DOOR_HEIGHT = 12

local function makePart(parent: Instance, options: PartOptions): Part
	local item = Instance.new("Part")
	item.Name = options.name
	item.Size = options.size
	item.CFrame = options.cframe
	item.Color = options.color
	item.Material = options.material or Enum.Material.SmoothPlastic
	item.Shape = options.shape or Enum.PartType.Block
	item.Transparency = options.transparency or 0
	item.Anchored = true

	local solid = options.canCollide ~= false
	item.CanCollide = solid
	item.CanQuery = if options.canQuery ~= nil then options.canQuery else solid
	item.CanTouch = false
	item.CastShadow = if options.castShadow ~= nil then options.castShadow else true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function localPart(parent: Instance, frame: CFrame, options: PartOptions): Part
	options.cframe = frame * options.cframe
	return makePart(parent, options)
end

local function groundYAt(position: Vector3): number
	local hit = Workspace:Raycast(position + Vector3.new(0, 100, 0), Vector3.new(0, -240, 0))
	return if hit then hit.Position.Y else Constants.WORLD.PLATFORM_TOP
end

local function yawOf(frame: CFrame): number
	local look = frame.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function largestPart(model: Model): BasePart?
	local root = model.PrimaryPart
	local largest = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if not root or volume > largest then
				root = descendant
				largest = volume
			end
		end
	end
	model.PrimaryPart = root
	return root
end

local function placeAsset(
	parent: Instance,
	key: string,
	frame: CFrame,
	offset: Vector3,
	rotation: number?,
	solid: boolean?
): Model?
	local model = AssetService.clone(key)
	if not model then
		if key == "cookingPot" then
			warn("[KitchenBuilder] cookingPot is unavailable; the room has no cooking station")
		else
			warn(`[KitchenBuilder] asset "{key}" is unavailable; skipping it`)
		end
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			if solid ~= nil then
				descendant.CanCollide = solid
				descendant.CanQuery = solid
			end
			descendant.CanTouch = false
		end
	end

	local at = frame:PointToWorldSpace(offset)
	AssetService.place(model, at, yawOf(frame) + (rotation or 0))
	model.Parent = parent
	return model
end

local function buildSideWall(parent: Instance, frame: CFrame, side: number)
	local x = side * (SIZE.X / 2 - WALL_THICKNESS / 2)
	local wallY = FLOOR_HEIGHT + WALL_HEIGHT / 2

	-- True opening from z=-4..6 and y=5..12; glass is not painted over a wall.
	localPart(parent, frame, {
		name = "SideWallFront",
		size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, 15.5),
		cframe = CFrame.new(x, wallY, -11.75),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	localPart(parent, frame, {
		name = "SideWallBack",
		size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, 13.5),
		cframe = CFrame.new(x, wallY, 12.75),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	localPart(parent, frame, {
		name = "WindowSillWall",
		size = Vector3.new(WALL_THICKNESS, 4, 10),
		cframe = CFrame.new(x, 3, 1),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	localPart(parent, frame, {
		name = "WindowLintelWall",
		size = Vector3.new(WALL_THICKNESS, 7, 10),
		cframe = CFrame.new(x, 15.5, 1),
		color = WHITE,
		material = Enum.Material.Plaster,
	})

	local glassX = side * (SIZE.X / 2 + 0.03)
	localPart(parent, frame, {
		name = "WindowGlass",
		size = Vector3.new(0.22, 7, 10),
		cframe = CFrame.new(glassX, 8.5, 1),
		color = GLASS,
		material = Enum.Material.Glass,
		transparency = 0.28,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})

	local trimX = side * (SIZE.X / 2 + 0.18)
	for _, z in { -4, 6 } do
		localPart(parent, frame, {
			name = "WindowTrim",
			size = Vector3.new(0.4, 8, 0.55),
			cframe = CFrame.new(trimX, 8.5, z),
			color = PEACH,
			canCollide = false,
			canQuery = false,
		})
	end
	for _, y in { 5, 12 } do
		localPart(parent, frame, {
			name = "WindowTrim",
			size = Vector3.new(0.4, 0.55, 10.6),
			cframe = CFrame.new(trimX, y, 1),
			color = PEACH,
			canCollide = false,
			canQuery = false,
		})
	end
	-- A soft eyebrow gives the rectangular opening the storybook silhouette.
	localPart(parent, frame, {
		name = "RoundedWindowTop",
		size = Vector3.new(0.48, 1.1, 11.2),
		cframe = CFrame.new(trimX, 12.35, 1),
		color = PEACH_LIGHT,
		shape = Enum.PartType.Ball,
		canCollide = false,
		canQuery = false,
	})

	local boxX = side * (SIZE.X / 2 + 1.25)
	localPart(parent, frame, {
		name = "FlowerBox",
		size = Vector3.new(2.2, 1.25, 9),
		cframe = CFrame.new(boxX, 4.45, 1),
		color = PEACH,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})
	for index, z in { -2.2, 0.2, 2.6 } do
		localPart(parent, frame, {
			name = `WindowFlower{index}`,
			size = Vector3.new(1.2, 1.2, 1.2),
			cframe = CFrame.new(boxX, 5.45, z),
			color = if index % 2 == 0 then WHITE else PEACH_LIGHT,
			shape = Enum.PartType.Ball,
			canCollide = false,
			canQuery = false,
		})
	end
end

local function buildShell(parent: Instance, frame: CFrame)
	localPart(parent, frame, {
		name = "Floor",
		size = Vector3.new(SIZE.X, FLOOR_HEIGHT, SIZE.Z),
		cframe = CFrame.new(0, FLOOR_HEIGHT / 2, 0),
		color = CREAM,
		material = Enum.Material.WoodPlanks,
	})

	local wallY = FLOOR_HEIGHT + WALL_HEIGHT / 2
	local frontSegment = (SIZE.X - DOOR_WIDTH) / 2
	local frontX = DOOR_WIDTH / 2 + frontSegment / 2
	for _, side in { -1, 1 } do
		localPart(parent, frame, {
			name = "FrontWall",
			size = Vector3.new(frontSegment, WALL_HEIGHT, WALL_THICKNESS),
			cframe = CFrame.new(side * frontX, wallY, -(SIZE.Z / 2 - WALL_THICKNESS / 2)),
			color = WHITE,
			material = Enum.Material.Plaster,
		})
	end
	localPart(parent, frame, {
		name = "DoorLintelWall",
		size = Vector3.new(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, WALL_THICKNESS),
		cframe = CFrame.new(
			0,
			FLOOR_HEIGHT + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2,
			-(SIZE.Z / 2 - WALL_THICKNESS / 2)
		),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	localPart(parent, frame, {
		name = "BackWall",
		size = Vector3.new(SIZE.X, WALL_HEIGHT, WALL_THICKNESS),
		cframe = CFrame.new(0, wallY, SIZE.Z / 2 - WALL_THICKNESS / 2),
		color = WHITE,
		material = Enum.Material.Plaster,
	})

	buildSideWall(parent, frame, -1)
	buildSideWall(parent, frame, 1)

	-- Peach baseboards and rounded corner posts soften the white shell.
	for _, z in { -(SIZE.Z / 2 + 0.05), SIZE.Z / 2 + 0.05 } do
		localPart(parent, frame, {
			name = "BaseTrim",
			size = Vector3.new(SIZE.X + 1, 1.1, 0.45),
			cframe = CFrame.new(0, 1.45, z),
			color = PEACH_LIGHT,
			canCollide = false,
			canQuery = false,
		})
	end
	for _, x in { -(SIZE.X / 2 + 0.05), SIZE.X / 2 + 0.05 } do
		localPart(parent, frame, {
			name = "BaseTrim",
			size = Vector3.new(0.45, 1.1, SIZE.Z + 1),
			cframe = CFrame.new(x, 1.45, 0),
			color = PEACH_LIGHT,
			canCollide = false,
			canQuery = false,
		})
	end
	for _, x in { -SIZE.X / 2, SIZE.X / 2 } do
		for _, z in { -SIZE.Z / 2, SIZE.Z / 2 } do
			localPart(parent, frame, {
				name = "RoundedCorner",
				size = Vector3.new(WALL_HEIGHT, 2.1, 2.1),
				cframe = CFrame.new(x, wallY, z) * CFrame.Angles(0, 0, math.rad(90)),
				color = PEACH,
				shape = Enum.PartType.Cylinder,
				canCollide = false,
				canQuery = false,
			})
		end
	end

	-- Static open doors: they sell the cottage without adding moving state or
	-- narrowing the fourteen-stud entrance.
	local frontZ = -SIZE.Z / 2 - 0.45
	for _, spec in {
		{ hinge = -DOOR_WIDTH / 2, angle = math.rad(-64), extension = 1 },
		{ hinge = DOOR_WIDTH / 2, angle = math.rad(64), extension = -1 },
	} do
		local doorFrame = CFrame.new(spec.hinge, FLOOR_HEIGHT + DOOR_HEIGHT / 2, frontZ)
			* CFrame.Angles(0, spec.angle, 0)
			* CFrame.new(spec.extension * 3.15, 0, 0)
		localPart(parent, frame, {
			name = "OpenDoor",
			size = Vector3.new(6.3, DOOR_HEIGHT - 0.6, 0.65),
			cframe = doorFrame,
			color = PEACH,
			material = Enum.Material.WoodPlanks,
			canCollide = false,
			canQuery = false,
		})
	end
	for _, x in { -DOOR_WIDTH / 2, DOOR_WIDTH / 2 } do
		localPart(parent, frame, {
			name = "DoorFrame",
			size = Vector3.new(1, DOOR_HEIGHT + 1, 1),
			cframe = CFrame.new(x, FLOOR_HEIGHT + DOOR_HEIGHT / 2, frontZ + 0.25),
			color = PEACH_LIGHT,
			canCollide = false,
			canQuery = false,
		})
	end
	localPart(parent, frame, {
		name = "DoorFrameTop",
		size = Vector3.new(DOOR_WIDTH + 1, 1, 1),
		cframe = CFrame.new(0, FLOOR_HEIGHT + DOOR_HEIGHT, frontZ + 0.25),
		color = PEACH_LIGHT,
		canCollide = false,
		canQuery = false,
	})

	-- Open gable ceiling: two shallow roof panels peak at twenty-six studs.
	local roofRun = SIZE.X / 2 + 1.5
	local roofRise = 7
	local roofLength = math.sqrt(roofRun * roofRun + roofRise * roofRise)
	local roofAngle = math.atan2(roofRise, roofRun)
	local roofY = FLOOR_HEIGHT + WALL_HEIGHT + roofRise / 2
	for _, side in { -1, 1 } do
		localPart(parent, frame, {
			name = "PeachRoof",
			size = Vector3.new(roofLength, 1.25, SIZE.Z + 3),
			cframe = CFrame.new(side * roofRun / 2, roofY, 0) * CFrame.Angles(0, 0, -side * roofAngle),
			color = PEACH,
			material = Enum.Material.SmoothPlastic,
		})
	end
	for _, z in { -(SIZE.Z / 2 + 1.55), SIZE.Z / 2 + 1.55 } do
		for index = -4, 4 do
			localPart(parent, frame, {
				name = "ScallopedEave",
				size = Vector3.new(2.4, 2.4, 2.4),
				cframe = CFrame.new(index * 6.2, FLOOR_HEIGHT + WALL_HEIGHT + 0.3, z),
				color = PEACH_LIGHT,
				shape = Enum.PartType.Ball,
				canCollide = false,
				canQuery = false,
			})
		end
	end

	-- Stepped gable fill is tucked beneath the roof and reads rounded at game scale.
	for _, z in { -(SIZE.Z / 2 - 0.6), SIZE.Z / 2 - 0.6 } do
		for index, row in {
			{ width = 38, y = 20.3 },
			{ width = 25, y = 22.5 },
			{ width = 12, y = 24.7 },
		} do
			localPart(parent, frame, {
				name = `GableFill{index}`,
				size = Vector3.new(row.width, 2.25, 1.2),
				cframe = CFrame.new(0, row.y, z),
				color = WHITE,
				material = Enum.Material.Plaster,
			})
		end
	end

	localPart(parent, frame, {
		name = "Chimney",
		size = Vector3.new(4.2, 9, 4.2),
		cframe = CFrame.new(15, 24, 10),
		color = PEACH_LIGHT,
		material = Enum.Material.Brick,
	})
	localPart(parent, frame, {
		name = "ChimneyCap",
		size = Vector3.new(5.2, 1, 5.2),
		cframe = CFrame.new(15, 28.6, 10),
		color = WHITE,
		material = Enum.Material.Brick,
	})
end

local function buildApproach(parent: Instance, frame: CFrame)
	localPart(parent, frame, {
		name = "Porch",
		size = Vector3.new(18, 0.9, 8),
		cframe = CFrame.new(0, 0.45, -(SIZE.Z / 2 + 3.5)),
		color = CREAM,
		material = Enum.Material.Cobblestone,
	})

	local drift = { 0, -0.7, 0.5, -0.35, 0.8, 0 }
	for index, x in drift do
		localPart(parent, frame, {
			name = `KitchenPathStone{index}`,
			size = Vector3.new(0.45, 6.4, 6.4),
			cframe = CFrame.new(x, 0.25, -(SIZE.Z / 2 + 9 + (index - 1) * 5.8))
				* CFrame.Angles(0, 0, math.rad(90)),
			color = if index % 3 == 0 then PEACH_LIGHT else CREAM,
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Cylinder,
			canCollide = false,
			canQuery = false,
		})
	end

	local sign = localPart(parent, frame, {
		name = "KitchenSign",
		size = Vector3.new(10, 4.5, 0.8),
		cframe = CFrame.new(-13, 6.2, -(SIZE.Z / 2 + 4.5)),
		color = PEACH,
		material = Enum.Material.WoodPlanks,
		canCollide = false,
		canQuery = false,
	})
	localPart(parent, frame, {
		name = "KitchenSignPost",
		size = Vector3.new(1, 6, 1),
		cframe = CFrame.new(-13, 3, -(SIZE.Z / 2 + 4.5)),
		color = WOOD,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Label"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "KITCHEN"
	label.TextColor3 = WHITE
	label.TextScaled = true
	label.TextStrokeColor3 = WOOD_DARK
	label.TextStrokeTransparency = 0.55
	label.Parent = surface
end

local function cabinetDetail(parent: Instance, frame: CFrame)
	-- Back counter faces -Z toward the open room.
	for _, x in { -17, -11, -5, 1, 7 } do
		localPart(parent, frame, {
			name = "CabinetSeam",
			size = Vector3.new(0.18, 3.3, 0.18),
			cframe = CFrame.new(x, 3.05, 14.93),
			color = PEACH_LIGHT,
			canCollide = false,
			canQuery = false,
		})
		localPart(parent, frame, {
			name = "CabinetKnob",
			size = Vector3.new(0.42, 0.42, 0.42),
			cframe = CFrame.new(x + 1.7, 3.2, 14.75),
			color = WOOD_DARK,
			shape = Enum.PartType.Ball,
			canCollide = false,
			canQuery = false,
		})
	end

	-- Left counter faces +X.
	for _, z in { -3, 2, 7, 12 } do
		localPart(parent, frame, {
			name = "CabinetSeam",
			size = Vector3.new(0.18, 3.3, 0.18),
			cframe = CFrame.new(-20.43, 3.05, z),
			color = PEACH_LIGHT,
			canCollide = false,
			canQuery = false,
		})
		localPart(parent, frame, {
			name = "CabinetKnob",
			size = Vector3.new(0.42, 0.42, 0.42),
			cframe = CFrame.new(-20.25, 3.2, z + 1.4),
			color = WOOD_DARK,
			shape = Enum.PartType.Ball,
			canCollide = false,
			canQuery = false,
		})
	end
end

local function buildNativeFurniture(parent: Instance, frame: CFrame)
	local furniture = Instance.new("Model")
	furniture.Name = "NativeKitchenFurniture"
	furniture.Parent = parent

	-- Perimeter L only: no island, preserving the broad centre and door-to-pot aisle.
	localPart(furniture, frame, {
		name = "BackLowerCabinets",
		size = Vector3.new(30, 4, 5),
		cframe = CFrame.new(-5, 3, 17.4),
		color = PEACH,
		material = Enum.Material.WoodPlanks,
	})
	localPart(furniture, frame, {
		name = "BackCountertop",
		size = Vector3.new(30.5, 0.6, 5.4),
		cframe = CFrame.new(-5, 5.3, 17.4),
		color = WHITE,
		material = Enum.Material.Marble,
	})
	localPart(furniture, frame, {
		name = "LeftLowerCabinets",
		size = Vector3.new(5, 4, 21),
		cframe = CFrame.new(-23, 3, 4.5),
		color = PEACH,
		material = Enum.Material.WoodPlanks,
	})
	localPart(furniture, frame, {
		name = "LeftCountertop",
		size = Vector3.new(5.4, 0.6, 21.5),
		cframe = CFrame.new(-23, 5.3, 4.5),
		color = WHITE,
		material = Enum.Material.Marble,
	})
	cabinetDetail(furniture, frame)

	for _, cabinet in {
		{ x = -15, width = 10 },
		{ x = 5.5, width = 7 },
	} do
		localPart(furniture, frame, {
			name = "UpperCabinet",
			size = Vector3.new(cabinet.width, 6.5, 2.5),
			cframe = CFrame.new(cabinet.x, 13.1, 19.3),
			color = PEACH_LIGHT,
			material = Enum.Material.WoodPlanks,
		})
	end
	localPart(furniture, frame, {
		name = "RangeHood",
		size = Vector3.new(7, 4, 2.5),
		cframe = CFrame.new(-4, 13, 19.2),
		color = WHITE,
		material = Enum.Material.Metal,
	})

	-- Refrigerator at the back-right end of the run.
	localPart(furniture, frame, {
		name = "Refrigerator",
		size = Vector3.new(7, 14, 5.5),
		cframe = CFrame.new(17.5, 8, 17),
		color = WHITE,
		material = Enum.Material.SmoothPlastic,
	})
	localPart(furniture, frame, {
		name = "FridgeDoorLine",
		size = Vector3.new(6.5, 0.18, 0.2),
		cframe = CFrame.new(17.5, 9.2, 14.18),
		color = PEACH_LIGHT,
		canCollide = false,
		canQuery = false,
	})
	for _, y in { 7.2, 11.2 } do
		localPart(furniture, frame, {
			name = "FridgeHandle",
			size = Vector3.new(0.45, 2.6, 0.35),
			cframe = CFrame.new(15.1, y, 14.02),
			color = PEACH,
			material = Enum.Material.Metal,
			canCollide = false,
			canQuery = false,
		})
	end

	-- Oven and stove are decorative; the pot in front remains the one station.
	localPart(furniture, frame, {
		name = "Oven",
		size = Vector3.new(6, 4.6, 4.8),
		cframe = CFrame.new(-4, 3.3, 16.8),
		color = CREAM,
		material = Enum.Material.Metal,
	})
	localPart(furniture, frame, {
		name = "OvenWindow",
		size = Vector3.new(4.7, 2.4, 0.2),
		cframe = CFrame.new(-4, 3.2, 14.3),
		color = Color3.fromRGB(74, 72, 78),
		material = Enum.Material.Glass,
		canCollide = false,
		canQuery = false,
	})
	for _, x in { -5.5, -2.5 } do
		for _, z in { 15.7, 18 } do
			localPart(furniture, frame, {
				name = "Burner",
				size = Vector3.new(0.18, 1.55, 1.55),
				cframe = CFrame.new(x, 5.7, z) * CFrame.Angles(0, 0, math.rad(90)),
				color = Color3.fromRGB(72, 70, 74),
				material = Enum.Material.Metal,
				shape = Enum.PartType.Cylinder,
				canCollide = false,
				canQuery = false,
			})
		end
	end

	-- Sink and faucet on the left run.
	localPart(furniture, frame, {
		name = "SinkBasin",
		size = Vector3.new(3.7, 0.28, 5.2),
		cframe = CFrame.new(-23, 5.62, 5),
		color = METAL,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
	})
	localPart(furniture, frame, {
		name = "FaucetStem",
		size = Vector3.new(2.7, 0.45, 0.45),
		cframe = CFrame.new(-24.2, 7, 8) * CFrame.Angles(0, 0, math.rad(90)),
		color = METAL,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		canCollide = false,
		canQuery = false,
	})
	localPart(furniture, frame, {
		name = "FaucetSpout",
		size = Vector3.new(2.4, 0.45, 0.45),
		cframe = CFrame.new(-22.9, 8.1, 8) * CFrame.Angles(0, math.rad(90), 0),
		color = METAL,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		canCollide = false,
		canQuery = false,
	})

	-- A light shelf and jars finish the room without filling its centre.
	localPart(furniture, frame, {
		name = "WallShelf",
		size = Vector3.new(0.8, 0.5, 10),
		cframe = CFrame.new(-24.7, 11, -3),
		color = WOOD,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})
	for index, z in { -6, -3, 0 } do
		localPart(furniture, frame, {
			name = `PantryJar{index}`,
			size = Vector3.new(1.2, 1.7, 1.2),
			cframe = CFrame.new(-24.15, 12.1, z),
			color = if index == 2 then PEACH_LIGHT else CREAM,
			material = Enum.Material.Glass,
			transparency = 0.12,
			canCollide = false,
			canQuery = false,
		})
	end
end

local function buildImportedFurniture(parent: Instance, frame: CFrame): boolean
	local model = AssetService.clone("kitchenSet")
	if not model then
		return false
	end

	local extents = model:GetExtentsSize()
	if extents.X <= 0.01 or extents.Y <= 0.01 or extents.Z <= 0.01 then
		model:Destroy()
		return false
	end
	local scale = math.clamp(math.min(31 / math.max(extents.X, extents.Z), 13 / extents.Y), 0.2, 2)
	model:ScaleTo(model:GetScale() * scale)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local at = frame:PointToWorldSpace(Vector3.new(-7, FLOOR_HEIGHT, 12))
	AssetService.place(model, at, yawOf(frame))
	model.Name = "ImportedKitchenFurniture"
	model.Parent = parent

	-- Stable box proxies replace arbitrary mesh collision.
	for _, proxy in {
		{ size = Vector3.new(30, 5, 5), at = Vector3.new(-5, 3.5, 17.4) },
		{ size = Vector3.new(5, 5, 21), at = Vector3.new(-23, 3.5, 4.5) },
	} do
		localPart(parent, frame, {
			name = "KitchenCollision",
			size = proxy.size,
			cframe = CFrame.new(proxy.at),
			color = WHITE,
			transparency = 1,
			canCollide = true,
			canQuery = true,
			castShadow = false,
		})
	end
	return true
end

local function buildStationTable(parent: Instance, frame: CFrame): Vector3
	local tableOffset = Vector3.new(3, FLOOR_HEIGHT, -3)
	local table_ = placeAsset(parent, "lowTable", frame, tableOffset, nil, false)
	local tabletopY: number
	if table_ then
		local extents = table_:GetExtentsSize()
		local proxySize = Vector3.new(
			math.max(extents.X * 0.82, 3),
			math.max(extents.Y, 1),
			math.max(extents.Z * 0.82, 3)
		)
		localPart(parent, frame, {
			name = "LowTableCollision",
			size = proxySize,
			cframe = CFrame.new(tableOffset.X, FLOOR_HEIGHT + proxySize.Y / 2, tableOffset.Z),
			color = WHITE,
			transparency = 1,
			castShadow = false,
		})
		tabletopY = FLOOR_HEIGHT + extents.Y
	else
		-- The table is now structural to the station, so keep cooking usable if
		-- its decorative template is ever missing.
		local fallbackHeight = 2.5
		localPart(parent, frame, {
			name = "LowTableFallback",
			size = Vector3.new(10, fallbackHeight, 8.5),
			cframe = CFrame.new(tableOffset.X, FLOOR_HEIGHT + fallbackHeight / 2, tableOffset.Z),
			color = PEACH_LIGHT,
			material = Enum.Material.WoodPlanks,
		})
		tabletopY = FLOOR_HEIGHT + fallbackHeight
	end

	-- Keep the smaller tea set nearby without crowding the pot's tabletop.
	placeAsset(parent, "kettle", frame, Vector3.new(8, 5.65, 17), nil, false)
	placeAsset(parent, "floorCushion", frame, Vector3.new(tableOffset.X, FLOOR_HEIGHT, -9), math.pi, false)
	placeAsset(parent, "floorCushion", frame, Vector3.new(tableOffset.X, FLOOR_HEIGHT, 3), 0, false)
	return Vector3.new(tableOffset.X, tabletopY, tableOffset.Z)
end

local function buildLighting(parent: Instance, frame: CFrame)
	localPart(parent, frame, {
		name = "KitchenRug",
		size = Vector3.new(13, 0.16, 10),
		cframe = CFrame.new(3, FLOOR_HEIGHT + 0.09, -5),
		color = PEACH_LIGHT,
		material = Enum.Material.Fabric,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})

	for index, x in { -10, 10 } do
		local lamp = localPart(parent, frame, {
			name = `WarmLamp{index}`,
			size = Vector3.new(1.8, 1.8, 1.8),
			cframe = CFrame.new(x, 17.2, -1),
			color = WARM,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
			canCollide = false,
			canQuery = false,
			castShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Color = WARM
		light.Brightness = 1.25
		light.Range = 23
		light.Shadows = false
		light.Parent = lamp
	end
end

local function buildStation(parent: Instance, frame: CFrame, tabletopOffset: Vector3): (BasePart?, Vector3?)
	local pot = placeAsset(parent, "cookingPot", frame, tabletopOffset, nil, true)
	if not pot then
		return nil, nil
	end
	pot.Name = "Cooking Pot"

	local root = largestPart(pot)
	if not root then
		warn("[KitchenBuilder] cookingPot has no parts; the room has no cooking station")
		pot:Destroy()
		return nil, nil
	end
	local boundingFrame = pot:GetBoundingBox()
	return root, boundingFrame.Position
end

function KitchenBuilder.build(parent: Instance, configuredFrame: CFrame): BuildResult
	local groundY = groundYAt(configuredFrame.Position)
	local frame = CFrame.new(configuredFrame.Position.X, groundY, configuredFrame.Position.Z) * configuredFrame.Rotation

	local kitchen = Instance.new("Model")
	kitchen.Name = "Kitchen"

	buildShell(kitchen, frame)
	buildApproach(kitchen, frame)
	if not buildImportedFurniture(kitchen, frame) then
		buildNativeFurniture(kitchen, frame)
	end
	local tabletopOffset = buildStationTable(kitchen, frame)
	buildLighting(kitchen, frame)
	local stationRoot, stationPosition = buildStation(kitchen, frame, tabletopOffset)

	kitchen.Parent = parent
	return {
		model = kitchen,
		stationRoot = stationRoot,
		stationPosition = stationPosition,
	}
end

return KitchenBuilder

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Farming = require(Shared.Modules.Config.Farming)
local Layout = require(Shared.Modules.Config.Layout)
local ModelUtil = require(Shared.Modules.ModelUtil)
local AssetService = require(script.Parent.AssetService)

type AreaDefinition = Areas.AreaDefinition

type PartSpec = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	collide: boolean?,
	query: boolean?,
	shadow: boolean?,
	transparency: number?,
}

local FarmEnvironmentBuilder = {}

local PALETTE = {
	earth = Color3.fromRGB(151, 107, 72),
	soil = Color3.fromRGB(132, 91, 62),
	path = Color3.fromRGB(187, 132, 82),
	pathLight = Color3.fromRGB(211, 165, 105),
	stone = Color3.fromRGB(224, 216, 194),
	stoneShade = Color3.fromRGB(199, 194, 178),
	grass = Color3.fromRGB(132, 184, 105),
	grassLight = Color3.fromRGB(157, 203, 126),
	wood = Color3.fromRGB(177, 128, 78),
	woodDark = Color3.fromRGB(139, 94, 62),
	pink = Color3.fromRGB(244, 174, 190),
	cream = Color3.fromRGB(255, 246, 219),
	vine = Color3.fromRGB(94, 154, 76),
}

local function makePart(parent: Instance, spec: PartSpec): Part
	local item = Instance.new("Part")
	item.Name = spec.name
	item.Size = spec.size
	item.CFrame = spec.cframe
	item.Color = spec.color
	item.Material = spec.material
	item.Shape = spec.shape or Enum.PartType.Block
	item.Anchored = true
	item.CanCollide = spec.collide == true
	item.CanQuery = spec.query == true
	item.CanTouch = false
	item.CastShadow = spec.shadow ~= false
	item.Transparency = spec.transparency or 0
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function localPart(parent: Instance, frame: CFrame, spec: PartSpec): Part
	spec.cframe = frame * spec.cframe
	return makePart(parent, spec)
end

local function setDecorative(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

local function placeAsset(parent: Instance, key: string, footing: CFrame, height: number): Model?
	local model = AssetService.clone(key)
	if not model then
		warn(`[FarmEnvironmentBuilder] asset "{key}" is unavailable`)
		return nil
	end
	ModelUtil.standUpright(model)
	if not ModelUtil.scaleToHeight(model, height) then
		model:Destroy()
		return nil
	end
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(footing.Position) * footing.Rotation * pivot.Rotation)
	local centre, size = ModelUtil.worldBox(model)
	model:PivotTo(model:GetPivot() + Vector3.new(0, footing.Position.Y - (centre.Y - size.Y / 2), 0))
	setDecorative(model)
	model.Name = key
	model.Parent = parent
	return model
end

local function addRoundedTerrace(parent: Model, frame: CFrame)
	local width = Farming.TERRACE_WIDTH
	local length = Farming.TERRACE_LENGTH
	local radius = Farming.TERRACE_CORNER_RADIUS
	local height = Farming.TERRACE_HEIGHT
	local y = -height / 2 - 0.08

	localPart(parent, frame, {
		name = "TerraceEarthLong",
		size = Vector3.new(width - radius * 2, height, length),
		cframe = CFrame.new(0, y, 0),
		color = PALETTE.earth,
		material = Enum.Material.Ground,
		collide = true,
	})
	localPart(parent, frame, {
		name = "TerraceEarthWide",
		size = Vector3.new(width, height - 0.02, length - radius * 2),
		cframe = CFrame.new(0, y - 0.01, 0),
		color = PALETTE.earth,
		material = Enum.Material.Ground,
		collide = true,
	})

	for _, x in { -width / 2 + radius, width / 2 - radius } do
		for _, z in { -length / 2 + radius, length / 2 - radius } do
			localPart(parent, frame, {
				name = "TerraceEarthCorner",
				size = Vector3.new(height - 0.06, radius * 2, radius * 2),
				cframe = CFrame.new(x, y - 0.03, z) * CFrame.Angles(0, 0, math.rad(90)),
				color = PALETTE.earth,
				material = Enum.Material.Ground,
				shape = Enum.PartType.Cylinder,
				collide = true,
			})
		end
	end
end

local function addZEdgeSlope(parent: Model, frame: CFrame, zSign: number, centreX: number, span: number)
	if span <= 0 then
		return
	end
	local depth = Farming.TERRACE_SLOPE_DEPTH
	local rise = Farming.TERRACE_HEIGHT
	local slope = math.sqrt(depth * depth + rise * rise)
	local angle = math.atan2(rise, depth)
	localPart(parent, frame, {
		name = "GrassySlope",
		size = Vector3.new(span, 1.1, slope),
		cframe = CFrame.new(centreX, -rise / 2 - 0.38, zSign * (Farming.TERRACE_LENGTH / 2 + depth / 2))
			* CFrame.Angles(zSign * angle, 0, 0),
		color = PALETTE.grass,
		material = Enum.Material.Grass,
		shadow = false,
	})
end

local function addXEdgeSlope(parent: Model, frame: CFrame, xSign: number, centreZ: number, span: number)
	if span <= 0 then
		return
	end
	local depth = Farming.TERRACE_SLOPE_DEPTH
	local rise = Farming.TERRACE_HEIGHT
	local slope = math.sqrt(depth * depth + rise * rise)
	local angle = math.atan2(rise, depth)
	localPart(parent, frame, {
		name = "GrassySlope",
		size = Vector3.new(slope, 1.1, span),
		cframe = CFrame.new(xSign * (Farming.TERRACE_WIDTH / 2 + depth / 2), -rise / 2 - 0.38, centreZ)
			* CFrame.Angles(0, 0, -xSign * angle),
		color = PALETTE.grass,
		material = Enum.Material.Grass,
		shadow = false,
	})
end

local function addGrassyEdges(parent: Model, frame: CFrame)
	local width = Farming.TERRACE_WIDTH
	local length = Farming.TERRACE_LENGTH
	local corner = Farming.TERRACE_CORNER_RADIUS
	local frontSpan = width - corner * 2
	local mainGap = Farming.MAIN_RAMP_WIDTH + 8
	local frontPiece = (frontSpan - mainGap) / 2
	addZEdgeSlope(parent, frame, -1, -(mainGap + frontPiece) / 2, frontPiece)
	addZEdgeSlope(parent, frame, -1, (mainGap + frontPiece) / 2, frontPiece)
	addZEdgeSlope(parent, frame, 1, 0, frontSpan)

	local sideSpan = length - corner * 2
	local sideGap = Farming.SIDE_RAMP_WIDTH + 8
	local before = Farming.SIDE_RAMP_LOCAL_Z - sideGap / 2 - (-length / 2 + corner)
	local after = length / 2 - corner - (Farming.SIDE_RAMP_LOCAL_Z + sideGap / 2)
	addXEdgeSlope(parent, frame, -1, -length / 2 + corner + before / 2, before)
	addXEdgeSlope(parent, frame, -1, Farming.SIDE_RAMP_LOCAL_Z + sideGap / 2 + after / 2, after)
	addXEdgeSlope(parent, frame, 1, 0, sideSpan)

	for _, x in { -width / 2 + corner, width / 2 - corner } do
		for _, z in { -length / 2 + corner, length / 2 - corner } do
			localPart(parent, frame, {
				name = "GrassyCorner",
				size = Vector3.new(corner * 2 + 11, 2.4, corner * 2 + 11),
				cframe = CFrame.new(x, -Farming.TERRACE_HEIGHT + 0.25, z),
				color = PALETTE.grassLight,
				material = Enum.Material.Grass,
				shape = Enum.PartType.Ball,
				shadow = false,
			})
		end
	end
end

local function stoneAllowed(x: number, z: number): boolean
	local front = z < -Farming.TERRACE_LENGTH / 2 + 1
	if front and math.abs(x) < Farming.MAIN_RAMP_WIDTH / 2 + 5 then
		return false
	end
	local side = x < -Farming.TERRACE_WIDTH / 2 + 1
	if side and math.abs(z - Farming.SIDE_RAMP_LOCAL_Z) < Farming.SIDE_RAMP_WIDTH / 2 + 5 then
		return false
	end
	return true
end

local function addStone(parent: Model, frame: CFrame, x: number, z: number, yaw: number, index: number)
	if not stoneAllowed(x, z) then
		return
	end
	local shade = if index % 3 == 0 then PALETTE.stoneShade else PALETTE.stone
	localPart(parent, frame, {
		name = "RetainingFieldstone",
		size = Vector3.new(7.2, 2.8, 4.2),
		cframe = CFrame.new(x, -Farming.TERRACE_HEIGHT * 0.52, z) * CFrame.Angles(0, yaw, 0),
		color = shade,
		material = Enum.Material.Cobblestone,
		shape = Enum.PartType.Ball,
		shadow = false,
	})
end

local function addRetainingStones(parent: Model, frame: CFrame)
	local halfX = Farming.TERRACE_WIDTH / 2 + 0.8
	local halfZ = Farming.TERRACE_LENGTH / 2 + 0.8
	local corner = Farming.TERRACE_CORNER_RADIUS
	local spacing = Farming.RETAINING_STONE_SPACING
	local index = 0

	for x = -halfX + corner, halfX - corner, spacing do
		index += 1
		addStone(parent, frame, x, -halfZ, 0, index)
		index += 1
		addStone(parent, frame, x, halfZ, 0, index)
	end
	for z = -halfZ + corner, halfZ - corner, spacing do
		index += 1
		addStone(parent, frame, -halfX, z, math.rad(90), index)
		index += 1
		addStone(parent, frame, halfX, z, math.rad(90), index)
	end
	for _, xSign in { -1, 1 } do
		for _, zSign in { -1, 1 } do
			for step = 0, 2 do
				local angle = math.rad(step * 45)
				local x = xSign * (halfX - corner + math.cos(angle) * corner)
				local z = zSign * (halfZ - corner + math.sin(angle) * corner)
				index += 1
				addStone(parent, frame, x, z, -angle * xSign * zSign, index)
			end
		end
	end
end

local function addMainRamp(parent: Model, frame: CFrame)
	local rise = Farming.TERRACE_HEIGHT
	local length = Farming.MAIN_RAMP_LENGTH
	local slope = math.sqrt(length * length + rise * rise)
	local angle = math.atan2(rise, length)
	local z = -Farming.TERRACE_LENGTH / 2 - length / 2
	local rampFrame = CFrame.new(0, -rise / 2 - 0.39, z) * CFrame.Angles(-angle, 0, 0)
	localPart(parent, frame, {
		name = "MainRamp",
		size = Vector3.new(Farming.MAIN_RAMP_WIDTH, 0.8, slope + 1),
		cframe = rampFrame,
		color = PALETTE.path,
		material = Enum.Material.Ground,
		collide = true,
	})
	for _, side in { -1, 1 } do
		localPart(parent, frame, {
			name = "MainRampGrassyShoulder",
			size = Vector3.new(4, 1, slope + 1.5),
			cframe = CFrame.new(side * (Farming.MAIN_RAMP_WIDTH / 2 + 2), -rise / 2 - 0.42, z)
				* CFrame.Angles(-angle, 0, 0),
			color = PALETTE.grassLight,
			material = Enum.Material.Grass,
			shadow = false,
		})
	end
	localPart(parent, frame, {
		name = "BottomEntranceApron",
		size = Vector3.new(Farming.BOTTOM_APRON_SIZE.X, Farming.PATH_THICKNESS, Farming.BOTTOM_APRON_SIZE.Y),
		cframe = CFrame.new(
			0,
			-rise + Farming.PATH_THICKNESS / 2 + 0.03,
			-Farming.TERRACE_LENGTH / 2 - length - Farming.BOTTOM_APRON_SIZE.Y / 2
		),
		color = PALETTE.pathLight,
		material = Enum.Material.Ground,
		shadow = false,
	})
end

local function addSideRamp(parent: Model, frame: CFrame)
	local side = Farming.SIDE_RAMP_SIDE
	local rise = Farming.TERRACE_HEIGHT
	local length = Farming.SIDE_RAMP_LENGTH
	local slope = math.sqrt(length * length + rise * rise)
	local angle = math.atan2(rise, length)
	local x = side * (Farming.TERRACE_WIDTH / 2 + length / 2)
	local rampFrame = CFrame.new(x, -rise / 2 - 0.39, Farming.SIDE_RAMP_LOCAL_Z) * CFrame.Angles(0, 0, -side * angle)
	localPart(parent, frame, {
		name = "SideRamp",
		size = Vector3.new(slope + 1, 0.8, Farming.SIDE_RAMP_WIDTH),
		cframe = rampFrame,
		color = PALETTE.path,
		material = Enum.Material.Ground,
		collide = true,
	})
	for _, zSide in { -1, 1 } do
		localPart(parent, frame, {
			name = "SideRampGrassyShoulder",
			size = Vector3.new(slope + 1.5, 1, 3.4),
			cframe = CFrame.new(x, -rise / 2 - 0.42, Farming.SIDE_RAMP_LOCAL_Z + zSide * 6.2)
				* CFrame.Angles(0, 0, -side * angle),
			color = PALETTE.grassLight,
			material = Enum.Material.Grass,
			shadow = false,
		})
	end
	localPart(parent, frame, {
		name = "SideEntranceApron",
		size = Vector3.new(Farming.TERRACE_MARGIN.X + 3, Farming.PATH_THICKNESS, Farming.SIDE_RAMP_WIDTH),
		cframe = CFrame.new(
			side * (Farming.TERRACE_WIDTH / 2 - Farming.TERRACE_MARGIN.X / 2),
			Farming.PATH_THICKNESS / 2 + 0.03,
			Farming.SIDE_RAMP_LOCAL_Z
		),
		color = PALETTE.pathLight,
		material = Enum.Material.Ground,
		shadow = false,
	})
end

local function addPath(parent: Model, frame: CFrame, name: string, size: Vector3, x: number, z: number, lift: number)
	localPart(parent, frame, {
		name = name,
		size = size,
		cframe = CFrame.new(x, Farming.PATH_THICKNESS / 2 + lift, z),
		color = if name == "VisualAxis" then PALETTE.pathLight else PALETTE.path,
		material = Enum.Material.Ground,
		shadow = false,
	})
end

local function addPaths(parent: Model, frame: CFrame)
	for column = 1, Farming.COLUMNS - 1 do
		local x = (column - Farming.COLUMNS / 2) * Farming.PLOT_STRIDE
		addPath(
			parent,
			frame,
			"FarmAisle",
			Vector3.new(Farming.PATH_WIDTH, Farming.PATH_THICKNESS, Farming.FIELD_LENGTH),
			x,
			0,
			0.04
		)
	end
	for row = 1, Farming.ROWS - 1 do
		local z = (row - Farming.ROWS / 2) * Farming.PLOT_STRIDE
		addPath(
			parent,
			frame,
			"FarmAisle",
			Vector3.new(Farming.FIELD_WIDTH, Farming.PATH_THICKNESS, Farming.PATH_WIDTH),
			0,
			z,
			0.05
		)
	end

	local frontPlotEdge = -Farming.FIELD_LENGTH / 2
	local terraceEdge = -Farming.TERRACE_LENGTH / 2
	local stemLength = frontPlotEdge - terraceEdge
	addPath(
		parent,
		frame,
		"EntranceApron",
		Vector3.new(Farming.TOP_APRON_SIZE.X, Farming.PATH_THICKNESS, Farming.TOP_APRON_SIZE.Y),
		0,
		terraceEdge + Farming.TOP_APRON_SIZE.Y / 2,
		0.06
	)
	addPath(
		parent,
		frame,
		"VisualAxis",
		Vector3.new(Farming.VISUAL_AXIS_WIDTH, Farming.PATH_THICKNESS, stemLength),
		0,
		(terraceEdge + frontPlotEdge) / 2,
		0.08
	)
	addPath(
		parent,
		frame,
		"VisualAxisFork",
		Vector3.new(Farming.PLOT_STRIDE + Farming.PATH_WIDTH, Farming.PATH_THICKNESS, Farming.PATH_WIDTH),
		0,
		frontPlotEdge - Farming.PATH_WIDTH / 2,
		0.09
	)

	local stones = {
		Vector2.new(0, terraceEdge + 4),
		Vector2.new(0, terraceEdge + 9),
		Vector2.new(-11, frontPlotEdge - 3),
		Vector2.new(11, frontPlotEdge - 3),
		Vector2.new(-Farming.PLOT_STRIDE / 2, -Farming.PLOT_STRIDE * 2),
		Vector2.new(Farming.PLOT_STRIDE / 2, -Farming.PLOT_STRIDE * 2),
		Vector2.new(-Farming.PLOT_STRIDE / 2, -Farming.PLOT_STRIDE),
		Vector2.new(Farming.PLOT_STRIDE / 2, -Farming.PLOT_STRIDE),
		Vector2.new(-Farming.PLOT_STRIDE / 2, 0),
		Vector2.new(Farming.PLOT_STRIDE / 2, 0),
	}
	for index, at in stones do
		localPart(parent, frame, {
			name = "SteppingStone",
			size = Vector3.new(Farming.STEPPING_STONE_SIZE.X, 0.34, Farming.STEPPING_STONE_SIZE.Y),
			cframe = CFrame.new(at.X, 0.2, at.Y) * CFrame.Angles(0, math.rad(index * 19 % 32 - 16), 0),
			color = if index % 2 == 0 then PALETTE.stone else PALETTE.stoneShade,
			material = Enum.Material.Cobblestone,
			shape = Enum.PartType.Ball,
			shadow = false,
		})
	end
end

local function addFenceSegment(parent: Model, frame: CFrame, from: Vector2, to: Vector2)
	local span = to - from
	local length = span.Magnitude
	if length < 2 then
		return
	end
	local direction = span.Unit
	local centre = (from + to) / 2
	local yaw = math.atan2(direction.X, direction.Y)
	for _, y in { 0.9, 1.8 } do
		localPart(parent, frame, {
			name = "FarmFenceRail",
			size = Vector3.new(0.5, 0.5, length),
			cframe = CFrame.new(centre.X, y, centre.Y) * CFrame.Angles(0, yaw, 0),
			color = PALETTE.wood,
			material = Enum.Material.WoodPlanks,
			shadow = false,
		})
	end
	local posts = math.max(1, math.ceil(length / 20))
	for index = 0, posts do
		local at = from + direction * (length * index / posts)
		localPart(parent, frame, {
			name = "FarmFencePost",
			size = Vector3.new(0.8, 2.8, 0.8),
			cframe = CFrame.new(at.X, 1.4, at.Y),
			color = PALETTE.woodDark,
			material = Enum.Material.Wood,
			shadow = false,
		})
		localPart(parent, frame, {
			name = "FarmFenceCap",
			size = Vector3.new(1.2, 1.2, 1.2),
			cframe = CFrame.new(at.X, 3, at.Y),
			color = PALETTE.pink,
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Ball,
			shadow = false,
		})
	end
end

local function addFence(parent: Model, frame: CFrame)
	local halfX = Farming.FIELD_WIDTH / 2 + Farming.FIELD_MARGIN
	local halfZ = Farming.FIELD_LENGTH / 2 + Farming.FIELD_MARGIN
	local mainHalf = Farming.MAIN_RAMP_WIDTH / 2
	local sideHalf = Farming.SIDE_RAMP_WIDTH / 2
	addFenceSegment(parent, frame, Vector2.new(-halfX, -halfZ), Vector2.new(-mainHalf, -halfZ))
	addFenceSegment(parent, frame, Vector2.new(mainHalf, -halfZ), Vector2.new(halfX, -halfZ))
	addFenceSegment(parent, frame, Vector2.new(-halfX, halfZ), Vector2.new(halfX, halfZ))
	addFenceSegment(parent, frame, Vector2.new(halfX, -halfZ), Vector2.new(halfX, halfZ))
	addFenceSegment(
		parent,
		frame,
		Vector2.new(-halfX, -halfZ),
		Vector2.new(-halfX, Farming.SIDE_RAMP_LOCAL_Z - sideHalf)
	)
	addFenceSegment(
		parent,
		frame,
		Vector2.new(-halfX, Farming.SIDE_RAMP_LOCAL_Z + sideHalf),
		Vector2.new(-halfX, halfZ)
	)
end

local function addFlower(parent: Model, frame: CFrame, x: number, y: number, z: number, index: number)
	localPart(parent, frame, {
		name = "ArchFlower",
		size = Vector3.new(0.9, 0.9, 0.9),
		cframe = CFrame.new(x, y, z),
		color = if index % 2 == 0 then PALETTE.cream else PALETTE.pink,
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		shadow = false,
	})
end

local function addArch(parent: Model, frame: CFrame, area: AreaDefinition)
	local arch = Instance.new("Model")
	arch.Name = "CommunityFarmArch"
	arch.Parent = parent
	local entrance = Layout.farmEntranceCFrame(area)
	local localEntrance = frame:ToObjectSpace(entrance)
	local postX = Farming.ARCH_OPENING_WIDTH / 2 + 0.9

	for _, side in { -1, 1 } do
		localPart(arch, frame, {
			name = "ArchPost",
			size = Vector3.new(1.6, Farming.ARCH_TOTAL_HEIGHT, 1.6),
			cframe = localEntrance * CFrame.new(side * postX, Farming.ARCH_TOTAL_HEIGHT / 2, 0),
			color = PALETTE.wood,
			material = Enum.Material.WoodPlanks,
			collide = true,
		})
		localPart(arch, frame, {
			name = "ArchFinial",
			size = Vector3.new(2.2, 2.2, 2.2),
			cframe = localEntrance * CFrame.new(side * postX, Farming.ARCH_TOTAL_HEIGHT + 0.4, 0),
			color = PALETTE.pink,
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Ball,
			shadow = false,
		})
		for vine = 1, 4 do
			local y = 2.5 + vine * 2.3
			localPart(arch, frame, {
				name = "ArchVine",
				size = Vector3.new(0.55, 2.8, 0.55),
				cframe = localEntrance
					* CFrame.new(side * (postX - 0.65), y, -0.72)
					* CFrame.Angles(0, 0, side * math.rad(18)),
				color = PALETTE.vine,
				material = Enum.Material.Grass,
				shadow = false,
			})
			addFlower(arch, frame, side * (postX - 0.7), y + 0.8, localEntrance.Position.Z - 0.8, vine)
		end
	end

	localPart(arch, frame, {
		name = "ArchLintel",
		size = Vector3.new(Farming.ARCH_OPENING_WIDTH + 5, 1.8, 2),
		cframe = localEntrance * CFrame.new(0, Farming.ARCH_TOTAL_HEIGHT, 0),
		color = PALETTE.pink,
		material = Enum.Material.SmoothPlastic,
		shadow = false,
	})
	local signY = Farming.ARCH_CLEAR_HEIGHT + 1.35
	for _, side in { -1, 1 } do
		localPart(arch, frame, {
			name = "SignHanger",
			size = Vector3.new(0.22, 2, 0.22),
			cframe = localEntrance * CFrame.new(side * 5.6, signY + 1.8, 0),
			color = PALETTE.woodDark,
			material = Enum.Material.Wood,
			shadow = false,
		})
	end
	local sign = localPart(arch, frame, {
		name = "CommunityFarmSign",
		size = Vector3.new(16.5, 2.6, 0.8),
		cframe = localEntrance * CFrame.new(0, signY, 0),
		color = PALETTE.woodDark,
		material = Enum.Material.WoodPlanks,
		shadow = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Name = "FarmTitle"
	gui.Adornee = sign
	gui.Size = UDim2.fromOffset(380, 72)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 420
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "COMMUNITY FARM"
	label.TextColor3 = PALETTE.cream
	label.TextScaled = true
	label.TextStrokeColor3 = PALETTE.woodDark
	label.TextStrokeTransparency = 0.12
	label.Parent = gui

	local archWorld = frame * localEntrance
	placeAsset(arch, "wateringCan", archWorld * CFrame.new(0, Farming.ARCH_TOTAL_HEIGHT - 1.8, -1.5), 2.2)
	for _, side in { -1, 1 } do
		placeAsset(arch, "lanternTall", archWorld * CFrame.new(side * 13.5, 0, 3), 6.5)
		placeAsset(arch, if side < 0 then "flowerBed1" else "flowerBed3", archWorld * CFrame.new(side * 12, 0, -2), 2.2)
	end
end

local function addRampAccents(parent: Model, frame: CFrame)
	local mainBottomZ = -Farming.TERRACE_LENGTH / 2 - Farming.MAIN_RAMP_LENGTH
	for index, side in { -1, 1 } do
		local x = side * (Farming.MAIN_RAMP_WIDTH / 2 + 4.5)
		local z = mainBottomZ + 4
		localPart(parent, frame, {
			name = "RampShoulderStone",
			size = Vector3.new(3.4, 1.8, 3),
			cframe = CFrame.new(x, -Farming.TERRACE_HEIGHT + 0.5, z),
			color = PALETTE.stone,
			material = Enum.Material.Cobblestone,
			shape = Enum.PartType.Ball,
			shadow = false,
		})
		addFlower(parent, frame, x + side * 1.5, -Farming.TERRACE_HEIGHT + 1.1, z + 3, index)
	end
	for index, zSide in { -1, 1 } do
		local x = -Farming.TERRACE_WIDTH / 2 - Farming.SIDE_RAMP_LENGTH + 4
		local z = Farming.SIDE_RAMP_LOCAL_Z + zSide * 7
		addFlower(parent, frame, x, -Farming.TERRACE_HEIGHT + 1.1, z, index + 2)
	end
end

function FarmEnvironmentBuilder.build(area: AreaDefinition, parent: Instance): Model
	local existing = parent:FindFirstChild("FarmEnvironment")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "FarmEnvironment"
	model.Parent = parent
	local frame = Layout.farmCFrame(area)
	model:SetAttribute("AnchorX", frame.Position.X)
	model:SetAttribute("AnchorZ", frame.Position.Z)

	addRoundedTerrace(model, frame)
	addGrassyEdges(model, frame)
	addRetainingStones(model, frame)
	addMainRamp(model, frame)
	addSideRamp(model, frame)
	addPaths(model, frame)
	addFence(model, frame)
	addArch(model, frame, area)
	addRampAccents(model, frame)

	local parts, collidable = 0, 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
			if descendant.CanCollide then
				collidable += 1
			end
		end
	end
	model:SetAttribute("GeneratedPartCount", parts)
	model:SetAttribute("CollidablePartCount", collidable)
	print(`[FarmEnvironmentBuilder] built {parts} part(s), {collidable} collidable`)
	return model
end

return FarmEnvironmentBuilder

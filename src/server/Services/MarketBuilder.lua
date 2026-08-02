--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Market = require(Shared.Modules.Config.Market)
local Streets = require(Shared.Modules.Config.Streets)
local MarketBuilder = {}

export type BuildResult = {
	model: Model,
	anchorPosition: Vector3,
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

local WHITE = Color3.fromRGB(255, 251, 246)
local PAPER = Color3.fromRGB(250, 243, 234)
local PEACH = Color3.fromRGB(246, 178, 158)
local PEACH_LIGHT = Color3.fromRGB(252, 214, 197)
local PEACH_DARK = Color3.fromRGB(220, 132, 118)
local WOOD = Color3.fromRGB(153, 108, 76)
local WOOD_DARK = Color3.fromRGB(100, 69, 55)
local WARM = Color3.fromRGB(255, 225, 177)
local CANVAS = Color3.fromRGB(238, 226, 210)
local SURFACE_Y = Streets.SURFACE_Y
local HALF = Market.HALF.X
local TERRACE_WIDTH = Market.TERRACE
local ARCADE_INSET = 7
local POST_SPACING = 12.5
local POST_HEIGHT = 11
local POST_THICK = 1.5
local BEAM_HEIGHT = 1.3
local ROOF_DEPTH = 9
local ROOF_PITCH = 11
local ENTRANCE_GAP = 20
local ARCH_HEIGHT = 15

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
	item.CanCollide = options.canCollide ~= false
	item.CanQuery = if options.canQuery ~= nil then options.canQuery else item.CanCollide
	item.CanTouch = false
	item.CastShadow = if options.castShadow ~= nil then options.castShadow else true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function at(origin: Vector3, x: number, y: number, z: number): CFrame
	return CFrame.new(origin + Vector3.new(Market.CENTRE.X + x, SURFACE_Y + y, Market.CENTRE.Y + z))
end

local function buildTerrace(parent: Instance, origin: Vector3)
	local rise = (SURFACE_Y - Constants.WORLD.TERRAIN_TOP) / 2

	makePart(parent, {
		name = "TerraceStep",
		size = Vector3.new((HALF + TERRACE_WIDTH) * 2, 4, (HALF + TERRACE_WIDTH) * 2),
		cframe = at(origin, 0, -rise - 2, 0),
		color = PAPER,
		material = Enum.Material.Slate,
	})

	makePart(parent, {
		name = "TerraceLip",
		size = Vector3.new((HALF + TERRACE_WIDTH) * 2 + 0.6, 0.4, (HALF + TERRACE_WIDTH) * 2 + 0.6),
		cframe = at(origin, 0, -rise - 0.2, 0),
		color = PEACH_LIGHT,
		material = Enum.Material.Slate,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})
end

local function buildPlaza(parent: Instance, origin: Vector3)
	local band = 5
	local runs = {
		{ x = 0, z = HALF - band / 2, sx = HALF * 2, sz = band },
		{ x = 0, z = -HALF + band / 2, sx = HALF * 2, sz = band },
		{ x = -HALF + band / 2, z = 0, sx = band, sz = HALF * 2 },
		{ x = HALF - band / 2, z = 0, sx = band, sz = HALF * 2 },
	}

	for index, run in runs do
		makePart(parent, {
			name = `PlazaBand_{index}`,
			size = Vector3.new(run.sx, 0.3, run.sz),
			cframe = at(origin, run.x, 0.06, run.z),
			color = PEACH_LIGHT,
			material = Enum.Material.Slate,
			canCollide = false,
			canQuery = false,
			castShadow = false,
		})
	end

	makePart(parent, {
		name = "PlazaMedallion",
		size = Vector3.new(26, 0.3, 26),
		cframe = at(origin, 0, 0.06, -6) * CFrame.Angles(0, math.rad(45), 0),
		color = PAPER,
		material = Enum.Material.Slate,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})

	makePart(parent, {
		name = "PlazaMedallionInner",
		size = Vector3.new(14, 0.3, 14),
		cframe = at(origin, 0, 0.08, -6) * CFrame.Angles(0, math.rad(45), 0),
		color = PEACH,
		material = Enum.Material.Slate,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})
end

local function buildPost(parent: Instance, origin: Vector3, x: number, z: number, index: number)
	makePart(parent, {
		name = `ArcadePost_{index}`,
		size = Vector3.new(POST_THICK, POST_HEIGHT, POST_THICK),
		cframe = at(origin, x, POST_HEIGHT / 2, z),
		color = WOOD,
		material = Enum.Material.Wood,
	})

	makePart(parent, {
		name = `ArcadePostFoot_{index}`,
		size = Vector3.new(POST_THICK + 0.9, 0.7, POST_THICK + 0.9),
		cframe = at(origin, x, 0.35, z),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
		canQuery = false,
	})
end

local function buildArcadeRun(
	parent: Instance,
	origin: Vector3,
	config: { along: string, fixed: number, from: number, to: number, inward: number, tag: string }
)
	local span = config.to - config.from
	local length = math.abs(span)
	if length < POST_SPACING then
		return
	end

	local alongX = config.along == "x"
	local count = math.max(2, math.round(length / POST_SPACING) + 1)

	for index = 1, count do
		local slide = config.from + span * ((index - 1) / (count - 1))
		local x = if alongX then slide else config.fixed
		local z = if alongX then config.fixed else slide
		buildPost(parent, origin, x, z, index)
	end

	local midSlide = (config.from + config.to) / 2
	local beamX = if alongX then midSlide else config.fixed
	local beamZ = if alongX then config.fixed else midSlide
	local beamSize = if alongX
		then Vector3.new(length, BEAM_HEIGHT, POST_THICK + 0.6)
		else Vector3.new(POST_THICK + 0.6, BEAM_HEIGHT, length)

	makePart(parent, {
		name = `ArcadeBeam_{config.tag}`,
		size = beamSize,
		cframe = at(origin, beamX, POST_HEIGHT + BEAM_HEIGHT / 2, beamZ),
		color = WOOD,
		material = Enum.Material.Wood,
		canQuery = false,
	})

	local pitch = math.rad(ROOF_PITCH)
	local drop = math.sin(pitch) * ROOF_DEPTH / 2
	local roofX = beamX + (if alongX then 0 else config.inward * ROOF_DEPTH / 2)
	local roofZ = beamZ + (if alongX then config.inward * ROOF_DEPTH / 2 else 0)
	local roofSize = if alongX
		then Vector3.new(length + 1.5, 0.55, ROOF_DEPTH)
		else Vector3.new(ROOF_DEPTH, 0.55, length + 1.5)
	local tilt = if alongX
		then CFrame.Angles(pitch * config.inward, 0, 0)
		else CFrame.Angles(0, 0, -pitch * config.inward)

	makePart(parent, {
		name = `ArcadeRoof_{config.tag}`,
		size = roofSize,
		cframe = at(origin, roofX, POST_HEIGHT + BEAM_HEIGHT + 0.7 - drop, roofZ) * tilt,
		color = PEACH,
		material = Enum.Material.Slate,
		canCollide = false,
		canQuery = false,
	})

	local fasciaX = beamX + (if alongX then 0 else config.inward * ROOF_DEPTH)
	local fasciaZ = beamZ + (if alongX then config.inward * ROOF_DEPTH else 0)
	local fasciaSize = if alongX then Vector3.new(length + 1.5, 0.8, 0.5) else Vector3.new(0.5, 0.8, length + 1.5)

	makePart(parent, {
		name = `ArcadeFascia_{config.tag}`,
		size = fasciaSize,
		cframe = at(origin, fasciaX, POST_HEIGHT + BEAM_HEIGHT + 0.4 - drop * 2, fasciaZ),
		color = WHITE,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		canQuery = false,
	})
end

local function buildArcade(parent: Instance, origin: Vector3)
	local edge = HALF - ARCADE_INSET

	buildArcadeRun(parent, origin, {
		along = "x",
		fixed = edge,
		from = -edge,
		to = -ENTRANCE_GAP / 2,
		inward = -1,
		tag = "NorthWest",
	})

	buildArcadeRun(parent, origin, {
		along = "x",
		fixed = edge,
		from = ENTRANCE_GAP / 2,
		to = edge,
		inward = -1,
		tag = "NorthEast",
	})
end

local STALL_STANDOFF = 12
local NOREN_WIDTH = 9
local NOREN_POST = 6.5

local function buildStallFront(parent: Instance, origin: Vector3, index: number, x: number, z: number, facing: number)
	local frame = at(origin, x, 0, z) * CFrame.Angles(0, math.rad(facing), 0) * CFrame.new(0, 0, -STALL_STANDOFF)

	for _, side in { -1, 1 } do
		makePart(parent, {
			name = `NorenPost_{index}`,
			size = Vector3.new(0.42, NOREN_POST, 0.42),
			cframe = frame * CFrame.new(side * NOREN_WIDTH / 2, NOREN_POST / 2, 0),
			color = WOOD,
			material = Enum.Material.Wood,
		})
	end

	makePart(parent, {
		name = `NorenRail_{index}`,
		size = Vector3.new(NOREN_WIDTH + 1, 0.36, 0.36),
		cframe = frame * CFrame.new(0, NOREN_POST, 0),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})

	makePart(parent, {
		name = `NorenCloth_{index}`,
		size = Vector3.new(NOREN_WIDTH, 2.1, 0.2),
		cframe = frame * CFrame.new(0, NOREN_POST - 1.05, 0),
		color = if index % 2 == 0 then PEACH_DARK else CANVAS,
		material = Enum.Material.Fabric,
		canCollide = false,
		canQuery = false,
	})

	makePart(parent, {
		name = `StallCrate_{index}`,
		size = Vector3.new(2.8, 2.2, 2.8),
		cframe = frame * CFrame.new(NOREN_WIDTH / 2 + 1.8, 1.1, 0.6) * CFrame.Angles(0, math.rad(16), 0),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
	})
end

local function buildStallDressing(parent: Instance, origin: Vector3)
	local index = 0
	for _, row in Market.stalls do
		if not row.faceEntrance or row.name ~= nil then
			continue
		end
		index += 1
		buildStallFront(parent, origin, index, row.x, row.z, Market.yawFor(row) - Market.STALL_FRONT_OFFSET)
	end
end

local function buildEntranceArch(parent: Instance, origin: Vector3)
	local z = HALF - ARCADE_INSET
	local halfGap = ENTRANCE_GAP / 2

	for _, side in { -1, 1 } do
		makePart(parent, {
			name = "ArchPillar",
			size = Vector3.new(2.6, ARCH_HEIGHT, 2.6),
			cframe = at(origin, side * halfGap, ARCH_HEIGHT / 2, z),
			color = PEACH,
			material = Enum.Material.Wood,
		})

		makePart(parent, {
			name = "ArchPillarFoot",
			size = Vector3.new(3.6, 0.9, 3.6),
			cframe = at(origin, side * halfGap, 0.45, z),
			color = PEACH_DARK,
			material = Enum.Material.Wood,
			canQuery = false,
		})
	end

	makePart(parent, {
		name = "ArchBeam",
		size = Vector3.new(ENTRANCE_GAP + 6.5, 2.2, 2.2),
		cframe = at(origin, 0, ARCH_HEIGHT + 1.1, z),
		color = PEACH,
		material = Enum.Material.Wood,
		canQuery = false,
	})

	makePart(parent, {
		name = "ArchCrown",
		size = Vector3.new(ENTRANCE_GAP + 9, 0.7, 3.4),
		cframe = at(origin, 0, ARCH_HEIGHT + 2.5, z),
		color = WHITE,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		canQuery = false,
	})
end

local function buildSign(parent: Instance, origin: Vector3)
	local sign = makePart(parent, {
		name = "MarketSign",
		size = Vector3.new(ENTRANCE_GAP + 3, 4.2, 0.6),
		cframe = at(origin, 0, ARCH_HEIGHT + 1.1, HALF - ARCADE_INSET + 1.3),
		color = PAPER,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignFace"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0.2
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "Market Square"
	label.TextColor3 = Color3.fromRGB(89, 60, 55)
	label.TextScaled = true
	label.TextStrokeColor3 = WHITE
	label.TextStrokeTransparency = 0.55
	label.Parent = surface
end

local function buildApproach(parent: Instance, origin: Vector3)
	for index = 1, 7 do
		makePart(parent, {
			name = "ApproachStone",
			size = Vector3.new(12, 0.35, 4),
			cframe = at(origin, 0, 0.1, HALF + 2 + (index - 1) * 4.5),
			color = if index % 2 == 0 then WHITE else PEACH_LIGHT,
			material = Enum.Material.Slate,
			canCollide = false,
			canQuery = false,
			castShadow = false,
		})
	end
end

local function buildLighting(parent: Instance, origin: Vector3)
	local under = HALF - ARCADE_INSET - 4

	local spots = {
		Vector3.new(-34, POST_HEIGHT - 1.4, under),
		Vector3.new(-16, POST_HEIGHT - 1.4, under),
		Vector3.new(16, POST_HEIGHT - 1.4, under),
		Vector3.new(34, POST_HEIGHT - 1.4, under),
		Vector3.new(-ENTRANCE_GAP / 2, ARCH_HEIGHT - 0.8, HALF - ARCADE_INSET),
		Vector3.new(ENTRANCE_GAP / 2, ARCH_HEIGHT - 0.8, HALF - ARCADE_INSET),
	}

	for index, spot in spots do
		local lamp = makePart(parent, {
			name = `WarmLamp_{index}`,
			size = Vector3.new(2.2, 2.2, 2.2),
			shape = Enum.PartType.Ball,
			cframe = at(origin, spot.X, spot.Y, spot.Z),
			color = WARM,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			castShadow = false,
		})

		local light = Instance.new("PointLight")
		light.Color = WARM
		light.Brightness = 1.2
		light.Range = 23
		light.Shadows = false
		light.Parent = lamp
	end
end

function MarketBuilder.build(parent: Instance, origin: Vector3): BuildResult
	local model = Instance.new("Model")
	model.Name = "MarketHall"
	model:SetAttribute("Cell", "C3")

	buildTerrace(model, origin)
	buildPlaza(model, origin)
	buildArcade(model, origin)
	buildStallDressing(model, origin)
	buildEntranceArch(model, origin)
	buildSign(model, origin)
	buildApproach(model, origin)
	buildLighting(model, origin)

	model.Parent = parent

	return {
		model = model,
		anchorPosition = at(origin, 0, 0, 0).Position,
	}
end

return MarketBuilder

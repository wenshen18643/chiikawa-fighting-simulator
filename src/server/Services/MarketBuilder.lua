--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Market = require(Shared.Modules.Config.Market)
local Sections = require(Shared.Modules.Config.Sections)
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
local SURFACE_Y = Streets.SURFACE_Y
local HALF_X = Market.HALF.X
local HALF_Z = Market.HALF.Y
local TERRACE_WIDTH = Market.TERRACE
local ARCADE_INSET = 3
local POST_SPACING = 16
local POST_HEIGHT = 11
local POST_THICK = 1.5
local BEAM_HEIGHT = 1.3
local ROOF_DEPTH = 7
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
	local spanX = (HALF_X + TERRACE_WIDTH) * 2
	local spanZ = (HALF_Z + TERRACE_WIDTH) * 2

	makePart(parent, {
		name = "TerraceStep",
		size = Vector3.new(spanX, 4, spanZ),
		cframe = at(origin, 0, -rise - 2, 0),
		color = PAPER,
		material = Enum.Material.Slate,
	})

	makePart(parent, {
		name = "TerraceLip",
		size = Vector3.new(spanX + 0.6, 0.4, spanZ + 0.6),
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
		{ x = 0, z = HALF_Z - band / 2, sx = HALF_X * 2, sz = band },
		{ x = 0, z = -HALF_Z + band / 2, sx = HALF_X * 2, sz = band },
		{ x = -HALF_X + band / 2, z = 0, sx = band, sz = HALF_Z * 2 },
		{ x = HALF_X - band / 2, z = 0, sx = band, sz = HALF_Z * 2 },
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
		size = Vector3.new(27, 0.3, 27),
		cframe = at(origin, 0, 0.06, 0) * CFrame.Angles(0, math.rad(45), 0),
		color = PAPER,
		material = Enum.Material.Slate,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})

	makePart(parent, {
		name = "PlazaMedallionInner",
		size = Vector3.new(14, 0.3, 14),
		cframe = at(origin, 0, 0.08, 0) * CFrame.Angles(0, math.rad(45), 0),
		color = PEACH,
		material = Enum.Material.Slate,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})
end

local function buildPost(parent: Instance, origin: Vector3, x: number, z: number, index: string)
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
		buildPost(parent, origin, x, z, `{config.tag}_{index}`)
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
	local reach = HALF_X - ARCADE_INSET
	local north = HALF_Z - ARCADE_INSET
	local south = -north

	buildArcadeRun(parent, origin, {
		along = "x",
		fixed = north,
		from = -reach,
		to = -ENTRANCE_GAP / 2,
		inward = -1,
		tag = "NorthWest",
	})

	buildArcadeRun(parent, origin, {
		along = "x",
		fixed = north,
		from = ENTRANCE_GAP / 2,
		to = reach,
		inward = -1,
		tag = "NorthEast",
	})

	buildArcadeRun(parent, origin, {
		along = "x",
		fixed = south,
		from = -reach,
		to = reach,
		inward = 1,
		tag = "South",
	})
end

local STALL = Market.STALL
local STALL_STANDOFF = 10
local NOREN_WIDTH = 9
local NOREN_POST = 6.5

local function buildNoren(parent: Instance, frame: CFrame, style: Market.StallStyle, index: number)
	local base = frame * CFrame.new(0, 0, -STALL_STANDOFF)

	for _, side in { -1, 1 } do
		makePart(parent, {
			name = `NorenPost_{index}`,
			size = Vector3.new(0.42, NOREN_POST, 0.42),
			cframe = base * CFrame.new(side * NOREN_WIDTH / 2, NOREN_POST / 2, 0),
			color = style.timber,
			material = Enum.Material.Wood,
		})
	end

	makePart(parent, {
		name = `NorenRail_{index}`,
		size = Vector3.new(NOREN_WIDTH + 1, 0.36, 0.36),
		cframe = base * CFrame.new(0, NOREN_POST, 0),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})

	makePart(parent, {
		name = `NorenCloth_{index}`,
		size = Vector3.new(NOREN_WIDTH, 2.1, 0.2),
		cframe = base * CFrame.new(0, NOREN_POST - 1.05, 0),
		color = style.canopy,
		material = Enum.Material.Fabric,
		canCollide = false,
		canQuery = false,
	})

	makePart(parent, {
		name = `StallCrate_{index}`,
		size = Vector3.new(2.8, 2.2, 2.8),
		cframe = base * CFrame.new(NOREN_WIDTH / 2 + 1.8, 1.1, 0.6) * CFrame.Angles(0, math.rad(16), 0),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
	})
end

local function buildGable(
	parent: Instance,
	frame: CFrame,
	style: Market.StallStyle,
	eaveY: number,
	span: number,
	depth: number,
	rise: number
)
	local half = depth / 2
	local pitch = math.atan2(rise, half)
	local slope = math.sqrt(half * half + rise * rise)

	for _, side in { -1, 1 } do
		makePart(parent, {
			name = "RoofSlope",
			size = Vector3.new(span, STALL.roofThickness, slope),
			cframe = frame * CFrame.new(0, eaveY + rise / 2, side * half / 2) * CFrame.Angles(side * pitch, 0, 0),
			color = style.tile,
			material = Enum.Material.Slate,
			canCollide = false,
			canQuery = false,
		})
	end

	makePart(parent, {
		name = "RoofRidge",
		size = Vector3.new(span + 0.6, 0.5, 1.3),
		cframe = frame * CFrame.new(0, eaveY + rise + 0.2, 0),
		color = style.trim,
		material = Enum.Material.Slate,
		canCollide = false,
		canQuery = false,
	})
end

local function buildArch(
	parent: Instance,
	frame: CFrame,
	style: Market.StallStyle,
	eaveY: number,
	span: number,
	depth: number
)
	local segments = STALL.roofSegments
	local spread = math.rad(120)
	local radius = (depth / 2) / math.sin(spread / 2)
	local seat = radius * math.cos(spread / 2)
	local slab = radius * spread / segments + 0.3

	for index = 1, segments do
		local angle = -spread / 2 + spread * ((index - 0.5) / segments)
		makePart(parent, {
			name = `RoofArch_{index}`,
			size = Vector3.new(span, STALL.roofThickness, slab),
			cframe = frame
				* CFrame.new(0, eaveY + radius * math.cos(angle) - seat, radius * math.sin(angle))
				* CFrame.Angles(angle, 0, 0),
			color = if index % 2 == 0 then style.trim else style.tile,
			material = Enum.Material.Slate,
			canCollide = false,
			canQuery = false,
		})
	end
end

local function buildRoof(parent: Instance, frame: CFrame, style: Market.StallStyle): number
	local eaveY = STALL.plinth + STALL.postHeight
	local span = STALL.width + STALL.roofOverhang * 2
	local depth = STALL.depth + STALL.roofOverhang * 2
	local rise = STALL.roofRise

	if style.roof == "arch" then
		buildArch(parent, frame, style, eaveY, span, depth)
		return eaveY + (depth / 2) / math.sin(math.rad(60)) * (1 - math.cos(math.rad(60)))
	end

	if style.roof == "pagoda" then
		buildGable(parent, frame, style, eaveY, span, depth, rise * 0.55)

		for _, side in { -1, 1 } do
			makePart(parent, {
				name = "EaveUpturn",
				size = Vector3.new(2.4, 0.5, 1.6),
				cframe = frame * CFrame.new(side * (span / 2 - 1.2), eaveY + 0.45, -depth / 2 + 1)
					* CFrame.Angles(0, 0, side * math.rad(20)),
				color = style.trim,
				material = Enum.Material.Slate,
				canCollide = false,
				canQuery = false,
			})
		end

		local upper = eaveY + rise * 0.55 + 0.8
		buildGable(parent, frame, style, upper, span * 0.62, depth * 0.62, rise * 0.6)
		return upper + rise * 0.6 + 0.45
	end

	buildGable(parent, frame, style, eaveY, span, depth, rise)
	return eaveY + rise + 0.45
end

local function buildTopper(parent: Instance, frame: CFrame, style: Market.StallStyle, peakY: number)
	local span = STALL.width + STALL.roofOverhang * 2
	local lip = -(STALL.depth + STALL.roofOverhang * 2) / 2

	if style.topper == "lantern" then
		for _, side in { -1, 1 } do
			makePart(parent, {
				name = "StallLantern",
				shape = Enum.PartType.Ball,
				size = Vector3.new(2.1, 2.1, 2.1),
				cframe = frame * CFrame.new(side * (span / 2 - 1.4), peakY - 2.6, lip + 0.6),
				color = WARM,
				material = Enum.Material.Neon,
				canCollide = false,
				canQuery = false,
				castShadow = false,
			})
		end
		return
	end

	if style.topper == "ball" then
		makePart(parent, {
			name = "RidgeFinial",
			shape = Enum.PartType.Ball,
			size = Vector3.new(2.4, 2.4, 2.4),
			cframe = frame * CFrame.new(0, peakY + 0.9, 0),
			color = style.trim,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
		})

		for _, side in { -1, 1 } do
			makePart(parent, {
				name = "CornerFinial",
				shape = Enum.PartType.Ball,
				size = Vector3.new(1.3, 1.3, 1.3),
				cframe = frame * CFrame.new(side * (span / 2 - 0.7), peakY - 2.2, lip + 0.5),
				color = style.canopy,
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				canQuery = false,
				castShadow = false,
			})
		end
		return
	end

	local flags = 7
	local step = (span - 1.6) / (flags - 1)

	for index = 1, flags do
		makePart(parent, {
			name = `Pennant_{index}`,
			size = Vector3.new(1.5, 1.7, 0.16),
			cframe = frame * CFrame.new(-span / 2 + 0.8 + step * (index - 1), peakY - 1.9, lip + 0.4)
				* CFrame.Angles(0, 0, math.rad(if index % 2 == 0 then 12 else -12)),
			color = if index % 2 == 0 then style.canopy else style.trim,
			material = Enum.Material.Fabric,
			canCollide = false,
			canQuery = false,
			castShadow = false,
		})
	end
end

local function buildAwning(parent: Instance, frame: CFrame, style: Market.StallStyle, lip: number)
	local pitch = math.rad(STALL.awningPitch)
	local drop = math.sin(pitch) * STALL.awningDepth / 2
	local width = STALL.width + 1.6
	local stripe = width / STALL.awningStripes
	local y = STALL.plinth + STALL.postHeight + 0.5 - drop
	local z = lip + 0.9 - STALL.awningDepth / 2

	for index = 1, STALL.awningStripes do
		makePart(parent, {
			name = `Awning_{index}`,
			size = Vector3.new(stripe, 0.45, STALL.awningDepth),
			cframe = frame * CFrame.new(-width / 2 + stripe * (index - 0.5), y, z) * CFrame.Angles(-pitch, 0, 0),
			color = if index % 2 == 0 then style.stripe else style.canopy,
			material = Enum.Material.Fabric,
			canCollide = false,
			canQuery = false,
		})
	end

	makePart(parent, {
		name = "AwningFascia",
		size = Vector3.new(width + 0.4, 0.75, 0.5),
		cframe = frame * CFrame.new(0, y - drop - 0.15, z - STALL.awningDepth / 2),
		color = WHITE,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		canQuery = false,
	})
end

local function buildStall(origin: Vector3, row: Market.Stall, index: number): Model
	local model = Instance.new("Model")
	model.Name = row.name or `Stall_{index}`

	local style = Market.STALL_STYLES[row.style]
	local frame = at(origin, row.x, 0, row.z) * CFrame.Angles(0, math.rad(row.yaw), 0)
	local halfWidth = STALL.width / 2
	local halfDepth = STALL.depth / 2
	local lip = -halfDepth

	local base = makePart(model, {
		name = "Base",
		size = Vector3.new(STALL.width + 1.6, STALL.plinth, STALL.depth + 1.6),
		cframe = frame * CFrame.new(0, STALL.plinth / 2, 0),
		color = PAPER,
		material = Enum.Material.Slate,
	})

	makePart(model, {
		name = "BackPanel",
		size = Vector3.new(STALL.width, STALL.backHeight, 0.9),
		cframe = frame * CFrame.new(0, STALL.plinth + STALL.backHeight / 2, halfDepth - 0.45),
		color = style.timber,
		material = Enum.Material.WoodPlanks,
	})

	makePart(model, {
		name = "SignBoard",
		size = Vector3.new(STALL.width * 0.62, STALL.signHeight, 0.4),
		cframe = frame * CFrame.new(0, STALL.plinth + STALL.backHeight - STALL.signHeight, halfDepth - 1.1),
		color = style.trim,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})

	for _, side in { -1, 1 } do
		makePart(model, {
			name = "SidePanel",
			size = Vector3.new(0.9, STALL.sideHeight, STALL.depth),
			cframe = frame * CFrame.new(side * (halfWidth - 0.45), STALL.plinth + STALL.sideHeight / 2, 0),
			color = style.timber,
			material = Enum.Material.WoodPlanks,
		})

		makePart(model, {
			name = "Post",
			size = Vector3.new(STALL.postThickness, STALL.postHeight, STALL.postThickness),
			cframe = frame
				* CFrame.new(side * (halfWidth - 0.45), STALL.plinth + STALL.postHeight / 2, lip + 0.45),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
		})
	end

	makePart(model, {
		name = "Counter",
		size = Vector3.new(STALL.width, STALL.counterHeight, STALL.counterDepth),
		cframe = frame * CFrame.new(0, STALL.plinth + STALL.counterHeight / 2, lip + STALL.counterDepth / 2),
		color = style.timber,
		material = Enum.Material.WoodPlanks,
	})

	makePart(model, {
		name = "CounterTop",
		size = Vector3.new(STALL.width + 1.6, 0.5, STALL.counterDepth + 1.4),
		cframe = frame
			* CFrame.new(0, STALL.plinth + STALL.counterHeight + 0.25, lip + STALL.counterDepth / 2 - 0.3),
		color = PAPER,
		material = Enum.Material.WoodPlanks,
	})

	buildAwning(model, frame, style, lip)
	buildTopper(model, frame, style, buildRoof(model, frame, style))

	if row.name == nil then
		buildNoren(model, frame, style, index)
	end

	model.PrimaryPart = base
	return model
end

function MarketBuilder.stalls(parent: Instance, origin: Vector3)
	for index, row in Market.STALLS do
		buildStall(origin, row, index).Parent = parent
	end
end

local function buildEntranceArch(parent: Instance, origin: Vector3)
	local z = HALF_Z - ARCADE_INSET
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
		cframe = at(origin, 0, ARCH_HEIGHT + 1.1, HALF_Z - ARCADE_INSET + 1.3),
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

local LAMP_SPACING = 52

local function buildLighting(parent: Instance, origin: Vector3)
	local under = HALF_Z - ARCADE_INSET - 1.5
	local reach = HALF_X - ARCADE_INSET - 8
	local count = math.max(2, math.round(reach * 2 / LAMP_SPACING) + 1)
	local spots: { Vector3 } = {}

	for index = 1, count do
		local x = -reach + reach * 2 * ((index - 1) / (count - 1))
		table.insert(spots, Vector3.new(x, POST_HEIGHT - 1.4, under))
		table.insert(spots, Vector3.new(x, POST_HEIGHT - 1.4, -under))
	end

	table.insert(spots, Vector3.new(-ENTRANCE_GAP / 2, ARCH_HEIGHT - 0.8, HALF_Z - ARCADE_INSET))
	table.insert(spots, Vector3.new(ENTRANCE_GAP / 2, ARCH_HEIGHT - 0.8, HALF_Z - ARCADE_INSET))

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
	local cell = Sections.cellAt(Market.CENTRE.X, Market.CENTRE.Y)
	model:SetAttribute("Cell", if cell then cell.coord else "")

	buildTerrace(model, origin)
	buildPlaza(model, origin)
	buildArcade(model, origin)
	buildEntranceArch(model, origin)
	buildSign(model, origin)
	buildLighting(model, origin)

	model.Parent = parent

	return {
		model = model,
		anchorPosition = at(origin, 0, 0, 0).Position,
	}
end

return MarketBuilder

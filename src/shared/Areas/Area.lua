local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local ModelUtil = require(Shared.Modules.ModelUtil)
-- selene: allow(unused_variable)
local UI = require(Shared.UI)
local Area = {}

export type Gate = {
	skillTotal: number | { m: number, e: number },
	certificationTotal: number,
}

export type Palette = {
	ground: Color3,
	prop: Color3,
	sky: Color3,
}

export type Terrain = {
	material: string,
	islandSize: number,
}

export type DecorateContext = {
	area: any,
	origin: Vector3,
	parent: Folder,
	rng: Random,
	isReserved: (x: number, z: number) -> boolean,
	plazaRadius: number,
	helpers: typeof(Area.helpers),
	UI: typeof(UI),

	model: ((key: string) -> Model?)?,
	groundY: ((x: number, z: number) -> number)?,
	step: (() -> ())?,
}

local function step(ctx: DecorateContext)
	if ctx.step then
		ctx.step()
	end
end

local function groundAt(ctx: DecorateContext, x: number, z: number): number
	if ctx.groundY then
		return ctx.groundY(x, z)
	end
	return Constants.WORLD.TERRAIN_TOP
end

local function placeAsset(ctx: DecorateContext, key: string, x: number, z: number, config: { [string]: any }?): Model?
	local get = ctx.model
	if not get then
		return nil
	end

	local model = get(key)
	if not model then
		return nil
	end

	step(ctx)

	local options = config or {}

	if options.upright then
		local extents = model:GetExtentsSize()
		if extents.Y < extents.X or extents.Y < extents.Z then
			local fix = if extents.X > extents.Z
				then CFrame.Angles(0, 0, math.rad(90))
				else CFrame.Angles(math.rad(90), 0, 0)
			model:PivotTo(model:GetPivot() * fix)
		end
	end

	local scale = options.scale
	if scale and scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end

	if options.height then
		local extents = model:GetExtentsSize()
		if extents.Y > 0.01 then
			model:ScaleTo(model:GetScale() * (options.height / extents.Y))
		end
	end

	local size = model:GetExtentsSize()
	local base = ctx.origin + Vector3.new(x, groundAt(ctx, x, z) + (options.y or 0) + size.Y / 2, z)
	local pivot = CFrame.new(base)
	local spin = options.rotation
	if spin then
		pivot *= CFrame.Angles(0, spin, 0)
	end
	if options.pitch or options.roll then
		pivot *= CFrame.Angles(math.rad(options.pitch or 0), 0, math.rad(options.roll or 0))
	end

	model:PivotTo(pivot)

	local centre, box = ModelUtil.worldBox(model)
	local target = ctx.origin.Y + groundAt(ctx, x, z) + (options.y or 0)
	model:PivotTo(model:GetPivot() + Vector3.new(0, target - (centre.Y - box.Y / 2), 0))

	model.Parent = options.parent or ctx.parent
	return model
end

export type AreaDefinition = {
	id: number,
	key: string,
	name: string,
	flavour: string,
	gate: Gate,
	origin: Vector3,
	terrain: Terrain,
	palette: Palette,
	bridgeTo: string?,
	decorate: ((ctx: DecorateContext) -> ())?,
}

Area.helpers = {}

local SHADOW_MIN_SIZE = 6

function Area.helpers.block(ctx: DecorateContext, config: { [string]: any }): Part
	step(ctx)

	local part = Instance.new("Part")
	part.Name = config.name or "Decor"
	part.Anchored = true
	part.CanCollide = config.collide ~= false
	part.CanTouch = false
	part.CanQuery = config.collide ~= false
	part.Size = config.size
	if math.max(config.size.X, config.size.Y, config.size.Z) < SHADOW_MIN_SIZE then
		part.CastShadow = false
	end
	part.Shape = config.shape or Enum.PartType.Block
	part.Color = config.color or ctx.area.palette.prop
	part.Material = config.material or Enum.Material.SmoothPlastic
	part.Transparency = config.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local groundY = groundAt(ctx, config.x or 0, config.z or 0) + (config.y or 0)
	if config.cframe then
		part.CFrame = config.cframe
	else
		part.Position = ctx.origin + Vector3.new(config.x or 0, groundY, config.z or 0)
	end

	part.Parent = config.parent or ctx.parent
	return part
end

function Area.helpers.tree(ctx: DecorateContext, x: number, z: number, height: number, canopySize: number)
	local asset = placeAsset(ctx, "tree", x, z, { rotation = ctx.rng:NextNumber() * math.pi * 2 })
	if asset then
		local natural = asset:GetExtentsSize().Y
		if natural > 0.01 then
			asset:ScaleTo(asset:GetScale() * (height / natural))
			local size = asset:GetExtentsSize()
			asset:PivotTo(
				CFrame.new(ctx.origin + Vector3.new(x, groundAt(ctx, x, z) + size.Y / 2, z))
					* CFrame.Angles(0, ctx.rng:NextNumber() * math.pi * 2, 0)
			)
		end
		return asset
	end

	local rng = ctx.rng
	local lean = if rng then (rng:NextNumber() - 0.5) * 0.14 else 0
	local gy = groundAt(ctx, x, z)

	local trunk = Area.helpers.block(ctx, {
		name = "Trunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 1.9, 1.9),
		color = Color3.fromRGB(122, 96, 74),
		material = Enum.Material.Wood,
		cframe = CFrame.new(ctx.origin + Vector3.new(x, gy + height / 2 - 1, z))
			* CFrame.Angles(lean, 0, math.rad(90) + lean),
	})

	Area.helpers.block(ctx, {
		name = "TrunkBase",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(2.4, 2.9, 2.9),
		color = Color3.fromRGB(104, 80, 60),
		material = Enum.Material.Wood,
		cframe = CFrame.new(ctx.origin + Vector3.new(x, gy + 0.2, z)) * CFrame.Angles(0, 0, math.rad(90)),
		collide = false,
	})

	local leaf = Color3.fromRGB(104, 168, 84)
	local BLOBS = {
		{ scale = 1.00, dx = 0.00, dz = 0.00, dy = 0.34, tint = 0.00 },
		{ scale = 0.68, dx = -0.34, dz = 0.20, dy = 0.10, tint = 0.14 },
		{ scale = 0.60, dx = 0.32, dz = -0.24, dy = 0.16, tint = -0.10 },
	}

	for index, blob in BLOBS do
		local jitterX = if rng then (rng:NextNumber() - 0.5) * canopySize * 0.16 else 0
		local jitterZ = if rng then (rng:NextNumber() - 0.5) * canopySize * 0.16 else 0
		local size = canopySize * blob.scale
		local shade = if blob.tint >= 0
			then leaf:Lerp(Color3.fromRGB(150, 208, 118), blob.tint)
			else leaf:Lerp(Color3.fromRGB(58, 112, 52), -blob.tint)

		Area.helpers.block(ctx, {
			name = `Canopy_{index}`,
			shape = Enum.PartType.Ball,
			size = Vector3.new(size, size * 0.88, size),
			x = x + canopySize * blob.dx + jitterX,
			z = z + canopySize * blob.dz + jitterZ,
			y = height - 1 + canopySize * blob.dy,
			color = shade,
			material = Enum.Material.Grass,
			collide = false,
		})
	end

	return trunk
end

function Area.helpers.stone(ctx: DecorateContext, x: number, z: number, size: number)
	local asset = placeAsset(ctx, "stone", x, z, { rotation = ctx.rng:NextNumber() * math.pi * 2 })
	if asset then
		return asset
	end

	return Area.helpers.block(ctx, {
		name = "Stone",
		shape = Enum.PartType.Ball,
		size = Vector3.new(size, size * 0.7, size),
		x = x,
		z = z,
		y = size * 0.25,
		color = Color3.fromRGB(168, 168, 160),
		material = Enum.Material.Slate,
	})
end

function Area.helpers.bush(ctx: DecorateContext, x: number, z: number, size: number)
	local asset = placeAsset(ctx, "bush", x, z, { rotation = ctx.rng:NextNumber() * math.pi * 2 })
	if asset then
		return asset
	end

	return Area.helpers.block(ctx, {
		name = "Bush",
		shape = Enum.PartType.Ball,
		size = Vector3.new(size, size * 0.72, size),
		x = x,
		z = z,
		y = size * 0.26,
		color = Color3.fromRGB(96, 148, 78),
		material = Enum.Material.Grass,
		collide = false,
	})
end

function Area.helpers.log(ctx: DecorateContext, x: number, z: number, length: number)
	local asset = placeAsset(ctx, "log", x, z, { rotation = ctx.rng:NextNumber() * math.pi * 2 })
	if asset then
		return asset
	end

	local part = Area.helpers.block(ctx, {
		name = "Log",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(length, 2.2, 2.2),
		x = x,
		z = z,
		y = 1.1,
		color = Color3.fromRGB(116, 88, 66),
		material = Enum.Material.Wood,
		collide = false,
	})
	part.CFrame = part.CFrame * CFrame.Angles(0, ctx.rng:NextNumber() * math.pi * 2, 0)
	return part
end

function Area.helpers.studyDesk(ctx: DecorateContext, config: { [string]: any }): Model
	local model = Instance.new("Model")
	model.Name = "StudyDeskProp"
	local x, z, y = config.x or 0, config.z or 0, config.y or 3.2
	local gy = groundAt(ctx, x, z)

	local top = Area.helpers.block(ctx, {
		name = "TableTop",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.6, 9.5, 6.2),
		color = Color3.fromRGB(245, 175, 195),
		material = Enum.Material.SmoothPlastic,
		cframe = CFrame.new(ctx.origin + Vector3.new(x, gy + y, z)) * CFrame.Angles(0, 0, math.rad(90)),
		parent = model,
	})

	local legOffsets = {
		Vector3.new(-3.6, -1.2, -1.8),
		Vector3.new(3.6, -1.2, -1.8),
		Vector3.new(-3.6, -1.2, 1.8),
		Vector3.new(3.6, -1.2, 1.8),
	}
	for i, offset in legOffsets do
		Area.helpers.block(ctx, {
			name = `Leg_{i}`,
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(2.4, 0.5, 0.5),
			color = Color3.fromRGB(80, 60, 50),
			material = Enum.Material.Wood,
			cframe = CFrame.new(top.Position + offset) * CFrame.Angles(0, 0, math.rad(90)),
			parent = model,
		})
	end

	local bookLeft = Area.helpers.block(ctx, {
		name = "BookLeftPage",
		size = Vector3.new(2.4, 0.15, 3.2),
		color = Color3.fromRGB(255, 252, 245),
		material = Enum.Material.SmoothPlastic,
		cframe = CFrame.new(top.Position + Vector3.new(-1.3, 0.35, -0.2)) * CFrame.Angles(0, 0, math.rad(-5)),
		parent = model,
	})
	local bookRight = Area.helpers.block(ctx, {
		name = "BookRightPage",
		size = Vector3.new(2.4, 0.15, 3.2),
		color = Color3.fromRGB(255, 252, 245),
		material = Enum.Material.SmoothPlastic,
		cframe = CFrame.new(top.Position + Vector3.new(1.3, 0.35, -0.2)) * CFrame.Angles(0, 0, math.rad(5)),
		parent = model,
	})

	Area.helpers.block(ctx, {
		name = "PencilLine1",
		size = Vector3.new(1.6, 0.05, 0.3),
		color = Color3.fromRGB(100, 90, 85),
		cframe = bookLeft.CFrame * CFrame.new(0, 0.1, -0.6),
		parent = model,
	})
	Area.helpers.block(ctx, {
		name = "PencilLine2",
		size = Vector3.new(1.6, 0.05, 0.3),
		color = Color3.fromRGB(100, 90, 85),
		cframe = bookRight.CFrame * CFrame.new(0, 0.1, 0.4),
		parent = model,
	})

	Area.helpers.block(ctx, {
		name = "Eraser",
		size = Vector3.new(0.8, 0.3, 1.2),
		color = Color3.fromRGB(70, 140, 230),
		material = Enum.Material.SmoothPlastic,
		cframe = CFrame.new(top.Position + Vector3.new(-3.2, 0.35, 1.0)) * CFrame.Angles(0, math.rad(25), 0),
		parent = model,
	})

	Area.helpers.block(ctx, {
		name = "SideBook",
		size = Vector3.new(2.0, 0.4, 2.4),
		color = Color3.fromRGB(180, 220, 150),
		material = Enum.Material.SmoothPlastic,
		cframe = CFrame.new(top.Position + Vector3.new(2.8, 0.35, 0.8)) * CFrame.Angles(0, math.rad(-15), 0),
		parent = model,
	})

	Area.helpers.block(ctx, {
		name = "Cushion",
		size = Vector3.new(4.5, 0.6, 4.5),
		color = Color3.fromRGB(240, 180, 220),
		material = Enum.Material.Fabric,
		cframe = CFrame.new(top.Position + Vector3.new(0, -1.8, 4.5)),
		parent = model,
	})

	local emitterAttachment = Instance.new("Attachment")
	emitterAttachment.Name = "StudyEmitterAttachment"
	emitterAttachment.Position = Vector3.new(0, 2, 0)
	emitterAttachment.Parent = top

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "StudyParticleEmitter"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 140, 210)),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.2) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Rate = 4
	emitter.Speed = NumberRange.new(1.5, 3.5)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Parent = emitterAttachment

	local tier = math.clamp(config.tier or 1, 1, 7)
	local BOOK_COLORS = {
		Color3.fromRGB(226, 108, 130),
		Color3.fromRGB(120, 168, 224),
		Color3.fromRGB(242, 196, 108),
		Color3.fromRGB(146, 196, 130),
		Color3.fromRGB(196, 146, 214),
	}

	for index = 1, tier - 1 do
		local column = if index % 2 == 0 then 1 else -1
		local level = math.floor((index - 1) / 2)

		Area.helpers.block(ctx, {
			name = `StackedBook_{index}`,
			size = Vector3.new(2.6, 0.42, 3.4),
			color = BOOK_COLORS[(index - 1) % #BOOK_COLORS + 1],
			material = Enum.Material.SmoothPlastic,
			cframe = CFrame.new(top.Position + Vector3.new(column * 5.4, -0.1 + level * 0.46, 1.6))
				* CFrame.Angles(0, math.rad(index * 7 % 18 - 9), 0),
			parent = model,
		})
	end

	model.Parent = config.parent or ctx.parent
	return model
end

function Area.helpers.prop(ctx: DecorateContext, key: string, x: number, z: number, config: { [string]: any }?): Model?
	local options = config or {}
	return placeAsset(ctx, key, x, z, {
		height = options.height,
		rotation = options.rotation or ctx.rng:NextNumber() * math.pi * 2,
		y = options.y,
		parent = options.parent,
		upright = options.upright,
		pitch = options.pitch,
		roll = options.roll,
	})
end

function Area.helpers.paving(
	ctx: DecorateContext,
	area: { [string]: any },
	style: { [string]: any },
	color: Color3?
): Part
	step(ctx)

	local midX = (area.minX + area.maxX) / 2
	local midZ = (area.minZ + area.maxZ) / 2
	local top = style.SURFACE_Y + (area.rise or 0)
	local part = Instance.new("Part")
	part.Name = area.name or "Paving"
	part.Size = Vector3.new(area.maxX - area.minX, style.THICKNESS, area.maxZ - area.minZ)
	part.CFrame = CFrame.new(ctx.origin + Vector3.new(midX, top - style.THICKNESS / 2, midZ))
	part.Color = color or style.COLOR
	part.Material = style.MATERIAL
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = ctx.parent
	return part
end

function Area.helpers.hedge(ctx: DecorateContext, verge: { [string]: any }, style: { [string]: any })
	local from = Vector2.new(verge.fromX, verge.fromZ)
	local span = Vector2.new(verge.toX, verge.toZ) - from
	local length = span.Magnitude
	if length < 1 then
		return
	end

	local direction = span.Unit
	local yaw = math.atan2(direction.X, direction.Y)
	local count = math.max(1, math.round(length / style.HEDGE_SEGMENT))
	local piece = length / count
	local top = style.SURFACE_Y + style.HEDGE_HEIGHT
	local bodyHeight = style.HEDGE_HEIGHT + style.HEDGE_SKIRT
	local segments = if verge.hedge == false then 0 else count

	for index = 1, segments do
		step(ctx)

		local at = from + direction * ((index - 0.5) * piece)
		local body = Instance.new("Part")
		body.Name = "Hedge"
		body.Size = Vector3.new(style.HEDGE_WIDTH, bodyHeight, piece + 0.2)
		body.CFrame = CFrame.new(ctx.origin + Vector3.new(at.X, top - bodyHeight / 2, at.Y)) * CFrame.Angles(0, yaw, 0)
		body.Color = style.HEDGE_COLOR
		body.Material = Enum.Material.Grass
		body.Anchored = true
		body.CanCollide = true
		body.CanTouch = false
		body.CastShadow = false
		body.Parent = ctx.parent

		local crown = Instance.new("Part")
		crown.Name = "HedgeCrown"
		crown.Size = Vector3.new(style.HEDGE_WIDTH * 0.72, 0.5, piece + 0.2)
		crown.CFrame = CFrame.new(ctx.origin + Vector3.new(at.X, top + 0.15, at.Y)) * CFrame.Angles(0, yaw, 0)
		crown.Color = style.HEDGE_CROWN
		crown.Material = Enum.Material.Grass
		crown.Anchored = true
		crown.CanCollide = false
		crown.CanQuery = false
		crown.CanTouch = false
		crown.CastShadow = false
		crown.Parent = ctx.parent
	end

	local inward = Vector2.new(math.sin(math.rad(verge.facing)), math.cos(math.rad(verge.facing)))

	local function alongRun(spacing: number, inset: number, place: (x: number, z: number, y: number) -> ())
		local slots = math.floor(length / spacing)
		for index = 1, slots do
			local at = from + direction * (index * spacing - spacing / 2)
			local x, z = at.X + inward.X * inset, at.Y + inward.Y * inset
			place(x, z, style.SURFACE_Y - groundAt(ctx, x, z))
		end
	end

	if verge.lamps then
		alongRun(style.LAMP_SPACING, style.LAMP_INSET, function(x, z, y)
			ctx.helpers.prop(ctx, "lantern", x, z, { height = 4.6, y = y, rotation = math.rad(verge.facing) })
		end)
	end
end

local REQUIRED = { "id", "key", "name", "flavour", "gate", "origin", "terrain", "palette" }

function Area.define(definition: AreaDefinition): AreaDefinition
	for _, field in REQUIRED do
		assert((definition :: any)[field] ~= nil, `Area "{definition.key or "?"}" is missing "{field}"`)
	end
	assert(type(definition.id) == "number", `Area "{definition.key}" id must be a number`)
	assert(definition.terrain.islandSize > 0, `Area "{definition.key}" needs a positive islandSize`)
	assert(definition.gate.certificationTotal ~= nil, `Area "{definition.key}" gate needs certificationTotal`)
	assert(
		definition.bridgeTo == nil or type(definition.bridgeTo) == "string",
		`Area "{definition.key}" bridgeTo must be an area key`
	)
	return definition
end

return Area

local Theme = require(script.Parent.Theme)
local Glyphs = {}

type Ctx = { parent: Frame, color: Color3, zIndex: number }

local function shape(ctx: Ctx, config: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.Name = config.name or "Shape"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(config.x, config.y)
	frame.Size = UDim2.fromScale(config.w, config.h)
	frame.Rotation = config.rot or 0
	frame.BackgroundColor3 = config.color or ctx.color
	frame.BackgroundTransparency = config.transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = ctx.zIndex + (config.layer or 0)
	frame.Parent = ctx.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(config.round or 0, 0)
	corner.Parent = frame

	return frame
end

local function dot(ctx: Ctx, x: number, y: number, size: number, config: { [string]: any }?)
	local options = config or {}
	return shape(ctx, {
		name = "Dot",
		x = x,
		y = y,
		w = size,
		h = options.h or size,
		round = 0.5,
		color = options.color,
		rot = options.rot,
		layer = options.layer,
		transparency = options.transparency,
	})
end

local function bar(ctx: Ctx, config: { [string]: any })
	config.round = config.round or 0.35
	config.name = "Bar"
	return shape(ctx, config)
end

local shapes: { [string]: (Ctx) -> () } = {}

function shapes.fish(ctx)
	dot(ctx, 0.46, 0.5, 0.62, { h = 0.44 })
	shape(ctx, { name = "Tail", x = 0.86, y = 0.5, w = 0.26, h = 0.34, rot = 45, round = 0.1 })
	dot(ctx, 0.3, 0.44, 0.11, { color = Theme.color.paper, layer = 2 })
end

function shapes.ore(ctx)
	shape(ctx, { name = "Rock", x = 0.5, y = 0.6, w = 0.72, h = 0.5, round = 0.28 })
	shape(ctx, { name = "Facet", x = 0.4, y = 0.4, w = 0.4, h = 0.36, rot = 32, round = 0.14 })
	dot(ctx, 0.62, 0.58, 0.14, { color = Theme.color.paper, layer = 2 })
	dot(ctx, 0.4, 0.68, 0.1, { color = Theme.color.paper, layer = 2 })
end

function shapes.meat(ctx)
	dot(ctx, 0.42, 0.42, 0.56, { h = 0.5, rot = -20 })
	bar(ctx, { x = 0.72, y = 0.72, w = 0.36, h = 0.13, rot = -38, color = Theme.color.paper })
	dot(ctx, 0.86, 0.83, 0.17, { color = Theme.color.paper, layer = 2 })
	dot(ctx, 0.34, 0.36, 0.13, { color = Theme.color.paper, layer = 2 })
end

function shapes.pickaxe(ctx)
	bar(ctx, { x = 0.5, y = 0.62, w = 0.1, h = 0.62, rot = 12 })
	shape(ctx, { name = "Head", x = 0.5, y = 0.26, w = 0.74, h = 0.16, rot = -16, round = 0.4 })
end

function shapes.rod(ctx)
	bar(ctx, { x = 0.44, y = 0.54, w = 0.09, h = 0.78, rot = 24 })
	bar(ctx, { x = 0.72, y = 0.62, w = 0.05, h = 0.44 })
	dot(ctx, 0.72, 0.86, 0.2)
end

function shapes.leaf(ctx)
	bar(ctx, { x = 0.42, y = 0.72, w = 0.09, h = 0.44, rot = -20 })
	dot(ctx, 0.56, 0.38, 0.62, { h = 0.42, rot = -38 })
end

function shapes.sasumata(ctx)
	bar(ctx, { x = 0.5, y = 0.65, w = 0.1, h = 0.55 })
	bar(ctx, { x = 0.5, y = 0.82, w = 0.16, h = 0.14, color = Theme.color.paper })
	bar(ctx, { x = 0.5, y = 0.36, w = 0.52, h = 0.12 })
	bar(ctx, { x = 0.28, y = 0.22, w = 0.1, h = 0.36, rot = -12 })
	bar(ctx, { x = 0.72, y = 0.22, w = 0.1, h = 0.36, rot = 12 })
end

function shapes.tears(ctx)
	dot(ctx, 0.5, 0.58, 0.54)
	shape(ctx, { name = "Tip", x = 0.5, y = 0.34, w = 0.36, h = 0.36, rot = 45, round = 0.1 })
end

function shapes.book(ctx)
	shape(ctx, { name = "LeftPage", x = 0.3, y = 0.5, w = 0.36, h = 0.54, round = 0.15 })
	shape(ctx, { name = "RightPage", x = 0.7, y = 0.5, w = 0.36, h = 0.54, round = 0.15 })
	bar(ctx, { x = 0.5, y = 0.5, w = 0.08, h = 0.58, color = Theme.color.paper })
end

function shapes.sweat(ctx)
	dot(ctx, 0.36, 0.44, 0.34)
	shape(ctx, { name = "Tip", x = 0.36, y = 0.26, w = 0.22, h = 0.22, rot = 45, round = 0.1 })
	dot(ctx, 0.7, 0.68, 0.26)
	shape(ctx, { name = "TipSmall", x = 0.7, y = 0.54, w = 0.17, h = 0.17, rot = 45, round = 0.1 })
end

function shapes.ramen(ctx)
	shape(ctx, { name = "Bowl", x = 0.5, y = 0.62, w = 0.7, h = 0.38, round = 0.4 })
	bar(ctx, { x = 0.5, y = 0.42, w = 0.76, h = 0.1 })
	bar(ctx, { x = 0.45, y = 0.28, w = 0.06, h = 0.4, rot = -45 })
	bar(ctx, { x = 0.55, y = 0.24, w = 0.06, h = 0.4, rot = -45 })
end

function shapes.lightbulb(ctx)
	dot(ctx, 0.5, 0.4, 0.56)
	shape(ctx, { name = "Base", x = 0.5, y = 0.72, w = 0.28, h = 0.24, round = 0.15 })
	bar(ctx, { x = 0.5, y = 0.88, w = 0.16, h = 0.08 })
end

shapes.broom = shapes.sasumata
shapes.weight = shapes.tears
shapes.hammer = shapes.book
shapes.pot = shapes.ramen
shapes.heart = shapes.lightbulb

function shapes.lock(ctx)
	shape(ctx, { name = "Shackle", x = 0.5, y = 0.34, w = 0.44, h = 0.44, round = 0.5 })
	shape(ctx, {
		name = "ShackleHole",
		x = 0.5,
		y = 0.34,
		w = 0.22,
		h = 0.22,
		round = 0.5,
		color = Theme.color.paper,
		layer = 1,
	})
	shape(ctx, { name = "Body", x = 0.5, y = 0.66, w = 0.66, h = 0.44, round = 0.22, layer = 2 })
end

function shapes.pin(ctx)
	dot(ctx, 0.5, 0.38, 0.56)
	shape(ctx, { name = "Point", x = 0.5, y = 0.62, w = 0.34, h = 0.34, rot = 45, round = 0.1 })
	shape(
		ctx,
		{ name = "Hole", x = 0.5, y = 0.38, w = 0.2, h = 0.2, round = 0.5, color = Theme.color.paper, layer = 3 }
	)
end

function shapes.coin(ctx)
	dot(ctx, 0.5, 0.5, 0.82)
	shape(ctx, { name = "Inner", x = 0.5, y = 0.5, w = 0.58, h = 0.58, round = 0.5, layer = 1, transparency = 0.55 })
	bar(ctx, { x = 0.5, y = 0.56, w = 0.42, h = 0.1, layer = 2 })
	bar(ctx, { x = 0.5, y = 0.4, w = 0.1, h = 0.34, layer = 2 })
end

function shapes.stamp(ctx)
	shape(ctx, { name = "Head", x = 0.5, y = 0.7, w = 0.66, h = 0.3, round = 0.2 })
	bar(ctx, { x = 0.5, y = 0.34, w = 0.26, h = 0.44 })
end

function shapes.home(ctx)
	shape(ctx, { name = "Roof", x = 0.5, y = 0.34, w = 0.5, h = 0.5, rot = 45, round = 0.12 })
	shape(ctx, { name = "Body", x = 0.5, y = 0.68, w = 0.56, h = 0.4, round = 0.14, layer = 1 })
end

function shapes.arrow(ctx)
	bar(ctx, { x = 0.4, y = 0.5, w = 0.46, h = 0.16 })
	shape(ctx, { name = "Head", x = 0.7, y = 0.5, w = 0.34, h = 0.34, rot = 45, round = 0.12 })
end

function shapes.map(ctx)
	shape(ctx, { name = "Sheet", x = 0.5, y = 0.5, w = 0.78, h = 0.62, round = 0.12 })
	bar(ctx, { x = 0.34, y = 0.5, w = 0.06, h = 0.62, color = Theme.color.paper, layer = 1, round = 0 })
	bar(ctx, { x = 0.66, y = 0.5, w = 0.06, h = 0.62, color = Theme.color.paper, layer = 1, round = 0 })
end

function shapes.help(ctx)
	shape(ctx, { name = "Hook", x = 0.5, y = 0.34, w = 0.52, h = 0.52, round = 0.5 })
	shape(ctx, {
		name = "HookHole",
		x = 0.5,
		y = 0.34,
		w = 0.24,
		h = 0.24,
		round = 0.5,
		color = Theme.color.paper,
		layer = 1,
	})
	shape(ctx, { name = "HookCut", x = 0.5, y = 0.58, w = 0.54, h = 0.2, color = Theme.color.paper, layer = 2 })
	bar(ctx, { x = 0.5, y = 0.6, w = 0.14, h = 0.26, layer = 3 })
	dot(ctx, 0.5, 0.86, 0.16, { layer = 3 })
end

function shapes.spark(ctx)
	bar(ctx, { x = 0.5, y = 0.5, w = 0.18, h = 0.8 })
	bar(ctx, { x = 0.5, y = 0.5, w = 0.8, h = 0.18 })
end

function shapes.carrot(ctx)
	bar(ctx, { x = 0.5, y = 0.6, w = 0.34, h = 0.48, round = 0.5 })
	shape(ctx, { name = "Tip", x = 0.5, y = 0.88, w = 0.22, h = 0.22, rot = 45, round = 0.08 })
	dot(ctx, 0.34, 0.26, 0.2, { h = 0.3, rot = -28 })
	dot(ctx, 0.5, 0.2, 0.2, { h = 0.32 })
	dot(ctx, 0.66, 0.26, 0.2, { h = 0.3, rot = 28 })
end

function shapes.potato(ctx)
	dot(ctx, 0.5, 0.54, 0.8, { h = 0.58, rot = -12 })
	dot(ctx, 0.34, 0.44, 0.12, { color = Theme.color.paper, layer = 1 })
	dot(ctx, 0.56, 0.62, 0.1, { color = Theme.color.paper, layer = 1 })
	dot(ctx, 0.68, 0.42, 0.09, { color = Theme.color.paper, layer = 1 })
end

function shapes.rice(ctx)
	shape(ctx, { name = "Mound", x = 0.5, y = 0.62, w = 0.72, h = 0.4, round = 0.5 })
	dot(ctx, 0.33, 0.34, 0.15, { h = 0.24, rot = -30 })
	dot(ctx, 0.5, 0.28, 0.15, { h = 0.24 })
	dot(ctx, 0.67, 0.34, 0.15, { h = 0.24, rot = 30 })
end

function shapes.berry(ctx)
	bar(ctx, { x = 0.52, y = 0.16, w = 0.08, h = 0.22, rot = -16 })
	dot(ctx, 0.5, 0.42, 0.4, { layer = 1 })
	dot(ctx, 0.34, 0.66, 0.4, { layer = 1 })
	dot(ctx, 0.66, 0.66, 0.4, { layer = 1 })
end

function shapes.mushroom(ctx)
	shape(ctx, { name = "Cap", x = 0.5, y = 0.42, w = 0.84, h = 0.46, round = 0.5 })
	shape(ctx, { name = "CapCut", x = 0.5, y = 0.64, w = 0.9, h = 0.2, color = Theme.color.paper, layer = 1 })
	shape(ctx, { name = "Stem", x = 0.5, y = 0.72, w = 0.3, h = 0.42, round = 0.25, layer = 2 })
	dot(ctx, 0.36, 0.34, 0.15, { color = Theme.color.paper, layer = 3 })
	dot(ctx, 0.62, 0.3, 0.11, { color = Theme.color.paper, layer = 3 })
end

function shapes.sausage(ctx)
	bar(ctx, { x = 0.5, y = 0.5, w = 0.78, h = 0.34, round = 0.5, rot = -20 })
	dot(ctx, 0.14, 0.64, 0.14)
	dot(ctx, 0.86, 0.36, 0.14)
end

function shapes.onigiri(ctx)
	shape(ctx, { name = "Body", x = 0.5, y = 0.46, w = 0.56, h = 0.56, rot = 45, round = 0.18 })
	shape(ctx, { name = "Gap", x = 0.5, y = 0.74, w = 0.94, h = 0.06, color = Theme.color.paper, layer = 1 })
	shape(ctx, { name = "Nori", x = 0.5, y = 0.84, w = 0.46, h = 0.18, round = 0.2, layer = 2 })
end

function shapes.dango(ctx)
	bar(ctx, { x = 0.5, y = 0.5, w = 0.08, h = 0.96, round = 0.5 })
	dot(ctx, 0.5, 0.24, 0.4, { layer = 1 })
	dot(ctx, 0.5, 0.51, 0.4, { layer = 1 })
	dot(ctx, 0.5, 0.78, 0.4, { layer = 1 })
	shape(ctx, { name = "Seam", x = 0.5, y = 0.375, w = 0.5, h = 0.03, color = Theme.color.paper, layer = 2 })
	shape(ctx, { name = "Seam", x = 0.5, y = 0.645, w = 0.5, h = 0.03, color = Theme.color.paper, layer = 2 })
end

function shapes.yogurt(ctx)
	dot(ctx, 0.5, 0.2, 0.2, { h = 0.16 })
	dot(ctx, 0.5, 0.32, 0.36, { h = 0.24 })
	bar(ctx, { x = 0.5, y = 0.44, w = 0.78, h = 0.13, layer = 1 })
	shape(ctx, { name = "Cup", x = 0.5, y = 0.7, w = 0.6, h = 0.46, round = 0.24, layer = 1 })
end

function shapes.tea(ctx)
	shape(ctx, { name = "Handle", x = 0.82, y = 0.6, w = 0.26, h = 0.26, round = 0.5 })
	shape(ctx, {
		name = "HandleHole",
		x = 0.82,
		y = 0.6,
		w = 0.11,
		h = 0.11,
		round = 0.5,
		color = Theme.color.paper,
		layer = 1,
	})
	shape(ctx, { name = "Cup", x = 0.44, y = 0.62, w = 0.58, h = 0.44, round = 0.3, layer = 2 })
	bar(ctx, { x = 0.5, y = 0.9, w = 0.56, h = 0.09, layer = 2 })
	bar(ctx, { x = 0.34, y = 0.22, w = 0.07, h = 0.26, rot = 14 })
	bar(ctx, { x = 0.54, y = 0.18, w = 0.07, h = 0.3, rot = -14 })
end

function shapes.pancakes(ctx)
	dot(ctx, 0.5, 0.34, 0.62, { h = 0.2 })
	dot(ctx, 0.5, 0.52, 0.72, { h = 0.2 })
	dot(ctx, 0.5, 0.7, 0.8, { h = 0.2 })
	shape(ctx, { name = "Seam", x = 0.5, y = 0.43, w = 0.66, h = 0.03, color = Theme.color.paper, layer = 1 })
	shape(ctx, { name = "Seam", x = 0.5, y = 0.61, w = 0.76, h = 0.03, color = Theme.color.paper, layer = 1 })
	dot(ctx, 0.5, 0.2, 0.28, { h = 0.14, layer = 2 })
end

function shapes.platter(ctx)
	dot(ctx, 0.5, 0.18, 0.16)
	dot(ctx, 0.5, 0.46, 0.74, { h = 0.5, layer = 1 })
	shape(ctx, { name = "DomeCut", x = 0.5, y = 0.76, w = 0.86, h = 0.22, color = Theme.color.paper, layer = 2 })
	bar(ctx, { x = 0.5, y = 0.72, w = 0.96, h = 0.12, layer = 3 })
	bar(ctx, { x = 0.5, y = 0.85, w = 0.42, h = 0.08, layer = 3 })
end

Glyphs.FOR_SKILL = {
	tobatsu = "sasumata",
	resilience = "tears",
	kusatori = "leaf",
	examprep = "book",
	strength = "sasumata",
	durability = "tears",
	agility = "leaf",
	special = "book",
	subjugation = "sasumata",
	grit = "tears",
	weeding = "leaf",
	craft = "book",
}

function Glyphs.exists(name: string): boolean
	return shapes[name] ~= nil
end

function Glyphs.render(parent: Instance, name: string, config: { [string]: any }?): Frame
	local options = config or {}
	local container = Instance.new("Frame")
	container.Name = `Glyph_{name}`
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ZIndex = options.zIndex or 4
	container.Size = options.extent or UDim2.fromOffset(18, 18)
	if options.position then
		container.Position = options.position
	end
	if options.anchor then
		container.AnchorPoint = options.anchor
	end
	container.Rotation = options.rotation or 0
	container.Parent = parent

	local draw = shapes[name]
	if not draw then
		warn(`[Glyphs] no glyph named "{name}"`)
		return container
	end

	draw({
		parent = container,
		color = options.color or Theme.color.ink,
		zIndex = container.ZIndex,
	})

	return container
end

function Glyphs.forSkill(parent: Instance, skillId: string, config: { [string]: any }?): Frame
	return Glyphs.render(parent, Glyphs.FOR_SKILL[skillId] or "spark", config)
end

return Glyphs

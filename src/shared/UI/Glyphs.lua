--[[
	Icons, drawn as geometry.
]]

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

-- Kusatori: leaf
function shapes.leaf(ctx)
	bar(ctx, { x = 0.42, y = 0.72, w = 0.09, h = 0.44, rot = -20 })
	dot(ctx, 0.56, 0.38, 0.62, { h = 0.42, rot = -38 })
end

-- Tobatsu: Sasumata (two-pronged fork weapon)
function shapes.sasumata(ctx)
	bar(ctx, { x = 0.5, y = 0.65, w = 0.1, h = 0.55 })
	bar(ctx, { x = 0.5, y = 0.36, w = 0.52, h = 0.12 })
	bar(ctx, { x = 0.28, y = 0.22, w = 0.1, h = 0.36, rot = -12 })
	bar(ctx, { x = 0.72, y = 0.22, w = 0.1, h = 0.36, rot = 12 })
end

-- Resilience: Tears / Water drop
function shapes.tears(ctx)
	dot(ctx, 0.5, 0.58, 0.54)
	shape(ctx, { name = "Tip", x = 0.5, y = 0.34, w = 0.36, h = 0.36, rot = 45, round = 0.1 })
end

-- Exam Prep: Open Booklet / Book
function shapes.book(ctx)
	shape(ctx, { name = "LeftPage", x = 0.3, y = 0.5, w = 0.36, h = 0.54, round = 0.15 })
	shape(ctx, { name = "RightPage", x = 0.7, y = 0.5, w = 0.36, h = 0.54, round = 0.15 })
	bar(ctx, { x = 0.5, y = 0.5, w = 0.08, h = 0.58, color = Theme.color.paper })
end

-- Tobatsu: sweat. Two droplets flung off at different sizes, so it reads as
-- effort rather than as the single tidy teardrop `tears` already owns.
function shapes.sweat(ctx)
	dot(ctx, 0.36, 0.44, 0.34)
	shape(ctx, { name = "Tip", x = 0.36, y = 0.26, w = 0.22, h = 0.22, rot = 45, round = 0.1 })
	dot(ctx, 0.7, 0.68, 0.26)
	shape(ctx, { name = "TipSmall", x = 0.7, y = 0.54, w = 0.17, h = 0.17, rot = 45, round = 0.1 })
end

-- Ramen Bowl
function shapes.ramen(ctx)
	shape(ctx, { name = "Bowl", x = 0.5, y = 0.62, w = 0.7, h = 0.38, round = 0.4 })
	bar(ctx, { x = 0.5, y = 0.42, w = 0.76, h = 0.1 })
	bar(ctx, { x = 0.45, y = 0.28, w = 0.06, h = 0.4, rot = -45 })
	bar(ctx, { x = 0.55, y = 0.24, w = 0.06, h = 0.4, rot = -45 })
end

-- Lightbulb
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
	shape(ctx, { name = "ShackleHole", x = 0.5, y = 0.34, w = 0.22, h = 0.22, round = 0.5, color = Theme.color.paper, layer = 1 })
	shape(ctx, { name = "Body", x = 0.5, y = 0.66, w = 0.66, h = 0.44, round = 0.22, layer = 2 })
end

function shapes.pin(ctx)
	dot(ctx, 0.5, 0.38, 0.56)
	shape(ctx, { name = "Point", x = 0.5, y = 0.62, w = 0.34, h = 0.34, rot = 45, round = 0.1 })
	shape(ctx, { name = "Hole", x = 0.5, y = 0.38, w = 0.2, h = 0.2, round = 0.5, color = Theme.color.paper, layer = 3 })
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

--[[
	A question mark, for the controls button.

	Built as a ring with its lower half masked off, rather than as an arc: there
	is no arc primitive here, and a rounded square with a hole punched in it and
	its bottom covered reads as the hook of a "?" at 22px.
]]
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

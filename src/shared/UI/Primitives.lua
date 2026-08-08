local Theme = require(script.Parent.Theme)
local Primitives = {}

function Primitives.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.radius.card)
	corner.Parent = parent
	return corner
end

function Primitives.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.color.line
	stroke.Thickness = thickness or Theme.stroke.base
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 0
	stroke.Parent = parent
	return stroke
end

function Primitives.focusRing(target: GuiObject, color: Color3?): UIStroke
	local ring = Instance.new("UIStroke")
	ring.Name = "SelectionFocus"
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = color or Theme.color.info
	ring.Thickness = Theme.state.focus.thickness
	ring.Transparency = 1
	ring.Parent = target
	return ring
end

function Primitives.padding(parent: Instance, all: number?, extra: { [string]: number }?): UIPadding
	local amount = all or Theme.space.base
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, (extra and extra.top) or amount)
	padding.PaddingBottom = UDim.new(0, (extra and extra.bottom) or amount)
	padding.PaddingLeft = UDim.new(0, (extra and extra.left) or amount)
	padding.PaddingRight = UDim.new(0, (extra and extra.right) or amount)
	padding.Parent = parent
	return padding
end

function Primitives.gradient(parent: Instance, from: Color3, to: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(from, to)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

function Primitives.list(parent: Instance, padding: number?, align: Enum.HorizontalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or Theme.space.tight)
	layout.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	layout.Parent = parent
	return layout
end

function Primitives.grid(parent: Instance, cell: UDim2, padding: UDim2?): UIGridLayout
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cell
	layout.CellPadding = padding or UDim2.fromOffset(Theme.space.tight, Theme.space.tight)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function elevationOf(level: (string | number)?): { layers: number, spread: number, opacity: number }
	if type(level) == "number" then
		return { layers = level, spread = 3, opacity = 0.68 }
	end
	return (Theme.elevation :: any)[level or "base"] or Theme.elevation.base
end

function Primitives.shadow(target: GuiObject, level: (string | number)?, tint: Color3?)
	local spec = elevationOf(level)
	if spec.layers <= 0 then
		return
	end

	local radius = Theme.radius.card
	local corner = target:FindFirstChildOfClass("UICorner")
	if corner then
		radius = corner.CornerRadius.Offset
	end

	for index = spec.layers, 1, -1 do
		local grow = index * spec.spread
		local drop = math.ceil(index * spec.spread * 0.5)
		local shade = Instance.new("Frame")
		shade.Name = `Shadow_{index}`
		shade.AnchorPoint = Vector2.new(0.5, 0.5)
		shade.Position = UDim2.new(0.5, 0, 0.5, drop)
		shade.Size = UDim2.new(1, grow, 1, grow)
		shade.BackgroundColor3 = tint or Theme.color.shadow
		shade.BackgroundTransparency = spec.opacity + (1 - spec.opacity) * (index / spec.layers) * 0.92
		shade.BorderSizePixel = 0
		shade.ZIndex = target.ZIndex - 1
		shade.Parent = target
		Primitives.corner(shade, radius + math.floor(grow / 2))
	end
end

function Primitives.sheen(target: GuiObject, strength: number?): Frame
	local gloss = Instance.new("Frame")
	gloss.Name = "Sheen"
	gloss.BackgroundColor3 = Theme.color.white
	gloss.BackgroundTransparency = 1 - (strength or 0.34)
	gloss.BorderSizePixel = 0
	gloss.Size = UDim2.new(1, 0, 0.52, 0)
	gloss.ZIndex = target.ZIndex
	gloss.Parent = target

	local corner = target:FindFirstChildOfClass("UICorner")
	Primitives.corner(gloss, if corner then corner.CornerRadius.Offset else Theme.radius.card)

	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.68, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = gloss

	return gloss
end

function Primitives.innerLine(target: GuiObject, color: Color3?, inset: number?): Frame
	local amount = inset or 3
	local liner = Instance.new("Frame")
	liner.Name = "InnerLine"
	liner.AnchorPoint = Vector2.new(0.5, 0.5)
	liner.Position = UDim2.fromScale(0.5, 0.5)
	liner.Size = UDim2.new(1, -amount * 2, 1, -amount * 2)
	liner.BackgroundTransparency = 1
	liner.ZIndex = target.ZIndex
	liner.Parent = target

	local corner = target:FindFirstChildOfClass("UICorner")
	local base = if corner then corner.CornerRadius.Offset else Theme.radius.card
	Primitives.corner(liner, math.max(2, base - amount))

	local edge = Primitives.stroke(liner, color or Theme.color.lineBright, Theme.stroke.hair)
	edge.Transparency = 0.55

	return liner
end

function Primitives.divider(parent: Instance, color: Color3?): Frame
	local rule = Instance.new("Frame")
	rule.Name = "Divider"
	rule.BackgroundColor3 = color or Theme.color.lineSoft
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.ZIndex = 3
	rule.Parent = parent
	Primitives.corner(rule, 1)
	return rule
end

function Primitives.well(parent: Instance, name: string, config: { [string]: any }?): Frame
	local options = config or {}
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = options.color or Theme.color.paperSunken
	frame.BorderSizePixel = 0
	frame.ZIndex = options.zIndex or 3
	if options.extent then
		frame.Size = options.extent
	end
	if options.position then
		frame.Position = options.position
	end
	if options.anchor then
		frame.AnchorPoint = options.anchor
	end
	frame.Parent = parent

	Primitives.corner(frame, options.radius or Theme.radius.well)
	local edge = Primitives.stroke(frame, Theme.color.lineSoft, Theme.stroke.hair)
	edge.Transparency = 0.2

	local shade = Instance.new("Frame")
	shade.Name = "InnerShade"
	shade.BackgroundColor3 = Theme.color.shadow
	shade.BackgroundTransparency = 0.86
	shade.BorderSizePixel = 0
	shade.Size = UDim2.new(1, 0, 0, 10)
	shade.ZIndex = frame.ZIndex + 1
	shade.Parent = frame
	Primitives.corner(shade, options.radius or Theme.radius.well)

	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = shade

	return frame
end

local RING_TICKS = 44

function Primitives.ring(parent: Instance, name: string, config: { [string]: any }): (Frame, (fraction: number) -> ())
	local thickness = config.thickness or 8
	local color = config.color or Theme.color.leaf
	local track = config.trackColor or Theme.color.lineSoft
	local container = Instance.new("Frame")
	container.Name = name
	container.BackgroundTransparency = 1
	container.Size = config.extent or UDim2.fromOffset(96, 96)
	container.ZIndex = config.zIndex or 3
	if config.position then
		container.Position = config.position
	end
	if config.anchor then
		container.AnchorPoint = config.anchor
	end
	container.Parent = parent

	local radius = 0.42
	local ticks: { Frame } = {}
	local glows: { Frame } = {}
	for index = 1, RING_TICKS do
		local angle = (index - 1) / RING_TICKS * math.pi * 2
		local px = 0.5 + math.sin(angle) * radius
		local py = 0.5 - math.cos(angle) * radius
		local glow = Instance.new("Frame")
		glow.Name = `Glow_{index}`
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(px, py)
		glow.Size = UDim2.fromOffset(math.max(4, thickness * 0.9), thickness + 6)
		glow.Rotation = math.deg(angle)
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 1
		glow.BorderSizePixel = 0
		glow.ZIndex = container.ZIndex
		glow.Parent = container
		Primitives.corner(glow, 4)
		glows[index] = glow

		local tick = Instance.new("Frame")
		tick.Name = `Tick_{index}`
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(px, py)
		tick.Size = UDim2.fromOffset(math.max(2, thickness * 0.42), thickness)
		tick.Rotation = math.deg(angle)
		tick.BackgroundColor3 = track
		tick.BorderSizePixel = 0
		tick.ZIndex = container.ZIndex + 1
		tick.Parent = container
		Primitives.corner(tick, 2)
		ticks[index] = tick
	end

	local lit = -1

	local function setProgress(fraction: number)
		local clamped = math.clamp(fraction, 0, 1)
		local count = math.floor(clamped * RING_TICKS + 0.5)
		if count == lit then
			return
		end
		lit = count

		for index, tick in ticks do
			local on = index <= count
			tick.BackgroundColor3 = if on then color else track
			tick.BackgroundTransparency = if on then 0 else 0.5
			glows[index].BackgroundTransparency = if on and index > count - 4 then 0.72 else 1
		end
	end

	setProgress(config.progress or 0)
	return container, setProgress
end

function Primitives.vignette(parent: Instance, name: string, color: Color3): { Frame }
	local edges = {
		{ anchor = Vector2.new(0.5, 0), pos = UDim2.fromScale(0.5, 0), size = UDim2.new(1, 0, 0, 130), rot = 90 },
		{ anchor = Vector2.new(0.5, 1), pos = UDim2.fromScale(0.5, 1), size = UDim2.new(1, 0, 0, 130), rot = 270 },
		{ anchor = Vector2.new(0, 0.5), pos = UDim2.fromScale(0, 0.5), size = UDim2.new(0, 170, 1, 0), rot = 0 },
		{ anchor = Vector2.new(1, 0.5), pos = UDim2.fromScale(1, 0.5), size = UDim2.new(0, 170, 1, 0), rot = 180 },
	}

	local frames: { Frame } = {}
	for index, edge in edges do
		local frame = Instance.new("Frame")
		frame.Name = `{name}_{index}`
		frame.AnchorPoint = edge.anchor
		frame.Position = edge.pos
		frame.Size = edge.size
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ZIndex = 20
		frame.Parent = parent

		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = edge.rot
		gradient.Parent = frame

		frames[index] = frame
	end

	return frames
end

return Primitives

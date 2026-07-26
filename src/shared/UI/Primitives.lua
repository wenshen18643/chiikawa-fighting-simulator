--[[
	The small decorations every component is assembled from.

	Split out from the components themselves so there is exactly one place that
	decides what a corner radius, a border or a shadow is — otherwise every new
	panel invents its own and the interface drifts.
]]

local Theme = require(script.Parent.Theme)

local Primitives = {}

function Primitives.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.radius.card)
	corner.Parent = parent
	return corner
end

--[[
	The outline.

	Solid and heavy by default, where this used to be a 1.5px hairline at 35%
	transparency. A near-black border at full opacity is most of what separates
	the arcade look from a flat dark panel, and it is the one property that has
	to be consistent across every surface for the set to look like one thing.
]]
function Primitives.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.color.line
	stroke.Thickness = thickness or Theme.stroke.base
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 0
	stroke.Parent = parent
	return stroke
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

--[[
	A soft drop shadow, faked with a stack of offset frames rather than an image
	asset. Costs a few frames and needs no upload, which matters because the
	whole UI is built in code and has no asset dependencies.
]]
function Primitives.shadow(target: GuiObject, layers: number?)
	local count = layers or 3
	for index = count, 1, -1 do
		local shade = Instance.new("Frame")
		shade.Name = `Shadow_{index}`
		shade.AnchorPoint = target.AnchorPoint
		shade.Position = target.Position + UDim2.fromOffset(0, index)
		shade.Size = target.Size
		-- Near-black, and denser than the old warm-brown shadow: a soft brown
		-- haze under a dark panel is invisible, and the drop is part of the
		-- chunky look rather than a nicety.
		shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		shade.BackgroundTransparency = 0.62 + index * 0.08
		shade.BorderSizePixel = 0
		shade.ZIndex = target.ZIndex - 1
		shade.Parent = target.Parent
		Primitives.corner(shade, Theme.radius.card)
	end
end

function Primitives.aspect(parent: Instance, ratio: number): UIAspectRatioConstraint
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio
	constraint.Parent = parent
	return constraint
end

function Primitives.grid(parent: Instance, cell: UDim2, padding: UDim2?): UIGridLayout
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cell
	layout.CellPadding = padding or UDim2.fromOffset(Theme.space.tight, Theme.space.tight)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

--[[
	A radial progress meter, with no image assets.

	Built as N discrete tick marks arranged around a circle, lit up to the
	fraction. NOT as a swept arc: Roblox has no arc primitive, and the usual
	two-mask trick (clip the circle in half, rotate a leaf inside each half)
	only works if the leaf is a half-disc — rotate a FULL disc and nothing
	visibly moves, which is exactly the bug the obvious implementation has.

	Ticks sidestep the whole problem, and are honestly the better read for a
	gauge: they give the eye something to count.

	Returns `(container, setProgress)`. The caller never sees the ticks.

	Used for the stamina ring in the work core — the most looked-at number in
	the game, and worth not being another horizontal bar in a stack of them.
]]
local RING_TICKS = 40

function Primitives.ring(parent: Instance, name: string, config: { [string]: any }): (Frame, (fraction: number) -> ())
	local thickness = config.thickness or 8
	local color = config.color or Theme.color.leaf
	local track = config.trackColor or Theme.color.line

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

	-- Ticks sit on this radius, in scale. Leaves room inside for a glyph and a
	-- number without either crowding the ring.
	local radius = 0.42

	local ticks: { Frame } = {}
	for index = 1, RING_TICKS do
		--[[
			Clockwise from the top, which is how every dial a player has ever
			seen reads. Screen +Y is DOWN, so "up" from the centre is -Y and the
			cosine term is subtracted.
		]]
		local angle = (index - 1) / RING_TICKS * math.pi * 2

		local tick = Instance.new("Frame")
		tick.Name = `Tick_{index}`
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5 + math.sin(angle) * radius, 0.5 - math.cos(angle) * radius)
		tick.Size = UDim2.fromOffset(math.max(2, thickness * 0.42), thickness)
		-- A Frame at rotation 0 has its long axis vertical, which is radial at
		-- the top of the circle — so the rotation IS the bearing, unchanged.
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
			tick.BackgroundTransparency = if on then 0 else 0.45
		end
	end

	setProgress(config.progress or 0)
	return container, setProgress
end

--[[
	A vignette: four edge gradients that darken or tint the screen border.

	Used for the click pulse. Four frames rather than one image keeps the
	no-assets rule and costs nothing, since they are transparent at rest.
]]
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

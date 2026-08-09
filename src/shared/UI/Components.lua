local Motion = require(script.Parent.Motion)
local Primitives = require(script.Parent.Primitives)
local Responsive = require(script.Parent.Responsive)
local Theme = require(script.Parent.Theme)
local Components = {}

export type LabelConfig = {
	text: string?,
	font: Enum.Font?,
	size: number?,
	color: Color3?,
	align: Enum.TextXAlignment?,
	position: UDim2?,
	extent: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	wrapped: boolean?,
	rich: boolean?,
	scaled: boolean?,
}

local function surfaceOf(key: string?): { fill: Color3 }
	return (Theme.surface :: any)[key or "canvas"] or Theme.surface.canvas
end

function Components.card(parent: Instance, name: string, config: { [string]: any }?): Frame
	local options = config or {}
	local surface = surfaceOf(options.surface)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = options.color or surface.fill
	frame.BackgroundTransparency = options.transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = options.zIndex or 2
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

	local radius = options.radius or Theme.radius.card
	Primitives.corner(frame, radius)

	if options.stroke ~= false then
		Primitives.stroke(frame, options.strokeColor or Theme.color.lineCard, options.strokeWidth or Theme.stroke.hair)
	end

	if options.sheen == true then
		Primitives.sheen(frame, options.sheenStrength or 0.3)
	end

	if options.innerLine == true then
		Primitives.innerLine(frame)
	end

	if options.elevation then
		Primitives.shadow(frame, options.elevation)
	end

	return frame
end

function Components.label(parent: Instance, name: string, config: LabelConfig): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = config.font or Theme.font.body
	text.TextColor3 = config.color or Theme.color.ink
	text.TextSize = config.size or Theme.text.body
	text.TextScaled = config.scaled == true
	text.TextXAlignment = config.align or Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.TextWrapped = config.wrapped == true
	text.RichText = config.rich == true
	text.Text = config.text or ""
	text.ZIndex = config.zIndex or 3

	if config.position then
		text.Position = config.position
	end
	if config.extent then
		text.Size = config.extent
	end
	if config.anchor then
		text.AnchorPoint = config.anchor
	end

	text.Parent = parent
	return text
end

function Components.bar(parent: Instance, name: string, fillColor: Color3): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = name
	track.BackgroundColor3 = Theme.color.paperSunken
	track.BorderSizePixel = 0
	track.ZIndex = 3
	track.Parent = parent
	Primitives.corner(track, Theme.radius.bar)

	local trackEdge = Primitives.stroke(track, Theme.color.lineSoft, Theme.stroke.hair)
	trackEdge.Transparency = 0.25

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = track
	Primitives.corner(fill, Theme.radius.bar)
	Primitives.gradient(fill, Theme.lighten(fillColor, 0.3), fillColor, 90)

	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.Size = UDim2.new(1, 0, 0.46, 0)
	gloss.BackgroundColor3 = Theme.color.white
	gloss.BackgroundTransparency = 0.66
	gloss.BorderSizePixel = 0
	gloss.ZIndex = 5
	gloss.Parent = fill
	Primitives.corner(gloss, Theme.radius.bar)

	return track, fill
end

function Components.chip(parent: Instance, name: string, config: { [string]: any }): Frame
	local base = Theme.fill(config.color or Theme.color.paperDeep)
	local chip = Instance.new("Frame")
	chip.Name = name
	chip.BackgroundColor3 = base
	chip.BorderSizePixel = 0
	chip.ZIndex = config.zIndex or 3
	if config.position then
		chip.Position = config.position
	end
	if config.extent then
		chip.Size = config.extent
	end
	if config.anchor then
		chip.AnchorPoint = config.anchor
	end
	chip.Parent = parent

	Primitives.corner(chip, config.radius or Theme.radius.chip)
	if config.stroke ~= false then
		Primitives.stroke(chip, config.strokeColor, Theme.stroke.base)
	end
	Primitives.sheen(chip, 0.24)

	Components.label(chip, "Text", {
		text = config.text,
		font = config.font or Theme.font.bold,
		size = config.textSize or Theme.text.small,
		color = Theme.legible(base, config.textColor),
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 1),
		zIndex = (config.zIndex or 3) + 2,
	})

	return chip
end

local function laidOut(button: TextButton): boolean
	local parent = button.Parent
	if not parent then
		return false
	end
	return parent:FindFirstChildOfClass("UIListLayout") ~= nil or parent:FindFirstChildOfClass("UIGridLayout") ~= nil
end

local function attachButtonStates(button: TextButton, base: Color3, config: { [string]: any }, focusRing: UIStroke)
	local hovered = false
	local held = false
	local home = button.Position
	local canLift = not laidOut(button)

	local function paint()
		local color = base
		if held then
			color = Theme.darken(base, Theme.state.press.darken)
		elseif hovered then
			color = Theme.lighten(base, Theme.state.hover.lighten)
		end

		local goal: { [string]: any } = { BackgroundColor3 = color }

		if canLift then
			local lift = 0
			if held then
				lift = Theme.state.press.lift
			elseif hovered then
				lift = -Theme.state.hover.lift
			end
			goal.Position = home + UDim2.fromOffset(0, lift)
		end

		Motion.to(button, if held then Motion.press else Motion.hover, goal)
	end

	button.MouseEnter:Connect(function()
		hovered = true
		paint()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		held = false
		paint()
	end)
	button.MouseButton1Down:Connect(function()
		held = true
		paint()
	end)
	button.MouseButton1Up:Connect(function()
		held = false
		paint()
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			held = true
			paint()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			held = false
			paint()
		end
	end)
	button.SelectionGained:Connect(function()
		focusRing.Transparency = 0
	end)
	button.SelectionLost:Connect(function()
		focusRing.Transparency = 1
	end)

	if config.onActivated then
		button.Activated:Connect(function()
			if canLift then
				Motion.to(button, Motion.release, { Position = home })
			end
			config.onActivated()
		end)
	end
end

local function attachPressScale(button: TextButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button

	local function setHeld(held: boolean)
		Motion.to(scale, if held then Motion.press else Motion.release, { Scale = if held then 0.96 else 1 })
	end
	button.MouseButton1Down:Connect(function()
		setHeld(true)
	end)
	button.MouseButton1Up:Connect(function()
		setHeld(false)
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			setHeld(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			setHeld(false)
		end
	end)
end

function Components.button(parent: Instance, name: string, config: { [string]: any }): TextButton
	local base = Theme.fill(config.color or Theme.color.paperRaised)
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = base
	button.BorderSizePixel = 0
	button.AutoButtonColor = config.autoColor == true
	button.Font = config.font or Theme.font.bold
	button.Text = config.text or ""
	button.TextSize = config.textSize or Theme.text.small
	button.TextColor3 = Theme.legible(base, config.textColor)
	button.ZIndex = config.zIndex or 3
	if config.position then
		button.Position = config.position
	end
	if config.extent then
		button.Size = config.extent
	end
	if config.anchor then
		button.AnchorPoint = config.anchor
	end
	button.Parent = parent

	Primitives.corner(button, config.radius or Theme.radius.chip)
	local focusRing = Primitives.focusRing(button, config.focusColor)
	if config.stroke ~= false then
		Primitives.stroke(button, config.strokeColor, Theme.stroke.base)
	end
	if config.sheen == true then
		Primitives.sheen(button, 0.3)
	end
	if config.elevation then
		Primitives.shadow(button, config.elevation)
	end

	if button.AutoButtonColor or config.states == false then
		if config.states == false then
			attachPressScale(button)
		end
		if config.onActivated then
			button.Activated:Connect(config.onActivated)
		end
	else
		attachButtonStates(button, base, config, focusRing)
	end
	if button.AutoButtonColor or config.states == false then
		button.SelectionGained:Connect(function()
			focusRing.Transparency = 0
		end)
		button.SelectionLost:Connect(function()
			focusRing.Transparency = 1
		end)
	end

	return button
end

function Components.header(parent: Instance, name: string, config: { [string]: any }): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Size = config.extent or UDim2.new(1, 0, 0, 44)
	row.ZIndex = config.zIndex or 4
	if config.position then
		row.Position = config.position
	end
	row.Parent = parent

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.AnchorPoint = Vector2.new(0, 0.5)
	accent.Position = UDim2.new(0, 0, 0.5, 0)
	accent.Size = UDim2.fromOffset(6, 26)
	accent.BackgroundColor3 = config.accent or Theme.color.blush
	accent.BorderSizePixel = 0
	accent.ZIndex = row.ZIndex + 1
	accent.Parent = row
	Primitives.corner(accent, 3)

	Components.label(row, "Title", {
		text = config.title,
		font = Theme.font.display,
		size = config.titleSize or Theme.text.title,
		color = Theme.color.ink,
		position = UDim2.fromOffset(16, 0),
		extent = UDim2.new(1, -16, if config.subtitle then 0.6 else 1, 0),
		zIndex = row.ZIndex + 1,
	})

	if config.subtitle then
		Components.label(row, "Subtitle", {
			text = config.subtitle,
			font = Theme.font.light,
			size = Theme.text.caption,
			color = Theme.color.inkSoft,
			position = UDim2.new(0, 16, 0.6, 0),
			extent = UDim2.new(1, -16, 0.4, 0),
			zIndex = row.ZIndex + 1,
		})
	end

	return row
end

function Components.meter(parent: Instance, name: string, config: { [string]: any }): (Frame, (number) -> ())
	local color = config.color or Theme.color.leaf
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Size = config.extent or UDim2.new(1, 0, 0, 30)
	holder.ZIndex = config.zIndex or 3
	if config.position then
		holder.Position = config.position
	end
	holder.Parent = parent

	if config.caption then
		Components.label(holder, "Caption", {
			text = config.caption,
			font = Theme.font.bold,
			size = Theme.text.caption,
			color = Theme.color.inkSoft,
			extent = UDim2.new(1, 0, 0, 12),
			zIndex = holder.ZIndex + 1,
		})
	end

	local track, fill = Components.bar(holder, "Track", color)
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.fromScale(0, 1)
	track.Size = UDim2.new(1, 0, 0, config.thickness or 14)
	track.ZIndex = holder.ZIndex + 1

	return holder,
		function(fraction: number)
			Motion.to(fill, Motion.settle, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
		end
end

function Components.sign(adornee: BasePart, config: { [string]: any }): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = config.name or "Sign"
	gui.Size = config.extent or UDim2.fromScale(14, 4)
	gui.StudsOffsetWorldSpace = config.offset or Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = config.alwaysOnTop == true
	gui.MaxDistance = config.maxDistance or 250
	gui.Parent = adornee

	local hasSubtitle = config.subtitle ~= nil

	local title = Components.label(gui, "Title", {
		text = config.title,
		font = Theme.font.display,
		color = config.titleColor or Theme.color.white,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, if hasSubtitle then 0.55 else 1),
		scaled = true,
	})
	title.TextStrokeColor3 = Theme.color.glassDark
	title.TextStrokeTransparency = 0.25

	if hasSubtitle then
		local subtitle = Components.label(gui, "Subtitle", {
			text = config.subtitle,
			font = Theme.font.light,
			color = config.subtitleColor or Theme.color.white,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromScale(0, 0.55),
			extent = UDim2.fromScale(1, 0.45),
			scaled = true,
		})
		subtitle.TextStrokeColor3 = Theme.color.glassDark
		subtitle.TextStrokeTransparency = 0.45
	end

	return gui
end

function Components.ticker(parent: Instance, name: string, config: LabelConfig): (TextLabel, (string, number?) -> ())
	local label = Components.label(parent, name, config)
	local displayed: number? = nil
	local target: number? = nil
	local pending: string = label.Text
	local running = false

	local function flash()
		label.TextColor3 = Theme.color.gold
		Motion.to(label, Motion.settle, { TextColor3 = config.color or Theme.color.ink })
	end

	local function set(text: string, numeric: number?)
		if text == pending then
			return
		end
		pending = text

		if not numeric or not displayed then
			displayed = numeric
			target = numeric
			label.Text = text
			flash()
			return
		end

		target = numeric
		if running then
			return
		end
		running = true

		task.spawn(function()
			while running do
				local goal = target
				local current = displayed
				if not goal or not current then
					break
				end
				if math.abs(goal - current) < math.max(1, math.abs(goal) * 0.001) then
					displayed = goal
					label.Text = pending
					break
				end
				displayed = current + (goal - current) * 0.25
				label.Text = string.format("%.0f", displayed)
				task.wait(0.03)
			end
			running = false
			label.Text = pending
			flash()
		end)
	end

	return label, set
end

function Components.pips(parent: Instance, name: string, config: { [string]: any }): (Frame, (number) -> ())
	local total = config.total or 7
	local color = config.color or Theme.color.leaf
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.ZIndex = config.zIndex or 3
	if config.position then
		row.Position = config.position
	end
	row.Size = config.extent or UDim2.new(1, 0, 0, 5)
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local pips: { Frame } = {}
	for index = 1, total do
		local pip = Instance.new("Frame")
		pip.Name = `Pip_{index}`
		pip.LayoutOrder = index
		pip.Size = UDim2.new(1 / total, -2, 1, 0)
		pip.BackgroundColor3 = Theme.color.lineSoft
		pip.BorderSizePixel = 0
		pip.ZIndex = row.ZIndex
		pip.Parent = row
		Primitives.corner(pip, 3)
		pips[index] = pip
	end

	local function setFilled(filled: number)
		for index, pip in pips do
			local lit = index <= filled
			pip.BackgroundColor3 = if lit then color else Theme.color.lineSoft
			pip.BackgroundTransparency = if lit then 0 else 0.3
		end
	end

	setFilled(config.filled or 0)
	return row, setFilled
end

function Components.tabs(
	parent: Instance,
	name: string,
	config: { [string]: any }
): (Frame, (string) -> (), () -> string)
	local entries = config.entries :: { { key: string, label: string } }
	local current = config.initial or entries[1].key
	local accent = config.accent or Theme.color.blush

	local bar = Primitives.well(parent, name, {
		extent = config.extent or UDim2.new(1, 0, 0, 40),
		position = config.position,
		zIndex = config.zIndex or 4,
		radius = Theme.radius.pill,
	})

	local container = Instance.new("Frame")
	container.Name = "TabContainer"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.ZIndex = bar.ZIndex + 2
	container.Parent = bar

	Primitives.padding(container, 4)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local buttons: { [string]: TextButton } = {}
	local pills: { [string]: Frame } = {}
	local activate

	for index, entry in entries do
		local slot = Instance.new("Frame")
		slot.Name = `{entry.key}Slot`
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.new(1 / #entries, 0, 1, 0)
		slot.LayoutOrder = index
		slot.ZIndex = container.ZIndex
		slot.Parent = container

		local pill = Instance.new("Frame")
		pill.Name = "Pill"
		pill.AnchorPoint = Vector2.new(0.5, 0.5)
		pill.Position = UDim2.fromScale(0.5, 0.5)
		pill.Size = UDim2.new(1, -4, 1, 0)
		pill.BackgroundColor3 = Theme.color.paperSunken
		pill.BorderSizePixel = 0
		pill.ZIndex = slot.ZIndex + 1
		pill.Parent = slot
		Primitives.corner(pill, Theme.radius.pill)
		pills[entry.key] = pill

		local button = Components.button(slot, entry.key, {
			text = entry.label,
			textSize = Theme.text.small,
			extent = UDim2.fromScale(1, 1),
			radius = Theme.radius.pill,
			zIndex = slot.ZIndex + 2,
			color = Theme.color.paperSunken,
			stroke = false,
			sheen = false,
			states = false,

			onActivated = function()
				activate(entry.key)
			end,
		})
		button.BackgroundTransparency = 1
		buttons[entry.key] = button
	end

	function activate(key: string)
		current = key
		for entryKey, button in buttons do
			local active = entryKey == key
			Motion.to(pills[entryKey], Motion.settle, {
				BackgroundColor3 = if active then accent else Theme.color.paperSunken,
			})
			Motion.to(button, Motion.settle, {
				TextColor3 = if active then Theme.color.ink else Theme.color.inkSoft,
			})
		end
		if config.onChanged then
			config.onChanged(key)
		end
	end

	activate(current)
	return bar, activate, function()
		return current
	end
end

function Components.modal(
	parent: Instance,
	name: string,
	config: { [string]: any }
): (Frame, Frame, (boolean, boolean?) -> ())
	local extent = config.extent or UDim2.fromScale(0.72, 0.76)
	local scrim = Instance.new("TextButton")
	scrim.Name = `{name}_Scrim`
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Theme.color.scrim
	scrim.BackgroundTransparency = 1
	scrim.BorderSizePixel = 0
	scrim.AutoButtonColor = false
	scrim.Text = ""
	scrim.Visible = false
	scrim.ZIndex = config.zIndex or 30
	scrim.Parent = parent

	local blocker = Instance.new("TextButton")
	blocker.Name = "PanelBlocker"
	blocker.AnchorPoint = Vector2.new(0.5, 0.5)
	blocker.Position = UDim2.fromScale(0.5, 0.5)
	blocker.BackgroundTransparency = 1
	blocker.BorderSizePixel = 0
	blocker.AutoButtonColor = false
	blocker.Text = ""
	blocker.ZIndex = scrim.ZIndex
	blocker.Parent = scrim

	local panel = Components.card(scrim, "Panel", {
		zIndex = scrim.ZIndex + 1,
		radius = Theme.radius.card,
		surface = "overlay",
		strokeWidth = Theme.stroke.heavy,
	})
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Active = true
	blocker.Size = panel.Size
	panel:GetPropertyChangedSignal("Size"):Connect(function()
		blocker.Size = panel.Size
	end)

	local setOpen
	local openState = false
	local generation = 0
	local activeTweens: { Tween } = {}

	local function cancelTweens()
		for _, tween in activeTweens do
			tween:Cancel()
		end
		table.clear(activeTweens)
	end

	local function targetSize(): (UDim2, boolean)
		return Responsive.panelSize(extent, config.maxSize)
	end

	local function applyLayout()
		local size, compact = targetSize()
		if openState then
			panel.Size = size
		end
		local corner = panel:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, if compact then Theme.radius.well else Theme.radius.card)
		end
		if config.onResponsiveChanged then
			config.onResponsiveChanged(compact, size)
		end
	end

	local function close()
		if config.onDismiss then
			config.onDismiss()
		else
			setOpen(false)
		end
	end
	if config.dismissOnBackground ~= false then
		scrim.Activated:Connect(close)
	end

	function setOpen(open: boolean, instant: boolean?)
		generation += 1
		local request = generation
		openState = open
		cancelTweens()
		local size = targetSize()
		if open then
			scrim.Visible = true
			panel.Size = UDim2.new(size.X.Scale * 0.96, size.X.Offset * 0.96, size.Y.Scale * 0.96, size.Y.Offset * 0.96)
			panel.Rotation = -1.5
			if instant then
				scrim.BackgroundTransparency = Theme.opacity.veil
				panel.Size = size
				panel.Rotation = 0
			else
				table.insert(activeTweens, Motion.play(scrim, Motion.settle, { BackgroundTransparency = Theme.opacity.veil }))
				table.insert(activeTweens, Motion.play(panel, Motion.pop, { Size = size, Rotation = 0 }))
			end
		else
			if instant then
				scrim.BackgroundTransparency = 1
				scrim.Visible = false
			else
				local fade = Motion.play(scrim, Motion.snap, { BackgroundTransparency = 1 })
				table.insert(activeTweens, fade)
				table.insert(activeTweens, Motion.play(panel, Motion.snap, { Rotation = 1 }))
				fade.Completed:Connect(function()
					if generation == request and not openState then
						scrim.Visible = false
					end
				end)
			end
		end
		if config.onToggled then
			config.onToggled(open)
		end
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local current = workspace.CurrentCamera
		if current then
			current:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
		end
		applyLayout()
	end)
	applyLayout()

	return scrim :: any, panel, setOpen
end

return Components

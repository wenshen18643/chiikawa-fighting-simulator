--[[
	Reusable UI components. Import via the UI barrel:

		local UI = require(ReplicatedStorage.Shared.UI)
		local card = UI.card(parent, "Purse")
		UI.label(card, "Title", { text = "¥ 120", font = UI.font.display })

	Every component takes (parent, name, config) and returns the Instance, so
	they compose without a framework and without any build step.

	Usable from BOTH realms: the client builds ScreenGui panels out of these and
	the server builds world-space signs out of the same pieces.
]]

local Motion = require(script.Parent.Motion)
local Primitives = require(script.Parent.Primitives)
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

--[[
	A panel. The base surface for everything in the HUD.
]]
function Components.card(parent: Instance, name: string, config: { [string]: any }?): Frame
	local options = config or {}

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = options.color or Theme.color.paper
	frame.BackgroundTransparency = options.transparency or 0.02
	frame.BorderSizePixel = 0
	frame.ZIndex = options.zIndex or 2
	frame.Parent = parent

	Primitives.corner(frame, options.radius or Theme.radius.card)
	if options.stroke ~= false then
		Primitives.stroke(frame, options.strokeColor)
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

--[[
	A rounded progress bar. Returns both track and fill: callers resize and
	recolour the fill, the track is inert once built.
]]
function Components.bar(parent: Instance, name: string, fillColor: Color3): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = name
	track.BackgroundColor3 = Theme.color.paperDeep
	track.BorderSizePixel = 0
	track.ZIndex = 3
	track.Parent = parent
	Primitives.corner(track, Theme.radius.bar)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = track
	Primitives.corner(fill, Theme.radius.bar)
	Primitives.gradient(fill, fillColor, fillColor:Lerp(Theme.color.white, 0.35))

	return track, fill
end

--[[
	A small rounded key/value pill — used for keycaps in the controls panel and
	for status tags elsewhere.
]]
function Components.chip(parent: Instance, name: string, config: { [string]: any }): Frame
	local chip = Instance.new("Frame")
	chip.Name = name
	chip.BackgroundColor3 = config.color or Theme.color.paperDeep
	chip.BorderSizePixel = 0
	chip.ZIndex = config.zIndex or 3
	if config.position then
		chip.Position = config.position
	end
	if config.extent then
		chip.Size = config.extent
	end
	chip.Parent = parent

	Primitives.corner(chip, Theme.radius.chip)
	if config.stroke ~= false then
		Primitives.stroke(chip)
	end

	Components.label(chip, "Text", {
		text = config.text,
		font = config.font or Theme.font.bold,
		size = config.textSize or Theme.text.small,
		color = config.textColor or Theme.color.ink,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 1),
		zIndex = (config.zIndex or 3) + 1,
	})

	return chip
end

function Components.button(parent: Instance, name: string, config: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = config.color or Theme.color.paperDeep
	button.BorderSizePixel = 0
	button.AutoButtonColor = config.autoColor ~= false
	button.Font = config.font or Theme.font.bold
	button.Text = config.text or ""
	button.TextSize = config.textSize or Theme.text.small
	button.TextColor3 = config.textColor or Theme.color.ink
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
	if config.stroke then
		Primitives.stroke(button)
	end
	if config.onActivated then
		button.Activated:Connect(config.onActivated)
	end

	return button
end

--[[
	A world-space sign: a BillboardGui with a title and optional subtitle,
	styled the same as the HUD. This is what area files use to label places
	without each one hand-rolling a BillboardGui.
]]
function Components.sign(adornee: BasePart, config: { [string]: any }): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = config.name or "Sign"
	gui.Size = config.extent or UDim2.fromScale(14, 4)
	gui.StudsOffsetWorldSpace = config.offset or Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = config.alwaysOnTop == true
	gui.MaxDistance = config.maxDistance or 250
	gui.Parent = adornee

	local hasSubtitle = config.subtitle ~= nil

	Components.label(gui, "Title", {
		text = config.title,
		font = Theme.font.display,
		color = config.titleColor or Theme.color.white,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, if hasSubtitle then 0.55 else 1),
		scaled = true,
	}).TextStrokeTransparency =
		0.4

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
		subtitle.TextStrokeTransparency = 0.6
	end

	return gui
end

--------------------------------------------------------------------------------
-- Composite components
--------------------------------------------------------------------------------

--[[
	A number that counts to its new value instead of snapping to it.

	Worth the machinery on exactly the values the player is trying to make go up.
	A purse that jumps from 1,200 to 1,340 reports a fact; one that runs up to it
	shows income arriving, and that is the entire feedback loop of an incremental
	game rendered in one control.

	Returns `set(text, numeric)`. `numeric` is optional: BigNumbers past the
	double range cannot be interpolated meaningfully, so the caller passes a
	number when it has one and the ticker falls back to a flash when it does not.
]]
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
			-- Eased toward the target rather than stepped: an income that
			-- arrives in bursts still reads as a smooth climb.
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

--[[
	A row of small segments, filled up to `count`. The tier strip beside each
	skill: seven pips, one per worksite tier, lit for the ones you have unlocked.

	A bar tells you how far along you are; pips tell you how many discrete things
	there are and exactly which one you are on. For a ladder with named rungs,
	that is the more useful shape.
]]
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
	row.Size = config.extent or UDim2.new(1, 0, 0, 4)
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
		-- Scale width so the strip fits whatever it is given, minus the gaps.
		pip.Size = UDim2.new(1 / total, -2, 1, 0)
		pip.BackgroundColor3 = Theme.color.line
		pip.BorderSizePixel = 0
		pip.ZIndex = row.ZIndex
		pip.Parent = row
		Primitives.corner(pip, 2)
		pips[index] = pip
	end

	local function setFilled(filled: number)
		for index, pip in pips do
			local lit = index <= filled
			pip.BackgroundColor3 = if lit then color else Theme.color.line
			pip.BackgroundTransparency = if lit then 0 else 0.35
		end
	end

	setFilled(config.filled or 0)
	return row, setFilled
end

--[[
	A tab bar. Returns the bar and `select(key)`; the caller supplies an
	`onChanged` and owns the panels.
]]
function Components.tabs(
	parent: Instance,
	name: string,
	config: { [string]: any }
): (Frame, (string) -> (), () -> string)
	local entries = config.entries :: { { key: string, label: string } }
	local current = config.initial or entries[1].key

	local bar = Instance.new("Frame")
	bar.Name = name
	bar.BackgroundTransparency = 1
	bar.ZIndex = config.zIndex or 4
	bar.Size = config.extent or UDim2.new(1, 0, 0, 36)
	if config.position then
		bar.Position = config.position
	end
	bar.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, Theme.space.tight)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local buttons: { [string]: TextButton } = {}
	-- Named `activate` rather than `select`: that is a Lua builtin, and shadowing
	-- it makes every call site look like a varargs bug.
	local activate

	for index, entry in entries do
		local button = Components.button(bar, entry.key, {
			text = entry.label,
			textSize = Theme.text.body,
			extent = UDim2.new(1 / #entries, -Theme.space.tight, 1, 0),
			radius = Theme.radius.chip,
			zIndex = bar.ZIndex,
			onActivated = function()
				activate(entry.key)
			end,
		})
		button.LayoutOrder = index
		button.AutoButtonColor = false
		buttons[entry.key] = button
	end

	function activate(key: string)
		current = key
		for entryKey, button in buttons do
			local active = entryKey == key
			Motion.to(button, Motion.snap, {
				BackgroundColor3 = if active then Theme.color.leaf else Theme.color.paperDeep,
				TextColor3 = if active then Theme.color.white else Theme.color.inkSoft,
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

--[[
	A full-screen panel with a scrim behind it.

	Returns the content frame and `setOpen(boolean)`. The scrim absorbs clicks so
	the world underneath cannot be interacted with while the panel is up, and it
	closes on click, which is what everybody tries first.
]]
function Components.modal(parent: Instance, name: string, config: { [string]: any }): (Frame, Frame, (boolean) -> ())
	local scrim = Instance.new("TextButton")
	scrim.Name = `{name}_Scrim`
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.fromRGB(40, 34, 30)
	scrim.BackgroundTransparency = 1
	scrim.BorderSizePixel = 0
	scrim.AutoButtonColor = false
	scrim.Text = ""
	scrim.Visible = false
	scrim.ZIndex = config.zIndex or 30
	scrim.Parent = parent

	local panel = Components.card(scrim, "Panel", {
		zIndex = scrim.ZIndex + 1,
		radius = Theme.radius.card,
	})
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = config.extent or UDim2.fromScale(0.72, 0.76)

	local setOpen
	local function close()
		setOpen(false)
	end
	scrim.Activated:Connect(close)

	function setOpen(open: boolean)
		if open then
			scrim.Visible = true
			panel.Size = UDim2.new(
				panel.Size.X.Scale * 0.96,
				panel.Size.X.Offset,
				panel.Size.Y.Scale * 0.96,
				panel.Size.Y.Offset
			)
			Motion.to(scrim, Motion.settle, { BackgroundTransparency = 0.45 })
			Motion.to(panel, Motion.pop, { Size = config.extent or UDim2.fromScale(0.72, 0.76) })
		else
			local fade = Motion.play(scrim, Motion.snap, { BackgroundTransparency = 1 })
			fade.Completed:Connect(function()
				scrim.Visible = false
			end)
		end
		if config.onToggled then
			config.onToggled(open)
		end
	end

	return scrim :: any, panel, setOpen
end

return Components

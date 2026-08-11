local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local InputMode = require(script.Parent.InputMode)
local TutorialContent = require(script.Parent.TutorialContent)
local UIManager = require(script.Parent.UIManager)
local ControlsPanel = {}
local MENU_ID = "field-guide"
local PAGE_EDGE_GUTTER = 6
local PAGE_SCROLLBAR_GUTTER = 16
local HERO_PADDING = 18
local HERO_ACCENT_INSET = 4
local HERO_ACCENT_WIDTH = 6
local HERO_ACCENT_GAP = 12
local HERO_ACCENT_BLEED = 2
local HERO_TEXT_INSET = HERO_ACCENT_INSET + HERO_ACCENT_WIDTH + HERO_ACCENT_GAP
local PANEL_MARGIN = UI.space.loose
local PANEL_MIN = Vector2.new(640, 420)
local PANEL_MAX = Vector2.new(960, 680)
local HEADER_HEIGHT = 78
local NAV_WIDTH = 164
local screen: ScreenGui
local scrim: TextButton
local panel: Frame
local headerRule: Frame
local closeButton: TextButton
local navigation: ScrollingFrame
local navigationLayout: UIListLayout
local contentHost: Frame
local open = false
local acknowledged = false
local currentPage = "start"
local closedListeners: { (firstSession: boolean) -> () } = {}
local pages: { TutorialContent.Page } = {}
local pageViews: { [string]: ScrollingFrame } = {}
local pageButtons: { [string]: TextButton } = {}
local animationGeneration = 0
local activeTweens: { Tween } = {}
local applyOpen: (boolean, boolean?) -> ()

local function accentFor(key: string?): Color3
	if not key then
		return UI.color.leaf
	end
	return (UI.color :: any)[key] or UI.color.leaf
end

local function autoLabel(parent: Instance, name: string, text: string, options: { [string]: any }?): TextLabel
	local config = options or {}
	local label = UI.label(parent, name, {
		text = text,
		font = config.font or UI.font.body,
		size = config.size or UI.text.small,
		color = config.color or UI.color.ink,
		align = config.align,
		extent = UDim2.new(1, 0, 0, 0),
		wrapped = true,
		zIndex = config.zIndex or 25,
	})
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function addBullet(parent: Instance, index: number, copy: string, accent: Color3)
	local row = Instance.new("Frame")
	row.Name = `Bullet_{index}`
	row.Size = UDim2.new(1, 0, 0, 22)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.LayoutOrder = index
	row.ZIndex = 25
	row.Parent = parent

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromOffset(7, 10)
	marker.Size = UDim2.fromOffset(8, 8)
	marker.BackgroundColor3 = accent
	marker.BorderSizePixel = 0
	marker.ZIndex = 26
	marker.Parent = row
	UI.corner(marker, UI.radius.pill)

	local label = autoLabel(row, "Copy", copy, {
		font = UI.font.light,
		color = UI.color.inkSoft,
		zIndex = 26,
	})
	label.Position = UDim2.fromOffset(24, 0)
	label.Size = UDim2.new(1, -24, 0, 0)
end

local function addStandardRow(parent: Instance, index: number, rowData: TutorialContent.Row, style: string)
	local accent = accentFor(rowData.accent)
	local row = UI.card(parent, `Row_{index}`, {
		color = UI.color.paper,
		transparency = 0.18,
		radius = UI.radius.chip,
		stroke = false,
		zIndex = 25,
	})
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = index
	UI.padding(row, 12)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row

	local label = autoLabel(row, "Label", string.upper(rowData.label), {
		font = UI.font.bold,
		size = UI.text.caption,
		color = if style == "skills" then accent else UI.color.inkFaint,
		zIndex = 26,
	})
	label.LayoutOrder = 1

	local value = autoLabel(row, "Value", rowData.value, {
		font = if style == "table" then UI.font.bold else UI.font.body,
		size = if style == "table" then UI.text.body else UI.text.small,
		zIndex = 26,
	})
	value.LayoutOrder = 2

	if rowData.note then
		local note = autoLabel(row, "Note", rowData.note, {
			font = UI.font.light,
			size = 12,
			color = UI.color.inkSoft,
			zIndex = 26,
		})
		note.LayoutOrder = 3
	end
end

local function addTimelineRow(parent: Instance, index: number, rowData: TutorialContent.Row)
	local accent = accentFor(rowData.accent)
	local row = UI.card(parent, `Stop_{index}`, {
		color = UI.color.paper,
		transparency = 0.14,
		radius = UI.radius.chip,
		stroke = false,
		zIndex = 25,
	})
	row.Size = UDim2.new(1, 0, 0, 78)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = index
	row.ClipsDescendants = true

	local rail = Instance.new("Frame")
	rail.Name = "Route"
	rail.Position = UDim2.fromOffset(14, 0)
	rail.Size = UDim2.new(0, 4, 1, 0)
	rail.BackgroundColor3 = accent
	rail.BorderSizePixel = 0
	rail.ZIndex = 26
	rail.Parent = row
	UI.corner(rail, UI.radius.pill)

	local time = UI.chip(row, "Time", {
		text = rowData.label,
		color = UI.color.paperDeep,
		textColor = accent,
		textSize = 11,
		extent = UDim2.fromOffset(74, 26),
		position = UDim2.fromOffset(28, 12),
		stroke = false,
		zIndex = 27,
	})
	time.AnchorPoint = Vector2.zero

	local copy = Instance.new("Frame")
	copy.Name = "Copy"
	copy.Position = UDim2.fromOffset(116, 10)
	copy.Size = UDim2.new(1, -166, 0, 0)
	copy.AutomaticSize = Enum.AutomaticSize.Y
	copy.BackgroundTransparency = 1
	copy.ZIndex = 26
	copy.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = copy

	local title = autoLabel(copy, "Action", rowData.value, {
		font = UI.font.bold,
		size = UI.text.body,
		zIndex = 27,
	})
	title.LayoutOrder = 1

	if rowData.note then
		local note = autoLabel(copy, "Note", rowData.note, {
			font = UI.font.light,
			size = 12,
			color = UI.color.inkSoft,
			zIndex = 27,
		})
		note.LayoutOrder = 2
	end

	local complete = false
	local check: TextButton
	check = UI.button(row, "Check", {
		text = "",
		color = UI.color.paperDeep,
		textColor = UI.readable(UI.color.paperDeep),
		textSize = 16,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 0, 12),
		extent = UDim2.fromOffset(28, 28),
		radius = UI.radius.pill,
		stroke = true,
		zIndex = 28,

		onActivated = function()
			complete = not complete
			check.Text = if complete then "✓" else ""
			UI.motion.to(check, UI.motion.snap, {
				BackgroundColor3 = if complete then accent else UI.color.paperDeep,
			})
			UI.motion.to(row, UI.motion.snap, {
				BackgroundTransparency = if complete then 0.42 else 0.14,
			})
		end,
	})
end

local function buildBlock(parent: ScrollingFrame, index: number, block: TutorialContent.Block, pageAccent: Color3)
	local card = UI.card(parent, `Block_{index}`, {
		color = UI.color.paperDeep,
		transparency = 0.08,
		radius = UI.radius.tile,
		stroke = false,
		sheen = false,
		innerLine = false,
		zIndex = 23,
	})
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = index + 1
	UI.padding(card, UI.space.base)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 9)
	layout.Parent = card

	local title = autoLabel(card, "Title", block.title, {
		font = UI.font.display,
		size = UI.text.subtitle,
		zIndex = 25,
	})
	title.LayoutOrder = 1

	local order = 2
	if block.body then
		local body = autoLabel(card, "Body", block.body, {
			font = UI.font.light,
			color = UI.color.inkSoft,
			zIndex = 25,
		})
		body.LayoutOrder = order
		order += 1
	end

	if block.bullets then
		local bullets = Instance.new("Frame")
		bullets.Name = "Bullets"
		bullets.Size = UDim2.new(1, 0, 0, 0)
		bullets.AutomaticSize = Enum.AutomaticSize.Y
		bullets.BackgroundTransparency = 1
		bullets.LayoutOrder = order
		bullets.ZIndex = 24
		bullets.Parent = card

		local bulletLayout = Instance.new("UIListLayout")
		bulletLayout.SortOrder = Enum.SortOrder.LayoutOrder
		bulletLayout.Padding = UDim.new(0, 7)
		bulletLayout.Parent = bullets

		for bulletIndex, copy in block.bullets do
			addBullet(bullets, bulletIndex, copy, pageAccent)
		end
		order += 1
	end

	if block.rows then
		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.Size = UDim2.new(1, 0, 0, 0)
		rows.AutomaticSize = Enum.AutomaticSize.Y
		rows.BackgroundTransparency = 1
		rows.LayoutOrder = order
		rows.ZIndex = 24
		rows.Parent = card

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Padding = UDim.new(0, 7)
		rowLayout.Parent = rows

		for rowIndex, rowData in block.rows do
			if block.style == "timeline" then
				addTimelineRow(rows, rowIndex, rowData)
			else
				addStandardRow(rows, rowIndex, rowData, block.style or "plain")
			end
		end
	end
end

local function buildPage(parent: Frame, pageData: TutorialContent.Page): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = pageData.key
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 7
	page.ScrollBarImageColor3 = accentFor(pageData.accent)
	page.ScrollBarImageTransparency = 0.2
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.Visible = false
	page.ZIndex = 22
	page.Parent = parent
	UI.padding(page, PAGE_EDGE_GUTTER, {
		right = PAGE_SCROLLBAR_GUTTER,
		bottom = 10,
	})

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 12)
	list.Parent = page

	local accent = accentFor(pageData.accent)
	local hero = UI.card(page, "Hero", {
		color = UI.color.paperDeep,
		transparency = 0,
		radius = UI.radius.tile,
		stroke = false,
		sheen = false,
		innerLine = false,
		zIndex = 23,
	})
	hero.Size = UDim2.new(1, 0, 0, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.LayoutOrder = 1
	UI.padding(hero, HERO_PADDING, { left = HERO_TEXT_INSET })

	local rule = Instance.new("Frame")
	rule.Name = "Accent"
	rule.Position = UDim2.fromOffset(HERO_ACCENT_INSET - HERO_TEXT_INSET, -HERO_ACCENT_BLEED)
	rule.Size = UDim2.new(0, HERO_ACCENT_WIDTH, 1, HERO_ACCENT_BLEED * 2)
	rule.BackgroundColor3 = accent
	rule.BorderSizePixel = 0
	rule.ZIndex = 24
	rule.Parent = hero
	UI.corner(rule, UI.radius.pill)

	UI.label(hero, "Kicker", {
		text = pageData.kicker,
		font = UI.font.bold,
		size = UI.text.caption,
		color = accent,
		extent = UDim2.new(1, 0, 0, 16),
		zIndex = 24,
	})

	local title = autoLabel(hero, "Title", pageData.title, {
		font = UI.font.display,
		size = UI.text.title,
		color = UI.color.ink,
		zIndex = 24,
	})
	title.Position = UDim2.fromOffset(0, 22)

	for index, block in pageData.blocks do
		buildBlock(page, index, block, accent)
	end

	return page
end

local function selectPage(key: string)
	if not pageViews[key] then
		return
	end
	currentPage = key

	for _, pageData in pages do
		local active = pageData.key == key
		local button = pageButtons[pageData.key]
		local view = pageViews[pageData.key]
		view.Visible = active
		if active then
			view.CanvasPosition = Vector2.zero
		end

		UI.motion.to(button, UI.motion.snap, {
			BackgroundColor3 = if active then accentFor(pageData.accent) else UI.color.paperDeep,
			TextColor3 = if active then UI.readable(accentFor(pageData.accent)) else UI.color.inkSoft,
		})
	end

	for _, pageData in pages do
		if pageData.key == key then
			headerRule.BackgroundColor3 = accentFor(pageData.accent)
			break
		end
	end
end

local function rebuildPages()
	for _, child in navigation:GetChildren() do
		if child ~= navigationLayout and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	for _, child in contentHost:GetChildren() do
		child:Destroy()
	end
	pageButtons = {}
	pageViews = {}
	pages = TutorialContent.pages(InputMode.current())
	for index, pageData in pages do
		local button = UI.button(navigation, pageData.key, {
			text = pageData.label,
			color = UI.color.paperDeep,
			textColor = UI.color.inkSoft,
			textSize = 12,
			radius = UI.radius.chip,
			zIndex = 23,

			onActivated = function()
				selectPage(pageData.key)
			end,
		})
		button.LayoutOrder = index
		button.AutoButtonColor = false
		pageButtons[pageData.key] = button
		pageViews[pageData.key] = buildPage(contentHost, pageData)
	end
	if not pageViews[currentPage] then
		currentPage = if pageViews.start then "start" else pages[1].key
	end
	selectPage(currentPage)
end

local function viewportSize(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function targetPanelSize(): UDim2
	local view = viewportSize()
	local compact = UI.responsive.isCompact(view)
	local widthShare = if compact then 0.96 else 0.9
	local heightShare = if compact then 0.92 else 0.88
	local width = math.clamp(view.X * widthShare, math.min(PANEL_MIN.X, view.X - 16), PANEL_MAX.X)
	local height = math.clamp(view.Y * heightShare, math.min(PANEL_MIN.Y, view.Y - 16), PANEL_MAX.Y)
	return UDim2.fromOffset(math.floor(width), math.floor(height))
end

local function applyResponsiveLayout()
	if not panel then
		return
	end

	local compact = UI.responsive.isCompact(viewportSize())
	if open then
		panel.Size = targetPanelSize()
	end

	if compact then
		navigation.Position = UDim2.fromOffset(PANEL_MARGIN, HEADER_HEIGHT)
		navigation.Size = UDim2.new(1, -PANEL_MARGIN * 2, 0, 40)
		navigation.AutomaticCanvasSize = Enum.AutomaticSize.X
		navigation.ScrollingDirection = Enum.ScrollingDirection.X
		navigationLayout.FillDirection = Enum.FillDirection.Horizontal
		navigationLayout.Padding = UDim.new(0, UI.space.tight)

		contentHost.Position = UDim2.fromOffset(PANEL_MARGIN, HEADER_HEIGHT + 50)
		contentHost.Size = UDim2.new(1, -PANEL_MARGIN * 2, 1, -(HEADER_HEIGHT + 50 + PANEL_MARGIN))
		closeButton.Text = "CLOSE"
		closeButton.Size = UDim2.fromOffset(88, 44)

		for _, button in pageButtons do
			button.Size = UDim2.fromOffset(112, 34)
		end
	else
		navigation.Position = UDim2.fromOffset(PANEL_MARGIN, HEADER_HEIGHT)
		navigation.Size = UDim2.new(0, NAV_WIDTH, 1, -(HEADER_HEIGHT + PANEL_MARGIN))
		navigation.AutomaticCanvasSize = Enum.AutomaticSize.Y
		navigation.ScrollingDirection = Enum.ScrollingDirection.Y
		navigationLayout.FillDirection = Enum.FillDirection.Vertical
		navigationLayout.Padding = UDim.new(0, UI.space.tight)

		local contentX = PANEL_MARGIN + NAV_WIDTH + UI.space.base
		contentHost.Position = UDim2.fromOffset(contentX, HEADER_HEIGHT)
		contentHost.Size = UDim2.new(1, -(contentX + PANEL_MARGIN), 1, -(HEADER_HEIGHT + PANEL_MARGIN))
		closeButton.Text = "BACK TO GAME"
		closeButton.Size = UDim2.fromOffset(132, 44)

		for _, button in pageButtons do
			button.Size = UDim2.new(1, 0, 0, 40)
		end
	end
end

local function buildPanel(parent: ScreenGui)
	scrim = Instance.new("TextButton")
	scrim.Name = "FieldGuideScrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = UI.color.scrim
	scrim.BackgroundTransparency = 1
	scrim.BorderSizePixel = 0
	scrim.AutoButtonColor = false
	scrim.Text = ""
	scrim.Visible = false
	scrim.ZIndex = 20
	scrim.Parent = parent
	scrim.Activated:Connect(function()
		ControlsPanel.setOpen(false)
	end)

	panel = UI.card(scrim, "FieldGuide", {
		color = UI.color.paper,
		transparency = 0,
		radius = UI.radius.card,
		strokeColor = UI.color.lineSoft,
		strokeWidth = UI.Theme.stroke.hair,
		innerLine = false,
		zIndex = 21,
	})
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = targetPanelSize()
	UI.shadow(panel)

	UI.label(panel, "Eyebrow", {
		text = "FIELD GUIDE",
		font = UI.font.bold,
		size = UI.text.caption,
		color = UI.color.inkFaint,
		position = UDim2.fromOffset(PANEL_MARGIN, 14),
		extent = UDim2.fromOffset(180, 14),
		zIndex = 23,
	})

	UI.label(panel, "Title", {
		text = "How to play",
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(PANEL_MARGIN, 29),
		extent = UDim2.new(1, -(PANEL_MARGIN + 160), 0, 28),
		zIndex = 23,
	})

	headerRule = Instance.new("Frame")
	headerRule.Name = "ChapterColour"
	headerRule.Position = UDim2.fromOffset(PANEL_MARGIN, HEADER_HEIGHT - 16)
	headerRule.Size = UDim2.new(1, -PANEL_MARGIN * 2, 0, 3)
	headerRule.BackgroundColor3 = UI.color.leaf
	headerRule.BorderSizePixel = 0
	headerRule.ZIndex = 22
	headerRule.Parent = panel
	UI.corner(headerRule, 2)

	closeButton = UI.button(panel, "Close", {
		text = "BACK TO GAME",
		color = UI.color.paperDeep,
		textColor = UI.color.inkSoft,
		textSize = 11,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -18, 0, 16),
		extent = UDim2.fromOffset(124, 30),
		stroke = true,
		zIndex = 24,

		onActivated = function()
			ControlsPanel.setOpen(false)
		end,
	})

	navigation = Instance.new("ScrollingFrame")
	navigation.Name = "Chapters"
	navigation.BackgroundTransparency = 1
	navigation.BorderSizePixel = 0
	navigation.CanvasSize = UDim2.fromOffset(0, 0)
	navigation.ScrollBarThickness = 0
	navigation.ZIndex = 22
	navigation.Parent = panel
	UI.padding(navigation, UI.strokeClearance)

	navigationLayout = Instance.new("UIListLayout")
	navigationLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navigationLayout.Parent = navigation

	contentHost = Instance.new("Frame")
	contentHost.Name = "Pages"
	contentHost.BackgroundTransparency = 1
	contentHost.ClipsDescendants = true
	contentHost.ZIndex = 22
	contentHost.Parent = panel

	rebuildPages()
	applyResponsiveLayout()

	UIManager.register(MENU_ID, {
		setVisible = function(shouldOpen: boolean, instant: boolean)
			applyOpen(shouldOpen, instant)
		end,

		focus = function()
			return pageButtons[currentPage] or closeButton
		end,
		dismissible = true,
		kind = "ordinary",
	})
end

local function cancelActiveTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

applyOpen = function(shouldOpen: boolean, instant: boolean?)
	if not panel or shouldOpen == open then
		return
	end

	animationGeneration += 1
	local generation = animationGeneration
	cancelActiveTweens()
	open = shouldOpen
	if shouldOpen then
		scrim.Visible = true
		scrim.BackgroundTransparency = 1

		local goal = targetPanelSize()
		if instant or UI.motion.isReducedMotion() then
			panel.Size = goal
			scrim.BackgroundTransparency = UI.opacity.veil
		else
			panel.Size = UDim2.fromOffset(math.floor(goal.X.Offset * 0.96), math.floor(goal.Y.Offset * 0.96))
			table.insert(activeTweens, UI.motion.play(scrim, UI.motion.snap, {
				BackgroundTransparency = UI.opacity.veil,
			}))
			table.insert(activeTweens, UI.motion.play(panel, UI.motion.pop, { Size = goal }))
		end
	else
		if instant or UI.motion.isReducedMotion() then
			scrim.BackgroundTransparency = 1
			scrim.Visible = false
		else
			local fade = UI.motion.play(scrim, UI.motion.snap, { BackgroundTransparency = 1 })
			table.insert(activeTweens, fade)
			fade.Completed:Connect(function()
				if animationGeneration == generation and not open then
					scrim.Visible = false
				end
			end)
		end

		for _, listener in closedListeners do
			task.spawn(listener, not acknowledged)
		end
	end
end

function ControlsPanel.setOpen(shouldOpen: boolean)
	if shouldOpen then
		UIManager.open(MENU_ID)
	else
		UIManager.close(MENU_ID)
	end
end

function ControlsPanel.onClosed(callback: (firstSession: boolean) -> ()): () -> ()
	table.insert(closedListeners, callback)
	return function()
		local index = table.find(closedListeners, callback)
		if index then
			table.remove(closedListeners, index)
		end
	end
end

function ControlsPanel.markIntroComplete()
	acknowledged = true
end

function ControlsPanel.isOpen(): boolean
	return open
end

function ControlsPanel.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "FieldGuide"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 20
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	buildPanel(screen)
	InputMode.onChanged(function()
		rebuildPages()
		applyResponsiveLayout()
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local current = Workspace.CurrentCamera
		if current then
			current:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
		end
		applyResponsiveLayout()
	end)

	local disconnect
	disconnect = StateController.onChanged(function(snapshot)
		if snapshot.showIntro and not acknowledged then
			selectPage("start")
			ControlsPanel.setOpen(true)
			if disconnect then
				disconnect()
			end
		elseif not snapshot.showIntro then
			acknowledged = true
			if disconnect then
				disconnect()
			end
		end
	end)
end

return ControlsPanel

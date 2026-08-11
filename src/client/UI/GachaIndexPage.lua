--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared.UI)

export type Config = {
	catalog: any,
	preview: any,
	isWeapon: boolean,
}

export type Controller = {
	render: () -> (),
	reset: () -> (),
}

type CardEntry = {
	button: TextButton,
	stage: Frame,
	stroke: UIStroke,
	skinId: string,
	viewport: ViewportFrame?,
	destroyPreview: (() -> ())?,
}

type SectionEntry = {
	frame: Frame,
	grid: Frame,
	layout: UIGridLayout,
	count: number,
}

local GachaIndexPage = {}
local CARD_HEIGHT = 112
local CARD_GAP = 8
local HEADER_HEIGHT = 36
local SECTION_GAP = 10
local THUMBNAIL_OVERSCAN = 160
local DESKTOP_LIST_WIDTH = 0.62

local function clearGuiObjects(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function isVisibleInHierarchy(gui: GuiObject): boolean
	local current: Instance? = gui
	while current and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current ~= nil and current:IsA("LayerCollector") and current.Enabled
end

function GachaIndexPage.build(parent: Frame, config: Config): Controller
	local catalog = config.catalog
	local preview = config.preview
	local selectedId: string? = nil
	local indexList: ScrollingFrame
	local detailPane: Frame
	local cards = {} :: { CardEntry }
	local sections = {} :: { SectionEntry }
	local render: () -> ()
	local renderDetail: () -> ()
	local paintSelection: () -> ()
	local updateThumbnails: () -> ()
	local applyLayout: () -> ()
	local thumbnailUpdateQueued = false

	local function destroyCardPreviews()
		for _, entry in cards do
			if entry.destroyPreview then
				entry.destroyPreview()
				entry.destroyPreview = nil
				entry.viewport = nil
			end
		end
	end

	local function queueThumbnailUpdate()
		if thumbnailUpdateQueued then
			return
		end
		thumbnailUpdateQueued = true
		task.defer(function()
			thumbnailUpdateQueued = false
			updateThumbnails()
		end)
	end

	function updateThumbnails()
		if not isVisibleInHierarchy(indexList) or indexList.AbsoluteSize.Y <= 0 then
			destroyCardPreviews()
			return
		end

		local viewportTop = indexList.AbsolutePosition.Y - THUMBNAIL_OVERSCAN
		local viewportBottom = indexList.AbsolutePosition.Y + indexList.AbsoluteSize.Y + THUMBNAIL_OVERSCAN
		for _, entry in cards do
			local cardTop = entry.button.AbsolutePosition.Y
			local cardBottom = cardTop + entry.button.AbsoluteSize.Y
			local shouldMount = cardBottom >= viewportTop and cardTop <= viewportBottom
			if shouldMount and not entry.viewport then
				local viewport, destroyPreview = preview.mount(entry.stage, entry.skinId, {
					spin = false,
					zoom = if config.isWeapon then 1.28 else 1.72,
					radius = UI.radius.chip,
					zIndex = entry.stage.ZIndex + 1,
				})
				entry.viewport = viewport
				entry.destroyPreview = destroyPreview
			elseif not shouldMount and entry.destroyPreview then
				entry.destroyPreview()
				entry.destroyPreview = nil
				entry.viewport = nil
			end
		end
	end

	function renderDetail()
		clearGuiObjects(detailPane)
		if not parent.Visible then
			return
		end
		local skin = if selectedId then catalog.get(selectedId) else nil
		if not skin then
			UI.label(detailPane, "Empty", {
				text = if config.isWeapon
					then "Pick a weapon to preview it in 3D."
					else "Pick a look to preview it in 3D.",
				font = UI.font.light,
				size = UI.text.small,
				color = UI.color.inkFaint,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 12, 0.5, -20),
				extent = UDim2.new(1, -24, 0, 40),
				wrapped = true,
			})
			return
		end

		local rarity = catalog.RARITIES[skin.rarity]
		local character = if config.isWeapon then nil else catalog.CHARACTERS[skin.characterId]
		local weapon = if config.isWeapon then catalog.getWeapon(skin.weaponId) else nil
		local origin = if config.isWeapon then catalog.getOrigin(skin.origin) else nil
		local infoHeight = if config.isWeapon then 82 else 64
		local stage = Instance.new("Frame")
		stage.Name = "Stage"
		stage.BackgroundTransparency = 1
		stage.Position = UDim2.fromOffset(10, 10)
		stage.Size = UDim2.new(1, -20, 1, -(infoHeight + 18))
		stage.Parent = detailPane
		preview.mount(stage, skin.id, { spin = true, zoom = if config.isWeapon then 1.3 else 1.6 })

		local info = Instance.new("Frame")
		info.Name = "Info"
		info.BackgroundTransparency = 1
		info.Position = UDim2.new(0, 10, 1, -infoHeight)
		info.Size = UDim2.new(1, -20, 0, infoHeight)
		info.Parent = detailPane

		UI.label(info, "Name", {
			text = skin.name,
			font = UI.font.display,
			size = UI.text.subtitle,
			align = Enum.TextXAlignment.Center,
			extent = UDim2.new(1, 0, 0, 24),
			wrapped = true,
		})
		UI.label(info, "Tagline", {
			text = `{string.upper(rarity.name)}  ·  {if config.isWeapon
				then if weapon then weapon.name else skin.weaponId
				else if character then character.name else skin.characterId}`,
			font = UI.font.bold,
			size = UI.text.caption,
			color = UI.accentInk(UI.color.paperRaised, rarity.color),
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, 26),
			extent = UDim2.new(1, 0, 0, 16),
		})
		UI.label(info, if config.isWeapon then "Blurb" else "Bonus", {
			text = if config.isWeapon
				then skin.blurb
				else `Bonus ×{string.format("%.2f", rarity.multiplier)}  ·  {rarity.resaleYen} yen`,
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkSoft,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, 44),
			extent = UDim2.new(1, 0, 0, if config.isWeapon then 20 else 16),
			wrapped = config.isWeapon,
		})
		if config.isWeapon then
			UI.label(info, "Origin", {
				text = `{if origin then origin.name else skin.origin}  ·  {rarity.resaleYen} yen`,
				font = UI.font.light,
				size = UI.text.caption,
				color = UI.color.inkFaint,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 64),
				extent = UDim2.new(1, 0, 0, 16),
			})
		end
	end

	function paintSelection()
		for _, entry in cards do
			local selected = entry.skinId == selectedId
			entry.button.BackgroundColor3 = if selected then UI.color.paperDeep else UI.color.paperRaised
			entry.stroke.Thickness = if selected then 4 else 2.5
			entry.stroke.Transparency = if selected then 0 else 0.18
		end
	end

	local function buildCard(skin: any, rarity: any, order: number, grid: Frame)
		local button = Instance.new("TextButton")
		button.Name = skin.id
		button.AutoButtonColor = false
		button.BackgroundColor3 = UI.color.paperRaised
		button.BorderSizePixel = 0
		button.LayoutOrder = order
		button.Text = ""
		button.Parent = grid
		UI.corner(button, UI.radius.tile)
		local stroke = UI.stroke(button, rarity.color, 2.5)
		stroke.Transparency = 0.18

		local nameBar = Instance.new("Frame")
		nameBar.Name = "NameBar"
		nameBar.BackgroundColor3 = rarity.color:Lerp(UI.color.paperRaised, 0.7)
		nameBar.BorderSizePixel = 0
		nameBar.Size = UDim2.new(1, 0, 0, 28)
		nameBar.ZIndex = button.ZIndex + 2
		nameBar.Parent = button
		UI.corner(nameBar, UI.radius.tile)

		UI.label(nameBar, "Name", {
			text = skin.name,
			font = UI.font.bold,
			size = UI.text.caption,
			color = UI.color.ink,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(4, 2),
			extent = UDim2.new(1, -8, 1, -4),
			wrapped = true,
			zIndex = nameBar.ZIndex + 1,
		})

		local stage = Instance.new("Frame")
		stage.Name = "Thumbnail"
		stage.BackgroundColor3 = rarity.color:Lerp(UI.color.paperDeep, 0.68)
		stage.BorderSizePixel = 0
		stage.ClipsDescendants = true
		stage.Position = UDim2.fromOffset(4, 31)
		stage.Size = UDim2.new(1, -8, 1, -35)
		stage.ZIndex = button.ZIndex + 1
		stage.Parent = button
		UI.corner(stage, UI.radius.chip)
		UI.gradient(stage, rarity.color:Lerp(UI.color.white, 0.5), rarity.color:Lerp(UI.color.paperDeep, 0.75), 90)

		local entry: CardEntry = {
			button = button,
			stage = stage,
			stroke = stroke,
			skinId = skin.id,
			viewport = nil,
			destroyPreview = nil,
		}
		table.insert(cards, entry)
		button.Activated:Connect(function()
			selectedId = skin.id
			paintSelection()
			renderDetail()
		end)
	end

	local function buildSection(rarityId: string, order: number)
		local rarity = catalog.RARITIES[rarityId]
		local skins = catalog.BY_RARITY[rarityId] or {}
		if #skins == 0 then
			return
		end

		local section = Instance.new("Frame")
		section.Name = rarityId
		section.BackgroundTransparency = 1
		section.LayoutOrder = order
		section.Size = UDim2.new(1, -8, 0, HEADER_HEIGHT + CARD_HEIGHT)
		section.Parent = indexList

		local header = Instance.new("Frame")
		header.Name = "Header"
		header.BackgroundColor3 = rarity.color:Lerp(UI.color.paperRaised, 0.76)
		header.BorderSizePixel = 0
		header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
		header.Parent = section
		UI.corner(header, UI.radius.bar)
		local headerStroke = UI.stroke(header, rarity.color, 2.5)
		headerStroke.Transparency = 0.22
		UI.label(header, "Title", {
			text = rarity.name,
			font = UI.font.display,
			size = UI.text.subtitle,
			color = UI.accentInk(header.BackgroundColor3, rarity.color),
			position = UDim2.fromOffset(14, 0),
			extent = UDim2.new(1, -28, 1, 0),
		})

		local grid = Instance.new("Frame")
		grid.Name = "Cards"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.fromOffset(0, HEADER_HEIGHT + SECTION_GAP)
		grid.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
		grid.Parent = section
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP)
		gridLayout.CellSize = UDim2.fromOffset(104, CARD_HEIGHT)
		gridLayout.FillDirection = Enum.FillDirection.Horizontal
		gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = grid

		for skinOrder, skin in skins do
			buildCard(skin, rarity, skinOrder, grid)
		end
		table.insert(sections, {
			frame = section,
			grid = grid,
			layout = gridLayout,
			count = #skins,
		})
	end

	local function updateSectionGeometry()
		local availableWidth = math.max(indexList.AbsoluteSize.X - 18, 196)
		local minimumCardWidth = if UI.responsive.isCompact() then 92 else 100
		local columns = math.max(2, math.floor((availableWidth + CARD_GAP) / (minimumCardWidth + CARD_GAP)))
		local cardWidth = math.floor((availableWidth - CARD_GAP * (columns - 1)) / columns)
		for _, section in sections do
			local rows = math.max(1, math.ceil(section.count / columns))
			local gridHeight = rows * CARD_HEIGHT + (rows - 1) * CARD_GAP
			section.layout.CellSize = UDim2.fromOffset(cardWidth, CARD_HEIGHT)
			section.grid.Size = UDim2.new(1, 0, 0, gridHeight)
			section.frame.Size = UDim2.new(1, -8, 0, HEADER_HEIGHT + SECTION_GAP + gridHeight)
		end
		queueThumbnailUpdate()
	end

	function applyLayout()
		local compact = UI.responsive.isCompact()
		if compact then
			indexList.Position = UDim2.fromOffset(0, 0)
			indexList.Size = UDim2.new(1, 0, 0.58, -6)
			detailPane.Position = UDim2.new(0, 0, 0.58, 6)
			detailPane.Size = UDim2.new(1, 0, 0.42, -6)
		else
			indexList.Position = UDim2.fromOffset(0, 0)
			indexList.Size = UDim2.new(DESKTOP_LIST_WIDTH, -6, 1, 0)
			detailPane.Position = UDim2.new(DESKTOP_LIST_WIDTH, 6, 0, 0)
			detailPane.Size = UDim2.new(1 - DESKTOP_LIST_WIDTH, -6, 1, 0)
		end
		task.defer(updateSectionGeometry)
	end

	function render()
		destroyCardPreviews()
		clearGuiObjects(indexList)
		table.clear(cards)
		table.clear(sections)

		local firstSkin: any = nil
		local sectionOrder = 0
		for rarityIndex = #catalog.RARITY_ORDER, 1, -1 do
			local rarityId = catalog.RARITY_ORDER[rarityIndex]
			local raritySkins = catalog.BY_RARITY[rarityId]
			if raritySkins and #raritySkins > 0 then
				sectionOrder += 1
				firstSkin = firstSkin or raritySkins[1]
				buildSection(rarityId, sectionOrder)
			end
		end

		if not selectedId or not catalog.get(selectedId) then
			selectedId = if firstSkin then firstSkin.id else nil
		end
		paintSelection()
		renderDetail()
		applyLayout()
	end

	indexList = Instance.new("ScrollingFrame")
	indexList.Name = "IndexList"
	indexList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	indexList.BackgroundTransparency = 1
	indexList.BorderSizePixel = 0
	indexList.CanvasSize = UDim2.fromOffset(0, 0)
	indexList.ScrollBarImageColor3 = UI.color.inkSoft
	indexList.ScrollBarThickness = 6
	indexList.Parent = parent
	UI.padding(indexList, 2)
	local sectionLayout = UI.list(indexList, SECTION_GAP)
	sectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	detailPane = UI.card(parent, "Detail", {
		color = UI.color.paperRaised,
		radius = UI.radius.tile,
		stroke = false,
		sheen = false,
		innerLine = false,
	})

	indexList:GetPropertyChangedSignal("CanvasPosition"):Connect(queueThumbnailUpdate)
	indexList:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateSectionGeometry()
	end)
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	parent:GetPropertyChangedSignal("Visible"):Connect(function()
		renderDetail()
		queueThumbnailUpdate()
	end)
	parent.Destroying:Connect(destroyCardPreviews)

	render()
	return {
		render = render,

		reset = function()
			selectedId = nil
			indexList.CanvasPosition = Vector2.zero
			render()
		end,
	}
end

return GachaIndexPage

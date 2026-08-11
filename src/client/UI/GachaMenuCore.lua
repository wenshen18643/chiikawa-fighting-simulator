--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)
local UIManager = require(script.Parent.UIManager)
local GachaIndexPage = require(script.Parent.GachaIndexPage)
local GachaReveal = require(script.Parent.GachaReveal)
local GachaResults = require(script.Parent.GachaResults)
local GachaTicket = require(script.Parent.GachaTicket)

type GachaState = {
	yen: BigNumber.BigNum,
	unlimitedYen: boolean,
	capacity: number,
	used: number,
	copies: { [string]: number },
	equipped: { [string]: string },
	rarePlusMisses: number,
	legendaryMisses: number,
	bestByCharacter: { [string]: string }?,
	selectedCharacter: string?,
}

type PullResult = {
	skinId: string,
	rarity: string,
	isNew: boolean,
}

export type Config = {
	catalog: any,
	preview: any,
	isWeapon: boolean,
	menuId: string,
	flowInputLock: string,
	screenName: string,
	displayOrder: number,
	remoteCategory: string,
	npcName: string,
	promptName: string,
}

local GachaMenuCore = {}

function GachaMenuCore.new(config: Config)
local Catalog = config.catalog
local Preview = config.preview
local GachaMenu = {}
local MENU_ID = config.menuId
local FLOW_INPUT_LOCK = config.flowInputLock
local CLOSE_DISTANCE = 24
local PANEL_EXTENT = UDim2.fromScale(0.66, 0.78)
local PANEL_MAX_SIZE = Vector2.new(900, 560)
local screen: ScreenGui
local setPanelOpen: (boolean, boolean?) -> ()
local closeButton: TextButton
local titleLabel: TextLabel
local isOpen = false
local state: GachaState? = nil
local activePage = "summon"
local collectionFilter = "all"
local pullBusy = false
local cancelReveal: (() -> ())? = nil
local cancelResults: (() -> ())? = nil
local pages = {} :: { [string]: Frame }
local drawButtons = {} :: { TextButton }
local sideButtons = {} :: { [string]: TextButton }
local indexPage: GachaIndexPage.Controller
local collectionList: ScrollingFrame
local collectionFilterBar: Frame
local selectedSkinId: string? = nil
local detailPane: Frame
local renderDetail: () -> ()
local renderCollection: () -> ()
local pullRemote: RemoteEvent
local equipRemote: RemoteEvent
local sellRemote: RemoteEvent

local function setPullBusy(busy: boolean)
	pullBusy = busy
	if busy then
		UIManager.beginBlock(FLOW_INPUT_LOCK, MENU_ID)
	else
		UIManager.endBlock(FLOW_INPUT_LOCK)
	end
	WorkController.setInputLocked(FLOW_INPUT_LOCK, busy)
	for _, button in drawButtons do
		button.Active = not busy
		button.AutoButtonColor = not busy
		button.TextTransparency = if busy then 0.4 else 0
	end
end

local function clearGuiObjects(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function presentResult(result: PullResult): GachaReveal.Presentation?
	local skin = Catalog.get(result.skinId)
	local rarity = Catalog.getRarity(result.rarity)
	if not skin or not rarity then
		return nil
	end
	local subject = if config.isWeapon then Catalog.getWeapon(skin.weaponId) else Catalog.CHARACTERS[skin.characterId]
	return {
		name = skin.name,
		subtitle = if subject then subject.name else (skin.weaponId or skin.characterId),
		rarityName = rarity.name,
		rarityColor = rarity.color,
		rarityOrder = rarity.order,

		mountPreview = function(parent: Instance, hero: boolean): GuiObject?
			local preview = Preview.mount(
				parent,
				skin.id,
				if config.isWeapon
					then if hero
						then { spin = true, backdrop = 1, zoom = 1.15 }
						else { backdrop = 1, zoom = 1.3, radius = UI.radius.chip }
					else if hero
						then { spin = true, backdrop = 1, zoom = 1.7 }
						else { backdrop = 1, zoom = 1.85, radius = UI.radius.chip }
			)
			return preview
		end,
	}
end

local function showPage(key: string)
	if key ~= "summon" and key ~= "index" and key ~= "owned" then
		return
	end
	activePage = key
	for pageKey, page in pages do
		page.Visible = pageKey == key
	end
	for pageKey, button in sideButtons do
		local selected = pageKey == key
		button.BackgroundColor3 = if selected then UI.color.mint else UI.color.paperRaised
		button.TextColor3 = if selected then UI.color.ink else UI.color.inkSoft
	end
	if key == "summon" then
		titleLabel.Text = if config.isWeapon then "Weapon Summon" else "Skin Summon"
		closeButton.Text = "Close"
	else
		titleLabel.Text = if key == "index"
			then if config.isWeapon then "Weapon Index" else "Skin Index"
			else if config.isWeapon then "Owned Weapons" else "Owned Skins"
		closeButton.Text = "Back"
	end
end

local function buildDrawTicket(parent: Instance, drawId: string, position: UDim2)
	local featured = Catalog.rollSkin(if drawId == "premium" then "legendary" else "epic", Random.new())
	GachaTicket.build(parent, {
		catalog = Catalog,
		drawId = drawId :: any,
		position = position,
		featuredName = featured.name,

		mountFeatured = function(stage: Frame)
			Preview.mount(
				stage,
				featured.id,
				if config.isWeapon
					then { spin = true, radius = UI.radius.tile }
					else { spin = true, zoom = 1.7, radius = UI.radius.tile }
			)
		end,

		onDraw = function(count: number)
			if pullBusy then
				return
			end
			setPullBusy(true)
			pullRemote:FireServer({ drawId = drawId, count = count })
			task.delay(6, function()
				if pullBusy and not cancelReveal and not cancelResults then
					setPullBusy(false)
				end
			end)
		end,

		onButton = function(button: TextButton)
			table.insert(drawButtons, button)
		end,
	})
end

local function sellableCopies(snapshot: GachaState, skin: any): number
	if config.isWeapon then
		return Catalog.sellableCopies(snapshot, skin.id)
	end
	local owned = snapshot.copies[skin.id] or 0
	local reserved = if snapshot.equipped[skin.characterId] == skin.id then 1 else 0
	return math.max(owned - reserved, 0)
end

local function buildCollectionRow(skin: any, index: number)
	local snapshot = state
	if not snapshot then
		return
	end
	local count = snapshot.copies[skin.id] or 0
	local equipped = if config.isWeapon
		then snapshot.equipped[Catalog.SLOT] == skin.id
		else snapshot.equipped[skin.characterId] == skin.id
	local rarity = Catalog.RARITIES[skin.rarity]
	local weapon = if config.isWeapon then Catalog.getWeapon(skin.weaponId) else nil
	local chosen = selectedSkinId == skin.id

	local row = UI.button(collectionList, skin.id, {
		text = "",
		color = if chosen then UI.color.paperDeep else UI.color.paperRaised,
		radius = UI.radius.chip,
		stroke = false,
		sheen = false,

		onActivated = function()
			selectedSkinId = skin.id
			renderCollection()
		end,
	})
	row.Size = UDim2.new(1, -10, 0, 46)
	row.LayoutOrder = index
	row.AutoButtonColor = false
	local stroke = UI.stroke(row, rarity.color, if chosen then 2 else 1)
	stroke.Transparency = if count > 0 then 0.2 else 0.72

	local dot = Instance.new("Frame")
	dot.Name = "Rarity"
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.BackgroundColor3 = rarity.color
	dot.BackgroundTransparency = if count > 0 then 0 else 0.6
	dot.BorderSizePixel = 0
	dot.Position = UDim2.new(0, 12, 0.5, 0)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.Parent = row
	UI.corner(dot, UI.radius.pill)

	UI.label(row, "Name", {
		text = skin.name,
		font = UI.font.display,
		size = UI.text.small,
		color = if count > 0 then UI.color.ink else UI.color.inkFaint,
		position = UDim2.fromOffset(30, 6),
		extent = UDim2.new(1, -124, 0, 20),
	})
	UI.label(row, "Owned", {
		text = if config.isWeapon
			then if count > 0
				then `{if weapon then weapon.name else skin.weaponId} · owned ×{count}`
				else `{if weapon then weapon.name else skin.weaponId} · not owned`
			else if skin.showcase
				then "Showcase"
				elseif count > 0 then `Owned ×{count}`
				else "Not owned",
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(30, 24),
		extent = UDim2.new(1, -124, 0, 16),
	})

	if equipped then
		UI.chip(row, "Equipped", {
			text = "Equipped",
			color = UI.color.mint,
			textColor = UI.color.ink,
			textSize = UI.text.caption,
			extent = UDim2.fromOffset(74, 22),
			position = UDim2.new(1, -86, 0.5, -11),
		})
	end
end

local function paintCollectionFilters()
	for _, child in collectionFilterBar:GetChildren() do
		if child:IsA("TextButton") then
			local selected = child.Name == collectionFilter
			child.BackgroundColor3 = if selected then UI.color.blush else UI.color.paperSunken
			child.TextColor3 = if selected then UI.color.ink else UI.color.inkSoft
		end
	end
end

local function matchesFilter(skin: any): boolean
	local snapshot = state
	if not snapshot or (snapshot.copies[skin.id] or 0) <= 0 then
		return false
	end
	if collectionFilter == "all" then
		return true
	end
	if config.isWeapon then
		return skin.origin == collectionFilter
	end
	if collectionFilter == "showcase" then
		return skin.showcase == true
	end
	return skin.characterId == collectionFilter
end

function renderDetail()
	clearGuiObjects(detailPane)

	local snapshot = state
	local skin = if selectedSkinId then Catalog.get(selectedSkinId) else nil
	if not skin or not snapshot then
		return
	end

	local rarity = Catalog.RARITIES[skin.rarity]
	local character = if config.isWeapon then nil else Catalog.CHARACTERS[skin.characterId]
	local weapon = if config.isWeapon then Catalog.getWeapon(skin.weaponId) else nil
	local origin = if config.isWeapon then Catalog.getOrigin(skin.origin) else nil
	local count = snapshot.copies[skin.id] or 0
	local equipped = if config.isWeapon
		then snapshot.equipped[Catalog.SLOT] == skin.id
		else snapshot.equipped[skin.characterId] == skin.id
	local sellable = sellableCopies(snapshot, skin)
	local actionHeight = if (not config.isWeapon and skin.showcase) or count == 0 then 44 else 78
	local infoHeight = if config.isWeapon then 82 else 64
	local footprint = actionHeight + infoHeight
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(10, 10)
	stage.Size = UDim2.new(1, -20, 1, -(footprint + 18))
	stage.Parent = detailPane
	Preview.mount(stage, skin.id, { spin = true, zoom = if config.isWeapon then 1.3 else 1.6 })

	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Position = UDim2.new(0, 10, 1, -footprint)
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

	if not config.isWeapon and skin.showcase then
		UI.label(detailPane, "Locked", {
			text = "Showcase look - not in the capsule pool.",
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkFaint,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new(0, 10, 1, -38),
			extent = UDim2.new(1, -20, 0, 30),
			wrapped = true,
		})
		return
	end

	if count == 0 then
		UI.label(detailPane, "Locked", {
			text = "Not owned yet - draw a capsule to unlock it.",
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkFaint,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new(0, 10, 1, -38),
			extent = UDim2.new(1, -20, 0, 30),
			wrapped = true,
		})
		return
	end

	local isDefault = config.isWeapon and skin.id == Catalog.DEFAULT_SKIN_ID
	if equipped and isDefault then
		UI.label(detailPane, "DefaultNote", {
			text = "Your starter weapon. Equipped by default.",
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkFaint,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new(0, 10, 1, -74),
			extent = UDim2.new(1, -20, 0, 26),
			wrapped = true,
		})
	elseif equipped then
		UI.button(detailPane, "Unequip", {
			text = if config.isWeapon
				then "Back to the Stale Sasumata"
				else `Back to {if character then character.name else "base"} base`,
			color = UI.color.paperSunken,
			textColor = UI.color.ink,
			textSize = UI.text.caption,
			extent = UDim2.new(1, -20, 0, 32),
			position = UDim2.new(0, 10, 1, -78),
			stroke = false,
			sheen = false,

			onActivated = function()
				equipRemote:FireServer(if config.isWeapon then {} else { characterId = skin.characterId })
			end,
		})
	else
		UI.button(detailPane, "Equip", {
			text = if config.isWeapon then "Equip this weapon" else "Equip this look",
			color = UI.color.sky,
			textColor = UI.color.ink,
			extent = UDim2.new(1, -20, 0, 32),
			position = UDim2.new(0, 10, 1, -78),
			stroke = false,
			sheen = false,

			onActivated = function()
				equipRemote:FireServer(
					if config.isWeapon then { skinId = skin.id } else { characterId = skin.characterId, skinId = skin.id }
				)
			end,
		})
	end

	if sellable > 0 then
		UI.button(detailPane, "SellOne", {
			text = "Sell 1",
			color = UI.color.paperSunken,
			textColor = UI.color.ink,
			textSize = UI.text.caption,
			extent = UDim2.new(0.5, -14, 0, 30),
			position = UDim2.new(0, 10, 1, -40),
			stroke = false,
			sheen = false,

			onActivated = function()
				sellRemote:FireServer({ skinId = skin.id, count = 1 })
			end,
		})
		UI.button(detailPane, "SellMax", {
			text = `Sell {sellable}`,
			color = UI.color.warning,
			textColor = UI.color.ink,
			textSize = UI.text.caption,
			extent = UDim2.new(0.5, -14, 0, 30),
			position = UDim2.new(0.5, 4, 1, -40),
			stroke = false,
			sheen = false,

			onActivated = function()
				sellRemote:FireServer({ skinId = skin.id, count = sellable })
			end,
		})
	else
		UI.label(detailPane, "NoSale", {
			text = if isDefault
				then "Your starter weapon cannot be sold."
				else "Your only copy is equipped, so it is protected.",
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkFaint,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new(0, 10, 1, -38),
			extent = UDim2.new(1, -20, 0, 28),
			wrapped = true,
		})
	end
end

function renderCollection()
	clearGuiObjects(collectionList)

	local visible = {}
	for _, skin in Catalog.SKINS do
		if matchesFilter(skin) then
			table.insert(visible, skin)
		end
	end

	local stillShown = false
	for _, skin in visible do
		if skin.id == selectedSkinId then
			stillShown = true
			break
		end
	end
	if not stillShown then
		selectedSkinId = if visible[1] then visible[1].id else nil
	end

	for index, skin in visible do
		buildCollectionRow(skin, index)
	end
	if #visible == 0 then
		local empty = UI.label(collectionList, "Empty", {
			text = if config.isWeapon then "No weapons owned" else "No skins owned",
			font = UI.font.display,
			size = UI.text.small,
			color = UI.color.inkFaint,
			align = Enum.TextXAlignment.Center,
			extent = UDim2.new(1, -10, 0, 52),
		})
		empty.LayoutOrder = 1
	end
	paintCollectionFilters()
	renderDetail()
end

local function buildCollectionFilters(parent: Frame)
	collectionFilterBar = Instance.new("Frame")
	collectionFilterBar.Name = "Filters"
	collectionFilterBar.BackgroundTransparency = 1
	collectionFilterBar.Size = UDim2.new(1, 0, 0, 34)
	collectionFilterBar.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = collectionFilterBar

	local entries: { { key: string, label: string } } = if config.isWeapon
		then {
			{ key = "all", label = "All" },
			{ key = "canon", label = "From the show" },
			{ key = "cool", label = "Cool" },
			{ key = "cute", label = "Cute" },
		}
		else {
			{ key = "all", label = "All" },
			{ key = "chiikawa", label = "Chiikawa" },
			{ key = "hachiware", label = "Hachiware" },
			{ key = "usagi", label = "Usagi" },
			{ key = "showcase", label = "Showcase" },
		}
	for index, entry in entries do
		local button = UI.button(collectionFilterBar, entry.key, {
			text = entry.label,
			textSize = UI.text.caption,
			color = UI.color.paperSunken,
			textColor = UI.color.inkSoft,
			extent = UDim2.new(1 / #entries, -5, 1, 0),
			stroke = false,
			sheen = false,
			states = false,

			onActivated = function()
				collectionFilter = entry.key
				paintCollectionFilters()
				renderCollection()
			end,
		})
		button.LayoutOrder = index
	end
end

local function buildPanel(parent: ScreenGui)
	local body: ScrollingFrame? = nil
	local sideRail: Frame? = nil

	local function applyBodyLayout(compact: boolean, panelSize: UDim2)
		if not body then
			return
		end
		local viewport = UI.responsive.viewport()
		local outsideSpace = (viewport.X - panelSize.X.Offset) / 2 - 28
		local outsideRail = not compact and outsideSpace >= 140
		body.CanvasSize = if compact then UDim2.fromOffset(0, 430) else UDim2.fromOffset(0, 0)
		body.ScrollBarThickness = if compact then 6 else 0
		body.Position = if outsideRail then UDim2.fromOffset(0, 52) else UDim2.fromOffset(96, 52)
		body.Size = if outsideRail then UDim2.new(1, 0, 1, -52) else UDim2.new(1, -96, 1, -52)
		for _, page in pages do
			page.Size = if compact then UDim2.new(1, -8, 0, 430) else UDim2.fromScale(1, 1)
		end
		if sideRail then
			local railWidth = if outsideRail then math.min(300, math.floor(outsideSpace)) else 84
			local buttonHeight = if outsideRail then math.clamp(math.floor(railWidth * 0.305), 60, 92) else 44
			local gap = if outsideRail then 12 else 8
			sideRail.AnchorPoint = if outsideRail then Vector2.new(1, 0) else Vector2.zero
			sideRail.Position = if outsideRail then UDim2.fromOffset(-28, 4) else UDim2.fromOffset(8, 54)
			sideRail.Size = UDim2.fromOffset(railWidth, buttonHeight * 2 + gap)
			local railLayout = sideRail:FindFirstChildOfClass("UIListLayout")
			if railLayout then
				railLayout.Padding = UDim.new(0, gap)
			end
			for _, button in sideButtons do
				button.Size = UDim2.fromOffset(railWidth, buttonHeight)
			end
		end
	end
	local _scrim, content, toggle = UI.modal(parent, config.screenName, {
		extent = PANEL_EXTENT,
		maxSize = PANEL_MAX_SIZE,
		zIndex = 30,
		dismissOnBackground = false,

		onDismiss = function()
			GachaMenu.setOpen(false)
		end,

		onResponsiveChanged = function(compact: boolean, size: UDim2)
			applyBodyLayout(compact, size)
		end,

		onToggled = function(open: boolean)
			isOpen = open
		end,
	})
	setPanelOpen = toggle
	UI.padding(content, UI.space.base)

	titleLabel = UI.label(content, "Title", {
		text = if config.isWeapon then "Weapon Summon" else "Skin Summon",
		font = UI.font.display,
		size = UI.text.display,
		extent = UDim2.new(if config.isWeapon then 0.68 else 0.6, 0, 0, 30),
	})
	closeButton = UI.button(content, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(88, 44),
		position = UDim2.new(1, -88, 0, 0),
		stroke = false,
		sheen = false,

		onActivated = function()
			if activePage == "summon" then
				GachaMenu.setOpen(false)
			else
				showPage("summon")
			end
		end,
	})

	local rail = Instance.new("Frame")
	rail.Name = "PageRail"
	rail.BackgroundTransparency = 1
	rail.Size = UDim2.fromOffset(84, 96)
	rail.ZIndex = content.ZIndex + 2
	rail.Parent = content
	sideRail = rail
	local railLayout = Instance.new("UIListLayout")
	railLayout.Padding = UDim.new(0, 8)
	railLayout.Parent = rail
	for index, entry in {
		{ key = "index", label = "Index" },
		{ key = "owned", label = "Owned" },
	} do
		local button = UI.button(rail, entry.key, {
			text = entry.label,
			textSize = UI.text.small,
			color = UI.color.paperRaised,
			textColor = UI.color.inkSoft,
			extent = UDim2.fromOffset(84, 44),
			stroke = false,
			sheen = false,
			states = false,
			zIndex = content.ZIndex + 3,

			onActivated = function()
				showPage(if activePage == entry.key then "summon" else entry.key)
			end,
		})
		button.LayoutOrder = index
		sideButtons[entry.key] = button
	end

	local bodyFrame = Instance.new("ScrollingFrame")
	bodyFrame.Name = "Body"
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.BorderSizePixel = 0
	bodyFrame.CanvasSize = UDim2.fromOffset(0, 0)
	bodyFrame.ScrollBarImageColor3 = UI.color.inkSoft
	bodyFrame.Position = UDim2.fromOffset(0, 52)
	bodyFrame.Size = UDim2.new(1, 0, 1, -52)
	bodyFrame.Parent = content
	UI.padding(bodyFrame, 2)
	body = bodyFrame

	for _, key in { "summon", "index", "owned" } do
		local page = Instance.new("Frame")
		page.Name = key
		page.BackgroundTransparency = 1
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = key == activePage
		page.Parent = bodyFrame
		pages[key] = page
	end
	local initialPanelSize, initialCompact = UI.responsive.panelSize(PANEL_EXTENT, PANEL_MAX_SIZE)
	applyBodyLayout(initialCompact, initialPanelSize)

	buildDrawTicket(pages.summon, "standard", UDim2.fromScale(0, 0))
	buildDrawTicket(pages.summon, "premium", UDim2.fromScale(0.515, 0))
	indexPage = GachaIndexPage.build(pages.index, {
		catalog = Catalog,
		preview = Preview,
		isWeapon = config.isWeapon,
	})

	buildCollectionFilters(pages.owned)
	collectionList = Instance.new("ScrollingFrame")
	collectionList.Name = "CollectionList"
	collectionList.BackgroundTransparency = 1
	collectionList.BorderSizePixel = 0
	collectionList.Position = UDim2.fromOffset(0, 42)
	collectionList.Size = UDim2.new(0.53, 0, 1, -42)
	collectionList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	collectionList.CanvasSize = UDim2.fromOffset(0, 0)
	collectionList.ScrollBarThickness = 6
	collectionList.ScrollBarImageColor3 = UI.color.inkSoft
	collectionList.Parent = pages.owned
	UI.padding(collectionList, 2)
	UI.list(collectionList, 6)

	detailPane = UI.card(pages.owned, "Detail", {
		color = UI.color.paperRaised,
		radius = UI.radius.tile,
		position = UDim2.new(0.55, 0, 0, 42),
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	detailPane.Size = UDim2.new(0.45, 0, 1, -42)
	showPage(activePage)

	UIManager.register(MENU_ID, {
		setVisible = setPanelOpen,

		focus = function()
			return closeButton
		end,

		back = function()
			return pullBusy
		end,
		dismissible = true,
		kind = "ordinary",
	})
end

local function acceptState(value: unknown): GachaState?
	if type(value) ~= "table" then
		return nil
	end
	local candidate = value :: { [string]: unknown }
	if
		type(candidate.capacity) ~= "number"
		or type(candidate.used) ~= "number"
		or type(candidate.copies) ~= "table"
		or type(candidate.equipped) ~= "table"
		or type(candidate.rarePlusMisses) ~= "number"
		or type(candidate.legendaryMisses) ~= "number"
		or (not config.isWeapon and type(candidate.bestByCharacter) ~= "table")
	then
		return nil
	end
	return value :: GachaState
end

local function applyState(value: unknown)
	local accepted = acceptState(value)
	if not accepted then
		return
	end
	state = accepted
	renderCollection()
end

local function parseResults(value: unknown): { PullResult }?
	if type(value) ~= "table" then
		return nil
	end
	local rawResults = value :: { unknown }
	if #rawResults > 10 then
		return nil
	end
	local results = {} :: { PullResult }
	for _, raw in rawResults do
		if type(raw) ~= "table" then
			return nil
		end
		local item = raw :: { [string]: unknown }
		if type(item.skinId) ~= "string" or type(item.rarity) ~= "string" or type(item.isNew) ~= "boolean" then
			return nil
		end
		local rarity = Catalog.getRarity(item.rarity)
		if not rarity or not Catalog.get(item.skinId) then
			return nil
		end
		local result: PullResult = {
			skinId = item.skinId,
			rarity = item.rarity,
			isNew = item.isNew,
		}
		table.insert(results, result)
	end
	return results
end

local function isNearNpc(): boolean
	local safeZone = Workspace:FindFirstChild("SafeZone")
	local model = safeZone and safeZone:FindFirstChild(config.npcName)
	local prompt = model and model:FindFirstChild(config.promptName, true)
	local anchor = prompt and prompt.Parent
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return anchor ~= nil
		and anchor:IsA("BasePart")
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - anchor.Position).Magnitude <= CLOSE_DISTANCE
end

function GachaMenu.setOpen(open: boolean)
	if open then
		UIManager.open(MENU_ID)
	else
		UIManager.close(MENU_ID)
	end
end

function GachaMenu.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = config.screenName
	screen.ResetOnSpawn = false
	screen.DisplayOrder = config.displayOrder
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	buildPanel(screen)

	pullRemote = Remotes.event(config.remoteCategory, "Pull")
	equipRemote = Remotes.event(config.remoteCategory, "Equip")
	sellRemote = Remotes.event(config.remoteCategory, "Sell")

	Remotes.event(config.remoteCategory, "Open").OnClientEvent:Connect(function(value)
		collectionFilter = "all"
		selectedSkinId = nil
		indexPage.reset()
		applyState(value)
		showPage("summon")
		GachaMenu.setOpen(true)
	end)

	Remotes.event(config.remoteCategory, "Event").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		applyState(payload.state)
		if payload.kind == "pull" then
			local results = parseResults(payload.results)
			if results and type(payload.drawId) == "string" then
				local drawId = payload.drawId
				showPage("summon")
				if cancelReveal then
					cancelReveal()
				end
				if cancelResults then
					cancelResults()
					cancelResults = nil
				end
				cancelReveal = GachaReveal.play(playerGui, results, presentResult, function()
					cancelReveal = nil
					cancelResults = GachaResults.show(playerGui, results, drawId, presentResult, function()
						cancelResults = nil
						setPullBusy(false)
					end)
				end)
			else
				setPullBusy(false)
			end
		elseif payload.kind == "denied" then
			setPullBusy(false)
		elseif payload.kind == "sold" or payload.kind == "state" then
			renderCollection()
		end
	end)

	StateController.onChanged(function(snapshot)
		local current = state
		if current and snapshot and BigNumber.isValid(snapshot.yen) then
			current.yen = snapshot.yen
			current.unlimitedYen = snapshot.unlimitedYen == true
		end
	end)

	player.CharacterAdded:Connect(function()
		if cancelReveal then
			cancelReveal()
			cancelReveal = nil
		end
		if cancelResults then
			cancelResults()
			cancelResults = nil
		end
		setPullBusy(false)
		if isOpen then
			GachaMenu.setOpen(false)
		end
	end)

	task.spawn(function()
		while screen.Parent do
			task.wait(0.25)
			if isOpen and not isNearNpc() then
				GachaMenu.setOpen(false)
			end
		end
	end)
end

return GachaMenu
end

return GachaMenuCore

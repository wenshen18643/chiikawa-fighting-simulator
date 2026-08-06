--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)
local GachaReveal = require(script.Parent.GachaReveal)
local GachaResults = require(script.Parent.GachaResults)
local SkinPreview = require(script.Parent.SkinPreview)

type GachaState = {
	yen: BigNumber.BigNum,
	unlimitedYen: boolean,
	capacity: number,
	used: number,
	copies: { [string]: number },
	equipped: { [string]: string },
	rarePlusMisses: number,
	legendaryMisses: number,
	bestByCharacter: { [string]: string },
	selectedCharacter: string?,
}

type PullResult = {
	skinId: string,
	rarity: CompanionSkins.RarityId,
	isNew: boolean,
}

local GachaMenu = {}
local INPUT_LOCK = "gacha-menu"
local FLOW_INPUT_LOCK = "gacha-flow"
local CLOSE_DISTANCE = 24
local screen: ScreenGui
local panel: Frame
local setOpen: (boolean) -> ()
local isOpen = false
local state: GachaState? = nil
local activePage = "draw"
local collectionFilter = "all"
local pullBusy = false
local cancelReveal: (() -> ())? = nil
local cancelResults: (() -> ())? = nil
local pages = {} :: { [string]: Frame }
local drawButtons = {} :: { TextButton }
local tabButtons = {} :: { [string]: TextButton }
local yenLabel: TextLabel
local capacityLabel: TextLabel
local collectionList: ScrollingFrame
local collectionFilterBar: Frame
local selectedSkinId: string? = nil
local pityMeters = {} :: { [string]: (number, string) -> () }
local detailPane: Frame
local renderDetail: () -> ()
local renderCollection: () -> ()
local pullRemote: RemoteEvent
local equipRemote: RemoteEvent
local sellRemote: RemoteEvent

local function setPullBusy(busy: boolean)
	pullBusy = busy
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

local function currentState(): GachaState?
	return state
end

local function paintStatus()
	local snapshot = currentState()
	if not snapshot then
		yenLabel.Text = "0 yen"
		capacityLabel.Text = `0 / {CompanionSkins.CAPACITY} slots`
		for _, paint in pityMeters do
			paint(0, "-")
		end
		return
	end

	yenLabel.Text = if snapshot.unlimitedYen then "∞ yen" else `{BigNumber.toString(snapshot.yen)} yen`
	capacityLabel.Text = `{snapshot.used} / {snapshot.capacity} slots used`

	local rareLeft = math.max(CompanionSkins.RARE_PLUS_PITY - snapshot.rarePlusMisses, 0)
	local legendaryLeft = math.max(CompanionSkins.LEGENDARY_PITY - snapshot.legendaryMisses, 0)
	local paintRare = pityMeters.rare
	if paintRare then
		paintRare(snapshot.rarePlusMisses / CompanionSkins.RARE_PLUS_PITY, `Rare+ in {rareLeft}`)
	end
	local paintLegendary = pityMeters.legendary
	if paintLegendary then
		paintLegendary(
			snapshot.legendaryMisses / CompanionSkins.LEGENDARY_PITY,
			`Legendary in {legendaryLeft}`
		)
	end
end

local function buildPityMeter(parent: Instance, key: string, accent: Color3, position: UDim2)
	local holder = Instance.new("Frame")
	holder.Name = `Pity_{key}`
	holder.BackgroundTransparency = 1
	holder.Position = position
	holder.Size = UDim2.new(0.32, 0, 0, 32)
	holder.Parent = parent

	local caption = UI.label(holder, "Caption", {
		text = "-",
		font = UI.font.bold,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, 0, 0, 14),
	})

	local track, fill = UI.bar(holder, "Track", accent)
	track.Position = UDim2.fromOffset(0, 18)
	track.Size = UDim2.new(1, 0, 0, 8)

	pityMeters[key] = function(fraction: number, text: string)
		caption.Text = text
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
end

local function showPage(key: string)
	activePage = key
	for pageKey, page in pages do
		page.Visible = pageKey == key
	end
	for pageKey, button in tabButtons do
		local selected = pageKey == key
		local accent = if pageKey == "draw"
			then UI.color.sky
			elseif pageKey == "collection" then UI.color.mint
			else UI.color.lavender
		button.BackgroundColor3 = if selected then accent else UI.color.paperRaised
		button.TextColor3 = if selected then UI.color.ink else UI.color.inkSoft
	end
end

local function buildNavigation(parent: Frame)
	local navigation = UI.card(parent, "Navigation", {
		color = UI.color.paperSunken,
		radius = UI.radius.chip,
		position = UDim2.fromOffset(0, 110),
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	navigation.Size = UDim2.new(1, 0, 0, 44)

	local entries = {
		{ key = "draw", label = "Draw" },
		{ key = "collection", label = "Collection" },
		{ key = "odds", label = "Odds" },
	}
	for index, entry in entries do
		local button = UI.button(navigation, entry.key, {
			text = entry.label,
			font = UI.font.bold,
			textSize = UI.text.body,
			color = UI.color.paperRaised,
			textColor = UI.color.inkSoft,
			radius = UI.radius.chip,
			position = UDim2.new((index - 1) / #entries, 4, 0, 4),
			extent = UDim2.new(1 / #entries, -8, 1, -8),
			stroke = false,
			sheen = false,

			onActivated = function()
				showPage(entry.key)
			end,
		})
		tabButtons[entry.key] = button
	end
	showPage(activePage)
end

local function drawButton(parent: Instance, drawId: CompanionSkins.DrawId, count: number, position: UDim2)
	local draw = CompanionSkins.DRAWS[drawId]
	local accent = if drawId == "premium" then UI.color.gold else UI.color.sky
	local button = UI.button(parent, `Draw{count}`, {
		text = if count == 1 then `Draw 1  ·  {draw.cost} yen` else `Draw 10  ·  {draw.cost * count} yen`,
		color = accent,
		textColor = UI.color.ink,
		extent = UDim2.new(0.46, 0, 0, 36),
		position = position,
		stroke = false,
		sheen = false,

		onActivated = function()
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
	})
	table.insert(drawButtons, button)
end

local function buildDrawTicket(parent: Instance, drawId: CompanionSkins.DrawId, position: UDim2)
	local draw = CompanionSkins.DRAWS[drawId]
	local premium = drawId == "premium"
	local card = UI.card(parent, drawId, {
		color = if premium then UI.color.sand else UI.color.paperRaised,
		radius = UI.radius.card,
		position = position,
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	card.Size = UDim2.new(0.485, 0, 1, 0)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = if premium then UI.color.gold else UI.color.sky
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromOffset(0, 14)
	accent.Size = UDim2.fromOffset(5, 48)
	accent.Parent = card
	UI.corner(accent, 3)

	UI.label(card, "Eyebrow", {
		text = if premium then "LUCKY CAPSULE" else "EVERYDAY CAPSULE",
		font = UI.font.bold,
		size = UI.text.caption,
		color = if premium then UI.color.gold else UI.color.sky,
		position = UDim2.fromOffset(18, 10),
		extent = UDim2.new(1, -32, 0, 18),
	})
	UI.label(card, "Title", {
		text = draw.name,
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(18, 27),
		extent = UDim2.new(1, -32, 0, 28),
	})
	local pips = Instance.new("Frame")
	pips.Name = "Odds"
	pips.BackgroundTransparency = 1
	pips.Position = UDim2.fromOffset(18, 58)
	pips.Size = UDim2.new(1, -36, 0, 26)
	pips.Parent = card

	for index, rarityId in CompanionSkins.RARITY_ORDER do
		local rarity = CompanionSkins.RARITIES[rarityId]
		local weight = draw.weights[rarityId]
		local pip = Instance.new("Frame")
		pip.Name = rarityId
		pip.BackgroundColor3 = rarity.color
		pip.BorderSizePixel = 0
		pip.Position = UDim2.new((index - 1) / 5, 2, 0, 0)
		pip.Size = UDim2.new(1 / 5, -4, 0, 5)
		pip.Parent = pips
		UI.corner(pip, UI.radius.pill)

		UI.label(pips, `{rarityId}Rate`, {
			text = `{weight}%`,
			font = UI.font.bold,
			size = UI.text.caption,
			color = rarity.color,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new((index - 1) / 5, 2, 0, 8),
			extent = UDim2.new(1 / 5, -4, 0, 16),
		})
	end

	local featured = CompanionSkins.rollSkin(if premium then "legendary" else "epic", Random.new())
	local stage = Instance.new("Frame")
	stage.Name = "Featured"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(18, 92)
	stage.Size = UDim2.new(1, -36, 1, -178)
	stage.Parent = card
	SkinPreview.mount(stage, featured.id, {
		spin = true,
		zoom = 1.7,
		radius = UI.radius.tile,
	})

	UI.label(card, "FeaturedName", {
		text = `Featured · {featured.name}`,
		font = UI.font.bold,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 18, 1, -82),
		extent = UDim2.new(1, -36, 0, 16),
	})
	UI.label(card, "Cost", {
		text = `{draw.cost} yen per capsule`,
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkFaint,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 18, 1, -66),
		extent = UDim2.new(1, -36, 0, 16),
	})

	drawButton(card, drawId, 1, UDim2.new(0.03, 0, 1, -44))
	drawButton(card, drawId, 10, UDim2.new(0.51, 0, 1, -44))
end

local function sellableCopies(snapshot: GachaState, skin: CompanionSkins.SkinDefinition): number
	local owned = snapshot.copies[skin.id] or 0
	local reserved = if snapshot.equipped[skin.characterId] == skin.id then 1 else 0
	return math.max(owned - reserved, 0)
end

local function buildCollectionRow(skin: CompanionSkins.SkinDefinition, index: number)
	local snapshot = currentState()
	if not snapshot then
		return
	end
	local count = snapshot.copies[skin.id] or 0
	local equipped = snapshot.equipped[skin.characterId] == skin.id
	local rarity = CompanionSkins.RARITIES[skin.rarity]
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
		extent = UDim2.new(1, -110, 0, 20),
	})
	UI.label(row, "Owned", {
		text = if skin.showcase
			then "Showcase"
			elseif count > 0 then `Owned ×{count}`
			else "Not owned",
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(30, 24),
		extent = UDim2.new(1, -110, 0, 16),
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

local function matchesFilter(skin: CompanionSkins.SkinDefinition): boolean
	if collectionFilter == "all" then
		return true
	end
	if collectionFilter == "showcase" then
		return skin.showcase == true
	end
	return skin.characterId == collectionFilter
end

function renderDetail()
	clearGuiObjects(detailPane)

	local snapshot = currentState()
	local skin = if selectedSkinId then CompanionSkins.get(selectedSkinId) else nil
	if not skin or not snapshot then
		UI.label(detailPane, "Empty", {
			text = "Pick a look on the left to preview it in 3D.",
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

	local rarity = CompanionSkins.RARITIES[skin.rarity]
	local character = CompanionSkins.CHARACTERS[skin.characterId]
	local count = snapshot.copies[skin.id] or 0
	local equipped = snapshot.equipped[skin.characterId] == skin.id
	local sellable = sellableCopies(snapshot, skin)
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(10, 10)
	stage.Size = UDim2.new(1, -20, 0, 172)
	stage.Parent = detailPane
	SkinPreview.mount(stage, skin.id, { spin = true, zoom = 1.6 })

	UI.label(detailPane, "Name", {
		text = skin.name,
		font = UI.font.display,
		size = UI.text.subtitle,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(10, 190),
		extent = UDim2.new(1, -20, 0, 24),
		wrapped = true,
	})
	UI.label(detailPane, "Tagline", {
		text = `{string.upper(rarity.name)}  ·  {if character then character.name else skin.characterId}`,
		font = UI.font.bold,
		size = UI.text.caption,
		color = rarity.color,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(10, 216),
		extent = UDim2.new(1, -20, 0, 16),
	})
	UI.label(detailPane, "Bonus", {
		text = `Best-owned bonus ×{string.format("%.2f", rarity.multiplier)}  ·  sells for {rarity.resaleYen} yen`,
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(10, 236),
		extent = UDim2.new(1, -20, 0, 16),
	})

	if skin.showcase then
		UI.label(detailPane, "Locked", {
			text = "Showcase look - not in the capsule pool.",
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkFaint,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new(0, 10, 1, -70),
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
			position = UDim2.new(0, 10, 1, -70),
			extent = UDim2.new(1, -20, 0, 30),
			wrapped = true,
		})
		return
	end

	if equipped then
		UI.button(detailPane, "Unequip", {
			text = `Back to {if character then character.name else "base"} base`,
			color = UI.color.paperSunken,
			textColor = UI.color.ink,
			textSize = UI.text.caption,
			extent = UDim2.new(1, -20, 0, 32),
			position = UDim2.new(0, 10, 1, -78),
			stroke = false,
			sheen = false,

			onActivated = function()
				equipRemote:FireServer({ characterId = skin.characterId })
			end,
		})
	else
		UI.button(detailPane, "Equip", {
			text = "Equip this look",
			color = UI.color.sky,
			textColor = UI.color.ink,
			extent = UDim2.new(1, -20, 0, 32),
			position = UDim2.new(0, 10, 1, -78),
			stroke = false,
			sheen = false,

			onActivated = function()
				equipRemote:FireServer({ characterId = skin.characterId, skinId = skin.id })
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
			text = "Your only copy is equipped, so it is protected.",
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
	for _, skin in CompanionSkins.SKINS do
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

	local entries = {
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

			onActivated = function()
				collectionFilter = entry.key
				renderCollection()
			end,
		})
		button.LayoutOrder = index
	end
end

local function buildOddsPage(parent: Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "OddsScroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = UI.color.inkSoft
	scroll.Parent = parent
	UI.list(scroll, 8)

	UI.label(scroll, "Intro", {
		text = `Every capsule uses the odds below. A capsule first picks a rarity, then picks evenly from the looks in that rarity. Showcase looks are viewable in the Collection tab but never drop. A rare or better is guaranteed every {CompanionSkins.RARE_PLUS_PITY} pulls, and a legendary every {CompanionSkins.LEGENDARY_PITY}.`,
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -10, 0, 60),
		wrapped = true,
	})

	for index, rarityId in CompanionSkins.RARITY_ORDER do
		local rarity = CompanionSkins.RARITIES[rarityId]
		local standard = CompanionSkins.DRAWS.standard.weights[rarityId]
		local premium = CompanionSkins.DRAWS.premium.weights[rarityId]
		local card = UI.card(scroll, rarityId, {
			color = UI.color.paperRaised,
			radius = UI.radius.chip,
			stroke = false,
			sheen = false,
			innerLine = false,
		})
		card.Size = UDim2.new(1, -10, 0, 58)
		card.LayoutOrder = index
		local stroke = UI.stroke(card, rarity.color, 2)
		stroke.Transparency = 0.25
		UI.label(card, "Name", {
			text = rarity.name,
			font = UI.font.display,
			size = UI.text.body,
			color = rarity.color,
			position = UDim2.fromOffset(14, 8),
			extent = UDim2.new(0.3, 0, 0, 22),
		})
		UI.label(card, "Bonus", {
			text = `Best-owned bonus ×{string.format("%.2f", rarity.multiplier)}  ·  sells for {rarity.resaleYen} yen`,
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkSoft,
			position = UDim2.fromOffset(14, 31),
			extent = UDim2.new(0.56, 0, 0, 18),
		})
		local pool = math.max(CompanionSkins.poolSize(rarityId), 1)
		UI.label(card, "Rates", {
			text = `Standard {standard}%  ·  Premium {premium}%\n{pool} look{if pool == 1 then "" else "s"} · each {string.format(
				"%.2f",
				standard / pool
			)}% / {string.format("%.2f", premium / pool)}%`,
			font = UI.font.bold,
			size = UI.text.caption,
			color = UI.color.ink,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -244, 0, 8),
			extent = UDim2.fromOffset(230, 42),
		})
	end
end

local function buildPanel(parent: ScreenGui)
	local _scrim, content, toggle = UI.modal(parent, "GachaMenu", {
		extent = UDim2.new(0.74, 0, 0.84, 0),
		zIndex = 30,

		onToggled = function(open: boolean)
			isOpen = open
			WorkController.setInputLocked(INPUT_LOCK, open)
		end,
	})
	panel = content
	setOpen = toggle
	UI.padding(panel, UI.space.base)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(700, 520)
	constraint.MaxSize = Vector2.new(980, 680)
	constraint.Parent = panel

	UI.label(panel, "Title", {
		text = "Skin Capsule Shop",
		font = UI.font.display,
		size = UI.text.display,
		extent = UDim2.new(0.6, 0, 0, 30),
	})
	UI.label(panel, "Subtitle", {
		text = "Draw, equip, and trade companion looks.",
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(0, 32),
		extent = UDim2.new(0.68, 0, 0, 20),
	})
	UI.button(panel, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(74, 30),
		position = UDim2.new(1, -74, 0, 2),
		stroke = false,
		sheen = false,

		onActivated = function()
			setOpen(false)
		end,
	})

	local status = UI.card(panel, "Status", {
		color = UI.color.paperRaised,
		radius = UI.radius.chip,
		position = UDim2.fromOffset(0, 56),
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	status.Size = UDim2.new(1, 0, 0, 46)
	yenLabel = UI.label(status, "Yen", {
		text = "0 yen",
		font = UI.font.bold,
		size = UI.text.small,
		position = UDim2.fromOffset(14, 6),
		extent = UDim2.new(0.26, -14, 0, 18),
	})
	capacityLabel = UI.label(status, "Capacity", {
		text = "0 / 60 slots used",
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 24),
		extent = UDim2.new(0.26, -14, 0, 16),
	})
	buildPityMeter(status, "rare", UI.color.sky, UDim2.new(0.3, 0, 0, 7))
	buildPityMeter(status, "legendary", UI.color.gold, UDim2.new(0.65, 0, 0, 7))

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 164)
	body.Size = UDim2.new(1, 0, 1, -164)
	body.Parent = panel

	for _, key in { "draw", "collection", "odds" } do
		local page = Instance.new("Frame")
		page.Name = key
		page.BackgroundTransparency = 1
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = key == activePage
		page.Parent = body
		pages[key] = page
	end

	buildNavigation(panel)

	buildDrawTicket(pages.draw, "standard", UDim2.fromScale(0, 0))
	buildDrawTicket(pages.draw, "premium", UDim2.fromScale(0.515, 0))

	buildCollectionFilters(pages.collection)
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
	collectionList.Parent = pages.collection
	UI.list(collectionList, 6)

	detailPane = UI.card(pages.collection, "Detail", {
		color = UI.color.paperRaised,
		radius = UI.radius.tile,
		position = UDim2.new(0.55, 0, 0, 42),
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	detailPane.Size = UDim2.new(0.45, 0, 1, -42)

	buildOddsPage(pages.odds)
	paintStatus()
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
		or type(candidate.bestByCharacter) ~= "table"
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
	paintStatus()
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
	local results = {}
	for _, raw in rawResults do
		if type(raw) ~= "table" then
			return nil
		end
		local item = raw :: { [string]: unknown }
		if type(item.skinId) ~= "string" or type(item.rarity) ~= "string" or type(item.isNew) ~= "boolean" then
			return nil
		end
		local rarity = CompanionSkins.getRarity(item.rarity)
		if not rarity or not CompanionSkins.get(item.skinId) then
			return nil
		end
		table.insert(results, {
			skinId = item.skinId,
			rarity = rarity.id,
			isNew = item.isNew,
		})
	end
	return results
end

local function isNearNpc(): boolean
	local safeZone = Workspace:FindFirstChild("SafeZone")
	local model = safeZone and safeZone:FindFirstChild("GachaGuy")
	local prompt = model and model:FindFirstChild("GachaPrompt", true)
	local anchor = prompt and prompt.Parent
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return anchor ~= nil
		and anchor:IsA("BasePart")
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - anchor.Position).Magnitude <= CLOSE_DISTANCE
end

function GachaMenu.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "GachaMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 11
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	buildPanel(screen)

	pullRemote = Remotes.event("Gacha", "Pull")
	equipRemote = Remotes.event("Gacha", "Equip")
	sellRemote = Remotes.event("Gacha", "Sell")

	Remotes.event("Gacha", "Open").OnClientEvent:Connect(function(value)
		applyState(value)
		showPage("draw")
		setOpen(true)
	end)

	Remotes.event("Gacha", "Event").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		applyState(payload.state)
		if payload.kind == "pull" then
			local results = parseResults(payload.results)
			if results and type(payload.drawId) == "string" then
				local drawId = payload.drawId
				showPage("draw")
				if cancelReveal then
					cancelReveal()
				end
				if cancelResults then
					cancelResults()
					cancelResults = nil
				end
				cancelReveal = GachaReveal.play(playerGui, results, function()
					cancelReveal = nil
					cancelResults = GachaResults.show(playerGui, results, drawId, function()
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
			paintStatus()
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
			setOpen(false)
		end
	end)

	task.spawn(function()
		while screen.Parent do
			task.wait(0.25)
			if isOpen and not isNearNpc() then
				setOpen(false)
			end
		end
	end)
end

return GachaMenu

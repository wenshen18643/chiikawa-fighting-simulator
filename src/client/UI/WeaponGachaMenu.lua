--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local WeaponSkins = require(Shared.Modules.Config.WeaponSkins)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)
local GachaReveal = require(script.Parent.GachaReveal)
local GachaResults = require(script.Parent.GachaResults)

type GachaState = {
	yen: BigNumber.BigNum,
	unlimitedYen: boolean,
	capacity: number,
	used: number,
	copies: { [string]: number },
	equipped: { [string]: string },
	rarePlusMisses: number,
	legendaryMisses: number,
}

type PullResult = {
	skinId: string,
	rarity: string,
	isNew: boolean,
}

local WeaponGachaMenu = {}
local INPUT_LOCK = "weapon-gacha-menu"
local FLOW_INPUT_LOCK = "weapon-gacha-flow"
local CLOSE_DISTANCE = 24
local WEAPON_ID = "sasumata"
local screen: ScreenGui
local setOpen: (boolean) -> ()
local isOpen = false
local state: GachaState? = nil
local activePage = "draw"
local pullBusy = false
local cancelReveal: (() -> ())? = nil
local cancelResults: (() -> ())? = nil
local pages = {} :: { [string]: Frame }
local drawButtons = {} :: { TextButton }
local tabButtons = {} :: { [string]: TextButton }
local yenLabel: TextLabel
local capacityLabel: TextLabel
local collectionList: ScrollingFrame
local pullRemote: RemoteEvent
local equipRemote: RemoteEvent
local sellRemote: RemoteEvent

local function clearGuiObjects(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function setPullBusy(busy: boolean)
	pullBusy = busy
	WorkController.setInputLocked(FLOW_INPUT_LOCK, busy)
	for _, button in drawButtons do
		button.Active = not busy
		button.AutoButtonColor = not busy
		button.TextTransparency = if busy then 0.4 else 0
	end
end

local function presentResult(result: PullResult): GachaReveal.Presentation?
	local skin = WeaponSkins.get(result.skinId)
	local rarity = WeaponSkins.getRarity(result.rarity)
	if not skin or not rarity then
		return nil
	end
	local weapon = WeaponSkins.WEAPONS[skin.weaponId]
	return {
		name = skin.name,
		subtitle = if weapon then `{weapon.name} skin` else "Weapon skin",
		rarityName = rarity.name,
		rarityColor = rarity.color,
		rarityOrder = rarity.order,
	}
end

local function paintStatus()
	local snapshot = state
	if not snapshot then
		yenLabel.Text = "0 yen"
		capacityLabel.Text = `0 / {WeaponSkins.CAPACITY} slots used`
		return
	end
	yenLabel.Text = if snapshot.unlimitedYen then "∞ yen" else `{BigNumber.toString(snapshot.yen)} yen`
	capacityLabel.Text = `{snapshot.used} / {snapshot.capacity} slots used`
end

local function showPage(key: string)
	activePage = key
	for pageKey, page in pages do
		page.Visible = pageKey == key
	end
	for pageKey, button in tabButtons do
		local selected = pageKey == key
		local accent = if pageKey == "draw"
			then UI.color.gold
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
		position = UDim2.fromOffset(0, 94),
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

local function drawButton(parent: Instance, drawId: WeaponSkins.DrawId, count: number, position: UDim2)
	local draw = WeaponSkins.DRAWS[drawId]
	local accent = if drawId == "premium" then UI.color.gold else UI.color.sky
	local button = UI.button(parent, `Draw{count}`, {
		text = `Draw {count}  ·  {draw.cost * count} yen`,
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

local function buildDrawTicket(parent: Instance, drawId: WeaponSkins.DrawId, position: UDim2)
	local draw = WeaponSkins.DRAWS[drawId]
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
	accent.BackgroundColor3 = if premium then UI.color.gold else UI.color.sky
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromOffset(0, 14)
	accent.Size = UDim2.fromOffset(5, 48)
	accent.Parent = card
	UI.corner(accent, 3)

	UI.label(card, "Eyebrow", {
		text = if premium then "LUCKY WEAPON CAPSULE" else "EVERYDAY WEAPON CAPSULE",
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
	UI.label(card, "Odds", {
		text = `Legendary {draw.weights.legendary}%  ·  Epic {draw.weights.epic}%`,
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(18, 56),
		extent = UDim2.new(1, -32, 0, 20),
	})

	drawButton(card, drawId, 1, UDim2.new(0.03, 0, 1, -44))
	drawButton(card, drawId, 10, UDim2.new(0.51, 0, 1, -44))
end

local function sellableCopies(snapshot: GachaState, skin: WeaponSkins.SkinDefinition): number
	local owned = snapshot.copies[skin.id] or 0
	local reserved = if snapshot.equipped[skin.weaponId] == skin.id then 1 else 0
	return math.max(owned - reserved, 0)
end

local function buildCollectionRow(skin: WeaponSkins.SkinDefinition, index: number)
	local snapshot = state
	if not snapshot then
		return
	end
	local count = snapshot.copies[skin.id] or 0
	local equipped = snapshot.equipped[skin.weaponId] == skin.id
	local sellable = sellableCopies(snapshot, skin)
	local rarity = WeaponSkins.RARITIES[skin.rarity]
	local row = UI.card(collectionList, skin.id, {
		color = if equipped then UI.color.paperDeep else UI.color.paperRaised,
		radius = UI.radius.chip,
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	row.Size = UDim2.new(1, -10, 0, 88)
	row.LayoutOrder = index
	local outline = UI.stroke(row, rarity.color, if equipped then 2 else 1)
	outline.Transparency = if count > 0 then 0.25 else 0.7

	UI.label(row, "Rarity", {
		text = string.upper(rarity.name),
		font = UI.font.bold,
		size = UI.text.caption,
		color = rarity.color,
		position = UDim2.fromOffset(14, 10),
		extent = UDim2.new(0.34, 0, 0, 16),
	})
	UI.label(row, "Name", {
		text = skin.name,
		font = UI.font.display,
		size = UI.text.body,
		color = if count > 0 then UI.color.ink else UI.color.inkFaint,
		position = UDim2.fromOffset(14, 27),
		extent = UDim2.new(0.42, 0, 0, 24),
	})
	UI.label(row, "Weapon", {
		text = "Sasumata finish",
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(14, 54),
		extent = UDim2.new(0.42, 0, 0, 18),
	})
	UI.chip(row, "Copies", {
		text = `×{count}`,
		color = if count > 0 then rarity.color else UI.color.paperSunken,
		textColor = UI.color.ink,
		extent = UDim2.fromOffset(52, 24),
		position = UDim2.new(0.45, 0, 0, 12),
	})

	if equipped then
		UI.chip(row, "Equipped", {
			text = "Equipped",
			color = UI.color.mint,
			textColor = UI.color.ink,
			extent = UDim2.fromOffset(84, 24),
			position = UDim2.new(0.45, 0, 0, 48),
		})
	elseif count > 0 then
		UI.button(row, "Equip", {
			text = "Equip",
			color = UI.color.sky,
			textColor = UI.color.ink,
			extent = UDim2.fromOffset(84, 28),
			position = UDim2.new(0.45, 0, 0, 46),

			onActivated = function()
				equipRemote:FireServer({ weaponId = skin.weaponId, skinId = skin.id })
			end,
		})
	end

	UI.label(row, "Sale", {
		text = `{rarity.resaleYen} yen each`,
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -220, 0, 9),
		extent = UDim2.fromOffset(206, 18),
	})
	if sellable > 0 then
		UI.button(row, "SellOne", {
			text = "Sell 1",
			color = UI.color.paperSunken,
			textColor = UI.color.ink,
			extent = UDim2.fromOffset(92, 30),
			position = UDim2.new(1, -204, 0, 40),

			onActivated = function()
				sellRemote:FireServer({ skinId = skin.id, count = 1 })
			end,
		})
		UI.button(row, "SellMax", {
			text = `Sell {sellable}`,
			color = UI.color.warning,
			textColor = UI.color.ink,
			extent = UDim2.fromOffset(98, 30),
			position = UDim2.new(1, -106, 0, 40),

			onActivated = function()
				sellRemote:FireServer({ skinId = skin.id, count = sellable })
			end,
		})
	else
		UI.label(row, "NoSale", {
			text = if equipped and count == 1 then "Equipped copy is protected" else "No copy to sell",
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkFaint,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -214, 0, 43),
			extent = UDim2.fromOffset(200, 24),
		})
	end
end

local function renderCollection()
	clearGuiObjects(collectionList)
	for index, skin in WeaponSkins.SKINS do
		buildCollectionRow(skin, index)
	end
	collectionList.CanvasPosition = Vector2.zero
end

local function buildBaseLook(parent: Frame)
	local holder = UI.card(parent, "BaseLook", {
		color = UI.color.paperRaised,
		radius = UI.radius.chip,
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	holder.Size = UDim2.new(1, 0, 0, 48)
	UI.label(holder, "Label", {
		text = "SASUMATA BASE LOOK",
		font = UI.font.bold,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(12, 15),
		extent = UDim2.new(0.6, 0, 0, 18),
	})
	UI.button(holder, "EquipBase", {
		text = "Equip Classic Pink",
		color = UI.color.paperSunken,
		textColor = UI.color.ink,
		extent = UDim2.fromOffset(180, 30),
		position = UDim2.new(1, -192, 0, 9),
		stroke = false,
		sheen = false,

		onActivated = function()
			equipRemote:FireServer({ weaponId = WEAPON_ID })
		end,
	})
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
		text = "Every capsule uses the odds below. Each rarity currently contains one Sasumata finish.",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -10, 0, 36),
		wrapped = true,
	})

	for index, rarityId in WeaponSkins.RARITY_ORDER do
		local rarity = WeaponSkins.RARITIES[rarityId]
		local standard = WeaponSkins.DRAWS.standard.weights[rarityId]
		local premium = WeaponSkins.DRAWS.premium.weights[rarityId]
		local card = UI.card(scroll, rarityId, {
			color = UI.color.paperRaised,
			radius = UI.radius.chip,
			stroke = false,
			sheen = false,
			innerLine = false,
		})
		card.Size = UDim2.new(1, -10, 0, 58)
		card.LayoutOrder = index
		local outline = UI.stroke(card, rarity.color, 2)
		outline.Transparency = 0.25
		UI.label(card, "Name", {
			text = rarity.name,
			font = UI.font.display,
			size = UI.text.body,
			color = rarity.color,
			position = UDim2.fromOffset(14, 8),
			extent = UDim2.new(0.3, 0, 0, 22),
		})
		UI.label(card, "Bonus", {
			text = `Sells for {rarity.resaleYen} yen`,
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkSoft,
			position = UDim2.fromOffset(14, 31),
			extent = UDim2.new(0.56, 0, 0, 18),
		})
		UI.label(card, "Rates", {
			text = `Standard {standard}%  ·  Premium {premium}%`,
			font = UI.font.bold,
			size = UI.text.caption,
			color = UI.color.ink,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -244, 0, 18),
			extent = UDim2.fromOffset(230, 22),
		})
	end
end

local function buildPanel(parent: ScreenGui)
	local _scrim, content, toggle = UI.modal(parent, "WeaponGachaMenu", {
		extent = UDim2.new(0.74, 0, 0.84, 0),
		zIndex = 30,

		onToggled = function(open: boolean)
			isOpen = open
			WorkController.setInputLocked(INPUT_LOCK, open)
		end,
	})
	setOpen = toggle
	UI.padding(content, UI.space.base)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(620, 500)
	constraint.MaxSize = Vector2.new(780, 650)
	constraint.Parent = content

	UI.label(content, "Title", {
		text = "Weapon Skin Capsule Shop",
		font = UI.font.display,
		size = UI.text.display,
		extent = UDim2.new(0.68, 0, 0, 30),
	})
	UI.label(content, "Subtitle", {
		text = "Draw, equip, and trade Sasumata finishes.",
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(0, 32),
		extent = UDim2.new(0.68, 0, 0, 20),
	})
	UI.button(content, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(74, 30),
		position = UDim2.new(1, -74, 0, 2),
		stroke = false,
		sheen = false,

		onActivated = function()
			setOpen(false)
		end,
	})

	local status = UI.card(content, "Status", {
		color = UI.color.paperRaised,
		radius = UI.radius.pill,
		position = UDim2.fromOffset(0, 56),
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	status.Size = UDim2.new(1, 0, 0, 30)
	yenLabel = UI.label(status, "Yen", {
		text = "0 yen",
		font = UI.font.bold,
		size = UI.text.small,
		position = UDim2.fromOffset(12, 5),
		extent = UDim2.new(0.5, -12, 0, 20),
	})
	capacityLabel = UI.label(status, "Capacity", {
		text = "0 / 60 slots used",
		font = UI.font.body,
		size = UI.text.small,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0.5, 0, 0, 5),
		extent = UDim2.new(0.5, -12, 0, 20),
	})

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 148)
	body.Size = UDim2.new(1, 0, 1, -148)
	body.Parent = content
	for _, key in { "draw", "collection", "odds" } do
		local page = Instance.new("Frame")
		page.Name = key
		page.BackgroundTransparency = 1
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = key == activePage
		page.Parent = body
		pages[key] = page
	end

	buildNavigation(content)
	buildDrawTicket(pages.draw, "standard", UDim2.fromScale(0, 0))
	buildDrawTicket(pages.draw, "premium", UDim2.fromScale(0.515, 0))
	buildBaseLook(pages.collection)

	collectionList = Instance.new("ScrollingFrame")
	collectionList.Name = "CollectionList"
	collectionList.BackgroundTransparency = 1
	collectionList.BorderSizePixel = 0
	collectionList.Position = UDim2.fromOffset(0, 56)
	collectionList.Size = UDim2.new(1, 0, 1, -56)
	collectionList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	collectionList.CanvasSize = UDim2.fromOffset(0, 0)
	collectionList.ScrollBarThickness = 6
	collectionList.ScrollBarImageColor3 = UI.color.inkSoft
	collectionList.Parent = pages.collection
	UI.list(collectionList, 7)
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
	local results = {} :: { PullResult }
	for _, raw in rawResults do
		if type(raw) ~= "table" then
			return nil
		end
		local item = raw :: { [string]: unknown }
		if type(item.skinId) ~= "string" or type(item.rarity) ~= "string" or type(item.isNew) ~= "boolean" then
			return nil
		end
		local rarity = WeaponSkins.getRarity(item.rarity)
		if not rarity or not WeaponSkins.get(item.skinId) then
			return nil
		end
		local result: PullResult = { skinId = item.skinId, rarity = item.rarity, isNew = item.isNew }
		table.insert(results, result)
	end
	return results
end

local function isNearNpc(): boolean
	local safeZone = Workspace:FindFirstChild("SafeZone")
	local model = safeZone and safeZone:FindFirstChild("WeaponsGachaGuy")
	local prompt = model and model:FindFirstChild("WeaponGachaPrompt", true)
	local anchor = prompt and prompt.Parent
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return anchor ~= nil
		and anchor:IsA("BasePart")
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - anchor.Position).Magnitude <= CLOSE_DISTANCE
end

function WeaponGachaMenu.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	screen = Instance.new("ScreenGui")
	screen.Name = "WeaponGachaMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 12
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	buildPanel(screen)

	pullRemote = Remotes.event("WeaponGacha", "Pull")
	equipRemote = Remotes.event("WeaponGacha", "Equip")
	sellRemote = Remotes.event("WeaponGacha", "Sell")
	Remotes.event("WeaponGacha", "Open").OnClientEvent:Connect(function(value)
		applyState(value)
		showPage("draw")
		setOpen(true)
	end)
	Remotes.event("WeaponGacha", "Event").OnClientEvent:Connect(function(payload)
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

return WeaponGachaMenu

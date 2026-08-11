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

local GachaIndexPage = {}

local function clearGuiObjects(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function GachaIndexPage.build(parent: Frame, config: Config): Controller
	local catalog = config.catalog
	local preview = config.preview
	local activeFilter = "all"
	local selectedId: string? = nil
	local filterBar: Frame
	local indexList: ScrollingFrame
	local detailPane: Frame
	local render: () -> ()

	local function matchesFilter(skin: any): boolean
		if activeFilter == "all" then
			return true
		end
		if config.isWeapon then
			return skin.origin == activeFilter
		end
		if activeFilter == "showcase" then
			return skin.showcase == true
		end
		return skin.characterId == activeFilter
	end

	local function paintFilters()
		for _, child in filterBar:GetChildren() do
			if child:IsA("TextButton") then
				local selected = child.Name == activeFilter
				child.BackgroundColor3 = if selected then UI.color.blush else UI.color.paperSunken
				child.TextColor3 = if selected then UI.color.ink else UI.color.inkSoft
			end
		end
	end

	local function renderDetail()
		clearGuiObjects(detailPane)
		local skin = if selectedId then catalog.get(selectedId) else nil
		if not skin then
			UI.label(detailPane, "Empty", {
				text = if config.isWeapon
					then "Pick a weapon on the left to preview it in 3D."
					else "Pick a look on the left to preview it in 3D.",
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

	local function buildRow(skin: any, index: number)
		local rarity = catalog.RARITIES[skin.rarity]
		local character = if config.isWeapon then nil else catalog.CHARACTERS[skin.characterId]
		local weapon = if config.isWeapon then catalog.getWeapon(skin.weaponId) else nil
		local origin = if config.isWeapon then catalog.getOrigin(skin.origin) else nil
		local chosen = selectedId == skin.id
		local row = UI.button(indexList, skin.id, {
			text = "",
			color = if chosen then UI.color.paperDeep else UI.color.paperRaised,
			radius = UI.radius.chip,
			stroke = false,
			sheen = false,

			onActivated = function()
				selectedId = skin.id
				render()
			end,
		})
		row.Size = UDim2.new(1, -10, 0, 46)
		row.LayoutOrder = index
		row.AutoButtonColor = false
		local stroke = UI.stroke(row, rarity.color, if chosen then 2 else 1)
		stroke.Transparency = 0.2

		local dot = Instance.new("Frame")
		dot.Name = "Rarity"
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.BackgroundColor3 = rarity.color
		dot.BorderSizePixel = 0
		dot.Position = UDim2.new(0, 12, 0.5, 0)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.Parent = row
		UI.corner(dot, UI.radius.pill)

		UI.label(row, "Name", {
			text = skin.name,
			font = UI.font.display,
			size = UI.text.small,
			position = UDim2.fromOffset(30, 6),
			extent = UDim2.new(1, -42, 0, 20),
		})
		UI.label(row, "Category", {
			text = if config.isWeapon
				then `{if weapon then weapon.name else skin.weaponId} · {if origin then origin.name else skin.origin}`
				else if skin.showcase
					then "Showcase"
					else if character then character.name else skin.characterId,
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkSoft,
			position = UDim2.fromOffset(30, 24),
			extent = UDim2.new(1, -42, 0, 16),
		})
	end

	function render()
		clearGuiObjects(indexList)
		local visible = {}
		for _, skin in catalog.SKINS do
			if matchesFilter(skin) then
				table.insert(visible, skin)
			end
		end

		local stillShown = false
		for _, skin in visible do
			if skin.id == selectedId then
				stillShown = true
				break
			end
		end
		if not stillShown then
			selectedId = if visible[1] then visible[1].id else nil
		end

		for index, skin in visible do
			buildRow(skin, index)
		end
		paintFilters()
		renderDetail()
	end

	filterBar = Instance.new("Frame")
	filterBar.Name = "Filters"
	filterBar.BackgroundTransparency = 1
	filterBar.Size = UDim2.new(1, 0, 0, 34)
	filterBar.Parent = parent
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.Padding = UDim.new(0, 6)
	filterLayout.Parent = filterBar

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
		local button = UI.button(filterBar, entry.key, {
			text = entry.label,
			textSize = UI.text.caption,
			color = UI.color.paperSunken,
			textColor = UI.color.inkSoft,
			extent = UDim2.new(1 / #entries, -5, 1, 0),
			stroke = false,
			sheen = false,
			states = false,

			onActivated = function()
				activeFilter = entry.key
				paintFilters()
				render()
			end,
		})
		button.LayoutOrder = index
	end

	indexList = Instance.new("ScrollingFrame")
	indexList.Name = "IndexList"
	indexList.BackgroundTransparency = 1
	indexList.BorderSizePixel = 0
	indexList.Position = UDim2.fromOffset(0, 42)
	indexList.Size = UDim2.new(0.53, 0, 1, -42)
	indexList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	indexList.CanvasSize = UDim2.fromOffset(0, 0)
	indexList.ScrollBarThickness = 6
	indexList.ScrollBarImageColor3 = UI.color.inkSoft
	indexList.Parent = parent
	UI.padding(indexList, 2)
	UI.list(indexList, 6)

	detailPane = UI.card(parent, "Detail", {
		color = UI.color.paperRaised,
		radius = UI.radius.tile,
		position = UDim2.new(0.55, 0, 0, 42),
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	detailPane.Size = UDim2.new(0.45, 0, 1, -42)

	render()
	return {
		render = render,

		reset = function()
			activeFilter = "all"
			selectedId = nil
			render()
		end,
	}
end

return GachaIndexPage

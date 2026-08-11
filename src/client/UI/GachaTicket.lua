--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local UI = require(Shared.UI)

export type Catalog = {
	RARITY_ORDER: { CompanionSkins.RarityId },
	RARITIES: { [string]: CompanionSkins.RarityDefinition },
	DRAWS: { [string]: CompanionSkins.DrawDefinition },
	poolSize: (rarityId: string, includeShowcase: boolean?) -> number,
}

export type TicketConfig = {
	catalog: Catalog,
	drawId: CompanionSkins.DrawId,
	position: UDim2,
	featuredName: string,
	mountFeatured: (stage: Frame) -> (),
	onDraw: (count: number) -> (),
	onButton: (button: TextButton) -> (),
}

export type OddsConfig = {
	catalog: Catalog,
	noun: string,
	intro: string,
	resale: (rarity: CompanionSkins.RarityDefinition) -> string,
}

local GachaTicket = {}
local ODDS_TOP = 58
local ODDS_HEIGHT = 38
local STAGE_TOP = ODDS_TOP + ODDS_HEIGHT + 6
local FOOTER = 96

local function compactYen(amount: number): string
	if amount < 1000 then
		return tostring(amount)
	end

	local thousands = amount / 1000
	if thousands % 1 == 0 then
		return `{thousands}k`
	end

	return `{string.format("%.1f", thousands)}k`
end

local function drawButton(parent: Frame, config: TicketConfig, count: number, position: UDim2)
	local draw = config.catalog.DRAWS[config.drawId]
	local accent = if config.drawId == "premium" then UI.color.gold else UI.color.sky
	local button = UI.button(parent, `Draw{count}`, {
		text = `Draw {count}  ·  {compactYen(draw.cost * count)}`,
		color = accent,
		textColor = UI.color.ink,
		extent = UDim2.new(0.46, 0, 0, 44),
		position = position,
		stroke = false,
		sheen = false,

		onActivated = function()
			config.onDraw(count)
		end,
	})
	UI.glyph(button, "coin", {
		color = UI.color.ink,
		extent = UDim2.fromOffset(17, 17),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.new(0.84, 0, 0.5, 0),
		zIndex = button.ZIndex + 1,
	})
	config.onButton(button)
end

local function buildOddsStrip(card: Frame, surface: Color3, config: TicketConfig)
	local catalog = config.catalog
	local draw = catalog.DRAWS[config.drawId]
	local strip = Instance.new("Frame")
	strip.Name = "Odds"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(18, ODDS_TOP)
	strip.Size = UDim2.new(1, -36, 0, ODDS_HEIGHT)
	strip.Parent = card

	local slots = #catalog.RARITY_ORDER
	for index, rarityId in catalog.RARITY_ORDER do
		local rarity = catalog.RARITIES[rarityId]
		local left = UDim2.new((index - 1) / slots, 2, 0, 0)
		local width = UDim2.new(1 / slots, -4, 0, 5)
		local pip = Instance.new("Frame")
		pip.Name = rarityId
		pip.BackgroundColor3 = rarity.color
		pip.BorderSizePixel = 0
		pip.Position = left
		pip.Size = width
		pip.Parent = strip
		UI.corner(pip, UI.radius.pill)

		UI.label(strip, `{rarityId}Name`, {
			text = rarity.name,
			font = UI.font.display,
			size = UI.text.small,
			color = UI.accentInk(surface, rarity.color),
			align = Enum.TextXAlignment.Center,
			position = UDim2.new((index - 1) / slots, 2, 0, 8),
			extent = UDim2.new(1 / slots, -4, 0, 14),
		})
		UI.label(strip, `{rarityId}Rate`, {
			text = `{draw.weights[rarityId]}%`,
			font = UI.font.bold,
			size = UI.text.small,
			color = UI.color.ink,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new((index - 1) / slots, 2, 0, 22),
			extent = UDim2.new(1 / slots, -4, 0, 14),
		})
	end
end

function GachaTicket.build(parent: Instance, config: TicketConfig): Frame
	local draw = config.catalog.DRAWS[config.drawId]
	local premium = config.drawId == "premium"
	local surface = if premium then UI.color.sand else UI.color.paperRaised
	local accent = if premium then UI.color.gold else UI.color.sky
	local card = UI.card(parent, config.drawId, {
		color = surface,
		radius = UI.radius.card,
		position = config.position,
		stroke = false,
		sheen = false,
		innerLine = false,
	})
	card.Size = UDim2.new(0.485, 0, 1, 0)

	local rail = Instance.new("Frame")
	rail.Name = "Accent"
	rail.BackgroundColor3 = accent
	rail.BorderSizePixel = 0
	rail.Position = UDim2.fromOffset(0, 14)
	rail.Size = UDim2.fromOffset(5, 48)
	rail.Parent = card
	UI.corner(rail, 3)

	UI.label(card, "Title", {
		text = draw.name,
		font = UI.font.display,
		size = UI.text.title,
		position = UDim2.fromOffset(18, 14),
		extent = UDim2.new(1, -32, 0, 28),
	})

	buildOddsStrip(card, surface, config)

	local stage = Instance.new("Frame")
	stage.Name = "Featured"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(18, STAGE_TOP)
	stage.Size = UDim2.new(1, -36, 1, -(STAGE_TOP + FOOTER))
	stage.Parent = card
	config.mountFeatured(stage)

	local featuredLabel = UI.label(card, "FeaturedName", {
		text = `Featured · {config.featuredName}`,
		font = UI.font.display,
		size = UI.text.subtitle,
		color = UI.color.ink,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 18, 1, -(FOOTER - 4)),
		extent = UDim2.new(1, -36, 0, 22),
	})
	featuredLabel.TextTruncate = Enum.TextTruncate.AtEnd

	drawButton(card, config, 1, UDim2.new(0.03, 0, 1, -52))
	drawButton(card, config, 10, UDim2.new(0.51, 0, 1, -52))

	return card
end

local function percent(value: number): string
	if value <= 0 then
		return "0%"
	end
	if value < 0.01 then
		return "<0.01%"
	end
	return `{string.format("%.2f", value)}%`
end

function GachaTicket.oddsPage(parent: Frame, config: OddsConfig): ScrollingFrame
	local catalog = config.catalog
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
	UI.padding(scroll, UI.strokeClearance)

	UI.label(scroll, "Intro", {
		text = config.intro,
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -10, 0, 60),
		wrapped = true,
	})

	for index, rarityId in catalog.RARITY_ORDER do
		local rarity = catalog.RARITIES[rarityId]
		local standard = catalog.DRAWS.standard.weights[rarityId]
		local premium = catalog.DRAWS.premium.weights[rarityId]
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
			color = UI.accentInk(UI.color.paperRaised, rarity.color),
			position = UDim2.fromOffset(14, 8),
			extent = UDim2.new(0.3, 0, 0, 22),
		})
		UI.label(card, "Bonus", {
			text = config.resale(rarity),
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkSoft,
			position = UDim2.fromOffset(14, 31),
			extent = UDim2.new(0.56, 0, 0, 18),
		})

		local pool = math.max(catalog.poolSize(rarityId), 1)
		UI.label(card, "Rates", {
			text = `Standard {standard}%  ·  Premium {premium}%\n{pool} {config.noun}{if pool == 1 then "" else "s"} · each {percent(
				standard / pool
			)} / {percent(premium / pool)}`,
			font = UI.font.bold,
			size = UI.text.caption,
			color = UI.color.ink,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -244, 0, 8),
			extent = UDim2.fromOffset(230, 42),
		})
	end

	return scroll
end

return GachaTicket

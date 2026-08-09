local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Modules.Boosts)
local Constants = require(Shared.Modules.Constants)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Recipes = require(Shared.Modules.Config.Recipes)
local Remotes = require(Shared.Modules.Remotes)
local Seasonings = require(Shared.Modules.Config.Seasonings)
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local UIManager = require(script.Parent.UIManager)
local InventoryMenu = {}
local MENU_ID = "inventory"
local TOGGLE_ACTION = "InventoryToggle"
local INGREDIENT_CELL = UDim2.fromOffset(160, 96)
local CONSUMABLE_CELL = UDim2.fromOffset(246, 122)
local USE_COOLDOWN = 0.5

local EMPTY_TEXT = {
	ingredients = "Nothing foraged yet.\nWild carrots, potatoes and rice grow west of Town.",
	dishes = "No dishes yet.\nTake ingredients to the kitchen pot in Town.",
	seasonings = "No seasonings yet.\nThey turn up in the weeds, now and then.",
}

local screen: ScreenGui
local panel: Frame
local listHolder: ScrollingFrame
local grid: UIGridLayout
local emptyLabel: TextLabel
local setPanelOpen: (boolean, boolean?) -> ()
local closeButton: TextButton
local eatRemote: RemoteEvent
local useSeasoningRemote: RemoteEvent
local currentTab = "ingredients"
local isOpen = false
local renderedFrom: string? = nil
local usingUntil: { [string]: number } = {}

local function ownedIngredients(counts: { [string]: number }): { { [string]: any } }
	local rows = {}
	for index, id in Ingredients.ORDER do
		local count = counts[id] or 0
		local def = Ingredients.get(id)
		if count > 0 and def then
			table.insert(rows, { id = id, count = count, rarity = Ingredients.RARITY[def.rarity], order = index })
		end
	end

	table.sort(rows, function(a, b)
		if a.rarity.order ~= b.rarity.order then
			return a.rarity.order < b.rarity.order
		end
		return a.order < b.order
	end)

	return rows
end

local function ownedFrom(counts: { [string]: number }, order: { string }): { { [string]: any } }
	local rows = {}
	for _, id in order do
		local count = counts[id] or 0
		if count > 0 then
			table.insert(rows, { id = id, count = count })
		end
	end
	return rows
end

local function countsFor(snapshot: any): ({ [string]: number }, { string })
	if currentTab == "dishes" then
		return snapshot.dishes or {}, Recipes.ORDER
	end
	if currentTab == "seasonings" then
		return snapshot.seasonings or {}, Seasonings.ORDER
	end
	return snapshot.ingredients or {}, Ingredients.ORDER
end

local function signature(snapshot: any): string
	local parts = { currentTab }
	local counts, order = countsFor(snapshot)
	for _, id in order do
		local count = counts and counts[id] or 0
		if count > 0 then
			table.insert(parts, `{id}={count}`)
		end
	end
	return table.concat(parts, ",")
end

local function buildIngredientCard(row: { [string]: any }, index: number)
	local def = Ingredients.get(row.id) :: Ingredients.IngredientDefinition
	local tint = row.rarity.color
	local card = UI.card(listHolder, def.id, { radius = UI.radius.chip })
	card.LayoutOrder = index

	if def.image then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Image = def.image
		image.ScaleType = Enum.ScaleType.Fit
		image.Position = UDim2.fromOffset(8, 8)
		image.Size = UDim2.fromOffset(38, 38)
		image.ZIndex = card.ZIndex + 2
		image.Parent = card
	else
		UI.glyph(card, def.glyph, {
			color = tint,
			extent = UDim2.fromOffset(30, 30),
			position = UDim2.fromOffset(12, 12),
			zIndex = card.ZIndex + 2,
		})
	end

	local name = UI.label(card, "Name", {
		text = def.name,
		font = UI.font.bold,
		size = UI.text.small,
		extent = UDim2.new(1, -60, 0, 30),
		position = UDim2.fromOffset(50, 12),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd

	UI.label(card, "Count", {
		text = `x{row.count}`,
		font = UI.font.display,
		size = UI.text.title,
		extent = UDim2.new(1, -100, 0, 28),
		position = UDim2.fromOffset(12, 54),
	})

	local chip = UI.chip(card, "Rarity", {
		text = string.upper(row.rarity.label),
		textSize = 9,
		color = tint,
		textColor = UI.color.paperDeep,
		extent = UDim2.fromOffset(74, 20),
		position = UDim2.new(1, -84, 1, -30),
		zIndex = card.ZIndex + 1,
	})
	chip.AnchorPoint = Vector2.new(0, 0)
end

local function buildConsumableCard(config: { [string]: any }, index: number)
	local id = config.id
	local card = UI.card(listHolder, id, { radius = UI.radius.chip })
	card.LayoutOrder = index

	UI.glyph(card, config.glyph, {
		color = config.tint,
		extent = UDim2.fromOffset(34, 34),
		position = UDim2.fromOffset(14, 14),
		zIndex = card.ZIndex + 2,
	})

	local name = UI.label(card, "Name", {
		text = config.name,
		font = UI.font.display,
		size = UI.text.body,
		extent = UDim2.new(1, -120, 0, 34),
		position = UDim2.fromOffset(58, 14),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd

	UI.chip(card, "Count", {
		text = `x{config.count}`,
		textSize = 12,
		extent = UDim2.fromOffset(44, 24),
		position = UDim2.new(1, -58, 0, 19),
		zIndex = card.ZIndex + 1,
	})

	local effectText = ""
	local recipeDef = Recipes.get(config.id)
	if recipeDef and Recipes.isAmplifier(recipeDef) then
		effectText = `Food buffs last x1.5 longer · {Constants.FOOD.AMPLIFIER_DURATION}s`
	elseif recipeDef then
		effectText = `{Boosts.describeFood(config.buff)} · {Recipes.duration(recipeDef)}s`
	else
		effectText = `{Boosts.describe(config.buff)} · {config.buff.duration}s`
	end

	UI.label(card, "Effect", {
		text = effectText,
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.ink,
		wrapped = true,
		extent = UDim2.new(1, -110, 0, 44),
		position = UDim2.fromOffset(14, 56),
	})

	local cooling = (usingUntil[id] or 0) > os.clock()
	local button
	button = UI.button(card, "Use", {
		text = config.verb,
		color = if cooling then UI.color.paperDeep else UI.color.leafDeep,
		textColor = if cooling then UI.color.inkFaint else UI.readable(UI.color.leafDeep),
		extent = UDim2.fromOffset(80, 30),
		position = UDim2.new(1, -94, 1, -44),
		zIndex = card.ZIndex + 1,

		onActivated = function()
			if (usingUntil[id] or 0) > os.clock() then
				return
			end
			usingUntil[id] = os.clock() + USE_COOLDOWN

			button.BackgroundColor3 = UI.color.paperDeep
			button.TextColor3 = UI.color.inkFaint
			config.remote:FireServer(id)

			task.delay(USE_COOLDOWN, function()
				if button.Parent then
					button.BackgroundColor3 = UI.color.leafDeep
				button.TextColor3 = UI.readable(UI.color.leafDeep)
				end
			end)
		end,
	})
end

local function render()
	local snapshot = StateController.getSnapshot()
	if not snapshot then
		return
	end
	renderedFrom = signature(snapshot)

	for _, child in listHolder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local counts, order = countsFor(snapshot)
	local rows = ownedFrom(counts, order)
	local count = #rows

	if currentTab == "dishes" then
		grid.CellSize = CONSUMABLE_CELL
		for index, row in rows do
			local def = Recipes.get(row.id) :: Recipes.RecipeDefinition
			buildConsumableCard({
				id = def.id,
				name = def.name,
				glyph = def.glyph,
				tint = Ingredients.RARITY[Recipes.rarity(def)].color,
				count = row.count,
				buff = def.buff,
				verb = "Eat",
				remote = eatRemote,
			}, index)
		end
	elseif currentTab == "seasonings" then
		grid.CellSize = CONSUMABLE_CELL
		for index, row in rows do
			local def = Seasonings.get(row.id) :: Seasonings.SeasoningDefinition
			buildConsumableCard({
				id = def.id,
				name = def.name,
				glyph = def.glyph,
				tint = def.color,
				count = row.count,
				buff = def.buff,
				verb = "Use",
				remote = useSeasoningRemote,
			}, index)
		end
	else
		grid.CellSize = INGREDIENT_CELL
		local sorted = ownedIngredients(counts)
		count = #sorted
		for index, row in sorted do
			buildIngredientCard(row, index)
		end
	end

	emptyLabel.Text = EMPTY_TEXT[currentTab]
	emptyLabel.Visible = count == 0
	listHolder.CanvasPosition = Vector2.zero
end

local function buildPanel(parent: ScreenGui)
	local scrim, content, toggle = UI.modal(parent, "InventoryMenu", {
		extent = UDim2.new(0, 560, 0.78, 0),
		zIndex = 20,

		onToggled = function(open)
			isOpen = open
		end,

		onDismiss = function()
			InventoryMenu.setOpen(false)
		end,
	})
	panel = content
	setPanelOpen = toggle
	scrim.Visible = false

	UI.padding(panel, UI.space.loose)

	UI.label(panel, "Title", {
		text = "Inventory",
		font = UI.font.display,
		size = UI.text.title,
		color = UI.color.ink,
		extent = UDim2.new(1, 0, 0, 30),
	})

	UI.label(panel, "Subtitle", {
		text = "Forage out in the world. Cook at the kitchen. Eat before a long shift.",
		font = UI.font.body,
		size = UI.text.small,
		color = UI.color.ink,
		position = UDim2.fromOffset(0, 32),
		extent = UDim2.new(1, 0, 0, 20),
	})

	UI.tabs(panel, "Tabs", {
		entries = {
			{ key = "ingredients", label = "Ingredients" },
			{ key = "dishes", label = "Dishes" },
			{ key = "seasonings", label = "Seasonings" },
		},
		initial = currentTab,
		position = UDim2.fromOffset(0, 60),
		zIndex = panel.ZIndex + 1,

		onChanged = function(key)
			currentTab = key
			if listHolder then
				render()
			end
		end,
	})

	listHolder = Instance.new("ScrollingFrame")
	listHolder.Name = "List"
	listHolder.BackgroundTransparency = 1
	listHolder.BorderSizePixel = 0
	listHolder.Position = UDim2.fromOffset(0, 106)
	listHolder.Size = UDim2.new(1, 0, 1, -152)
	listHolder.ScrollingDirection = Enum.ScrollingDirection.Y
	listHolder.ScrollBarThickness = 8
	listHolder.ScrollBarImageColor3 = UI.color.ink
	listHolder.ScrollBarImageTransparency = 0.2
	listHolder.CanvasSize = UDim2.fromOffset(0, 0)
	listHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listHolder.ZIndex = panel.ZIndex + 1
	listHolder.Parent = panel
	grid = UI.grid(listHolder, INGREDIENT_CELL, UDim2.fromOffset(UI.space.snug, UI.space.snug))
	UI.padding(listHolder, UI.strokeClearance, { right = 14 })

	emptyLabel = UI.label(panel, "Empty", {
		text = EMPTY_TEXT.ingredients,
		font = UI.font.bold,
		size = 16,
		color = UI.color.ink,
		align = Enum.TextXAlignment.Center,
		wrapped = true,
		position = UDim2.fromOffset(0, 106),
		extent = UDim2.new(1, 0, 1, -152),
		zIndex = panel.ZIndex + 2,
	})
	emptyLabel.Visible = false

	closeButton = UI.button(panel, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(120, 44),
		position = UDim2.new(0.5, -60, 1, -44),
		zIndex = panel.ZIndex + 1,

		onActivated = function()
			InventoryMenu.setOpen(false)
		end,
	})
	UIManager.register(MENU_ID, {
		setVisible = function(visible, instant)
			setPanelOpen(visible, instant)
		end,

		focus = function()
			return closeButton
		end,
	})
end

function InventoryMenu.setOpen(open: boolean)
	if not setPanelOpen then
		return
	end
	if open then
		render()
	end
	if open then
		UIManager.open(MENU_ID)
	else
		UIManager.close(MENU_ID)
	end
end

function InventoryMenu.toggle()
	InventoryMenu.setOpen(not isOpen)
end

function InventoryMenu.init()
	if screen then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screen = gui

	eatRemote = Remotes.event("Inventory", "Eat")
	useSeasoningRemote = Remotes.event("Inventory", "UseSeasoning")
	buildPanel(gui)

	StateController.onChanged(function(snapshot)
		if isOpen and signature(snapshot) ~= renderedFrom then
			render()
		end
	end)

	ContextActionService:BindAction(TOGGLE_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			InventoryMenu.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.I, Enum.KeyCode.ButtonY)
end

return InventoryMenu

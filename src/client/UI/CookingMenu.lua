local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Modules.Boosts)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Recipes = require(Shared.Modules.Config.Recipes)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local FeedbackController = require(script.Parent.Parent.Controllers.FeedbackController)
local GestureController = require(script.Parent.Parent.Controllers.GestureController)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)
local CookingMenu = {}
local COOKING = Constants.COOKING
local ROW_HEIGHT = 112
local STIR_DEBOUNCE = 1.05 / COOKING.MAX_CLICKS_PER_SECOND
local STIR_DURATION = 1.2
local COMPLETE_DURATION = 1.35

type Session = { recipeId: string, current: number, needed: number }

local screen: ScreenGui
local panel: Frame
local recipesView: Frame
local cookingView: Frame
local statusLabel: TextLabel
local dishGlyphHolder: Frame
local dishNameLabel: TextLabel
local progressFill: Frame
local counterLabel: TextLabel
local stirButton: TextButton
local setPanelOpen: (boolean) -> ()
local selectRemote: RemoteEvent
local clickRemote: RemoteEvent
local rowUpdaters: { (any) -> () } = {}
local session: Session? = nil
local isOpen = false
local lastStir = 0

local function hex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

local UNTRAINED = { skills = {} }

local function stirsFor(def: Recipes.RecipeDefinition, snapshot: any): number
	return Formulas.cookClicks(if snapshot and snapshot.skills then snapshot else UNTRAINED, def.baseClicks)
end

local function buildRecipeRow(parent: ScrollingFrame, def: Recipes.RecipeDefinition, index: number): (any) -> ()
	local tint = Ingredients.RARITY[Recipes.rarity(def)].color
	local row = UI.card(parent, def.id, { radius = UI.radius.chip })
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = index

	UI.glyph(row, def.glyph, {
		color = tint,
		extent = UDim2.fromOffset(36, 36),
		position = UDim2.fromOffset(14, 14),
		zIndex = row.ZIndex + 2,
	})

	UI.label(row, "Name", {
		text = def.name,
		font = UI.font.display,
		size = UI.text.body,
		extent = UDim2.new(1, -180, 0, 20),
		position = UDim2.fromOffset(60, 14),
	})

	local description = UI.label(row, "Description", {
		text = def.description,
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -180, 0, 18),
		position = UDim2.fromOffset(60, 34),
	})
	description.TextTruncate = Enum.TextTruncate.AtEnd

	local costLabel = UI.label(row, "Cost", {
		text = "",
		font = UI.font.bold,
		size = UI.text.small,
		rich = true,
		extent = UDim2.new(1, -130, 0, 18),
		position = UDim2.fromOffset(14, 62),
	})

	local effectText = ""
	if Recipes.isAmplifier(def) then
		effectText = `Food buffs last x1.5 longer · {Constants.FOOD.AMPLIFIER_DURATION}s`
	else
		effectText = `{Boosts.describeFood(def.buff)} · {Recipes.duration(def)}s`
	end

	UI.label(row, "Effect", {
		text = effectText,
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -130, 0, 18),
		position = UDim2.fromOffset(14, 84),
	})

	if Recipes.hasMeat(def) then
		UI.chip(row, "MeatBadge", {
			text = "MEAT",
			textSize = 10,
			color = UI.color.tobatsu,
			textColor = UI.color.white,
			extent = UDim2.fromOffset(42, 20),
			position = UDim2.new(1, -166, 0, 18),
			zIndex = row.ZIndex + 1,
		})
	end

	local stirsChip = UI.chip(row, "Stirs", {
		text = "",
		textSize = 11,
		extent = UDim2.fromOffset(104, 24),
		position = UDim2.new(1, -118, 0, 16),
		zIndex = row.ZIndex + 1,
	})
	local stirsText = stirsChip:FindFirstChild("Text") :: TextLabel
	local affordable = false
	local cook = UI.button(row, "Cook", {
		text = "Cook",
		extent = UDim2.fromOffset(104, 36),
		position = UDim2.new(1, -118, 1, -52),
		zIndex = row.ZIndex + 1,

		onActivated = function()
			if affordable then
				selectRemote:FireServer(def.id)
			end
		end,
	})

	return function(snapshot: any)
		local owned = snapshot.ingredients or {}
		local parts = {}
		affordable = true

		for _, entry in def.ingredients do
			local ingredient = Ingredients.get(entry.id)
			local have = owned[entry.id] or 0
			local enough = have >= entry.count
			affordable = affordable and enough
			local color = hex(if enough then UI.color.leaf else UI.color.tobatsu)
			local name = ingredient and ingredient.name or entry.id
			table.insert(parts, `<font color="{color}">{entry.count}× {name} ({have})</font>`)
		end

		costLabel.Text = table.concat(parts, "   ")
		stirsText.Text = `~{stirsFor(def, snapshot)} stirs`

		cook.BackgroundColor3 = if affordable then UI.color.leafDeep else UI.color.paperDeep
		cook.TextColor3 = if affordable then UI.color.white else UI.color.inkFaint
		cook.AutoButtonColor = affordable
	end
end

local function setStatus(message: string?)
	statusLabel.Text = message or ""
	statusLabel.Visible = message ~= nil
end

local function showCooking(active: Session)
	local def = Recipes.get(active.recipeId)
	if not def then
		return
	end

	for _, child in dishGlyphHolder:GetChildren() do
		child:Destroy()
	end
	UI.glyph(dishGlyphHolder, def.glyph, {
		color = Ingredients.RARITY[Recipes.rarity(def)].color,
		extent = UDim2.fromOffset(64, 64),
		anchor = Vector2.new(0.5, 0),
		position = UDim2.fromScale(0.5, 0),
		zIndex = cookingView.ZIndex + 2,
	})

	dishNameLabel.Text = def.name
	counterLabel.Text = `{active.current} / {active.needed}`
	progressFill.Size = UDim2.fromScale(math.clamp(active.current / active.needed, 0, 1), 1)

	recipesView.Visible = false
	cookingView.Visible = true
end

local function showRecipes()
	cookingView.Visible = false
	recipesView.Visible = true

	local snapshot = StateController.snapshot
	if not snapshot then
		return
	end
	for _, update in rowUpdaters do
		update(snapshot)
	end
end

local function stir()
	local now = os.clock()
	if now - lastStir < STIR_DEBOUNCE or not session then
		return
	end
	lastStir = now

	clickRemote:FireServer()
	GestureController.play("cook_stir", STIR_DURATION)

	stirButton.BackgroundColor3 = UI.color.leaf
	UI.motion.to(stirButton, UI.motion.settle, { BackgroundColor3 = UI.color.leafDeep })
end

local function buildRecipesView(parent: Frame)
	recipesView = Instance.new("Frame")
	recipesView.Name = "Recipes"
	recipesView.BackgroundTransparency = 1
	recipesView.Size = UDim2.fromScale(1, 1)
	recipesView.ZIndex = parent.ZIndex + 1
	recipesView.Parent = parent

	UI.label(recipesView, "Title", {
		text = "Kitchen",
		font = UI.font.display,
		size = UI.text.title,
		extent = UDim2.new(1, 0, 0, 30),
	})

	UI.label(recipesView, "Subtitle", {
		text = "Every stir trains Resilience. Ingredients are spent the moment you start.",
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(0, 32),
		extent = UDim2.new(1, 0, 0, 20),
	})

	statusLabel = UI.label(recipesView, "Status", {
		text = "",
		font = UI.font.bold,
		size = UI.text.small,
		color = UI.color.rest,
		position = UDim2.fromOffset(0, 54),
		extent = UDim2.new(1, 0, 0, 18),
	})
	statusLabel.Visible = false

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 78)
	list.Size = UDim2.new(1, 0, 1, -124)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = UI.color.inkSoft
	list.ScrollBarImageTransparency = 0.2
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ZIndex = recipesView.ZIndex + 1
	list.Parent = recipesView
	UI.list(list, UI.space.snug)
	UI.padding(list, 0, { right = 14 })

	for index, id in Recipes.ORDER do
		local def = Recipes.get(id)
		if def then
			table.insert(rowUpdaters, buildRecipeRow(list, def, index))
		end
	end

	UI.button(recipesView, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(120, 34),
		position = UDim2.new(0.5, -60, 1, -34),
		zIndex = recipesView.ZIndex + 1,

		onActivated = function()
			setPanelOpen(false)
		end,
	})
end

local function buildCookingView(parent: Frame)
	cookingView = Instance.new("Frame")
	cookingView.Name = "Cooking"
	cookingView.BackgroundTransparency = 1
	cookingView.Size = UDim2.fromScale(1, 1)
	cookingView.Visible = false
	cookingView.ZIndex = parent.ZIndex + 1
	cookingView.Parent = parent

	dishGlyphHolder = Instance.new("Frame")
	dishGlyphHolder.Name = "Dish"
	dishGlyphHolder.BackgroundTransparency = 1
	dishGlyphHolder.Size = UDim2.new(1, 0, 0, 64)
	dishGlyphHolder.Position = UDim2.fromOffset(0, 10)
	dishGlyphHolder.ZIndex = cookingView.ZIndex + 1
	dishGlyphHolder.Parent = cookingView

	dishNameLabel = UI.label(cookingView, "Name", {
		text = "",
		font = UI.font.display,
		size = UI.text.title,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 84),
		extent = UDim2.new(1, 0, 0, 30),
		zIndex = cookingView.ZIndex + 1,
	})

	UI.label(cookingView, "Hint", {
		text = "Stay by the pot. Walk away and the dish is lost.",
		font = UI.font.light,
		size = UI.text.small,
		color = UI.color.inkSoft,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 114),
		extent = UDim2.new(1, 0, 0, 18),
		zIndex = cookingView.ZIndex + 1,
	})

	local track
	track, progressFill = UI.bar(cookingView, "Progress", UI.color.resilience)
	track.Position = UDim2.fromOffset(0, 146)
	track.Size = UDim2.new(1, 0, 0, 22)
	track.ZIndex = cookingView.ZIndex + 1
	progressFill.ZIndex = track.ZIndex + 1

	counterLabel = UI.label(cookingView, "Counter", {
		text = "0 / 0",
		font = UI.font.bold,
		size = UI.text.body,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 174),
		extent = UDim2.new(1, 0, 0, 20),
		zIndex = cookingView.ZIndex + 1,
	})

	stirButton = UI.button(cookingView, "Stir", {
		text = "STIR!",
		font = UI.font.display,
		textSize = 30,
		color = UI.color.leafDeep,
		textColor = UI.color.white,
		radius = UI.radius.card,
		position = UDim2.fromOffset(0, 210),
		extent = UDim2.new(1, 0, 0, 170),
		zIndex = cookingView.ZIndex + 1,
		onActivated = stir,
	})

	UI.button(cookingView, "Close", {
		text = "Close",
		extent = UDim2.fromOffset(120, 34),
		position = UDim2.new(0.5, -60, 1, -34),
		zIndex = cookingView.ZIndex + 1,

		onActivated = function()
			setPanelOpen(false)
		end,
	})
end

local function buildPanel(parent: ScreenGui)
	local scrim, content, toggle = UI.modal(parent, "CookingMenu", {
		extent = UDim2.new(0, 600, 0.82, 0),
		zIndex = 22,

		onToggled = function(open)
			isOpen = open
			WorkController.setInputLocked("cooking-menu", open)
			if not open then
				setStatus(nil)
			end
		end,
	})
	panel = content
	setPanelOpen = toggle
	scrim.Visible = false

	UI.padding(panel, UI.space.loose)
	buildRecipesView(panel)
	buildCookingView(panel)
end

local function onCookEvent(kind: string, recipeId: string, a: any, b: any)
	if kind == "started" then
		session = { recipeId = recipeId, current = 0, needed = a }
		setStatus(nil)
		showCooking(session :: Session)
	elseif kind == "progress" then
		if session and session.recipeId == recipeId then
			session.current = a
			session.needed = b
			showCooking(session)
		end
	elseif kind == "done" then
		session = nil
		GestureController.play("cook_complete", COMPLETE_DURATION)
		FeedbackController.celebrate("resilience")
		showRecipes()
	elseif kind == "cancelled" then
		session = nil
		setStatus("You walked away — the dish was abandoned.")
		showRecipes()
	end
end

function CookingMenu.setOpen(open: boolean)
	if not setPanelOpen then
		return
	end
	if open then
		if session then
			showCooking(session)
		else
			showRecipes()
		end
	end
	setPanelOpen(open)
end

function CookingMenu.init()
	if screen then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "CookingMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screen = gui

	selectRemote = Remotes.event("Cook", "Select")
	clickRemote = Remotes.event("Cook", "Click")
	buildPanel(gui)

	Remotes.event("Cook", "Open").OnClientEvent:Connect(function()
		CookingMenu.setOpen(true)
	end)
	Remotes.event("Cook", "Event").OnClientEvent:Connect(onCookEvent)

	StateController.onChanged(function(snapshot)
		if isOpen and recipesView.Visible then
			for _, update in rowUpdaters do
				update(snapshot)
			end
		end
	end)
end

return CookingMenu

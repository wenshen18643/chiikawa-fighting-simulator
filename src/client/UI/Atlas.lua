--[[
	The Atlas: the full-screen panel behind M / Tab.

	Three tabs, each answering a question the HUD is too small to answer:

	  WORLD   where everything is, what is open, and fast travel. The map is the
	          real landmass at real proportions, drawn from Config/Layout.
	  LADDER  the whole worksite ladder as a grid — six skills across, seven
	          tiers down, every cell showing its requirement, multiplier and
	          which area it first appears in. This is where the cumulative ladder
	          becomes legible: you can see at a glance that the tier you want
	          exists in the area you are standing in.
	  GUIDE   controls, and what the game expects of you.

	Nothing here is authoritative. Every value is read from the last snapshot or
	from shared config; the panel cannot change anything except by asking the
	server to move you (docs/GAME.md §13).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)
local UI = require(Shared.UI)

local StateController = require(script.Parent.Parent.Controllers.StateController)

local Atlas = {}

local ACTION_NAME = "Atlas"

local scrim: Frame
local panel: Frame
local setOpen: (boolean) -> ()
local pages: { [string]: Frame } = {}
local isOpen = false

local travelRemote: RemoteEvent
local areaCells: { [number]: { cell: Frame, status: TextLabel, button: TextButton } } = {}
local ladderCells: { [string]: { cell: Frame, status: TextLabel } } = {}
local playerPin: Frame

--------------------------------------------------------------------------------
-- World page
--------------------------------------------------------------------------------

local function buildWorldPage(parent: Frame)
	local page = Instance.new("Frame")
	page.Name = "World"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.ZIndex = parent.ZIndex + 1
	page.Parent = parent
	pages.world = page

	UI.label(page, "Heading", {
		text = "ONE LANDMASS, SIX DISTRICTS",
		font = UI.font.bold,
		size = 11,
		color = UI.color.inkFaint,
		extent = UDim2.new(1, 0, 0, 16),
	})

	UI.label(page, "Blurb", {
		text = "Everything is walkable. Travel is a shortcut, not the only way there.",
		font = UI.font.light,
		size = 13,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 18),
	})

	--------------------------------------------------------------------------
	-- The map itself: areas at their true relative size and position.
	--------------------------------------------------------------------------
	local map = Instance.new("Frame")
	map.Name = "Map"
	map.Position = UDim2.fromOffset(0, 48)
	map.Size = UDim2.new(1, 0, 0, 168)
	map.BackgroundColor3 = UI.color.paperDeep
	map.BorderSizePixel = 0
	map.ClipsDescendants = true
	map.ZIndex = page.ZIndex + 1
	map.Parent = page
	UI.corner(map, UI.radius.chip)

	local bounds = Layout.BOUNDS_SIZE

	for _, area in Areas.ALL do
		local half = Layout.halfSize(area)
		local left = (area.origin.X - half - Layout.BOUNDS_MIN.X) / bounds.X
		local width = (half * 2) / bounds.X
		local height = (half * 2) / bounds.Z

		local cell = Instance.new("Frame")
		cell.Name = area.key
		cell.AnchorPoint = Vector2.new(0, 0.5)
		cell.Position = UDim2.new(left, 2, 0.5, 0)
		cell.Size = UDim2.new(width, -4, height, 0)
		cell.BackgroundColor3 = area.palette.ground
		cell.BorderSizePixel = 0
		cell.ZIndex = map.ZIndex + 1
		cell.Parent = map
		UI.corner(cell, 6)

		UI.label(cell, "Name", {
			text = area.name,
			font = UI.font.bold,
			size = 11,
			color = UI.color.ink,
			align = Enum.TextXAlignment.Center,
			wrapped = true,
			extent = UDim2.new(1, -6, 0, 30),
			position = UDim2.fromOffset(3, 6),
			zIndex = cell.ZIndex + 1,
		})

		local status = UI.label(cell, "Status", {
			text = "",
			font = UI.font.light,
			size = 10,
			color = UI.color.inkSoft,
			align = Enum.TextXAlignment.Center,
			extent = UDim2.new(1, -6, 0, 12),
			position = UDim2.new(0, 3, 1, -18),
			zIndex = cell.ZIndex + 1,
		})

		-- The whole area cell is the travel button: a separate row of buttons
		-- would mean reading the map and then finding the matching name in a
		-- list, which is two steps to do one thing.
		local button = Instance.new("TextButton")
		button.Name = "Travel"
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.AutoButtonColor = false
		button.ZIndex = cell.ZIndex + 2
		button.Parent = cell
		button.Activated:Connect(function()
			travelRemote:FireServer(area.id)
			setOpen(false)
		end)

		areaCells[area.id] = { cell = cell, status = status, button = button }
	end

	playerPin = UI.glyph(map, "pin", {
		color = UI.color.leafDeep,
		extent = UDim2.fromOffset(18, 18),
		anchor = Vector2.new(0.5, 1),
		zIndex = map.ZIndex + 4,
	})

	UI.label(page, "MapHint", {
		text = "click an area to travel there · your cottage is in Town",
		font = UI.font.light,
		size = 11,
		color = UI.color.inkFaint,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 222),
	})

	return page
end

--------------------------------------------------------------------------------
-- Ladder page
--------------------------------------------------------------------------------

local function buildLadderPage(parent: Frame)
	local page = Instance.new("Frame")
	page.Name = "Ladder"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.ZIndex = parent.ZIndex + 1
	page.Parent = parent
	pages.ladder = page

	UI.label(page, "Heading", {
		text = "EVERY SKILL, EVERY TIER",
		font = UI.font.bold,
		size = 11,
		color = UI.color.inkFaint,
		extent = UDim2.new(1, 0, 0, 16),
	})

	UI.label(page, "Blurb", {
		text = "Each area carries every tier below it, so you can train all six anywhere.",
		font = UI.font.light,
		size = 13,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 18),
	})

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(0, 44)
	grid.Size = UDim2.new(1, 0, 1, -44)
	grid.BackgroundTransparency = 1
	grid.ZIndex = page.ZIndex + 1
	grid.Parent = page

	local columns = #Skills.ORDER
	local HEADER_HEIGHT = 34
	local ROW_HEIGHT = 46

	for columnIndex, skillId in Skills.ORDER do
		local skill = Skills.get(skillId)
		local x = (columnIndex - 1) / columns

		-- Column header: the skill's glyph and name.
		local header = Instance.new("Frame")
		header.Name = `Header_{skillId}`
		header.Position = UDim2.new(x, 3, 0, 0)
		header.Size = UDim2.new(1 / columns, -6, 0, 30)
		header.BackgroundTransparency = 1
		header.ZIndex = grid.ZIndex + 1
		header.Parent = grid

		UI.skillGlyph(header, skillId, {
			color = skill and skill.color or UI.color.leaf,
			extent = UDim2.fromOffset(16, 16),
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, 0),
			zIndex = header.ZIndex + 1,
		})

		UI.label(header, "Name", {
			text = skill and skill.name or skillId,
			font = UI.font.bold,
			size = 11,
			color = skill and skill.color or UI.color.ink,
			align = Enum.TextXAlignment.Center,
			extent = UDim2.new(1, 0, 0, 12),
			position = UDim2.fromOffset(0, 18),
			zIndex = header.ZIndex + 1,
		})

		for tierIndex, worksite in Worksites.getLadder(skillId) do
			local cell = Instance.new("Frame")
			cell.Name = worksite.id
			cell.Position = UDim2.new(x, 3, 0, HEADER_HEIGHT + (tierIndex - 1) * ROW_HEIGHT)
			cell.Size = UDim2.new(1 / columns, -6, 0, ROW_HEIGHT - 4)
			cell.BackgroundColor3 = UI.color.paperDeep
			cell.BorderSizePixel = 0
			cell.ZIndex = grid.ZIndex + 1
			cell.Parent = grid
			UI.corner(cell, 8)

			UI.label(cell, "Tier", {
				text = `T{worksite.tier}  ·  x{worksite.multiplier}`,
				font = UI.font.bold,
				size = 11,
				extent = UDim2.new(1, -10, 0, 13),
				position = UDim2.fromOffset(6, 4),
				zIndex = cell.ZIndex + 1,
			})

			UI.label(cell, "Requirement", {
				text = if BigNumber.isZero(BigNumber.coerce(worksite.requirement))
					then "free"
					else BigNumber.toString(BigNumber.coerce(worksite.requirement)),
				font = UI.font.light,
				size = 10,
				color = UI.color.inkSoft,
				extent = UDim2.new(1, -10, 0, 12),
				position = UDim2.fromOffset(6, 16),
				zIndex = cell.ZIndex + 1,
			})

			local status = UI.label(cell, "Status", {
				text = "",
				font = UI.font.bold,
				size = 10,
				color = UI.color.inkFaint,
				extent = UDim2.new(1, -10, 0, 12),
				position = UDim2.fromOffset(6, 28),
				zIndex = cell.ZIndex + 1,
			})

			ladderCells[worksite.id] = { cell = cell, status = status }
		end
	end

	return page
end

--------------------------------------------------------------------------------
-- Guide page
--------------------------------------------------------------------------------

local CONTROLS = {
	{ key = "W A S D", what = "Walk" },
	{ key = "Shift", what = "Sprint — the world is big" },
	{ key = "Space", what = "Jump" },
	{ key = "Left click", what = "Work. One click is one gain." },
	{ key = "E", what = "Talk to someone" },
	{ key = "M", what = "This panel" },
	{ key = "H", what = "Controls" },
}

local function buildGuidePage(parent: Frame)
	local page = Instance.new("Frame")
	page.Name = "Guide"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.ZIndex = parent.ZIndex + 1
	page.Parent = parent
	pages.guide = page

	UI.label(page, "Heading", {
		text = "HOW THIS WORKS",
		font = UI.font.bold,
		size = 11,
		color = UI.color.inkFaint,
		extent = UDim2.new(1, 0, 0, 16),
	})

	for index, row in CONTROLS do
		local y = 26 + (index - 1) * 34

		UI.chip(page, `Key_{index}`, {
			text = row.key,
			extent = UDim2.fromOffset(120, 26),
			position = UDim2.fromOffset(0, y),
			zIndex = page.ZIndex + 1,
		})

		UI.label(page, `What_{index}`, {
			text = row.what,
			size = 13,
			color = UI.color.ink,
			extent = UDim2.new(1, -134, 0, 26),
			position = UDim2.fromOffset(134, y),
			zIndex = page.ZIndex + 1,
		})
	end

	local notes = {
		"Standing on a pad still earns while you are away, at half rate. Clicking is better.",
		"Out of stamina is a sit-down, not a penalty. You keep earning through it.",
		"Nothing in this game can hurt you. Your cottage is safe by rule, not by luck.",
		"An area opens by itself the moment you have earned it. The gate east unlocks with it.",
	}

	for index, note in notes do
		UI.label(page, `Note_{index}`, {
			text = `·  {note}`,
			font = UI.font.light,
			size = 12,
			color = UI.color.inkSoft,
			wrapped = true,
			extent = UDim2.new(1, 0, 0, 20),
			position = UDim2.fromOffset(0, 26 + #CONTROLS * 34 + 14 + (index - 1) * 22),
			zIndex = page.ZIndex + 1,
		})
	end

	return page
end

--------------------------------------------------------------------------------
-- Live state
--------------------------------------------------------------------------------

local function refresh()
	local snapshot = StateController.snapshot
	if not snapshot then
		return
	end

	for regionId, entry in areaCells do
		local unlocked = snapshot.unlockedRegions[tostring(regionId)] == true
		local here = snapshot.regionId == regionId
		local area = Areas.get(regionId)

		entry.cell.BackgroundTransparency = if unlocked then 0 else 0.6
		entry.button.Active = unlocked
		entry.status.Text = if here
			then "you are here"
			elseif unlocked then "open · click to travel"
			else "not open yet"
		entry.status.TextColor3 = if here then UI.color.leafDeep else UI.color.inkSoft

		if here and area then
			entry.cell.BackgroundColor3 = area.palette.ground:Lerp(UI.color.white, 0.25)
		elseif area then
			entry.cell.BackgroundColor3 = area.palette.ground
		end
	end

	-- Where the player is, on the real map.
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and playerPin then
		local fraction = Layout.toMapFraction(root.Position)
		playerPin.Position = UDim2.fromScale(fraction.X, 0.5)
	end

	--------------------------------------------------------------------------
	-- The ladder grid. A cell says which of three things it is: earned, the
	-- next thing to reach for, or further off.
	--------------------------------------------------------------------------
	local currentArea = Areas.get(snapshot.regionId)

	for worksiteId, entry in ladderCells do
		local worksite = Worksites.get(worksiteId)
		if not worksite then
			continue
		end

		local value = snapshot.skills[worksite.skill]
		local met = value ~= nil and not BigNumber.lt(value, BigNumber.coerce(worksite.requirement))
		local hereNow = currentArea ~= nil and worksite.homeRegion <= currentArea.id

		if met and hereNow then
			entry.status.Text = "OPEN HERE"
			entry.status.TextColor3 = UI.color.leafDeep
			entry.cell.BackgroundTransparency = 0
		elseif met then
			local home = Areas.get(worksite.homeRegion)
			entry.status.Text = string.upper(`from {home and home.name or "?"}`)
			entry.status.TextColor3 = UI.color.inkSoft
			entry.cell.BackgroundTransparency = 0.25
		else
			entry.status.Text = "LOCKED"
			entry.status.TextColor3 = UI.color.inkFaint
			entry.cell.BackgroundTransparency = 0.55
		end
	end
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function Atlas.toggle()
	Atlas.setOpen(not isOpen)
end

function Atlas.setOpen(open: boolean)
	isOpen = open
	setOpen(open)
	if open then
		refresh()
	end
end

function Atlas.isOpen(): boolean
	return isOpen
end

function Atlas.build(parent: Instance)
	travelRemote = Remotes.event("Region", "RequestTravel")

	scrim, panel, setOpen = UI.modal(parent, "Atlas", {
		extent = UDim2.fromScale(0.78, 0.8),
		zIndex = 30,
		onToggled = function(open)
			isOpen = open
		end,
	})
	UI.padding(panel, 22)

	UI.label(panel, "Title", {
		text = "Atlas",
		font = UI.font.display,
		size = 26,
		extent = UDim2.new(1, -120, 0, 32),
	})

	UI.button(panel, "Close", {
		text = "CLOSE",
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 2),
		extent = UDim2.fromOffset(88, 28),
		zIndex = panel.ZIndex + 1,
		onActivated = function()
			Atlas.setOpen(false)
		end,
	})

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 84)
	body.Size = UDim2.new(1, 0, 1, -84)
	body.BackgroundTransparency = 1
	body.ZIndex = panel.ZIndex + 1
	body.Parent = panel

	buildWorldPage(body)
	buildLadderPage(body)
	buildGuidePage(body)

	UI.tabs(panel, "Tabs", {
		position = UDim2.fromOffset(0, 42),
		extent = UDim2.new(1, 0, 0, 32),
		zIndex = panel.ZIndex + 1,
		entries = {
			{ key = "world", label = "World" },
			{ key = "ladder", label = "Ladder" },
			{ key = "guide", label = "Guide" },
		},
		onChanged = function(key)
			for pageKey, page in pages do
				page.Visible = pageKey == key
			end
			refresh()
		end,
	})

	StateController.onChanged(function()
		if isOpen then
			refresh()
		end
	end)

	ContextActionService:BindAction(ACTION_NAME, function(_name, state)
		if state == Enum.UserInputState.Begin then
			Atlas.toggle()
		end
		return Enum.ContextActionResult.Sink
	-- N, not M: M now toggles the minimap, which is the thing players reach for
	-- constantly. The Atlas is the occasional full-screen one and keeps its
	-- side-rail button.
	end, false, Enum.KeyCode.N, Enum.KeyCode.ButtonSelect)

	return scrim
end

return Atlas

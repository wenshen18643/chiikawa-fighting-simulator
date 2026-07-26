--[[
	Client-side reactions to where the player is standing.

	Two jobs, both consequences of the world becoming one continuous landmass:

	  TITLE CARDS. When areas were separate islands reached from a menu, arriving
	  somewhere was an explicit act and the menu was the announcement. Now you
	  walk, and a border is invisible ground. So crossing one — including walking
	  out of your own front door into Town — plays a card with the area's name.
	  It is the only thing that marks the moment, and it is what makes the world
	  feel authored rather than merely large.

	  GATE VEILS. A gate barrier is solid only for players who have not unlocked
	  what is behind it (WorldService's collision groups), but the part itself is
	  visible to everyone. Transparency is a purely local concern, so this clears
	  it for areas the player has already earned: having walked through, they
	  should stop seeing a door.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)

local StateController = require(script.Parent.StateController)

local WorldController = {}

local CARD_HOLD = 1.5

local screen: ScreenGui
local card: Frame
local cardTitle: TextLabel
local cardSubtitle: TextLabel
local cardRule: Frame

local cardToken = 0

--------------------------------------------------------------------------------
-- Title card
--------------------------------------------------------------------------------

--[[
	Type in, hold, fade out. Deliberately non-blocking and non-interactive: the
	player keeps walking through the whole thing, because a cutscene for crossing
	a field would be insufferable by the fourth time.
]]
local function showCard(title: string, subtitle: string)
	cardToken += 1
	local token = cardToken

	cardTitle.Text = string.upper(title)
	cardSubtitle.Text = subtitle

	cardTitle.TextTransparency = 1
	cardSubtitle.TextTransparency = 1
	cardRule.BackgroundTransparency = 1
	cardRule.Size = UDim2.fromOffset(0, 2)
	card.Visible = true

	UI.motion.to(cardTitle, UI.motion.settle, { TextTransparency = 0 })
	UI.motion.to(cardRule, UI.motion.wipe, { BackgroundTransparency = 0.15, Size = UDim2.fromOffset(320, 2) })
	task.delay(0.14, function()
		if token == cardToken then
			UI.motion.to(cardSubtitle, UI.motion.settle, { TextTransparency = 0.15 })
		end
	end)

	task.delay(CARD_HOLD, function()
		if token ~= cardToken then
			return
		end
		UI.motion.to(cardTitle, UI.motion.wipe, { TextTransparency = 1 })
		UI.motion.to(cardSubtitle, UI.motion.wipe, { TextTransparency = 1 })
		local out = UI.motion.play(cardRule, UI.motion.wipe, {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 2),
		})
		out.Completed:Connect(function()
			if token == cardToken then
				card.Visible = false
			end
		end)
	end)
end

--------------------------------------------------------------------------------
-- Gate veils
--------------------------------------------------------------------------------

--[[
	Clears the veil on every gate the player has unlocked.

	Re-run on each snapshot rather than only on unlock, because gates stream in
	and out as the player moves: a barrier that was not loaded when the area
	opened would otherwise still be showing a veil the next time it appears.
]]
local function refreshGates(snapshot: any)
	local world = Workspace:FindFirstChild("World")
	local bridges = world and world:FindFirstChild("Bridges")
	if not bridges then
		return
	end

	for _, gate in bridges:GetChildren() do
		local regionId = gate:GetAttribute("RegionId")
		if type(regionId) ~= "number" then
			continue
		end

		local barrier = gate:FindFirstChild("Barrier") :: BasePart?
		if not barrier then
			continue
		end

		local unlocked = snapshot.unlockedRegions[tostring(regionId)] == true
		local goal = if unlocked then 1 else 0.55
		if math.abs(barrier.Transparency - goal) > 0.01 then
			UI.motion.to(barrier, UI.motion.settle, { Transparency = goal })
		end
	end
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function WorldController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "WorldTitles"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 6
	screen.Parent = playerGui

	card = Instance.new("Frame")
	card.Name = "TitleCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.32)
	card.Size = UDim2.fromOffset(560, 108)
	card.BackgroundTransparency = 1
	card.Visible = false
	card.ZIndex = 25
	card.Parent = screen

	cardTitle = UI.label(card, "Title", {
		text = "",
		font = UI.font.display,
		size = 40,
		color = UI.color.white,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.new(1, 0, 0, 48),
		zIndex = 26,
	})
	cardTitle.TextStrokeTransparency = 0.55

	cardRule = Instance.new("Frame")
	cardRule.Name = "Rule"
	cardRule.AnchorPoint = Vector2.new(0.5, 0)
	cardRule.Position = UDim2.new(0.5, 0, 0, 54)
	cardRule.Size = UDim2.fromOffset(0, 2)
	cardRule.BackgroundColor3 = UI.color.white
	cardRule.BackgroundTransparency = 1
	cardRule.BorderSizePixel = 0
	cardRule.ZIndex = 26
	cardRule.Parent = card

	cardSubtitle = UI.label(card, "Subtitle", {
		text = "",
		font = UI.font.light,
		size = 15,
		color = UI.color.white,
		align = Enum.TextXAlignment.Center,
		wrapped = true,
		extent = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 62),
		zIndex = 26,
	})
	cardSubtitle.TextStrokeTransparency = 0.7

	--------------------------------------------------------------------------
	-- Signals
	--------------------------------------------------------------------------

	Remotes.event("Region", "Entered").OnClientEvent:Connect(function(regionId)
		local area = Areas.get(regionId)
		if area then
			showCard(area.name, area.flavour)
		end
	end)

	--[[
		Leaving the safe zone gets its own card rather than reusing the area one.
		Walking out of your front door is the first thing anyone does, and "TOWN
		& GRASS FIELD" is a less useful thing to say at that moment than telling
		them what just changed about their safety.
	]]
	Remotes.event("SafeZone", "Changed").OnClientEvent:Connect(function(isInside)
		if isInside then
			showCard("Home", "Nothing can reach you here.")
		else
			local town = Areas.BY_ID[Areas.STARTING_AREA]
			showCard(town.name, town.flavour)
		end
	end)

	StateController.onChanged(function(snapshot)
		local ok, err = pcall(refreshGates, snapshot)
		if not ok then
			warn(`[WorldController] gate refresh failed: {err}`)
		end
	end)
end

return WorldController

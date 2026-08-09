local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Modules.Config.Layout)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local StateController = require(script.Parent.StateController)
local WorldController = {}
local CARD_HOLD = 1.5
local LOCATION_CHECK_INTERVAL = 0.25
local HOME_NAME = "Home"
local HOME_FLAVOUR = "Your peaceful place inside the wall."
local screen: ScreenGui
local card: Frame
local cardTitle: TextLabel
local cardSubtitle: TextLabel
local cardRule: Frame
local cardToken = 0
local currentLocationName: string? = nil

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

local function locationAt(position: Vector3): (string, string)
	local area = Layout.areaAt(position)
	if Layout.isHomePosition(area, position) then
		return HOME_NAME, HOME_FLAVOUR
	end
	return area.name, area.flavour
end

local function refreshLocation(position: Vector3)
	local name, flavour = locationAt(position)
	if currentLocationName == name then
		return
	end
	currentLocationName = name
	showCard(name, flavour)
end

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

	Remotes.event("Region", "Entered").OnClientEvent:Connect(function(_regionId)
		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			refreshLocation(rootPart.Position)
		end
	end)

	Remotes.event("SafeZone", "Changed").OnClientEvent:Connect(function(isInside)
		if isInside then
			return
		end

		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then
			return
		end

		local position = rootPart.Position
		local area = Layout.areaAt(position)
		if Layout.isHomePosition(area, position) then
			currentLocationName = HOME_NAME
			showCard(HOME_NAME, HOME_FLAVOUR)
		end
	end)

	local locationAccumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		locationAccumulator += deltaTime
		if locationAccumulator < LOCATION_CHECK_INTERVAL then
			return
		end
		locationAccumulator = 0

		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			refreshLocation(rootPart.Position)
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

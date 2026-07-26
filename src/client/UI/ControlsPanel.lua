--[[
	The controls panel, and the game's only explanation of itself.

	Opens automatically on a player's first session (driven by `showIntro` in
	the server snapshot), and after that on H / F1 / the "?" button.

	The control list is built per input device, because telling a phone player
	to "hold left click" is worse than telling them nothing.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)

local StateController = require(script.Parent.Parent.Controllers.StateController)
local UI = require(Shared.UI)

local ControlsPanel = {}

local TOGGLE_ACTION = "ToggleControls"

local screen: ScreenGui
local panel: Frame
local listHolder: Frame
local open = false
local acknowledged = false
local acknowledgeRemote: RemoteEvent

--------------------------------------------------------------------------------
-- Content
--------------------------------------------------------------------------------

--[[
	One click is one action, so every "hold" below became "tap"/"click". The
	world is also walkable end to end now, so travel is described as the
	shortcut it is rather than as the way to get anywhere.
]]
local function controlRows(): { { key: string, action: string } }
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return {
			{ key = "Stick", action = "Walk around" },
			{ key = "Jump", action = "Jump" },
			{ key = "WORK", action = "Tap the Work button on a coloured pad. One tap, one gain." },
			{ key = "Tap", action = "Talk to a character (tap the prompt above them)" },
			{ key = "Atlas", action = "Map, the skill ladder, and fast travel" },
			{ key = "?", action = "Open this panel again" },
		}
	end

	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return {
			{ key = "L-Stick", action = "Walk around" },
			{ key = "A", action = "Jump" },
			{ key = "L3", action = "Sprint — the world is big" },
			{ key = "R2", action = "Work. One press, one gain." },
			{ key = "X", action = "Talk to a character" },
			{ key = "Select", action = "Atlas — map, ladder, fast travel" },
			{ key = "Start", action = "Open this panel again" },
		}
	end

	return {
		{ key = "W A S D", action = "Walk around" },
		{ key = "Shift", action = "Sprint — it is a long way between areas" },
		{ key = "Space", action = "Jump" },
		{ key = "Left click", action = "Work. One click is one gain, on any coloured pad." },
		{ key = "E", action = "Talk to a character when the prompt appears" },
		{ key = "M", action = "Atlas — the map, the whole skill ladder, and fast travel" },
		{ key = "H", action = "Open this panel again" },
	}
end

local HOW_IT_WORKS = {
	"Stand on a green pad and hold to work. The pad tells you which skill it trains and its multiplier.",
	"Working raises that skill. Weeding also pays you directly, and you earn wages every minute regardless.",
	"Each skill has a ladder of pads. Cross a requirement and the next, better pad opens up.",
	"Out of stamina? You sit down for a moment and keep earning at the slower rate. Nothing is lost.",
}

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function buildRow(index: number, key: string, action: string)
	local row = Instance.new("Frame")
	row.Name = `Row_{index}`
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 30)
	row.LayoutOrder = index
	row.ZIndex = 3
	row.Parent = listHolder

	local chip = Instance.new("Frame")
	chip.Name = "Key"
	chip.Size = UDim2.fromOffset(96, 24)
	chip.Position = UDim2.fromOffset(0, 3)
	chip.BackgroundColor3 = UI.color.paperDeep
	chip.BorderSizePixel = 0
	chip.ZIndex = 3
	chip.Parent = row
	UI.corner(chip, UI.radius.chip)
	UI.stroke(chip)

	UI.label(chip, "Label", {
		text = key,
		font = UI.font.bold,
		size = 12,
		color = UI.color.ink,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 1),
		zIndex = 4,
	})

	local label = UI.label(row, "Action", {
		text = action,
		size = 14,
		color = UI.color.ink,
		extent = UDim2.new(1, -110, 1, 0),
		position = UDim2.fromOffset(108, 0),
	})
	label.TextWrapped = true
end

local function buildPanel(parent: Instance)
	panel = UI.card(parent, "ControlsPanel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 500)
	panel.Visible = false
	panel.ZIndex = 20
	UI.padding(panel, 22)

	UI.label(panel, "Title", {
		text = "How to play",
		font = UI.font.display,
		size = 26,
		extent = UDim2.new(1, -40, 0, 32),
		zIndex = 21,
	})

	UI.label(panel, "Subtitle", {
		text = "A small job, done well.",
		font = UI.font.light,
		size = 13,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 32),
		zIndex = 21,
	})

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = UI.color.paperDeep
	close.BorderSizePixel = 0
	close.Font = UI.font.bold
	close.Text = "×"
	close.TextSize = 20
	close.TextColor3 = UI.color.inkSoft
	close.ZIndex = 22
	close.Parent = panel
	UI.corner(close, UI.radius.pill)
	close.Activated:Connect(function()
		ControlsPanel.setOpen(false)
	end)

	UI.label(panel, "ControlsHeading", {
		text = "CONTROLS",
		font = UI.font.bold,
		size = 11,
		color = UI.color.inkFaint,
		extent = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 62),
		zIndex = 21,
	})

	listHolder = Instance.new("Frame")
	listHolder.Name = "Controls"
	listHolder.BackgroundTransparency = 1
	listHolder.Position = UDim2.fromOffset(0, 82)
	listHolder.Size = UDim2.new(1, 0, 0, 190)
	listHolder.ZIndex = 21
	listHolder.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = listHolder

	for index, row in controlRows() do
		buildRow(index, row.key, row.action)
	end

	UI.label(panel, "LoopHeading", {
		text = "THE LOOP",
		font = UI.font.bold,
		size = 11,
		color = UI.color.inkFaint,
		extent = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 284),
		zIndex = 21,
	})

	for index, line in HOW_IT_WORKS do
		local bullet = UI.label(panel, `Loop_{index}`, {
			text = `·  {line}`,
			font = UI.font.light,
			size = 13,
			color = UI.color.inkSoft,
			extent = UDim2.new(1, 0, 0, 32),
			position = UDim2.fromOffset(0, 302 + (index - 1) * 34),
			zIndex = 21,
		})
		bullet.TextWrapped = true
		bullet.TextYAlignment = Enum.TextYAlignment.Top
	end

	local got = Instance.new("TextButton")
	got.Name = "GotIt"
	got.AnchorPoint = Vector2.new(0.5, 1)
	got.Position = UDim2.new(0.5, 0, 1, 0)
	got.Size = UDim2.fromOffset(180, 34)
	got.BackgroundColor3 = UI.color.leaf
	got.BorderSizePixel = 0
	got.Font = UI.font.bold
	got.Text = "Got it"
	got.TextSize = 14
	got.TextColor3 = UI.color.white
	got.ZIndex = 22
	got.Parent = panel
	UI.corner(got, UI.radius.pill)
	got.Activated:Connect(function()
		ControlsPanel.setOpen(false)
	end)
end

local function buildHelpButton(parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = "HelpButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -18, 1, -18)
	button.Size = UDim2.fromOffset(38, 38)
	button.BackgroundColor3 = UI.color.paper
	button.BorderSizePixel = 0
	button.Font = UI.font.display
	button.Text = "?"
	button.TextSize = 20
	button.TextColor3 = UI.color.inkSoft
	button.ZIndex = 6
	button.Parent = parent
	UI.corner(button, UI.radius.pill)
	UI.stroke(button)

	button.Activated:Connect(function()
		ControlsPanel.setOpen(not open)
	end)
end

--------------------------------------------------------------------------------
-- Behaviour
--------------------------------------------------------------------------------

function ControlsPanel.setOpen(shouldOpen: boolean)
	open = shouldOpen
	panel.Visible = shouldOpen

	if shouldOpen then
		panel.Size = UDim2.fromOffset(440, 480)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(460, 500),
		}):Play()
	elseif not acknowledged then
		-- Closing the panel is the acknowledgement. Only fires once.
		acknowledged = true
		acknowledgeRemote:FireServer()
	end
end

function ControlsPanel.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	acknowledgeRemote = Remotes.event("Guide", "Acknowledge")

	screen = Instance.new("ScreenGui")
	screen.Name = "Controls"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	buildPanel(screen)
	buildHelpButton(screen)

	ContextActionService:BindAction(TOGGLE_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			ControlsPanel.setOpen(not open)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.H, Enum.KeyCode.F1, Enum.KeyCode.ButtonStart)

	-- Open once, on a player's first ever session.
	local disconnect
	disconnect = StateController.onChanged(function(snapshot)
		if snapshot.showIntro and not acknowledged then
			ControlsPanel.setOpen(true)
			if disconnect then
				disconnect()
			end
		elseif not snapshot.showIntro then
			acknowledged = true
			if disconnect then
				disconnect()
			end
		end
	end)
end

return ControlsPanel

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local MovementController = require(script.Parent.Parent.Controllers.MovementController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)
local ControlsPanel = require(script.Parent.ControlsPanel)
local InputMode = require(script.Parent.InputMode)
local UIManager = require(script.Parent.UIManager)
local ControlTutorial = {}

type Step = {
	id: "move" | "run" | "jump" | "work",
	title: string,
	instruction: string,
	key: string,
	accent: Color3,
}

local screen: ScreenGui
local panel: Frame
local accentRule: Frame
local stepLabel: TextLabel
local titleLabel: TextLabel
local instructionLabel: TextLabel
local keycap: Frame
local keycapText: TextLabel
local pips: { Frame } = {}
local steps: { Step } = {}
local current = 0
local active = false
local finished = false
local transitioning = false
local acknowledgeRemote: RemoteEvent
local surfaceSuppressed = false
local changedListeners: { (boolean) -> () } = {}

local function refreshEnabled()
	if screen then
		screen.Enabled = active and not surfaceSuppressed
	end
end

local function notifyActive()
	for _, listener in changedListeners do
		task.spawn(listener, active)
	end
end

function ControlTutorial.onChanged(callback: (boolean) -> ()): () -> ()
	table.insert(changedListeners, callback)
	return function()
		local index = table.find(changedListeners, callback)
		if index then
			table.remove(changedListeners, index)
		end
	end
end

local function lessonPosition(shown: boolean): UDim2
	if screen and UI.responsive.isCompact(screen.AbsoluteSize) then
		return UDim2.new(0.5, 30, 0, if shown then 92 else 80)
	end
	return UDim2.new(0.5, 0, 0, if shown then 18 else 5)
end

local function lessonSize(shown: boolean): UDim2
	if screen and UI.responsive.isCompact(screen.AbsoluteSize) then
		return UDim2.new(1, -140, 0, if shown then 136 else 128)
	end
	return UDim2.new(0.9, 0, 0, if shown then 150 else 142)
end

local function stepList(): { Step }
	if InputMode.current() == "touch" then
		return {
			{
				id = "move",
				title = "Move around",
				instruction = "Hold and drag the movement stick.",
				key = "STICK",
				accent = UI.color.resilience,
			},
			{
				id = "jump",
				title = "Jump",
				instruction = "Tap Jump to hop over anything in your way.",
				key = "JUMP",
				accent = UI.color.examprep,
			},
			{
				id = "work",
				title = "Do one work action",
				instruction = "Tap WORK once. Holding it does not repeat the action.",
				key = "WORK",
				accent = UI.color.kusatori,
			},
		}
	end

	if InputMode.current() == "gamepad" then
		return {
			{
				id = "move",
				title = "Move around",
				instruction = "Hold the left stick in any direction.",
				key = "L-STICK",
				accent = UI.color.resilience,
			},
			{
				id = "run",
				title = "Run",
				instruction = "Click L3 while moving to sprint.",
				key = "L3 + MOVE",
				accent = UI.color.tobatsu,
			},
			{
				id = "jump",
				title = "Jump",
				instruction = "Press A to hop over anything in your way.",
				key = "A",
				accent = UI.color.examprep,
			},
			{
				id = "work",
				title = "Do one work action",
				instruction = "Press R2 once. Holding it does not repeat the action.",
				key = "R2",
				accent = UI.color.kusatori,
			},
		}
	end

	return {
		{
			id = "move",
			title = "Move around",
			instruction = "Hold W, A, S or D to move.",
			key = "W  A  S  D",
			accent = UI.color.resilience,
		},
		{
			id = "run",
			title = "Run",
			instruction = "Hold Shift while moving to sprint.",
			key = "SHIFT + MOVE",
			accent = UI.color.tobatsu,
		},
		{
			id = "jump",
			title = "Jump",
			instruction = "Press Space to hop over anything in your way.",
			key = "SPACE",
			accent = UI.color.examprep,
		},
		{
			id = "work",
			title = "Do one work action",
			instruction = "Left click once. Holding does not repeat the action.",
			key = "LEFT CLICK",
			accent = UI.color.kusatori,
		},
	}
end

local function drawProgress()
	for index, pip in pips do
		local step = steps[index]
		pip.Visible = step ~= nil
		if not step then
			continue
		end
		local complete = index < current
		local here = index == current
		pip.BackgroundColor3 = if complete or here then step.accent else UI.color.line
		pip.BackgroundTransparency = if complete then 0 elseif here then 0.3 else 0.55
		pip.Size = UDim2.fromOffset(if here then 34 else 22, 5)
	end
end

local function showCurrent()
	local step = steps[current]
	if not step then
		return
	end

	stepLabel.Text = `PRACTICE  {current} OF {#steps}`
	titleLabel.Text = step.title
	instructionLabel.Text = step.instruction
	keycap.BackgroundColor3 = step.accent:Lerp(UI.color.paperDeep, 0.74)
	keycapText.Text = step.key
	keycapText.TextColor3 = step.accent
	keycap.Visible = InputMode.current() ~= "touch"
	instructionLabel.Position = if keycap.Visible then UDim2.fromOffset(158, 64) else UDim2.fromOffset(20, 64)
	instructionLabel.Size = if keycap.Visible then UDim2.new(1, -176, 0, 52) else UDim2.new(1, -40, 0, 52)
	accentRule.BackgroundColor3 = step.accent
	drawProgress()
end

local function hideLesson()
	active = false
	transitioning = false
	refreshEnabled()
	notifyActive()
	ControlsPanel.markIntroComplete()
	acknowledgeRemote:FireServer()
end

local function completeStep()
	if not active or transitioning then
		return
	end
	transitioning = true

	local out = UI.motion.play(panel, UI.motion.snap, {
		Position = lessonPosition(false),
		Size = lessonSize(false),
	})
	out.Completed:Connect(function()
		if not active then
			return
		end

		panel.Visible = false
		current += 1
		if current > #steps then
			finished = true
			hideLesson()
			return
		end

		showCurrent()
		panel.Position = lessonPosition(false)
		panel.Size = lessonSize(false)
		task.delay(0.08, function()
			if not active then
				return
			end
			panel.Visible = true
			UI.motion.play(panel, UI.motion.pop, {
				Position = lessonPosition(true),
				Size = lessonSize(true),
			})
			transitioning = false
		end)
	end)
end

local function startLesson()
	if active or finished then
		return
	end

	steps = stepList()
	current = 1
	active = true
	transitioning = false
	refreshEnabled()
	notifyActive()
	panel.Visible = true
	panel.Position = lessonPosition(false)
	panel.Size = lessonSize(false)
	showCurrent()

	UI.motion.play(panel, UI.motion.pop, {
		Position = lessonPosition(true),
		Size = lessonSize(true),
	})
end

local function build(parent: ScreenGui)
	panel = UI.card(parent, "PracticePrompt", {
		color = UI.color.paper,
		transparency = 0,
		radius = UI.radius.card,
		zIndex = 30,
	})
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 18)
	panel.Size = UDim2.new(0.9, 0, 0, 150)
	UI.shadow(panel)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(520, 150)
	constraint.Parent = panel

	accentRule = Instance.new("Frame")
	accentRule.Name = "Accent"
	accentRule.Size = UDim2.new(0, 7, 1, 0)
	accentRule.BackgroundColor3 = UI.color.resilience
	accentRule.BorderSizePixel = 0
	accentRule.ZIndex = 31
	accentRule.Parent = panel

	stepLabel = UI.label(panel, "Step", {
		text = "PRACTICE  1 OF 4",
		font = UI.font.bold,
		size = UI.text.caption,
		color = UI.color.inkFaint,
		position = UDim2.fromOffset(20, 10),
		extent = UDim2.new(1, -130, 0, 16),
		zIndex = 32,
	})

	titleLabel = UI.label(panel, "Title", {
		text = "Move around",
		font = UI.font.display,
		size = 22,
		position = UDim2.fromOffset(20, 27),
		extent = UDim2.new(1, -130, 0, 28),
		zIndex = 32,
	})

	UI.button(panel, "Skip", {
		text = "SKIP LESSON",
		color = UI.color.paperDeep,
		textColor = UI.color.inkFaint,
		textSize = 10,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -14, 0, 14),
		extent = UDim2.fromOffset(104, 44),
		stroke = true,
		zIndex = 33,

		onActivated = function()
			if active then
				finished = true
				hideLesson()
			end
		end,
	})

	keycap = UI.chip(panel, "Key", {
		text = "",
		color = UI.color.paperDeep,
		extent = UDim2.fromOffset(124, 46),
		position = UDim2.fromOffset(20, 66),
		zIndex = 32,
	})
	keycapText = keycap:FindFirstChild("Text") :: TextLabel

	instructionLabel = UI.label(panel, "Instruction", {
		text = "Hold W, A, S or D to move.",
		font = UI.font.body,
		size = 14,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(158, 64),
		extent = UDim2.new(1, -176, 0, 52),
		wrapped = true,
		zIndex = 32,
	})

	local progress = Instance.new("Frame")
	progress.Name = "Progress"
	progress.Position = UDim2.fromOffset(20, 128)
	progress.Size = UDim2.new(1, -40, 0, 8)
	progress.BackgroundTransparency = 1
	progress.ZIndex = 32
	progress.Parent = panel

	local progressLayout = Instance.new("UIListLayout")
	progressLayout.FillDirection = Enum.FillDirection.Horizontal
	progressLayout.Padding = UDim.new(0, 6)
	progressLayout.SortOrder = Enum.SortOrder.LayoutOrder
	progressLayout.Parent = progress

	for index = 1, 4 do
		local pip = Instance.new("Frame")
		pip.Name = `Step_{index}`
		pip.Size = UDim2.fromOffset(22, 5)
		pip.BackgroundColor3 = UI.color.line
		pip.BackgroundTransparency = 0.55
		pip.BorderSizePixel = 0
		pip.LayoutOrder = index
		pip.ZIndex = 33
		pip.Parent = progress
		UI.corner(pip, UI.radius.pill)
		pips[index] = pip
	end
end

local function isMoving(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
end

function ControlTutorial.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	acknowledgeRemote = Remotes.event("Guide", "Acknowledge")

	screen = Instance.new("ScreenGui")
	screen.Name = "ControlTutorial"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 18
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = playerGui

	build(screen)
	surfaceSuppressed = UIManager.hasSurface()
	UIManager.onChanged(function()
		surfaceSuppressed = UIManager.hasSurface()
		refreshEnabled()
	end)
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if active and not transitioning then
			panel.Position = lessonPosition(true)
			panel.Size = lessonSize(true)
		end
	end)
	InputMode.onChanged(function()
		if not active then
			return
		end
		local previousId = if steps[current] then steps[current].id else nil
		steps = stepList()
		current = 1
		if previousId then
			for index, step in steps do
				if step.id == previousId then
					current = index
					break
				end
			end
		end
		showCurrent()
	end)

	ControlsPanel.onClosed(function(firstSession)
		if firstSession then
			startLesson()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not active or transitioning or surfaceSuppressed or ControlsPanel.isOpen() then
			return
		end
		local step = steps[current]
		if not step then
			return
		end
		if (step.id == "move" and isMoving()) or (step.id == "run" and MovementController.isSprinting()) then
			completeStep()
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		if
			active
			and not transitioning
			and not surfaceSuppressed
			and not ControlsPanel.isOpen()
			and steps[current]
			and steps[current].id == "jump"
		then
			completeStep()
		end
	end)

	WorkController.onStart(function()
		if
			active
			and not transitioning
			and not surfaceSuppressed
			and not ControlsPanel.isOpen()
			and steps[current]
			and steps[current].id == "work"
		then
			completeStep()
		end
	end)
end

return ControlTutorial

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)

local MovementController = {}

local MOVEMENT = Constants.MOVEMENT
local ACTION_NAME = "Sprint"

local sprinting = false
local humanoid: Humanoid?

function MovementController.isSprinting(): boolean
	return sprinting and humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
end

local function onAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		sprinting = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprinting = false
	end
	return Enum.ContextActionResult.Pass
end

local function bind(character: Model)
	local found = character:WaitForChild("Humanoid") :: Humanoid
	humanoid = found

	found.WalkSpeed = MOVEMENT.WALK_SPEED
	found.JumpPower = MOVEMENT.JUMP_POWER

	pcall(function()
		found.UseJumpPower = true
	end)
	sprinting = false
end

function MovementController.init()
	local player = Players.LocalPlayer

	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)

	ContextActionService:BindAction(
		ACTION_NAME,
		onAction,
		false,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)

	RunService.RenderStepped:Connect(function()
		local target = humanoid
		if not target or target.Health <= 0 then
			return
		end

		local goal = if sprinting then MOVEMENT.SPRINT_SPEED else MOVEMENT.WALK_SPEED
		if math.abs(target.WalkSpeed - goal) < 0.1 then
			target.WalkSpeed = goal
			return
		end
		target.WalkSpeed += (goal - target.WalkSpeed) * MOVEMENT.SPEED_LERP
	end)
end

return MovementController

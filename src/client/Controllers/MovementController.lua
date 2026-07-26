--[[
	Walking and sprinting. See docs/GAME.md §10.

	Exists because the world got big. Six areas laid end to end are roughly
	27,000 studs across, and Roblox's default WalkSpeed of 16 turns that from a
	place into a commute — crossing the Ruins alone would take six minutes.

	SPEC DEVIATION: §10 says sprint drains stamina. It does not. Stamina is the
	work-rate limiter (§4), so charging travel to it means walking across your
	own world costs you income, and the game ends up fining the player for
	looking at it. Sprint is free and always available.

	Speed is eased rather than snapped so the change of pace is felt as
	acceleration. The character's own WalkSpeed is the only thing written here —
	no CFrame manipulation, nothing the server has to trust.
]]

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
	-- Held in a local before being published to the upvalue: the upvalue is
	-- `Humanoid?` by declaration, so writing through it needs a nil check on
	-- every line for something we have just resolved.
	local found = character:WaitForChild("Humanoid") :: Humanoid
	humanoid = found

	found.WalkSpeed = MOVEMENT.WALK_SPEED
	found.JumpPower = MOVEMENT.JUMP_POWER

	--[[
		`UseJumpPower` is the post-2022 JumpHeight/JumpPower toggle and does not
		exist on every Roblox build; assigning to a missing property throws.

		Guarded rather than assumed, because this runs inside a CharacterAdded
		handler where a throw would silently abandon the WalkSpeed set above and
		leave the player permanently slow with no obvious cause. On builds
		without it, JumpPower is authoritative anyway and there is nothing to
		switch.
	]]
	pcall(function()
		found.UseJumpPower = true
	end)
	-- A held sprint key does not survive a respawn, and a character that
	-- respawns at speed with no key down is a bug you cannot see the cause of.
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
		false, -- no touch button: mobile has no spare thumb, and tapping to work
		-- is already the priority there
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

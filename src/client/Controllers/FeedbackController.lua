local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local UI = require(Shared.UI)
local WorkController = require(script.Parent.WorkController)
local FeedbackController = {}
local MAX_POPUPS = 16
local MAX_SPARKS = 40
local screen: ScreenGui
local popupLayer: Frame
local sparkLayer: Frame
local vignetteFrames: { Frame }
local activePopups = 0
local activeSparks = 0
local punch = 0
local punchTarget = 0
local baseFieldOfView = 70
local PUNCH_CAP = 0.45
local PUNCH_FOV = 0.9
local VIGNETTE_ALPHA = 0.94
local VIGNETTE_GAP = 0.4
local lastVignette = 0

local function skillColor(skillId: string?): Color3
	local skill = skillId and Skills.get(skillId)
	return skill and skill.color or UI.color.leaf
end

local function showGain(gain: any, skillId: string?, offsetX: number?, offsetY: number?, sizeScale: number?)
	if activePopups >= MAX_POPUPS or not popupLayer then
		return
	end
	activePopups += 1

	local magnitude = math.max(BigNumber.log10(gain), 0)
	local size = math.clamp(20 + magnitude * 2.4, 20, 44) * (sizeScale or 1)
	local color = skillColor(skillId)

	local label = UI.label(popupLayer, "Gain", {
		text = `+{BigNumber.toString(gain)}`,
		font = UI.font.display,
		size = size,
		color = color,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromOffset(200 * (sizeScale or 1), 36 * (sizeScale or 1)),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.new(0.5, offsetX or math.random(-48, 48), 0.60, offsetY or math.random(-14, 14)),
		zIndex = 9,
	})
	label.TextStrokeTransparency = 0.5
	label.TextTransparency = 1

	label.TextSize = math.floor(size * 0.4)
	UI.motion.to(label, UI.motion.pop, { TextSize = size, TextTransparency = 0 })

	task.delay(0.12, function()
		local rise = UI.motion.play(label, UI.motion.riseOut, {
			Position = label.Position - UDim2.fromOffset(0, 80),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		rise.Completed:Connect(function()
			label:Destroy()
			activePopups -= 1
		end)
	end)
end

local function burst(skillId: string?)
	if not sparkLayer or activeSparks >= MAX_SPARKS then
		return
	end

	local origin = UserInputService:GetMouseLocation()
	local color = skillColor(skillId)
	local glyphName = "spark"
	if skillId == "kusatori" or skillId == "agility" or skillId == "weeding" then
		glyphName = "leaf"
	elseif skillId == "resilience" or skillId == "durability" or skillId == "grit" then
		glyphName = "tears"
	elseif skillId == "examprep" or skillId == "special" or skillId == "craft" then
		glyphName = if math.random() > 0.4 then "book" else "lightbulb"
	elseif skillId == "tobatsu" or skillId == "strength" or skillId == "subjugation" then
		glyphName = if math.random() > 0.45 then "sasumata" else "sweat"
	end

	if math.random() < 0.15 then
		glyphName = "ramen"
	end

	local count = 7

	for index = 1, count do
		activeSparks += 1

		local spark = UI.glyph(sparkLayer, glyphName, {
			color = color,
			extent = UDim2.fromOffset(16, 16),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(origin.X, origin.Y),
			rotation = math.random(-30, 30),
			zIndex = 8,
		})

		local angle: number
		local distance: number

		if glyphName == "tears" then
			local side = if index % 2 == 0 then 1 else -1
			angle = (side > 0 and 0 or math.pi) + math.random(-0.35, 0.35)
			distance = math.random(60, 120)
		else
			angle = (index / count) * math.pi * 2 + math.random() * 0.5
			distance = math.random(40, 90)
		end

		local target = UDim2.fromOffset(origin.X + math.cos(angle) * distance, origin.Y + math.sin(angle) * distance)

		local fly = UI.motion.play(spark, UI.motion.riseOut, {
			Position = target,
			Rotation = spark.Rotation + math.random(-120, 120),
			Size = UDim2.fromOffset(4, 4),
		})
		fly.Completed:Connect(function()
			spark:Destroy()
			activeSparks -= 1
		end)
	end
end

local function pulseVignette(skillId: string?, force: boolean?)
	if not vignetteFrames or UI.motion.isReducedMotion() then
		return
	end

	local now = os.clock()
	if not force and now - lastVignette < VIGNETTE_GAP then
		return
	end
	lastVignette = now

	local color = skillColor(skillId)
	for _, frame in vignetteFrames do
		frame.BackgroundColor3 = color
		UI.motion.to(frame, UI.motion.snap, { BackgroundTransparency = VIGNETTE_ALPHA })
		task.delay(0.12, function()
			UI.motion.to(frame, UI.motion.settle, { BackgroundTransparency = 1 })
		end)
	end
end

local characterEffects: { sweat: ParticleEmitter?, trail: Trail? } = {}
local trailUntil = 0

local function buildCharacterEffects(character: Model)
	characterEffects = {}

	local head = character:FindFirstChild("Head") :: BasePart?
	if head then
		local anchor = Instance.new("Attachment")
		anchor.Name = "SweatAnchor"
		anchor.Position = Vector3.new(0, 0.3, 0)
		anchor.Parent = head

		local sweat = Instance.new("ParticleEmitter")
		sweat.Name = "Sweat"
		sweat.Enabled = false
		sweat.Color = ColorSequence.new(Color3.fromRGB(186, 226, 246))
		sweat.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.32),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		sweat.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		sweat.Lifetime = NumberRange.new(0.35, 0.6)
		sweat.Speed = NumberRange.new(7, 12)
		sweat.SpreadAngle = Vector2.new(70, 70)
		sweat.Acceleration = Vector3.new(0, -58, 0)
		sweat.Rate = 0
		sweat.Rotation = NumberRange.new(0, 360)
		sweat.Parent = anchor

		characterEffects.sweat = sweat
	end

	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		local top = Instance.new("Attachment")
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, 0.35, 0)
		top.Parent = hand

		local bottom = Instance.new("Attachment")
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -0.35, 0)
		bottom.Parent = hand

		local trail = Instance.new("Trail")
		trail.Name = "SpeedTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Enabled = false
		trail.Lifetime = 0.28
		trail.MinLength = 0.1
		trail.FaceCamera = true
		trail.LightEmission = 0.4
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Parent = hand

		characterEffects.trail = trail
	end
end

local SWEAT_DELAY = 0.30
local TRAIL_LINGER = 0.45

local function playCharacterEffect(skillId: string?)
	if not skillId then
		return
	end

	if skillId == "tobatsu" or skillId == "strength" or skillId == "subjugation" then
		local sweat = characterEffects.sweat
		if sweat then
			task.delay(SWEAT_DELAY, function()
				if sweat.Parent then
					sweat:Emit(6)
				end
			end)
		end
	elseif skillId == "kusatori" or skillId == "agility" or skillId == "weeding" then
		local trail = characterEffects.trail
		if trail then
			trail.Color = ColorSequence.new(skillColor(skillId))
			trail.Enabled = true
			trailUntil = os.clock() + TRAIL_LINGER
		end
	end
end

local function expireTrail()
	local trail = characterEffects.trail
	if trail and trail.Enabled and os.clock() >= trailUntil then
		trail.Enabled = false
	end
end

local function kickCamera(strength: number)
	if UI.motion.isReducedMotion() then
		return
	end
	punchTarget = math.min(punchTarget + strength, PUNCH_CAP)
end

local function driveCamera(delta: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	if punch <= 0.001 and punchTarget <= 0.001 then
		return
	end

	punchTarget *= math.exp(-delta * 9)
	punch += (punchTarget - punch) * math.min(delta * 16, 1)

	if punch <= 0.001 and punchTarget <= 0.001 then
		punch = 0
		punchTarget = 0
		camera.FieldOfView = baseFieldOfView
		return
	end
	camera.FieldOfView = baseFieldOfView - punch * PUNCH_FOV
end

local function rumble()
	if not UserInputService.GamepadEnabled or UI.motion.isReducedMotion() then
		return
	end
	if not HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small) then
		return
	end
	HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.22)
	task.delay(0.06, function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
	end)
end

function FeedbackController.celebrate(skillId: string?)
	burst(skillId)
	pulseVignette(skillId, true)
	kickCamera(0.45)
	rumble()
end

local function onLocalClick(skillId: string?)
	burst(skillId)
	pulseVignette(skillId)
	kickCamera(0.28)
	rumble()
end

function FeedbackController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "Feedback"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 5
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	vignetteFrames = UI.vignette(screen, "Pulse", UI.color.leaf)

	popupLayer = Instance.new("Frame")
	popupLayer.Name = "Gains"
	popupLayer.Size = UDim2.fromScale(1, 1)
	popupLayer.BackgroundTransparency = 1
	popupLayer.ZIndex = 9
	popupLayer.Parent = screen

	sparkLayer = Instance.new("Frame")
	sparkLayer.Name = "Sparks"
	sparkLayer.Size = UDim2.fromScale(1, 1)
	sparkLayer.BackgroundTransparency = 1
	sparkLayer.ZIndex = 8
	sparkLayer.Parent = screen

	local camera = Workspace.CurrentCamera
	if camera then
		baseFieldOfView = camera.FieldOfView
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local current = Workspace.CurrentCamera
		if current then
			baseFieldOfView = current.FieldOfView
		end
	end)

	local player = Players.LocalPlayer
	if player.Character then
		buildCharacterEffects(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		buildCharacterEffects(character)
	end)

	WorkController.onStart(function(skillId, _duration)
		playCharacterEffect(skillId)
	end)

	WorkController.onComplete(onLocalClick)

	Remotes.event("Work", "Feedback").OnClientEvent:Connect(function(skillId, gain, companionGain)
		local jx = math.random(-48, 48)
		local jy = math.random(-14, 14)

		showGain(gain, skillId, jx, jy, 1)

		if companionGain and not BigNumber.isZero(companionGain) then
			showGain(companionGain, skillId, jx + 110, jy + 14, 0.6)
		end
	end)

	Remotes.event("Forage", "Event").OnClientEvent:Connect(function(kind, _ingredientId, gain)
		if kind ~= "success" then
			return
		end
		showGain(gain, "kusatori")
		burst("kusatori")
	end)

	RunService.RenderStepped:Connect(function(delta)
		driveCamera(delta)
		expireTrail()
	end)
end

return FeedbackController

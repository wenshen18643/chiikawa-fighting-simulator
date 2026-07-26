--[[
	Spawns the cast. See docs/GAME.md §9.4 and Config/Npcs.lua.

	Characters are ASSEMBLED FROM PARTS rather than loaded from asset ids, so
	the world has people standing in it before any modelling work exists — and,
	given §0 is still open, without shipping anyone else's character designs.

	Each mascot is a round body with a belly, ears, eyes, blush and stubby limbs.
	Only the root is anchored; everything else is welded to it, so tweening the
	root moves the whole character and the idle bob costs one tween per NPC
	rather than one per part.

	Replacing these with authored models later means adding a `modelId` to the
	config and branching in build() — nothing else changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Npcs = require(Shared.Modules.Config.Npcs)
local Areas = require(Shared.Areas)

local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

local NpcService = {}

local EYE_COLOR = Color3.fromRGB(48, 42, 38)
local BLUSH_COLOR = Color3.fromRGB(246, 176, 176)

local spoken: { [Player]: { [string]: number } } = {}

--------------------------------------------------------------------------------
-- Part assembly
--------------------------------------------------------------------------------

local function piece(parent: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Ball
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weld(root: BasePart, target: BasePart, offset: CFrame)
	target.CFrame = root.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = target
	w.Parent = root
end

local function buildEars(model: Model, root: BasePart, build: Npcs.NpcBuild, headTop: number)
	if build.earStyle == "none" then
		return
	end

	local color = build.earColor or build.bodyColor
	local spread = build.height * 0.26

	for _, side in { -1, 1 } do
		if build.earStyle == "round" then
			local ear = piece(model, "Ear", Vector3.new(1, 1, 1) * (build.height * 0.34), color)
			weld(root, ear, CFrame.new(side * spread, headTop * 0.82, 0))
		elseif build.earStyle == "tall" then
			-- A Cylinder part runs along its X axis: Size.X is the length and
			-- Y/Z are the diameter. The Z rotation below stands it upright.
			local ear = piece(
				model,
				"Ear",
				Vector3.new(build.height * 0.75, build.height * 0.2, build.height * 0.2),
				color,
				Enum.PartType.Cylinder
			)
			weld(
				root,
				ear,
				CFrame.new(side * spread * 0.8, headTop * 1.15, 0) * CFrame.Angles(0, 0, math.rad(90 + side * 12))
			)
		else -- pointed
			local ear = piece(
				model,
				"Ear",
				Vector3.new(build.height * 0.26, build.height * 0.4, build.height * 0.26),
				color,
				Enum.PartType.Wedge
			)
			weld(root, ear, CFrame.new(side * spread, headTop * 0.95, 0) * CFrame.Angles(0, 0, math.rad(side * 14)))
		end
	end
end

local function buildFace(model: Model, root: BasePart, build: Npcs.NpcBuild)
	local h = build.height
	local eyeSize = h * 0.11
	local front = -h * 0.42

	for _, side in { -1, 1 } do
		local eye = piece(model, "Eye", Vector3.new(1, 1, 1) * eyeSize, EYE_COLOR)
		weld(root, eye, CFrame.new(side * h * 0.16, h * 0.06, front))

		if build.blush then
			local blush = piece(model, "Blush", Vector3.new(1, 1, 1) * (h * 0.14), BLUSH_COLOR)
			weld(root, blush, CFrame.new(side * h * 0.3, -h * 0.06, front * 0.88))
		end
	end

	local mouth = piece(model, "Mouth", Vector3.new(h * 0.08, h * 0.05, h * 0.08), EYE_COLOR)
	weld(root, mouth, CFrame.new(0, -h * 0.08, front))
end

local function buildLimbs(model: Model, root: BasePart, build: Npcs.NpcBuild)
	local h = build.height

	for _, side in { -1, 1 } do
		local arm = piece(model, "Arm", Vector3.new(h * 0.16, h * 0.28, h * 0.16), build.bodyColor)
		weld(root, arm, CFrame.new(side * h * 0.44, -h * 0.06, 0) * CFrame.Angles(0, 0, math.rad(side * 20)))

		local foot = piece(model, "Foot", Vector3.new(h * 0.2, h * 0.14, h * 0.28), build.bodyColor)
		weld(root, foot, CFrame.new(side * h * 0.18, -h * 0.46, -h * 0.06))
	end
end

local function buildMascot(definition: Npcs.NpcDefinition, position: Vector3): Model
	local build = definition.build
	local h = build.height

	local model = Instance.new("Model")
	model.Name = definition.id

	local root = Instance.new("Part")
	root.Name = "Body"
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.new(h, h, h)
	root.Color = build.bodyColor
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = true
	-- Lowest point of the assembled mascot is the foot, at roughly 0.53 * height
	-- below the root. Place the root so that lands just above PLATFORM_TOP,
	-- otherwise the legs end up inside the ground.
	root.Position = position
		+ Vector3.new(0, Constants.WORLD.PLATFORM_TOP + Constants.WORLD.NPC_FOOT_CLEARANCE + h * 0.53, 0)
	root.Parent = model
	model.PrimaryPart = root

	-- Belly patch, slightly proud of the body so it does not z-fight.
	local belly = piece(model, "Belly", Vector3.new(1, 1, 1) * (h * 0.62), build.bellyColor)
	weld(root, belly, CFrame.new(0, -h * 0.1, -h * 0.16))

	buildEars(model, root, build, h * 0.5)
	buildFace(model, root, build)
	buildLimbs(model, root, build)

	return model
end

--------------------------------------------------------------------------------
-- Presentation
--------------------------------------------------------------------------------

local function addNameplate(model: Model, definition: Npcs.NpcDefinition)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromScale(10, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, definition.build.height * 0.95, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Parent = model.PrimaryPart

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.6)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.35
	name.Text = definition.name
	name.Parent = gui

	local role = Instance.new("TextLabel")
	role.Position = UDim2.fromScale(0, 0.6)
	role.Size = UDim2.fromScale(1, 0.34)
	role.BackgroundTransparency = 1
	role.Font = Enum.Font.Gotham
	role.TextScaled = true
	role.TextColor3 = Color3.fromRGB(238, 232, 224)
	role.TextStrokeTransparency = 0.6
	role.Text = definition.role
	role.Parent = gui
end

-- Idle bob. Each NPC gets a different phase so a group does not pulse in unison.
local function startIdle(model: Model, definition: Npcs.NpcDefinition, phase: number)
	local root = model.PrimaryPart :: BasePart
	local base = root.CFrame
	local rise = definition.build.height * 0.07

	task.delay(phase, function()
		if not root.Parent then
			return
		end
		local up = TweenService:Create(
			root,
			TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ CFrame = base * CFrame.new(0, rise, 0) }
		)
		up:Play()
	end)
end

local function addPrompt(model: Model, definition: Npcs.NpcDefinition)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = definition.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	prompt.Triggered:Connect(function(player)
		local perPlayer = spoken[player]
		if not perPlayer then
			perPlayer = {}
			spoken[player] = perPlayer
		end

		-- Walk the lines in order rather than picking at random, so repeated
		-- talking reads as a conversation instead of a slot machine.
		local index = (perPlayer[definition.id] or 0) % #definition.lines + 1
		perPlayer[definition.id] = index

		NotifyService.send(player, `{definition.name}: {definition.lines[index]}`, "info")
	end)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function NpcService.init()
	local existing = Workspace:FindFirstChild("Npcs")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = Workspace

	for index, definition in Npcs.DEFINITIONS do
		local region = Areas.get(definition.regionId)
		if not region then
			warn(`[NpcService] "{definition.id}" references missing region {definition.regionId}`)
			continue
		end

		local model = buildMascot(definition, region.origin + definition.offset)
		model.Parent = folder

		addNameplate(model, definition)
		addPrompt(model, definition)
		startIdle(model, definition, (index % 7) * 0.2)
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		spoken[player] = nil
	end)
end

-- Kept so the world builder and NPC placement cannot silently drift apart.
function NpcService.validatePlacement()
	for _, definition in Npcs.DEFINITIONS do
		local region = Areas.get(definition.regionId)
		if region then
			local half = region.terrain.islandSize / 2 - 20
			if math.abs(definition.offset.X) > half or math.abs(definition.offset.Z) > half then
				warn(`[NpcService] "{definition.id}" is placed outside its island`)
			end
		end
	end
	if not WorldService.getSpawnCFrame(Areas.STARTING_AREA) then
		warn("[NpcService] world has no starting spawn - did WorldService run first?")
	end
end

return NpcService

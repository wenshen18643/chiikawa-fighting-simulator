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
local Mascot = require(Shared.Modules.Mascot)
local Npcs = require(Shared.Modules.Config.Npcs)
local Areas = require(Shared.Areas)

local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

local NpcService = {}

-- player -> npc id -> which line they heard last, so talking walks the script.
local spoken: { [Player]: { [string]: number } } = {}

--------------------------------------------------------------------------------
-- Part assembly
--------------------------------------------------------------------------------

--[[
	The cast stands still, so its mascots are anchored where they are placed.

	Shape and proportions live in Shared/Modules/Mascot, which CompanionService
	builds the same silhouettes from: the friend following you home is the same
	character you met in town, from one definition.
]]
local function buildMascot(definition: Npcs.NpcDefinition, position: Vector3): Model
	local h = definition.build.height

	-- Lowest point of the assembled mascot is the foot. Place the root so that
	-- lands just above PLATFORM_TOP, otherwise the legs end up inside the ground.
	local footToRoot = Constants.WORLD.PLATFORM_TOP + Constants.WORLD.NPC_FOOT_CLEARANCE + h * Mascot.ROOT_TO_FOOT
	local model = Mascot.build(definition.build, CFrame.new(position + Vector3.new(0, footToRoot, 0)), definition.id)

	local root = model.PrimaryPart :: BasePart
	root.Anchored = true

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

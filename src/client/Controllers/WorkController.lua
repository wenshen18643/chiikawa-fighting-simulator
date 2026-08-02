local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Mobs = require(Shared.Modules.Config.Mobs)
local Skills = require(Shared.Modules.Config.Skills)
local Feedback = require(Shared.Modules.Config.Feedback)
local StateController = require(script.Parent.StateController)
local WorkController = {}
local ACTION_NAME = "Work"
local WEED_RADIUS = 14
local FORAGE_RADIUS = Constants.FORAGE.PULL_RADIUS
local FORAGE_TAG = "Forage"
local performRemote: RemoteEvent
local selectRemote: RemoteEvent
local lastSend = 0
local inputLocks: { [string]: boolean } = {}
local MIN_GESTURE = 0.12
local startListeners: { (skillId: string?, duration: number) -> () } = {}
local completeListeners: { (skillId: string?) -> () } = {}
local selectionListeners: { (skillId: string) -> () } = {}

local function getMobSkill(): string?
	local mobs = Workspace:FindFirstChild("Mobs")
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not mobs or not root then
		return nil
	end

	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		return nil
	end
	forward = forward.Unit

	for _, child in mobs:GetChildren() do
		if not child:IsA("Model") then
			continue
		end
		local mobId = child:GetAttribute("MobId")
		local definition = if type(mobId) == "string" then Mobs.get(mobId) else nil
		if not definition then
			continue
		end
		local mobRoot = child.PrimaryPart or child:FindFirstChild("HumanoidRootPart", true) :: BasePart?
		local humanoid = child:FindFirstChildOfClass("Humanoid")
		if not mobRoot or not humanoid or humanoid.Health <= 0 then
			continue
		end

		local offset = mobRoot.Position - root.Position
		local planar = Vector3.new(offset.X, 0, offset.Z)
		if
			planar.Magnitude <= 0.01
			or planar.Magnitude > definition.playerAttackRange
			or forward:Dot(planar.Unit) < definition.playerFacingMinimum
		then
			continue
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: Model, child }
		local sight = mobRoot.Position + Vector3.new(0, definition.height * 0.5, 0)
		if Workspace:Raycast(root.Position, sight - root.Position, params) == nil then
			return "tobatsu"
		end
	end

	return nil
end

function WorkController.onStart(callback: (skillId: string?, duration: number) -> ())
	table.insert(startListeners, callback)
end

function WorkController.onComplete(callback: (skillId: string?) -> ())
	table.insert(completeListeners, callback)
end

function WorkController.onSelected(callback: (skillId: string) -> ())
	table.insert(selectionListeners, callback)
end

function WorkController.onClick(callback: (skillId: string?) -> ())
	WorkController.onStart(function(skillId, _duration)
		callback(skillId)
	end)
end

local function nearestTagged(tag: string, radius: number): Model?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local best: Model? = nil
	local bestDist = radius
	for _, model in CollectionService:GetTagged(tag) do
		if model:IsA("Model") then
			local delta = model:GetPivot().Position - root.Position
			local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = model
			end
		end
	end
	return best
end

local function kusatoriClip(): string?
	local node = nearestTagged(FORAGE_TAG, FORAGE_RADIUS)
	if node then
		local ingredientId = node:GetAttribute("IngredientId")
		local def = if type(ingredientId) == "string" then Ingredients.get(ingredientId) else nil
		if def then
			return def.clip
		end
	end
	return if nearestTagged("Weed", WEED_RADIUS) then "kusatori" else nil
end

local function tryPerform()
	if next(inputLocks) ~= nil then
		return
	end

	local now = os.clock()
	if now - lastSend < Constants.WORK.CLICK_DEBOUNCE then
		return
	end
	local interval = now - lastSend
	local skillId = getMobSkill() or WorkController.getTrainingSkill() or "tobatsu"
	if Skills.canonicalize(skillId) == "examprep" then
		WorkController.selectSkill("examprep")
		return
	end
	local clipId: string? = skillId
	if Skills.canonicalize(skillId) == "kusatori" then
		clipId = kusatoriClip()
	end

	local feedbackEntry = Feedback.get(clipId or skillId)
	local authored = if feedbackEntry and feedbackEntry.gesture then feedbackEntry.gesture.duration else 0.38
	local duration = math.min(authored, math.max(interval, MIN_GESTURE))
	lastSend = now

	if clipId then
		for _, listener in startListeners do
			task.spawn(listener, skillId, duration, clipId)
		end
	end

	task.delay(duration, function()
		performRemote:FireServer()
		if clipId then
			for _, listener in completeListeners do
				task.spawn(listener, skillId)
			end
		end
	end)
end

function WorkController.setInputLocked(owner: string, locked: boolean)
	if locked then
		inputLocks[owner] = true
	else
		inputLocks[owner] = nil
	end
end

local function onAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		tryPerform()
	end
	return Enum.ContextActionResult.Pass
end

function WorkController.getTrainingSkill(): string?
	local snapshot = StateController.snapshot
	return snapshot and snapshot.selectedSkill
end

function WorkController.getSelectedSkill(): string?
	local snapshot = StateController.snapshot
	return snapshot and snapshot.selectedSkill
end

function WorkController.isSelectable(skillId: string): boolean
	return Skills.canonicalize(skillId) ~= "resilience"
end

function WorkController.selectSkill(skillId: string)
	if next(inputLocks) ~= nil then
		return
	end
	if not Skills.exists(skillId) then
		return
	end
	local canonical = Skills.canonicalize(skillId)
	if not WorkController.isSelectable(canonical) then
		return
	end
	selectRemote:FireServer(canonical)
	for _, listener in selectionListeners do
		task.spawn(listener, canonical)
	end
end

local SELECT_ACTION = "SelectSkill"

local function bindSelection()
	local keys = {
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
	}

	local byKey: { [Enum.KeyCode]: string } = {}
	for index, skillId in Skills.ORDER do
		local key = keys[index]
		if key then
			byKey[key] = skillId
		end
	end

	ContextActionService:BindAction(SELECT_ACTION, function(_name, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local skillId = byKey[input.KeyCode]
		if skillId then
			WorkController.selectSkill(skillId)
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
end

function WorkController.init()
	performRemote = Remotes.event("Work", "Perform")
	selectRemote = Remotes.event("Work", "SelectSkill")

	bindSelection()

	ContextActionService:BindAction(
		ACTION_NAME,
		onAction,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION_NAME, "Work")

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function()
		lastSend = 0
	end)
end

return WorkController

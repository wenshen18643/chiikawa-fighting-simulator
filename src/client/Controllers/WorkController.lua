--[[
	Work input. See docs/GAME.md §4 and §13.

	ONE CLICK IS ONE ACTION.

	SPEC DEVIATION REVERSED. An earlier build made every skill hold-to-work,
	reasoning that a real click per action at 8/sec is a repetitive-strain
	problem and that holding is what an autoclicker does anyway. That was the
	wrong trade. Holding removes the only moment-to-moment decision the core loop
	has: the number goes up because the button is down, and the player is not
	doing anything. §4 called these "click" skills for a reason.

	So the Heartbeat loop is gone. `Begin` fires exactly once, and the rate cap
	moved up to match what a person can actually do (Constants.WORK) rather than
	what a held button generates. The debounce below is not a rate limit — it is
	only there to stop one physical click registering twice.

	Sends INTENT ONLY — Work.Perform carries no arguments, because the server
	already knows where the player is standing. There is nothing here for a
	client to lie about, which is the point.
]]

local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Mobs = require(Shared.Modules.Config.Mobs)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)

local Feedback = require(Shared.Modules.Config.Feedback)

-- Still used for the prompt text, just not as a gate on sending.
local StateController = require(script.Parent.StateController)

local WorkController = {}

local ACTION_NAME = "Work"
local WEED_RADIUS = 14
-- Mirrors Constants.FORAGE.PULL_RADIUS; the server still decides what was hit.
local FORAGE_RADIUS = Constants.FORAGE.PULL_RADIUS
local FORAGE_TAG = "Forage"

local performRemote: RemoteEvent
local selectRemote: RemoteEvent
local lastSend = 0
local inputLocks: { [string]: boolean } = {}

-- Floor on a cadence-fitted clip. Below this a gesture is a twitch, and the
-- blend envelope in GestureController is longer than the clip itself.
local MIN_GESTURE = 0.12

-- Fired locally when an action begins (gesture animation starts).
local startListeners: { (skillId: string?, duration: number) -> () } = {}
-- Fired locally when an action animation finishes (stat reward requested).
local completeListeners: { (skillId: string?) -> () } = {}
local selectionListeners: { (skillId: string) -> () } = {}

-- Mirrors the server strike cone only so the local gesture uses the sasumata.
-- The server independently resolves the target and owns all combat outcomes.
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
		-- Mid-body, matching the server: the rig root sits a stud off the floor,
		-- and a ray aimed there clips the ground on any slope.
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

-- Backward compatibility for onClick listeners (subscribes to start by default)
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

--[[
	Which clip a Kusatori click should play, guessed locally.

	The server decides what the click actually hits; this only decides what the
	character looks like while it happens. Waiting for the answer would put a
	sixth of a second of nothing between the click and the dig, which is the
	difference between a game that responds and one that lags.

	Returns nil when there is nothing in reach, which is how the caller knows
	to play no gesture at all rather than swinging at the lawn.
]]
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
		-- Study actions live inside the full-screen book. Work opens that book;
		-- it never sends Work.Perform and therefore cannot grant Exam Prep.
		WorkController.selectSkill("examprep")
		return
	end
	--[[
		Kusatori is the one skill whose gesture depends on WHAT is in front of
		you: a weed is yanked, a carrot is dug, a sausage is hauled off a
		branch. Every other skill has one clip and plays it.
	]]
	local clipId: string? = skillId
	if Skills.canonicalize(skillId) == "kusatori" then
		clipId = kusatoriClip()
	end

	local feedbackEntry = Feedback.get(clipId or skillId)
	local authored = if feedbackEntry and feedbackEntry.gesture then feedbackEntry.gesture.duration else 0.38

	--[[
		The gesture is fitted to how fast the player is ACTUALLY clicking, rather
		than the click being held back until the gesture is done.

		Locking input for the clip's length capped plucking at ~2 clicks/sec
		against a server that allows 14, so most of a fast player's clicks hit
		nothing at all. Now every click sends, and the clip is compressed to the
		gap between the last two clicks so it still reaches its payoff frame
		before the next one restarts it.
	]]
	local duration = math.min(authored, math.max(interval, MIN_GESTURE))
	lastSend = now

	if clipId then
		for _, listener in startListeners do
			task.spawn(listener, skillId, duration, clipId)
		end
	end

	-- Sent on the impact frame, not on the press, so the "+12" lands with the
	-- hand. Each click owns its own timer; they overlap rather than queue.
	task.delay(duration, function()
		performRemote:FireServer()
		if clipId then
			for _, listener in completeListeners do
				task.spawn(listener, skillId)
			end
		end
	end)
end

-- Modal gameplay can temporarily own the click without disabling the bound
-- touch button or stealing GUI activation through ContextActionService.
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

-- The skill the pad under your feet trains, or nil if you are not on one.
function WorkController.getCurrentSkill(): string?
	local snapshot = StateController.snapshot
	if not snapshot or not snapshot.currentWorksite then
		return nil
	end
	local worksite = Worksites.get(snapshot.currentWorksite)
	return worksite and worksite.skill
end

--[[
	What a click right now would actually raise.

	The pad you are stood on wins; otherwise it is your selected skill, or the
	skill of a pad you are stood on but have not unlocked (the server applies the
	same rule in WorkService.freeformSkill — this mirrors it so the gesture,
	sound and HUD agree with what is about to be credited).

	Read from the snapshot rather than tracked locally, so it cannot drift from
	the server's idea of it.
]]
function WorkController.getTrainingSkill(): string?
	local snapshot = StateController.snapshot
	if not snapshot then
		return nil
	end

	local onPad = WorkController.getCurrentSkill()
	if onPad then
		return onPad
	end

	if snapshot.blockedWorksite then
		local blocked = Worksites.get(snapshot.blockedWorksite)
		if blocked then
			return blocked.skill
		end
	end

	return snapshot.selectedSkill
end

function WorkController.getSelectedSkill(): string?
	local snapshot = StateController.snapshot
	return snapshot and snapshot.selectedSkill
end

-- Asks the server to change which skill free-form training raises. The server
-- validates and owns the value; this is a request, not an assignment.
-- Resilience is trained by cooking and moving, not by clicking; the server
-- refuses it too. One rule, read by the skill bar and by selectSkill.
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

function WorkController.getPromptText(): string?
	local skillId = WorkController.getCurrentSkill()
	if not skillId then
		return nil
	end
	local skill = Skills.get(skillId)
	if not skill then
		return nil
	end
	if Skills.canonicalize(skillId) == "examprep" then
		return if UserInputService.TouchEnabled then "Tap skill 4 to open book" else "Press 4 to open book"
	end

	local verb = if UserInputService.TouchEnabled then "Tap" else "Click"
	return `{verb} to {string.lower(skill.verb)}`
end

--[[
	Number keys pick which skill free-form training raises.

	Bound to the six digits in Skills.ORDER order, which is the same order the
	HUD stacks them in — so "the third one down" and "3" are the same thing
	without anyone having to be told.
]]
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
		true, -- create a touch button on mobile
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION_NAME, "Work")

	-- Nothing to reset on respawn any more — there is no held state to get
	-- stuck — but the debounce is cleared so the first click after a respawn is
	-- never swallowed.
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function()
		lastSend = 0
	end)
end

return WorkController

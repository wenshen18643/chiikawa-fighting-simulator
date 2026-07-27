--[[
	Gives every player a companion that trails them, and a stand in town where
	they choose which one.

	--------------------------------------------------------------------------
	CONSTRAINTS, NOT A HEARTBEAT LOOP
	--------------------------------------------------------------------------

	The obvious version of "follow me" is a server loop that writes the pet's
	CFrame every frame. That is one physics-rate loop per player, it replicates
	as a stream of property writes, and it looks stuttery to everyone else:
	anchored CFrame changes from the server are batched, so remote players see
	the pet jumping between positions at the replication rate.

	Instead the pet is UNANCHORED and held by an AlignPosition and an
	AlignOrientation aimed at an attachment on the player's HumanoidRootPart,
	with network ownership handed to that player. The simulation then runs on
	the owner's machine at their frame rate, replicates like any other moving
	part, and costs this service nothing per frame. The pet also lags and swings
	around corners for free.

	--------------------------------------------------------------------------
	IT CANNOT TOUCH YOU
	--------------------------------------------------------------------------

	A companion is welded to nothing, collides with nothing (its own collision
	group, non-collidable with every other group), and neither constraint feeds
	force back into the character it is chasing. This is deliberate and worth
	keeping: a follower that can shove is a follower that can push you off a
	path, into a gate, or through a doorway you had not unlocked.

	Every clone also has its scripts stripped again here, on top of the strip
	AssetService.prepare already does. The uploaded rig this shipped with is a
	free model that arrived with FIVE scripts, and a companion is the one thing
	in this game that is guaranteed to be standing next to the player -- the
	cost of the second sweep is a loop, and the cost of skipping it is somebody
	else's code running beside your character.

	--------------------------------------------------------------------------
	THE ROSTER IS FILTERED AT RUNTIME
	--------------------------------------------------------------------------

	Config/Companions lists mascots (built from parts, always available) and
	uploaded assets (may fail to load, forever, without warning). The menu is
	built from what actually exists on this server, so a moderated asset id
	removes a row rather than producing a button that does nothing.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Modules.Config.Assets)
local Companions = require(Shared.Modules.Config.Companions)
local Constants = require(Shared.Modules.Constants)
local Mascot = require(Shared.Modules.Mascot)
local Npcs = require(Shared.Modules.Config.Npcs)
local Remotes = require(Shared.Modules.Remotes)
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local Skills = require(Shared.Modules.Config.Skills)
local Areas = require(Shared.Areas)
local UI = require(Shared.UI)

local AssetService = require(script.Parent.AssetService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

local CompanionService = {}

--[[
	Where the pet is asked to be, in the player's own space: behind the left
	shoulder. -Z is the way a HumanoidRootPart faces, so +Z is behind. Y is
	solved per character rather than set here -- see `targetOffsetY`.
]]
local FOLLOW_OFFSET = Vector3.new(-3.5, 0, 4.5)

--[[
	How hard the constraints chase the target.

	Responsiveness is roughly "how sharply it corrects"; lower is floatier. 18
	keeps the pet visibly trailing a sprinting player rather than glued to their
	hip, which is the point of a companion.
]]
local FOLLOW_RESPONSIVENESS = 18
local TURN_RESPONSIVENESS = 12

--[[
	Uploaded companions are resized to this height. Mascots are NOT: they are
	built from Config/Npcs in world scale already, and stretching Little One to
	a standard size would make her a different character.

	How big an uploaded mesh is depends only on what its author had selected
	when they exported it. A rig that arrives 0.4 studs tall is invisible from
	eye level and one that arrives 80 studs tall is a wall you are standing
	inside -- and both look exactly like "it never spawned".
]]
local TARGET_HEIGHT = 4

-- Nameplate above the pet. Off makes them anonymous but no less present.
local SHOW_LABEL = true

--[[
	Beyond this, snap.

	Constraints pull, they do not teleport, so a player who respawns or takes a
	gate would otherwise be trailed by a pet flying across the map through the
	terrain.
]]
local TELEPORT_DISTANCE = 60
local WATCHDOG_INTERVAL = 0.5

-- Asset loads run off the boot path, so the first player can join before the
-- model has arrived.
local LOAD_TIMEOUT = 15

--[[
	Its own collision group, collidable with nothing.

	CanCollide = false on every part already covers this. The group is the
	belt-and-braces version, and it survives something later setting CanCollide
	back on -- a scaled model, an author's own script, a future gameplay pet
	that is meant to be solid to the world but never to a player.
]]
local COLLISION_GROUP = "Companion"

local ANIM_OWNER_ATTRIBUTE = "AnimOwner"
local ANIM_ACTION_ATTRIBUTE = "AnimAction"
local ANIM_SKILL_ATTRIBUTE = "AnimSkill"
local ACT_COOLDOWN = 0.12

local STAND_OFFSET = Vector3.new(9, 0, -7)

local folder: Folder
local resolved = false
local reported = false
local active: { [Player]: Model } = {}
local lastAct: { [Player]: number } = {}
local collisionGroupReady = false

--------------------------------------------------------------------------------
-- Physics safety
--------------------------------------------------------------------------------

--[[
	Registering can fail on a Roblox build without the API, and registering
	twice throws -- Studio re-runs this on every play session. Failure is
	survivable: CanCollide false is still doing the actual work.
]]
local function setupCollisionGroup()
	local ok = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
			PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
		end

		for _, group in PhysicsService:GetRegisteredCollisionGroups() do
			PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, group.name, false)
		end
	end)

	collisionGroupReady = ok
	if not ok then
		warn("[CompanionService] collision groups unavailable - relying on CanCollide alone")
	end
end

--------------------------------------------------------------------------------
-- Rig preparation
--------------------------------------------------------------------------------

--[[
	The part everything else hangs off.

	Uploaded rigs have no reliable convention: PrimaryPart is often unset, and
	`HumanoidRootPart` only exists if the author built a real character. Falling
	back to the largest part is what makes this work on a rig that is one
	MeshPart and nothing else, which is what the shipped asset reports being.
]]
local function findRoot(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local named = model:FindFirstChild("HumanoidRootPart", true)
	if named and named:IsA("BasePart") then
		return named
	end

	local best: BasePart?
	local bestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				best, bestVolume = descendant, volume
			end
		end
	end
	return best
end

--[[
	Make a model safe to carry around next to a player.

	Massless on every part but the root matters: an assembly's mass decides how
	much force the AlignPosition needs, and a multi-part rig at default density
	sags behind the target. One part with mass keeps the assembly a valid rigid
	body while keeping it light.

	Returns the root, or nil if the model has no parts at all.
]]
local function rig(model: Model, profileId: string): BasePart?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Humanoid") then
			descendant:Destroy()
		end
	end

	local root = Skeleton.prepare(model, profileId) or findRoot(model)
	if not root then
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = descendant ~= root
			if collisionGroupReady then
				descendant.CollisionGroup = COLLISION_GROUP
			end
		end
	end

	model.PrimaryPart = root
	return root
end

--[[
	Fit an uploaded model inside a TARGET_HEIGHT box. Returns the factor applied.

	Measured on the LARGEST axis, not on height. Height is the intuitive choice
	and it is wrong here: an uploaded rig is only upright if its author built it
	upright, and one modelled lying down -- or exported from a tool whose up
	axis is Z -- has a small Y extent. Dividing by that scales the thing UP,
	which is how two of these arrived as buildings. The largest axis cannot be
	fooled that way: whatever the pose, the companion ends up roughly a
	four-stud thing.
]]
local function normalise(model: Model, factor: number?): number
	local size = model:GetExtentsSize()
	local largest = math.max(size.X, size.Y, size.Z)
	if largest <= 0.01 then
		return 1
	end

	local scale = (TARGET_HEIGHT * (factor or 1)) / largest
	if math.abs(scale - 1) > 0.01 then
		model:ScaleTo(scale)
	end
	return scale
end

local function addLabel(root: BasePart, text: string)
	if not SHOW_LABEL then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "CompanionLabel"
	gui.Size = UDim2.fromScale(6, 1.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, TARGET_HEIGHT * 0.75, 0)
	gui.MaxDistance = 120
	gui.Parent = root

	local label = UI.label(gui, "Name", {
		text = text,
		font = UI.font.display,
		color = UI.color.white,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 1),
		scaled = true,
	})
	label.TextStrokeTransparency = 0.4
end

--[[
	How far below the HumanoidRootPart the pet's ROOT must sit for the pet to
	look like it is standing on the same ground the player is.

	Two unknowns meet here and both are runtime facts. The player's root floats
	at `HipHeight + half its own height` above their feet, which differs between
	R6 and R15. The pet's root is wherever its author left it inside the model,
	which is neither the model's centre nor its feet.
]]
local function targetOffsetY(model: Model, root: BasePart, humanoid: Humanoid, playerRoot: BasePart): number
	local boxCFrame, boxSize = model:GetBoundingBox()
	local rootAboveFeet = root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	local playerRootAboveFeet = humanoid.HipHeight + playerRoot.Size.Y / 2
	return rootAboveFeet - playerRootAboveFeet
end

--------------------------------------------------------------------------------
-- Roster
--------------------------------------------------------------------------------

-- An uploaded companion counts as available only once its model is in hand.
local function isAvailable(spec: Companions.CompanionSpec): boolean
	if spec.kind ~= "asset" then
		return true
	end
	return spec.assetKey ~= nil and AssetService.isReady(spec.assetKey)
end

--[[
	What this server can actually offer, as plain data for the client.

	Sent over the wire rather than read from the shared config on the client,
	because "did this free model load today" is not knowable from the config.
]]
local function roster(): { { id: string, name: string, blurb: string } }
	local out = {}
	for _, spec in Companions.LIST do
		if isAvailable(spec) then
			table.insert(out, { id = spec.id, name = spec.name, blurb = spec.blurb })
		end
	end
	return out
end

--[[
	Waits briefly for the profile rather than reading it optimistically: a
	player whose data is still loading would otherwise be handed the default
	companion and then watch it swap, which reads as a bug even though the
	saved choice arrives a moment later.
]]
local function selectionFor(player: Player): string
	local profile = DataService.await(player, 5)
	local saved = profile and profile.companions and profile.companions.selected
	if type(saved) == "string" and Companions.get(saved) then
		return saved
	end
	return Companions.DEFAULT
end

local function remember(player: Player, id: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if type(profile.companions) ~= "table" then
		profile.companions = {}
	end
	profile.companions.selected = id
end

--[[
	The model for a roster entry, unrigged and at the origin.

	Mascots are built rather than cloned, so they cannot fail. An uploaded
	companion that is not in the cache returns nil and the caller decides what
	that means -- which is "fall back to the default mascot", never "no
	companion".
]]
local function buildCompanion(spec: Companions.CompanionSpec): Model?
	if spec.kind == "asset" then
		local key = spec.assetKey
		if not key then
			return nil
		end

		--[[
			Some uploads are bundles rather than single characters -- one id
			holding a shelf of plushies. Cloning the container would hand the
			player all of them welded into one companion, so a pack is asked for
			one child by name instead.
		]]
		local asset = Assets.get(key)
		if asset and asset.kind == "pack" then
			return AssetService.clonePackItem(key, nil, spec.assetMatch)
		end
		return AssetService.clone(key)
	end

	local npcId = spec.npcId
	local definition = npcId and Npcs.get(npcId)
	if not definition then
		warn(`[CompanionService] "{spec.id}" names npc "{npcId}", which is not in Config/Npcs`)
		return nil
	end

	return Mascot.build(definition.build, CFrame.new(), spec.name)
end

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

local function despawn(player: Player)
	local existing = active[player]
	if existing then
		active[player] = nil
		existing:Destroy()
	end
end

--[[
	Every way out of this says so.

	Its first version had four silent early returns, and "no companion and no
	log line" cannot be told apart from "the file never synced" -- which cost a
	whole round trip to find out. A missing companion is now always either a
	spawn line or a reason.
]]
local function spawn(player: Player, character: Model, trigger: string)
	if not resolved then
		return
	end

	local wanted = selectionFor(player)
	if wanted == Companions.NONE then
		despawn(player)
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local playerRoot = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not playerRoot then
		warn(`[CompanionService] {player.Name} ({trigger}): character has no Humanoid/HumanoidRootPart`)
		return
	end

	--[[
		The character can be replaced while those waits run -- respawn, or a
		rejoin -- and a companion aimed at a dead character's root is a
		companion nobody sees.
	]]
	if player.Character ~= character or not character.Parent then
		return
	end

	local spec = Companions.get(wanted)
	local model = if spec then buildCompanion(spec) else nil

	--[[
		An uploaded companion that did not load falls back to the default
		mascot rather than to nothing. Parts always work, and a player who
		picked a friend should not be left alone because a free model went
		private overnight.
	]]
	if not model then
		local fallback = Companions.get(Companions.DEFAULT)
		spec = fallback
		model = if fallback then buildCompanion(fallback) else nil
		if model then
			warn(`[CompanionService] "{wanted}" unavailable for {player.Name} - using "{Companions.DEFAULT}"`)
		end
	end

	if not model or not spec then
		warn(`[CompanionService] {player.Name} ({trigger}): could not build "{wanted}" or the default`)
		return
	end

	local root = rig(model, spec.id)
	if not root then
		warn(`[CompanionService] "{spec.id}" has no BaseParts - nothing to follow with`)
		model:Destroy()
		return
	end

	despawn(player)
	model.Name = `Companion_{player.Name}`
	model:SetAttribute(ANIM_OWNER_ATTRIBUTE, player.UserId)

	--[[
		Scale before measuring the vertical offset: ScaleTo moves every part, so
		an offset computed from the authored size would be wrong by the scale
		factor -- for a rig that arrived ten times too big, the difference
		between standing on the ground and hovering out of frame.
	]]
	local scale = if spec.kind == "asset" then normalise(model, spec.scale) else 1
	addLabel(root, spec.name)

	local target = Instance.new("Attachment")
	target.Name = "CompanionTarget"
	target.Position = Vector3.new(
		FOLLOW_OFFSET.X,
		targetOffsetY(model, root, humanoid, playerRoot) + FOLLOW_OFFSET.Y,
		FOLLOW_OFFSET.Z
	)
	target.Parent = playerRoot

	local hold = Instance.new("Attachment")
	hold.Name = "CompanionHold"
	hold.Parent = root

	--[[
		MaxForce/MaxTorque are unbounded on purpose. The pet weighs whatever its
		author's mesh density says it weighs, which this repo cannot know, and a
		bounded force that turns out to be under that weight fails in the worst
		way available: the pet sinks through the world instead of following.
		Responsiveness, not force, is what makes the motion soft.

		The reaction flags are the ones that matter for the player: with them
		off, all of that force lands on the pet and none of it on the character
		being followed. They default off; they are written out because a pet
		that can push its owner around is a bug worth being explicit about.
	]]
	local position = Instance.new("AlignPosition")
	position.Attachment0 = hold
	position.Attachment1 = target
	position.MaxForce = math.huge
	position.Responsiveness = FOLLOW_RESPONSIVENESS
	position.ApplyAtCenterOfMass = true
	position.ReactionForceEnabled = false
	position.Parent = root

	local orientation = Instance.new("AlignOrientation")
	orientation.Attachment0 = hold
	orientation.Attachment1 = target
	orientation.MaxTorque = math.huge
	orientation.Responsiveness = TURN_RESPONSIVENESS
	orientation.ReactionTorqueEnabled = false
	orientation.Parent = root

	-- Start where it belongs, so the first thing anybody sees is not the pet
	-- flying in from the model's authored origin.
	model:PivotTo(playerRoot.CFrame * CFrame.new(target.Position))
	model.Parent = folder
	active[player] = model

	--[[
		Hand the simulation to the player's own client: their pet then moves at
		their frame rate against their own character with no round trip.
		Guarded because ownership cannot be assigned to a player who has left.
	]]
	pcall(function()
		root:SetNetworkOwner(player)
	end)

	--[[
		The final extents, not just the scale factor. "x0.05" says nothing on
		its own; "0.05 -> 4.0 x 2.1 x 1.8" says the companion is a companion and
		not a building, which is the failure this line exists to catch.
	]]
	local final = model:GetExtentsSize()
	print(
		string.format(
			'[CompanionService] %s (%s) now followed by "%s" at %.0f, %.0f, %.0f - x%.3f, %.1f x %.1f x %.1f studs',
			player.Name,
			trigger,
			spec.id,
			root.Position.X,
			root.Position.Y,
			root.Position.Z,
			scale,
			final.X,
			final.Y,
			final.Z
		)
	)

	if spec.kind == "asset" and not reported then
		reported = true
		print(`[CompanionService] "{spec.id}" contents: {AssetService.describe(model)}`)
	end

	--[[
		Snap-back watchdog. Half a second is far below the time it takes a
		player to notice a missing pet and far above the cost of a distance
		check per player.
	]]
	task.spawn(function()
		while active[player] == model and model.Parent and playerRoot.Parent do
			task.wait(WATCHDOG_INTERVAL)
			if active[player] ~= model or not model.Parent or not playerRoot.Parent then
				break
			end

			local home = playerRoot.CFrame * CFrame.new(target.Position)
			if (root.Position - home.Position).Magnitude > TELEPORT_DISTANCE then
				model:PivotTo(home)
			end
		end
	end)
end

local function respawnCompanion(player: Player, trigger: string)
	local character = player.Character
	if character then
		task.spawn(spawn, player, character, trigger)
	else
		despawn(player)
	end
end

--------------------------------------------------------------------------------
-- The friend stand
--------------------------------------------------------------------------------

local function slab(parent: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.WoodPlanks
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[
	A table you press E at.

	Deliberately a physical object in the world rather than a HUD button: the
	menu is a place you go to, which is the same reason worksites are pads you
	stand on. It is also self-explaining -- a prompt on a table with friends
	carved into the sign needs no tutorial line.
]]
local function buildStand(base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "FriendStand"

	local wood = Color3.fromRGB(176, 132, 92)
	local woodDeep = Color3.fromRGB(140, 102, 68)

	local topHeight = 3
	local top = slab(model, "Top", Vector3.new(7, 0.4, 3.4), base * CFrame.new(0, topHeight, 0), wood)
	model.PrimaryPart = top

	for _, x in { -3, 3 } do
		for _, z in { -1.4, 1.4 } do
			slab(model, "Leg", Vector3.new(0.4, topHeight, 0.4), base * CFrame.new(x, topHeight / 2, z), woodDeep)
		end
	end

	UI.sign(top, {
		name = "StandSign",
		title = "Friend Stand",
		subtitle = "Press E to choose who follows you",
		offset = Vector3.new(0, 3.4, 0),
		extent = UDim2.fromScale(12, 3.4),
		maxDistance = 120,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChooseFriend"
	prompt.ActionText = "Choose a friend"
	prompt.ObjectText = "Friend Stand"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = top

	prompt.Triggered:Connect(function(player)
		Remotes.event("Companion", "Open"):FireClient(player, roster(), selectionFor(player))
	end)

	return model
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

--[[
	Change who follows `player`. Returns false for an id this server is not
	offering, which is the whole validation story: the client sends an id, and
	an id it was never given does nothing.
]]
function CompanionService.select(player: Player, id: string): boolean
	local spec = Companions.get(id)
	if not spec or not isAvailable(spec) then
		warn(`[CompanionService] {player.Name} asked for "{id}", which is not on this server's roster`)
		return false
	end

	remember(player, id)

	if id == Companions.NONE then
		despawn(player)
		NotifyService.send(player, "Walking alone for now.", "info")
		return true
	end

	respawnCompanion(player, "selected")
	NotifyService.send(player, `{spec.name} is following you now.`, "info")
	return true
end

function CompanionService.act(player: Player, skillId: string?)
	local model = active[player]
	if not model or not model.Parent then
		return
	end

	local now = os.clock()
	if now - (lastAct[player] or 0) < ACT_COOLDOWN then
		return
	end
	lastAct[player] = now

	--[[
		Skill first, timestamp second. The client listens on the timestamp, so
		writing it last is what guarantees the skill it reads is this click's
		and not the previous one's.
	]]
	if type(skillId) == "string" and Skills.exists(skillId) then
		model:SetAttribute(ANIM_SKILL_ATTRIBUTE, Skills.canonicalize(skillId))
	end
	model:SetAttribute(ANIM_ACTION_ATTRIBUTE, now)
end

function CompanionService.init()
	setupCollisionGroup()

	local existing = Workspace:FindFirstChild("Companions")
	if existing then
		existing:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "Companions"
	folder.Parent = Workspace

	local spawnCFrame = WorldService.getSpawnCFrame(Areas.STARTING_AREA)
	if spawnCFrame then
		--[[
			Keep the spawn's facing, drop its height: the stand sits on the
			ground plane every plaza and pad presents, not at whatever Y the
			spawn point happens to float at.
		]]
		local base = spawnCFrame * CFrame.new(STAND_OFFSET)
		local ground = CFrame.new(Vector3.new(base.Position.X, Constants.WORLD.PLATFORM_TOP, base.Position.Z))
			* (base - base.Position)
		buildStand(ground).Parent = folder
	else
		warn("[CompanionService] no spawn for the starting area - the friend stand was not built")
	end

	Remotes.event("Companion", "Select").OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			CompanionService.select(player, id)
		end
	end)

	Remotes.event("Companion", "Act").OnServerEvent:Connect(function(player, skillId)
		CompanionService.act(player, if type(skillId) == "string" then skillId else nil)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAct[player] = nil
		despawn(player)
	end)

	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(spawn, player, character, "CharacterAdded")
		end)
		player.CharacterRemoving:Connect(function()
			despawn(player)
		end)

		--[[
			A player bound after their character already exists gets no
			CharacterAdded, which is the normal case in Studio: the world build
			ahead of this service in the boot order takes seconds, and the local
			player has spawned long before init runs.
		]]
		if player.Character then
			task.spawn(spawn, player, player.Character, "already spawned")
		end
	end

	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end

	--[[
		Spawning waits for the uploaded companions to resolve either way. Not
		because a mascot needs them -- it does not -- but because a player whose
		saved choice is an asset would otherwise be given the fallback mascot
		one second before their actual friend finished downloading.
	]]
	task.spawn(function()
		for _, spec in Companions.LIST do
			if spec.kind == "asset" and spec.assetKey then
				AssetService.waitFor(spec.assetKey, LOAD_TIMEOUT)
			end
		end

		resolved = true
		print(`[CompanionService] roster ready: {#roster()} of {#Companions.LIST} companion(s) available`)

		for _, player in Players:GetPlayers() do
			if player.Character and not active[player] then
				task.spawn(spawn, player, player.Character, "roster ready")
			end
		end
	end)
end

return CompanionService

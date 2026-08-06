local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Companions = require(Shared.Modules.Config.Companions)
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local Constants = require(Shared.Modules.Constants)
local Mascot = require(Shared.Modules.Mascot)
local Mobs = require(Shared.Modules.Config.Mobs)
local Npcs = require(Shared.Modules.Config.Npcs)
local Remotes = require(Shared.Modules.Remotes)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local Skills = require(Shared.Modules.Config.Skills)
local UI = require(Shared.UI)
local AssetService = require(script.Parent.AssetService)
local DataService = require(script.Parent.DataService)
local MobRig = require(script.Parent.MobRig)
local NotifyService = require(script.Parent.NotifyService)
local CompanionService = {}
local FOLLOW_OFFSET = Vector3.new(-3.5, 0, 4.5)
local FOLLOW_RESPONSIVENESS = 18
local TURN_RESPONSIVENESS = 12
local TARGET_HEIGHT = 4
local SHOW_LABEL = true
local TELEPORT_DISTANCE = 60
local WATCHDOG_INTERVAL = 0.5
local LOAD_TIMEOUT = 15
local COLLISION_GROUP = "Companion"
local ANIM_OWNER_ATTRIBUTE = "AnimOwner"
local ANIM_ACTION_ATTRIBUTE = "AnimAction"
local ANIM_SKILL_ATTRIBUTE = "AnimSkill"
local ACT_COOLDOWN = 0.12
local COMPANION_ID_ATTRIBUTE = "CompanionId"
local SHELF_PLUSHIE_SIZE = 2.6
local SHELF_SLOT_SPACING = 3.8
local TOSS_HAND_OFFSET = CFrame.new(1.2, 0.7, -1.9)
local TOSS_TO_HAND = 0.26
local TOSS_TO_APEX = 0.5
local TOSS_HEIGHT = 11
local folder: Folder
local resolved = false
local reported = false
local active: { [Player]: Model } = {}
local lastAct: { [Player]: number } = {}
local standSlots: { [string]: Model } = {}
local tossGeneration: { [Player]: number } = {}
local collisionGroupReady = false

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

local function targetOffsetY(model: Model, root: BasePart, humanoid: Humanoid, playerRoot: BasePart): number
	local boxCFrame, boxSize = model:GetBoundingBox()
	local rootAboveFeet = root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	local playerRootAboveFeet = humanoid.HipHeight + playerRoot.Size.Y / 2
	return rootAboveFeet - playerRootAboveFeet
end

local function isAvailable(spec: Companions.CompanionSpec): boolean
	if spec.kind ~= "asset" then
		return true
	end
	return spec.assetKey ~= nil and AssetService.isReady(spec.assetKey)
end

local function isOwned(spec: Companions.CompanionSpec, profile: any): boolean
	if not spec.locked then
		return true
	end
	local owned = profile and profile.companions and profile.companions.owned
	return type(owned) == "table" and owned[spec.id] == true
end

local function roster(profile: any?): { { id: string, name: string, blurb: string } }
	local out = {}
	for _, spec in Companions.LIST do
		if isAvailable(spec) and (profile == nil or isOwned(spec, profile)) then
			table.insert(out, { id = spec.id, name = spec.name, blurb = spec.blurb })
		end
	end
	table.insert(out, { id = Companions.NONE, name = "No one", blurb = "Walk alone." })
	return out
end

local function selectionFor(player: Player): string
	local profile = DataService.await(player, 5)
	local saved = profile and profile.companions and profile.companions.selected
	if type(saved) == "string" and Companions.get(saved) then
		return saved
	end
	return Companions.NONE
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

local function buildCompanion(spec: Companions.CompanionSpec, profile: any?): (Model?, number)
	if spec.kind == "asset" then
		local equippedSkin = profile and CompanionSkins.equippedSkin(profile, spec.id)
		if equippedSkin and equippedSkin.assetKey then
			local skinned = AssetService.clone(equippedSkin.assetKey)
			if skinned then
				skinned:SetAttribute("CompanionSkinId", equippedSkin.id)
				return skinned, equippedSkin.scale or 1
			end
			warn(`[CompanionService] skin asset "{equippedSkin.assetKey}" is unavailable; using {spec.id}'s base look`)
		end

		local key = spec.assetKey
		if not key then
			return nil, 1
		end

		local base = AssetService.clone(key)
		if base and equippedSkin then
			base:SetAttribute("CompanionSkinId", equippedSkin.id)
		end
		return base, 1
	end

	if spec.kind == "built" then
		local mobId = spec.mobId
		local definition = mobId and Mobs.get(mobId)
		if not definition then
			warn(`[CompanionService] "{spec.id}" names mob "{mobId}", which is not in Config/Mobs`)
			return nil, 1
		end

		local model = MobRig.build(definition)
		if not model then
			return nil, 1
		end
		model.Name = spec.name
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= model.PrimaryPart then
				descendant.Anchored = false
				descendant.Massless = true
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end
		return model, 1
	end

	local npcId = spec.npcId
	local definition = npcId and Npcs.get(npcId)
	if not definition then
		warn(`[CompanionService] "{spec.id}" names npc "{npcId}", which is not in Config/Npcs`)
		return nil, 1
	end

	return Mascot.build(definition.build, CFrame.new(), spec.name), 1
end

local function sendShelf(player: Player, id: string)
	Remotes.event("Companion", "Shelf"):FireClient(player, id)
end

local function despawn(player: Player)
	local existing = active[player]
	if existing then
		active[player] = nil
		existing:Destroy()
	end
end

local function spawn(player: Player, character: Model, trigger: string)
	if not resolved then
		return
	end

	local wanted = selectionFor(player)
	if wanted == Companions.NONE then
		despawn(player)
		sendShelf(player, Companions.NONE)
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local playerRoot = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not playerRoot then
		warn(`[CompanionService] {player.Name} ({trigger}): character has no Humanoid/HumanoidRootPart`)
		return
	end

	if player.Character ~= character or not character.Parent then
		return
	end

	local profile = DataService.get(player)
	local spec = Companions.get(wanted)
	local model: Model? = nil
	local skinScale = 1
	if spec then
		model, skinScale = buildCompanion(spec, profile)
	end

	if not model then
		local fallback = Companions.get(Companions.DEFAULT)
		spec = fallback
		if fallback then
			model, skinScale = buildCompanion(fallback, profile)
		else
			model, skinScale = nil, 1
		end
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
	sendShelf(player, spec.id)
	model.Name = `Companion_{player.Name}`
	model:SetAttribute(ANIM_OWNER_ATTRIBUTE, player.UserId)

	local scale = if spec.kind == "asset" then normalise(model, (spec.scale or 1) * skinScale) else 1
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

	model:PivotTo(playerRoot.CFrame * CFrame.new(target.Position))
	model.Parent = folder
	active[player] = model

	pcall(function()
		root:SetNetworkOwner(player)
	end)

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

local function buildStand(base: CFrame): Model?
	local model = AssetService.clone("friendStand")
	if not model then
		warn("[CompanionService] friendStand asset unavailable - the friend stand was not built")
		return nil
	end
	model.Name = "FriendStand"

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Camera") then
			descendant:Destroy()
		end
	end

	local size = model:GetExtentsSize()
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > 0.01 then
		local scale = SafeZone.STAND.fit / largest
		if math.abs(scale - 1) > 0.01 then
			model:ScaleTo(scale)
		end
	end

	local primary: BasePart?
	local primaryVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > primaryVolume then
				primary, primaryVolume = descendant, volume
			end
		end
	end
	if not primary then
		warn("[CompanionService] friendStand has no BaseParts - the friend stand was not built")
		model:Destroy()
		return nil
	end
	model.PrimaryPart = primary

	model:PivotTo(base)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = boxCFrame.Position - boxCFrame.YVector * (boxSize.Y / 2)
	model:PivotTo(model:GetPivot() + Vector3.new(0, base.Position.Y - bottom.Y, 0))

	local pivot = model:GetPivot()
	local topY = base.Position.Y + boxSize.Y
	local shelfY = topY
	local boards: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Size.Y < 0.5 then
			table.insert(boards, descendant)
		end
	end
	table.sort(boards, function(a: BasePart, b: BasePart)
		return (a.Position.Y + a.Size.Y / 2) > (b.Position.Y + b.Size.Y / 2)
	end)
	if #boards >= 2 then
		shelfY = boards[2].Position.Y + boards[2].Size.Y / 2
	end

	UI.sign(primary, {
		name = "StandSign",
		title = "Friend Stand",
		subtitle = "Press E to choose who follows you",
		offset = Vector3.new(0, topY + 2.5 - primary.Position.Y, 0),
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
	prompt.Parent = primary

	prompt.Triggered:Connect(function(player)
		Remotes.event("Companion", "Open"):FireClient(player, roster(DataService.get(player)), selectionFor(player))
	end)

	local across = { -SHELF_SLOT_SPACING, 0, SHELF_SLOT_SPACING }
	local alongX = boxSize.X >= boxSize.Z
	local plushies = Instance.new("Model")
	plushies.Name = "Plushies"

	for index, spec in Companions.LIST do
		local key = spec.assetKey
		local plushie = if spec.kind == "asset" and key then AssetService.clone(key) else nil
		if plushie then
			for _, descendant in plushie:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") or descendant:IsA("Humanoid") then
					descendant:Destroy()
				end
			end

			local plushieSize = plushie:GetExtentsSize()
			local plushieLargest = math.max(plushieSize.X, plushieSize.Y, plushieSize.Z)
			if plushieLargest > 0.01 then
				local scale = SHELF_PLUSHIE_SIZE / plushieLargest
				if math.abs(scale - 1) > 0.01 then
					plushie:ScaleTo(scale)
				end
			end

			for _, descendant in plushie:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
				end
			end

			plushie.Name = spec.name
			plushie:SetAttribute(COMPANION_ID_ATTRIBUTE, spec.id)
			standSlots[spec.id] = plushie

			local offset = across[index] or 0
			local slot = if alongX
				then Vector3.new(offset, shelfY - pivot.Position.Y, 0)
				else Vector3.new(0, shelfY - pivot.Position.Y, offset)
			local seat = (pivot * CFrame.new(slot)).Position
			plushie:PivotTo(CFrame.new(seat) * CFrame.Angles(0, math.rad(SafeZone.STAND.plushieYaw), 0))
			local plushieBox, plushieBoxSize = plushie:GetBoundingBox()
			local plushieBottom = plushieBox.Position - plushieBox.YVector * (plushieBoxSize.Y / 2)
			plushie:PivotTo(plushie:GetPivot() + Vector3.new(0, shelfY - plushieBottom.Y, 0))

			plushie.Parent = plushies
		end
	end

	plushies.Parent = model

	return model
end

local function burst(at: CFrame, size: number)
	local anchor = Instance.new("Part")
	anchor.Name = "FriendBurst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = at
	anchor.Parent = folder

	local light = Instance.new("PointLight")
	light.Brightness = 9
	light.Range = size * 7
	light.Color = Color3.fromRGB(255, 240, 208)
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 0
	sparks.Speed = NumberRange.new(16, 34)
	sparks.Lifetime = NumberRange.new(0.35, 0.8)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Drag = 3.5
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 236, 190), Color3.fromRGB(255, 178, 206))
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Parent = anchor
	sparks:Emit(70)

	local shell = Instance.new("Part")
	shell.Name = "FriendBurstShell"
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.Neon
	shell.Color = Color3.fromRGB(255, 246, 224)
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Size = Vector3.one * (size * 0.4)
	shell.CFrame = at
	shell.Parent = folder
	TweenService:Create(shell, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.one * (size * 3.4),
		Transparency = 1,
	}):Play()

	Debris:AddItem(anchor, 1.6)
	Debris:AddItem(shell, 0.6)
end

local function dressToss(flying: Model): BasePart?
	local core: BasePart? = nil
	local coreVolume = 0
	for _, descendant in flying:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > coreVolume then
				core, coreVolume = descendant, volume
			end
		end
	end

	if not core then
		return nil
	end

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, core.Size.Y * 0.5, 0)
	top.Parent = core

	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -core.Size.Y * 0.5, 0)
	bottom.Parent = core

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.32
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 226, 240), Color3.fromRGB(198, 232, 255))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = core

	return core
end

local function toss(player: Player, spec: Companions.CompanionSpec)
	local generation = (tossGeneration[player] or 0) + 1
	tossGeneration[player] = generation

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local source = standSlots[spec.id]
	if not root or not root:IsA("BasePart") or not source or not source.Parent then
		respawnCompanion(player, "selected")
		return
	end

	despawn(player)

	local flying = source:Clone()
	flying.Name = "FriendToss"
	flying.PrimaryPart = dressToss(flying)
	flying.Parent = folder

	local baseScale = flying:GetScale()
	local finalSize = TARGET_HEIGHT * (spec.scale or 1)
	local grow = finalSize / SHELF_PLUSHIE_SIZE
	local from = source:GetPivot().Position
	local spin = 0

	local function alive(): boolean
		return tossGeneration[player] == generation and flying.Parent ~= nil and root.Parent ~= nil
	end

	local start = os.clock()
	while alive() do
		local alpha = math.clamp((os.clock() - start) / TOSS_TO_HAND, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		spin += 0.14
		local hand = (root.CFrame * TOSS_HAND_OFFSET).Position
		flying:PivotTo(CFrame.new(from:Lerp(hand, eased)) * CFrame.Angles(0, spin, 0))
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	local launch = flying:GetPivot().Position
	local apex = launch + Vector3.new(0, TOSS_HEIGHT, 0)
	start = os.clock()
	while alive() do
		local alpha = math.clamp((os.clock() - start) / TOSS_TO_APEX, 0, 1)
		local eased = 1 - (1 - alpha) ^ 2
		spin += 0.38
		flying:PivotTo(CFrame.new(launch:Lerp(apex, eased)) * CFrame.Angles(spin * 0.4, spin, 0))
		flying:ScaleTo(baseScale * (1 + (grow - 1) * eased))
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	local landed = flying:GetPivot()
	flying:Destroy()

	if tossGeneration[player] ~= generation then
		return
	end

	burst(landed, finalSize)
	respawnCompanion(player, "selected")
end

function CompanionService.select(player: Player, id: string): boolean
	if id == Companions.NONE then
		remember(player, id)
		tossGeneration[player] = (tossGeneration[player] or 0) + 1
		despawn(player)
		sendShelf(player, id)
		NotifyService.send(player, "Walking alone for now.", "info")
		return true
	end

	local spec = Companions.get(id)
	if not spec or not isAvailable(spec) then
		warn(`[CompanionService] {player.Name} asked for "{id}", which is not on this server's roster`)
		return false
	end
	if not isOwned(spec, DataService.get(player)) then
		NotifyService.send(player, "You have not met that one yet.", "locked")
		return false
	end

	remember(player, id)
	sendShelf(player, id)

	task.spawn(toss, player, spec)
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

	if type(skillId) == "string" and Skills.exists(skillId) then
		model:SetAttribute(ANIM_SKILL_ATTRIBUTE, Skills.canonicalize(skillId))
	end
	model:SetAttribute(ANIM_ACTION_ATTRIBUTE, now)
end

function CompanionService.refreshAppearance(player: Player)
	tossGeneration[player] = (tossGeneration[player] or 0) + 1
	respawnCompanion(player, "skin changed")
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

	local stand = buildStand(
		CFrame.new(SafeZone.STAND.x, Constants.WORLD.PLATFORM_TOP + SafeZone.FLOOR_Y, SafeZone.STAND.z)
			* CFrame.Angles(0, math.rad(SafeZone.STAND.yaw), 0)
	)
	if stand then
		stand.Parent = folder
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
		tossGeneration[player] = nil
		despawn(player)
	end)

	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(spawn, player, character, "CharacterAdded")
		end)
		player.CharacterRemoving:Connect(function()
			despawn(player)
		end)

		if player.Character then
			task.spawn(spawn, player, player.Character, "already spawned")
		end
	end

	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end

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

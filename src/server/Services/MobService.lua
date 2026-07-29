--!strict

local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Mobs = require(Shared.Modules.Config.Mobs)

local AssetService = require(script.Parent.AssetService)
local MobRig = require(script.Parent.MobRig)
local SafeZoneService = require(script.Parent.SafeZoneService)
local WorldService = require(script.Parent.WorldService)

local MobService = {}

local ACTION_ATTRIBUTE = "MobAction"
local ACTION_SERIAL_ATTRIBUTE = "MobActionSerial"
local COLLISION_GROUP = "Mobs"
local REPATH_INTERVAL = 0.8
local TARGET_REPATH_DISTANCE = 6
local THINK_INTERVAL = 0.2

type MobState = "roam" | "chase" | "flee" | "return"

local folder: Folder
local spawnCFrames: { [string]: { CFrame } } = {}
-- Species whose roam and leash circles are centred somewhere other than their
-- own spawn point: the guardians orbit their BIG tree, not the spot they stood.
local spawnHomes: { [string]: Vector3? } = {}
local collisionGroupReady = false

-- A locked species is scenery: it cannot be attacked and does not fight back.
-- The forest uses it to keep the BIG tree inert until its guardians are down.
local lockedSpecies: { [string]: boolean } = {}
local killedCallbacks: { (Mobs.MobDefinition, number, Player?) -> () } = {}

local Mob = {}
Mob.__index = Mob

type MobActor = {
	_key: string,
	_slot: number,
	_definition: Mobs.MobDefinition,
	_model: Model,
	_root: BasePart,
	_humanoid: Humanoid,
	_healthFill: Frame,
	_home: Vector3,
	_target: Player?,
	_state: MobState,
	_destroyed: boolean,
	_actionSerial: number,
	_lastAttack: number,
	_fleeUntil: number,
	_nextPathAt: number,
	_nextRoamAt: number,
	_lastDestination: Vector3?,
	_path: Path?,
	_pathBlocked: RBXScriptConnection?,
	_waypoints: { PathWaypoint }?,
	_waypointIndex: number,
	_pathDone: boolean,
	_rng: Random,
	_connections: { RBXScriptConnection },
	_playAction: (MobActor, string) -> (),
	_disconnectPath: (MobActor) -> (),
	_moveNextWaypoint: (MobActor) -> (),
	_setDestination: (MobActor, Vector3) -> boolean,
	_hasLineOfSight: (MobActor, Model, BasePart) -> boolean,
	_validTarget: (MobActor) -> (Model?, BasePart?, Humanoid?),
	_disengage: (MobActor) -> (),
	_lastHitBy: Player?,
	_thinkChase: (MobActor, number) -> (),
	_thinkRoot: (MobActor, number) -> (),
	_thinkFlee: (MobActor, number) -> (),
	_thinkReturn: (MobActor, number) -> (),
	_thinkRoam: (MobActor, number) -> (),
	_run: (MobActor) -> (),
	TakeHit: (MobActor, Player, number) -> boolean,
	Destroy: (MobActor) -> (),
}

local actors: { [string]: MobActor } = {}

local function setupCollisionGroup()
	local ok, err = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
			PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
		end
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Default", true)
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, true)

		for regionIndex = 1, #Areas.ALL do
			PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, WorldService.accessGroupFor(regionIndex), false)
		end
	end)
	collisionGroupReady = ok
	if not ok then
		warn(`[MobService] collision group setup failed; mobs may push characters: {err}`)
	end
end

local function placeOnGround(model: Model, groundCFrame: CFrame)
	model:PivotTo(groundCFrame)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, groundCFrame.Position.Y - bottom, 0))
end

local function planarDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function characterParts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, if root and root:IsA("BasePart") then root else nil, humanoid
end

local function definitionSeed(id: string): number
	local seed = 0
	for index = 1, #id do
		seed += string.byte(id, index) * index
	end
	return seed
end

function Mob._playAction(self: MobActor, name: string)
	if self._destroyed then
		return
	end
	self._model:SetAttribute(ACTION_ATTRIBUTE, name)
	self._actionSerial += 1
	self._model:SetAttribute(ACTION_SERIAL_ATTRIBUTE, self._actionSerial)
end

function Mob._disconnectPath(self: MobActor)
	if self._pathBlocked then
		self._pathBlocked:Disconnect()
		self._pathBlocked = nil
	end
	self._path = nil
	self._waypoints = nil
	self._waypointIndex = 0
end

function Mob._moveNextWaypoint(self: MobActor)
	local waypoints = self._waypoints
	if self._destroyed or not waypoints or self._waypointIndex > #waypoints then
		self._pathDone = true
		return
	end
	local waypoint = waypoints[self._waypointIndex]
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		self._humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	self._humanoid:MoveTo(waypoint.Position)
end

function Mob._setDestination(self: MobActor, destination: Vector3): boolean
	if self._destroyed or self._humanoid.Health <= 0 then
		return false
	end
	local area = Areas.get(self._definition.regionId)
	if area and Layout.isFarmPosition(area, destination, 8) then
		return false
	end

	self:_disconnectPath()
	self._pathDone = false
	self._lastDestination = destination
	local rootSize = self._root.Size
	local path = PathfindingService:CreatePath({
		AgentRadius = math.clamp(math.max(rootSize.X, rootSize.Z) / 2, 2, 4),
		AgentHeight = math.max(5, self._definition.height + 1),
		AgentCanJump = true,
		WaypointSpacing = 6,
	})
	local ok, err = pcall(function()
		path:ComputeAsync(self._root.Position, destination)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		if not ok then
			warn(`[MobService] path computation failed for {self._model.Name}: {err}`)
		end
		self._pathDone = true
		self._nextPathAt = os.clock() + REPATH_INTERVAL
		return false
	end

	local waypoints = path:GetWaypoints()
	if #waypoints < 2 then
		self._pathDone = true
		return true
	end
	self._path = path
	self._waypoints = waypoints
	self._waypointIndex = 2
	self._pathBlocked = path.Blocked:Connect(function(index)
		if index >= self._waypointIndex then
			self._nextPathAt = 0
			self._pathDone = true
			if self._state == "roam" then
				self._nextRoamAt = 0
			end
		end
	end)
	self:_moveNextWaypoint()
	return true
end

function Mob._hasLineOfSight(self: MobActor, character: Model, targetRoot: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self._model }
	local result = Workspace:Raycast(self._root.Position, targetRoot.Position - self._root.Position, params)
	return result == nil or result.Instance:IsDescendantOf(character)
end

function Mob._validTarget(self: MobActor): (Model?, BasePart?, Humanoid?)
	local player = self._target
	if not player or player.Parent ~= Players then
		return nil, nil, nil
	end
	-- Home prevents hostile mobs from pursuing or damaging a player. A passive
	-- Duck may still regard that player as a threat so a hit inside the garden
	-- actually makes it flee instead of immediately cancelling the flee state.
	if self._definition.behavior ~= "flee" and SafeZoneService.isProtected(player) then
		return nil, nil, nil
	end
	local character, root, humanoid = characterParts(player)
	if
		not character
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or planarDistance(root.Position, self._home) > self._definition.leashRadius
	then
		return nil, nil, nil
	end
	return character, root, humanoid
end

function Mob._disengage(self: MobActor)
	self._target = nil
	self._state = "return"
	self._humanoid.WalkSpeed = self._definition.roamSpeed
	self._nextPathAt = 0
end

function Mob._thinkChase(self: MobActor, now: number)
	local definition = self._definition
	if definition.behavior ~= "fight" then
		self:_disengage()
		return
	end
	local character, targetRoot, targetHumanoid = self:_validTarget()
	if not character or not targetRoot or not targetHumanoid then
		self:_disengage()
		return
	end

	local distance = planarDistance(self._root.Position, targetRoot.Position)
	if distance <= definition.attackRange and self:_hasLineOfSight(character, targetRoot) then
		self._humanoid:Move(Vector3.zero)
		if now - self._lastAttack >= definition.attackCooldown then
			self._lastAttack = now
			self:_playAction("attack")
			local target = self._target
			if target and not SafeZoneService.isProtected(target) then
				targetHumanoid:TakeDamage(definition.attackDamage)
			end
		end
		return
	end

	self._humanoid.WalkSpeed = definition.chaseSpeed
	if
		now >= self._nextPathAt
		or not self._lastDestination
		or planarDistance(self._lastDestination, targetRoot.Position) >= TARGET_REPATH_DISTANCE
	then
		self._nextPathAt = now + REPATH_INTERVAL
		self:_setDestination(targetRoot.Position)
	end
end

--[[
	Planted mobs. No path, no roam: whoever walks into reach becomes the target,
	the trunk turns to face them and it swings on its cooldown.
]]
function Mob._thinkRoot(self: MobActor, now: number)
	local definition = self._definition
	if definition.behavior ~= "root" or lockedSpecies[definition.id] then
		return
	end

	local _, targetRoot, targetHumanoid = self:_validTarget()
	if not targetRoot or planarDistance(self._root.Position, targetRoot.Position) > definition.attackRange then
		self._target = nil
		for _, player in Players:GetPlayers() do
			if SafeZoneService.isProtected(player) then
				continue
			end
			local _, root, humanoid = characterParts(player)
			if
				root
				and humanoid
				and humanoid.Health > 0
				and planarDistance(root.Position, self._root.Position) <= definition.attackRange
			then
				self._target = player
				break
			end
		end
		return
	end

	self._root.CFrame = CFrame.lookAt(
		self._root.Position,
		Vector3.new(targetRoot.Position.X, self._root.Position.Y, targetRoot.Position.Z)
	)

	if now - self._lastAttack >= definition.attackCooldown then
		self._lastAttack = now
		self:_playAction("attack")
		if targetHumanoid then
			targetHumanoid:TakeDamage(definition.attackDamage)
		end
	end
end

function Mob._thinkFlee(self: MobActor, now: number)
	local definition = self._definition
	if definition.behavior ~= "flee" then
		self:_disengage()
		return
	end
	local _, targetRoot = self:_validTarget()
	if not targetRoot or now >= self._fleeUntil then
		self:_disengage()
		return
	end

	local away = self._root.Position - targetRoot.Position
	away = Vector3.new(away.X, 0, away.Z)
	local threatDistance = away.Magnitude
	if threatDistance >= definition.fleeSafeDistance then
		self:_disengage()
		return
	end
	if away.Magnitude < 0.01 then
		away = -Vector3.new(self._root.CFrame.LookVector.X, 0, self._root.CFrame.LookVector.Z)
	end
	if away.Magnitude < 0.01 then
		away = Vector3.new(1, 0, 0)
	end

	self._humanoid.WalkSpeed = definition.fleeSpeed
	if now >= self._nextPathAt or self._pathDone then
		self._nextPathAt = now + REPATH_INTERVAL
		local destination = self._root.Position + away.Unit * definition.fleeDistance
		local homeOffset = Vector3.new(destination.X - self._home.X, 0, destination.Z - self._home.Z)
		local maxDistance = definition.leashRadius * 0.9
		if homeOffset.Magnitude > maxDistance then
			homeOffset = homeOffset.Unit * maxDistance
			destination = self._home + homeOffset
		end
		self:_setDestination(Vector3.new(destination.X, self._home.Y, destination.Z))
	end
end

function Mob._thinkReturn(self: MobActor, now: number)
	if planarDistance(self._root.Position, self._home) <= 4 then
		self._state = "roam"
		self._pathDone = true
		self._nextRoamAt = now + self._rng:NextNumber(1.5, 4)
		return
	end
	if now >= self._nextPathAt then
		self._nextPathAt = now + REPATH_INTERVAL
		self:_setDestination(self._home)
	end
end

function Mob._thinkRoam(self: MobActor, now: number)
	if now < self._nextRoamAt or not self._pathDone then
		return
	end
	local definition = self._definition
	local angle = self._rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(self._rng:NextNumber(0, 1)) * definition.roamRadius
	local destination = self._home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	self._humanoid.WalkSpeed = definition.roamSpeed
	if self:_setDestination(destination) then
		self._nextRoamAt = now + self._rng:NextNumber(4, 7)
	else
		self._nextRoamAt = now + REPATH_INTERVAL
	end
end

function Mob._run(self: MobActor)
	while not self._destroyed do
		local now = os.clock()
		if self._definition.behavior == "root" then
			self:_thinkRoot(now)
		elseif self._state == "chase" then
			self:_thinkChase(now)
		elseif self._state == "flee" then
			self:_thinkFlee(now)
		elseif self._state == "return" then
			self:_thinkReturn(now)
		else
			self:_thinkRoam(now)
		end
		task.wait(THINK_INTERVAL)
	end
end

function Mob.TakeHit(self: MobActor, player: Player, damage: number): boolean
	if
		self._destroyed
		or self._humanoid.Health <= 0
		or damage ~= damage
		or damage <= 0
		or player.Parent ~= Players
	then
		return false
	end

	self:_playAction("hit")
	self._lastHitBy = player
	self._humanoid.Health = math.max(0, self._humanoid.Health - math.min(damage, self._humanoid.Health))
	if self._humanoid.Health <= 0 then
		return true
	end

	self._target = player
	self._nextPathAt = 0
	local definition = self._definition
	if definition.behavior == "root" then
		return true
	elseif definition.behavior == "fight" then
		self._state = "chase"
		self._humanoid.WalkSpeed = definition.chaseSpeed
	else
		self._state = "flee"
		self._humanoid.WalkSpeed = definition.fleeSpeed
		self._fleeUntil = os.clock() + definition.fleeDuration
	end
	return true
end

function Mob.Destroy(self: MobActor)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:_disconnectPath()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._target = nil
	if self._model.Parent then
		self._model:Destroy()
	end
end

function Mob.new(
	key: string,
	slot: number,
	definition: Mobs.MobDefinition,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	healthFill: Frame,
	onDied: (string, MobActor) -> ()
): MobActor
	local seed = definitionSeed(definition.id) * 1009 + slot * 7919
	local self = setmetatable({
		_key = key,
		_slot = slot,
		_definition = definition,
		_model = model,
		_root = root,
		_humanoid = humanoid,
		_healthFill = healthFill,
		_home = root.Position,
		_target = nil :: Player?,
		_state = "roam" :: MobState,
		_destroyed = false,
		_actionSerial = 0,
		_lastAttack = -math.huge,
		_fleeUntil = 0,
		_nextPathAt = 0,
		_nextRoamAt = os.clock() + Random.new(seed):NextNumber(1, 3),
		_lastDestination = nil :: Vector3?,
		_path = nil :: Path?,
		_pathBlocked = nil :: RBXScriptConnection?,
		_waypoints = nil :: { PathWaypoint }?,
		_waypointIndex = 0,
		_pathDone = true,
		_rng = Random.new(20260728 + seed),
		_connections = {} :: { RBXScriptConnection },
		_lastHitBy = nil :: Player?,
	}, Mob) :: any

	table.insert(
		self._connections,
		humanoid.HealthChanged:Connect(function(health)
			healthFill.Size = UDim2.fromScale(math.clamp(health / definition.maxHealth, 0, 1), 1)
		end)
	)
	table.insert(
		self._connections,
		humanoid.Died:Connect(function()
			task.defer(onDied, key, self)
		end)
	)
	table.insert(
		self._connections,
		humanoid.MoveToFinished:Connect(function(reached)
			if self._destroyed then
				return
			end
			if not reached then
				self._nextPathAt = 0
				self._pathDone = true
				return
			end
			self._waypointIndex += 1
			if self._waypoints and self._waypointIndex <= #self._waypoints then
				self:_moveNextWaypoint()
			else
				self._pathDone = true
			end
		end)
	)

	task.spawn(function()
		self:_run()
	end)
	return self
end

local function actorKey(definition: Mobs.MobDefinition, slot: number): string
	return `{definition.id}:{slot}`
end

local spawnSlot: (Mobs.MobDefinition, number) -> ()
spawnSlot = function(definition: Mobs.MobDefinition, slot: number)
	local key = actorKey(definition, slot)
	if actors[key] or not folder.Parent then
		return
	end
	local model = AssetService.clone(definition.assetKey)
	if not model then
		warn(`[MobService] could not clone asset "{definition.assetKey}" for {key}`)
		return
	end

	model.Name = `{definition.modelName}_{slot}`
	model:SetAttribute("MobSlot", slot)
	local root, humanoid, healthFill = MobRig.rig(
		model,
		definition,
		if collisionGroupReady then COLLISION_GROUP else nil
	)
	if not root or not humanoid or not healthFill then
		model:Destroy()
		warn(`[MobService] failed to rig {definition.name} slot {slot}`)
		return
	end

	local speciesSpawns = spawnCFrames[definition.id]
	local spawnCFrame = speciesSpawns and speciesSpawns[slot]
	if not spawnCFrame then
		model:Destroy()
		warn(`[MobService] no spawn configured for {key}`)
		return
	end
	placeOnGround(model, spawnCFrame)
	model.Parent = folder
	if definition.behavior == "root" then
		-- Planted: anchored so nothing can shove a tree out of its clearing.
		root.Anchored = true
	else
		local ok, err = pcall(function()
			root:SetNetworkOwner(nil)
		end)
		if not ok then
			warn(`[MobService] could not assign server network ownership for {model.Name}: {err}`)
		end
	end

	local actor: MobActor
	local home = spawnHomes[definition.id]
	actor = Mob.new(key, slot, definition, model, root, humanoid, healthFill, function(deadKey, deadActor)
		if actors[deadKey] ~= deadActor then
			return
		end
		actors[deadKey] = nil
		local killer = deadActor._lastHitBy
		deadActor:Destroy()
		for _, callback in killedCallbacks do
			task.spawn(callback, definition, slot, killer)
		end
		if definition.respawn ~= false then
			task.defer(spawnSlot, definition, slot)
		end
	end)
	if home then
		actor._home = Vector3.new(home.X, root.Position.Y, home.Z)
	end
	actors[key] = actor
end

local function clearLineOfSight(playerCharacter: Model, targetModel: Model, from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { playerCharacter, targetModel }
	return Workspace:Raycast(from, to - from, params) == nil
end

local function findAttackTarget(player: Player): MobActor?
	local character, playerRoot, playerHumanoid = characterParts(player)
	if not character or not playerRoot or not playerHumanoid or playerHumanoid.Health <= 0 then
		return nil
	end

	local forward = Vector3.new(playerRoot.CFrame.LookVector.X, 0, playerRoot.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		return nil
	end
	forward = forward.Unit

	local best: MobActor? = nil
	local bestDistance = math.huge
	local playerProtected = SafeZoneService.isProtected(player)
	for _, actor in actors do
		if actor._destroyed or actor._humanoid.Health <= 0 or actor._model.Parent ~= folder then
			continue
		end
		local definition = actor._definition
		if lockedSpecies[definition.id] then
			continue
		end
		-- Players may scare passive mobs from Home, but cannot safely farm hostile
		-- mobs which would be forbidden from retaliating across the boundary.
		if playerProtected and definition.behavior ~= "flee" then
			continue
		end
		local offset = actor._root.Position - playerRoot.Position
		local planar = Vector3.new(offset.X, 0, offset.Z)
		local distance = planar.Magnitude
		if
			distance > 0.01
			and distance <= definition.playerAttackRange
			and forward:Dot(planar.Unit) >= definition.playerFacingMinimum
			and distance < bestDistance
			and clearLineOfSight(character, actor._model, playerRoot.Position, actor._root.Position)
		then
			best = actor
			bestDistance = distance
		end
	end
	return best
end

--[[
	Put a species on the map at exactly these points.

	The ring spawner in init() only knows "N of them, R studs from the plaza",
	which cannot express "one per board section, ringed by its guardians". A
	caller that owns a layout owns its spawn points too.
]]
function MobService.deploy(mobId: string, cframes: { CFrame }, home: Vector3?)
	local definition = Mobs.get(mobId)
	if not definition then
		warn(`[MobService] deploy asked for unknown mob "{mobId}"`)
		return
	end
	spawnCFrames[mobId] = cframes
	spawnHomes[mobId] = home

	task.spawn(function()
		if not AssetService.waitFor(definition.assetKey, 10) then
			warn(`[MobService] asset "{definition.assetKey}" did not become ready`)
			return
		end
		for slot = 1, #cframes do
			spawnSlot(definition, slot)
		end
	end)
end

--[[
	Wake a whole species onto one player at once.

	Guardians are a ring, not four separate animals: walking up to the BIG tree
	should turn every one of them, not just whichever noticed first.
]]
function MobService.alert(mobId: string, player: Player)
	for _, actor in actors do
		local definition = actor._definition
		if
			definition.id ~= mobId
			or definition.behavior ~= "fight"
			or actor._destroyed
			or actor._humanoid.Health <= 0
			or actor._target == player
		then
			continue
		end
		actor._target = player
		actor._state = "chase"
		actor._nextPathAt = 0
		actor._humanoid.WalkSpeed = definition.chaseSpeed
	end
end

function MobService.setLocked(mobId: string, locked: boolean)
	lockedSpecies[mobId] = locked
end

function MobService.countAlive(mobId: string): number
	local count = 0
	for _, actor in actors do
		if actor._definition.id == mobId and not actor._destroyed and actor._humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

function MobService.onKilled(callback: (Mobs.MobDefinition, number, Player?) -> ())
	table.insert(killedCallbacks, callback)
end

function MobService.canAttack(player: Player): boolean
	return findAttackTarget(player) ~= nil
end

function MobService.tryAttack(player: Player, tobatsuPower: number): Mobs.MobDefinition?
	if tobatsuPower ~= tobatsuPower or tobatsuPower < 0 then
		return nil
	end
	local actor = findAttackTarget(player)
	if not actor then
		return nil
	end
	local definition = actor._definition
	local damage = math.max(1, tobatsuPower * definition.damageStatScale)
	if actor:TakeHit(player, damage) then
		return definition
	end
	return nil
end

function MobService.init()
	setupCollisionGroup()

	local existing = Workspace:FindFirstChild("Mobs")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Mobs"
	folder.Parent = Workspace

	for _, mobId in Mobs.ORDER do
		local definition = Mobs.get(mobId)
		if not definition then
			warn(`[MobService] configured mob "{mobId}" has no definition`)
			continue
		end
		local area = Areas.get(definition.regionId)
		if not area then
			warn(`[MobService] mob "{definition.id}" references missing region {definition.regionId}`)
			continue
		end
		spawnCFrames[definition.id] = Layout.mobSpawnCFrames(
			area,
			definition.population,
			definition.spawnRadius,
			definition.spawnAngleOffset
		)

		task.spawn(function()
			if not AssetService.waitFor(definition.assetKey, 10) then
				warn(`[MobService] asset "{definition.assetKey}" did not become ready`)
				return
			end
			for slot = 1, definition.population do
				spawnSlot(definition, slot)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, actor in actors do
			if actor._target == player then
				actor:_disengage()
			end
		end
	end)

	game:BindToClose(function()
		for key, actor in actors do
			actors[key] = nil
			actor:Destroy()
		end
	end)
end

return MobService

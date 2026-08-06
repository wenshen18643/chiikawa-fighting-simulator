--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)

export type ItemDefinition = {
	id: string,
	rarity: string,
}

export type RarityDefinition = {
	id: string,
	order: number,
	resaleYen: number,
}

export type DrawDefinition = {
	id: string,
	cost: number,
}

export type DomainConfig = {
	id: string,
	remoteCategory: string,
	npcName: string,
	npcDisplayName: string,
	promptName: string,
	promptAction: string,
	signTitle: string,
	signSubtitle: string,
	itemNoun: string,
	capacity: number,
	rarePlusPity: number,
	legendaryPity: number,
	allowedBatches: { [number]: boolean },
	getState: (profile: any) -> any,
	buildState: (profile: any, state: any) -> { [string]: any },
	totalCopies: (state: any) -> number,
	getDraw: (id: string) -> DrawDefinition?,
	getItem: (id: string) -> ItemDefinition?,
	getRarity: (id: string) -> RarityDefinition?,
	rollRarity: (draw: any, minimumOrder: number, rng: Random) -> string,
	rollItem: (rarityId: string, rng: Random) -> ItemDefinition,
	parseEquip: (request: unknown) -> any,
	equip: (profile: any, state: any, request: any) -> (boolean, string?),
	afterEquip: ((player: Player, profile: any, state: any) -> ())?,
	sellableCopies: (state: any, item: ItemDefinition) -> number,
}

export type Dependencies = {
	CurrencyService: any,
	DataService: any,
	NotifyService: any,
	ReplicationService: any,
}

type PullResult = {
	skinId: string,
	rarity: string,
	isNew: boolean,
}

local GachaMachine = {}
GachaMachine.__index = GachaMachine

export type GachaMachine = typeof(setmetatable(
	{} :: {
		_domain: DomainConfig,
		_dependencies: Dependencies,
		_rng: Random,
		_pullLimiters: { [Player]: RateLimiter.RateLimiter },
		_manageLimiters: { [Player]: RateLimiter.RateLimiter },
		_busy: { [Player]: boolean },
		_connections: { RBXScriptConnection },
		_npcAnchor: BasePart?,
		_openRemote: RemoteEvent?,
		_eventRemote: RemoteEvent?,
		_prompt: ProximityPrompt?,
		_sign: BillboardGui?,
		_destroyed: boolean,
	},
	GachaMachine
))

local INTERACTION_DISTANCE = 20
local PULL_RATE = 2
local PULL_BURST = 2
local MANAGE_RATE = 5
local MANAGE_BURST = 5

local function copyStringNumberMap(source: { [string]: number }): { [string]: number }
	return table.clone(source)
end

local function rootFor(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function findAnchor(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				best = descendant
				bestVolume = volume
			end
		end
	end
	return best
end

function GachaMachine.new(domain: DomainConfig, dependencies: Dependencies): GachaMachine
	return setmetatable({
		_domain = domain,
		_dependencies = dependencies,
		_rng = Random.new(),
		_pullLimiters = {},
		_manageLimiters = {},
		_busy = {},
		_connections = {},
		_npcAnchor = nil,
		_openRemote = nil,
		_eventRemote = nil,
		_prompt = nil,
		_sign = nil,
		_destroyed = false,
	}, GachaMachine)
end

local function limiterFor(
	collection: { [Player]: RateLimiter.RateLimiter },
	player: Player,
	rate: number,
	burst: number
): RateLimiter.RateLimiter
	local limiter = collection[player]
	if not limiter then
		limiter = RateLimiter.new(rate, burst)
		collection[player] = limiter
	end
	return limiter
end

function GachaMachine._withinReach(self: GachaMachine, player: Player): boolean
	local anchor = self._npcAnchor
	local root = rootFor(player)
	return anchor ~= nil
		and anchor.Parent ~= nil
		and root ~= nil
		and (root.Position - anchor.Position).Magnitude <= INTERACTION_DISTANCE
end

function GachaMachine._deny(self: GachaMachine, player: Player, message: string, profile: any?, state: any?)
	self._dependencies.NotifyService.send(player, message, "locked")
	local eventRemote = self._eventRemote
	if eventRemote then
		eventRemote:FireClient(player, {
			kind = "denied",
			message = message,
			state = if profile and state then self._domain.buildState(profile, state) else nil,
		})
	end
end

function GachaMachine._beginMutation(self: GachaMachine, player: Player): boolean
	if self._busy[player] then
		return false
	end
	self._busy[player] = true
	return true
end

function GachaMachine._finishMutation(self: GachaMachine, player: Player)
	self._busy[player] = nil
end

function GachaMachine._simulatePulls(
	self: GachaMachine,
	state: any,
	draw: DrawDefinition,
	count: number
): ({ PullResult }, { [string]: number }, number, number)
	local domain = self._domain
	local results = {} :: { PullResult }
	local copies = copyStringNumberMap(state.copies)
	local rarePlusMisses = state.rarePlusMisses
	local legendaryMisses = state.legendaryMisses

	for _ = 1, count do
		local minimumOrder = 1
		if legendaryMisses >= domain.legendaryPity - 1 then
			minimumOrder = 5
		elseif rarePlusMisses >= domain.rarePlusPity - 1 then
			minimumOrder = 3
		end

		local rarityId = domain.rollRarity(draw, minimumOrder, self._rng)
		local rarity = domain.getRarity(rarityId)
		local item = domain.rollItem(rarityId, self._rng)
		local previous = copies[item.id] or 0
		copies[item.id] = previous + 1

		table.insert(results, {
			skinId = item.id,
			rarity = rarityId,
			isNew = previous == 0,
		})

		if rarity and rarity.order >= 3 then
			rarePlusMisses = 0
		else
			rarePlusMisses += 1
		end
		if rarity and rarity.order >= 5 then
			legendaryMisses = 0
		else
			legendaryMisses += 1
		end
	end

	return results, copies, rarePlusMisses, legendaryMisses
end

function GachaMachine._parsePullRequest(self: GachaMachine, request: unknown): (DrawDefinition?, number?)
	if type(request) ~= "table" then
		return nil, nil
	end
	local payload = request :: { [string]: unknown }
	local drawId = payload.drawId
	local count = payload.count
	if type(drawId) ~= "string" or type(count) ~= "number" or count % 1 ~= 0 then
		return nil, nil
	end
	if not self._domain.allowedBatches[count] then
		return nil, nil
	end
	return self._domain.getDraw(drawId), count
end

function GachaMachine.Open(self: GachaMachine, player: Player)
	if not self:_withinReach(player) then
		return
	end
	local profile = self._dependencies.DataService.get(player)
	local state = profile and self._domain.getState(profile)
	local openRemote = self._openRemote
	if profile and state and openRemote then
		openRemote:FireClient(player, self._domain.buildState(profile, state))
	end
end

function GachaMachine.Pull(self: GachaMachine, player: Player, request: unknown): boolean
	if not limiterFor(self._pullLimiters, player, PULL_RATE, PULL_BURST):consume() then
		return false
	end
	local draw, count = self:_parsePullRequest(request)
	if not draw or not count or not self:_beginMutation(player) then
		return false
	end

	local ok, result = pcall(function(): boolean
		local domain = self._domain
		if not self:_withinReach(player) then
			self:_deny(player, `Stand beside {domain.npcDisplayName} to draw {domain.itemNoun}.`)
			return false
		end

		local profile = self._dependencies.DataService.get(player)
		local state = profile and domain.getState(profile)
		if not profile or not state then
			return false
		end

		if domain.totalCopies(state) + count > domain.capacity then
			self:_deny(player, `You need {count} free {domain.itemNoun} slots for this draw.`, profile, state)
			return false
		end

		local cost = BigNumber.fromNumber(draw.cost * count)
		if not self._dependencies.CurrencyService.canAfford(profile, "yen", cost) then
			self:_deny(player, `You need {draw.cost * count} yen for {count} draw(s).`, profile, state)
			return false
		end

		local results, copies, rarePlusMisses, legendaryMisses = self:_simulatePulls(state, draw, count)
		if not self._dependencies.CurrencyService.spend(profile, "yen", cost) then
			self:_deny(player, "Your yen changed before the draw could finish.", profile, state)
			return false
		end

		state.copies = copies
		state.rarePlusMisses = rarePlusMisses
		state.legendaryMisses = legendaryMisses

		local eventRemote = self._eventRemote
		if eventRemote then
			eventRemote:FireClient(player, {
				kind = "pull",
				drawId = draw.id,
				results = results,
				state = domain.buildState(profile, state),
			})
		end
		self._dependencies.ReplicationService.pushTo(player)
		return true
	end)

	self:_finishMutation(player)
	if not ok then
		warn(`[{self._domain.id}] pull failed for {player.Name}: {result}`)
		return false
	end
	return result
end

function GachaMachine.Equip(self: GachaMachine, player: Player, request: unknown): boolean
	if not limiterFor(self._manageLimiters, player, MANAGE_RATE, MANAGE_BURST):consume() then
		return false
	end
	local parsed = self._domain.parseEquip(request)
	if parsed == nil or not self:_beginMutation(player) then
		return false
	end

	local ok, result = pcall(function(): boolean
		local domain = self._domain
		if not self:_withinReach(player) then
			self:_deny(player, `Stand beside {domain.npcDisplayName} to change {domain.itemNoun}.`)
			return false
		end
		local profile = self._dependencies.DataService.get(player)
		local state = profile and domain.getState(profile)
		if not profile or not state then
			return false
		end

		local equipped, message = domain.equip(profile, state, parsed)
		if not equipped then
			self:_deny(player, message or `You do not own that {domain.itemNoun}.`, profile, state)
			return false
		end
		if domain.afterEquip then
			domain.afterEquip(player, profile, state)
		end
		local eventRemote = self._eventRemote
		if eventRemote then
			eventRemote:FireClient(player, { kind = "state", state = domain.buildState(profile, state) })
		end
		self._dependencies.ReplicationService.pushTo(player)
		return true
	end)

	self:_finishMutation(player)
	if not ok then
		warn(`[{self._domain.id}] equip failed for {player.Name}: {result}`)
		return false
	end
	return result
end

function GachaMachine.Sell(self: GachaMachine, player: Player, request: unknown): boolean
	if not limiterFor(self._manageLimiters, player, MANAGE_RATE, MANAGE_BURST):consume() then
		return false
	end
	if type(request) ~= "table" then
		return false
	end
	local payload = request :: { [string]: unknown }
	local skinId = payload.skinId
	local count = payload.count
	if
		type(skinId) ~= "string"
		or type(count) ~= "number"
		or count % 1 ~= 0
		or count < 1
		or count > self._domain.capacity
	then
		return false
	end
	local item = self._domain.getItem(skinId)
	if not item or not self:_beginMutation(player) then
		return false
	end

	local ok, result = pcall(function(): boolean
		local domain = self._domain
		if not self:_withinReach(player) then
			self:_deny(player, `Stand beside {domain.npcDisplayName} to sell {domain.itemNoun}.`)
			return false
		end
		local profile = self._dependencies.DataService.get(player)
		local state = profile and domain.getState(profile)
		if not profile or not state then
			return false
		end

		if count > domain.sellableCopies(state, item) then
			self:_deny(player, "Unequip that copy or choose a smaller sale amount.", profile, state)
			return false
		end

		local owned = state.copies[item.id] or 0
		local remaining = owned - count
		state.copies[item.id] = if remaining > 0 then remaining else nil
		local rarity = domain.getRarity(item.rarity)
		if not rarity then
			return false
		end
		local payout = rarity.resaleYen * count
		self._dependencies.CurrencyService.award(profile, "yen", BigNumber.fromNumber(payout))

		local eventRemote = self._eventRemote
		if eventRemote then
			eventRemote:FireClient(player, {
				kind = "sold",
				skinId = item.id,
				count = count,
				payout = payout,
				state = domain.buildState(profile, state),
			})
		end
		self._dependencies.ReplicationService.pushTo(player)
		return true
	end)

	self:_finishMutation(player)
	if not ok then
		warn(`[{self._domain.id}] sell failed for {player.Name}: {result}`)
		return false
	end
	return result
end

function GachaMachine._bindNpc(self: GachaMachine)
	local safeZone = Workspace:WaitForChild("SafeZone", 60)
	if self._destroyed then
		return
	end
	local model = safeZone and safeZone:FindFirstChild(self._domain.npcName)
	if not (model and model:IsA("Model")) then
		warn(`[{self._domain.id}] {self._domain.npcName} was not placed inside Workspace.SafeZone`)
		return
	end

	local anchor = findAnchor(model)
	if not anchor then
		warn(`[{self._domain.id}] {self._domain.npcName} has no BasePart for interaction`)
		return
	end
	self._npcAnchor = anchor

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = self._domain.promptName
	prompt.ActionText = self._domain.promptAction
	prompt.ObjectText = self._domain.npcDisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	self._prompt = prompt
	table.insert(self._connections, prompt.Triggered:Connect(function(player)
		self:Open(player)
	end))

	self._sign = UI.sign(anchor, {
		name = `{self._domain.id}Sign`,
		title = self._domain.signTitle,
		subtitle = self._domain.signSubtitle,
		offset = Vector3.new(0, 8, 0),
		extent = UDim2.fromScale(14, 4.2),
		maxDistance = 120,
	})
end

function GachaMachine.Init(self: GachaMachine)
	assert(not self._destroyed, "cannot initialize a destroyed GachaMachine")
	assert(self._openRemote == nil, "GachaMachine is already initialized")
	self._openRemote = Remotes.event(self._domain.remoteCategory, "Open")
	self._eventRemote = Remotes.event(self._domain.remoteCategory, "Event")

	table.insert(
		self._connections,
		Remotes.event(self._domain.remoteCategory, "Pull").OnServerEvent:Connect(function(player, request)
			self:Pull(player, request)
		end)
	)
	table.insert(
		self._connections,
		Remotes.event(self._domain.remoteCategory, "Equip").OnServerEvent:Connect(function(player, request)
			self:Equip(player, request)
		end)
	)
	table.insert(
		self._connections,
		Remotes.event(self._domain.remoteCategory, "Sell").OnServerEvent:Connect(function(player, request)
			self:Sell(player, request)
		end)
	)
	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player)
			self._pullLimiters[player] = nil
			self._manageLimiters[player] = nil
			self._busy[player] = nil
		end)
	)

	task.spawn(function()
		self:_bindNpc()
	end)
end

function GachaMachine.Destroy(self: GachaMachine)
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._prompt then
		self._prompt:Destroy()
		self._prompt = nil
	end
	if self._sign then
		self._sign:Destroy()
		self._sign = nil
	end
	self._npcAnchor = nil
	table.clear(self._pullLimiters)
	table.clear(self._manageLimiters)
	table.clear(self._busy)
end

return GachaMachine

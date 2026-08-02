--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local WorkOrders = require(Shared.Modules.Config.WorkOrders)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local ForagingService = require(script.Parent.ForagingService)
local HarvestNodes = require(script.Parent.HarvestNodes)
local MobService = require(script.Parent.MobService)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)
local WorkOrderService = {}
local LEVEL_ATTRIBUTE = "CaveLevel"
local LANTERN_ATTRIBUTE = "HasLantern"
local openRemote: RemoteEvent
local acceptRemote: RemoteEvent
local turnInRemote: RemoteEvent
local eventRemote: RemoteEvent
local offered: { [Player]: { string } } = {}

local function stateOf(profile: any)
	local state = profile.workOrders
	state.completed = state.completed or {}
	state.active = state.active or {}

	state.rank = state.rank or 0
	return state
end

local function hasCompleted(state: any, id: string): boolean
	for _, done in state.completed do
		if done == id then
			return true
		end
	end
	return false
end

local function activeId(state: any): string?
	for id in state.active do
		return id
	end
	return nil
end

local function chainDone(state: any): boolean
	for _, order in WorkOrders.CHAIN do
		if not hasCompleted(state, order.id) then
			return false
		end
	end
	return true
end

local function boardFor(profile: any): { WorkOrders.OrderDefinition }
	local state = stateOf(profile)
	local current = activeId(state)
	if current then
		local order = WorkOrders.get(current)
		if order then
			return { order }
		end
		state.active = {}
	end

	for _, order in WorkOrders.CHAIN do
		if not hasCompleted(state, order.id) then
			return { order }
		end
	end

	return WorkOrders.board(state.rank)
end

local function payloadFor(profile: any)
	local state = stateOf(profile)
	local current = activeId(state)
	local board = boardFor(profile)
	local ids = {}
	local entries = {}
	for _, order in board do
		table.insert(ids, order.id)
		table.insert(entries, {
			id = order.id,
			name = order.name,
			blurb = order.blurb,
			summary = WorkOrders.describe(order),
			objective = order.objective,
			reward = order.reward,
			grade = order.grade,
			progress = state.active[order.id] or 0,
			accepted = current == order.id,
		})
	end

	return ids, {
		orders = entries,
		active = current,
		rank = state.rank,
		chainDone = chainDone(state),
	}
end

local function sendBoard(player: Player, open: boolean)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local ids, payload = payloadFor(profile)
	offered[player] = ids
	if open then
		openRemote:FireClient(player, payload)
	else
		eventRemote:FireClient(player, "board", payload)
	end
end

function WorkOrderService.open(player: Player)
	sendBoard(player, true)
end

local function activeOrder(profile: any): (WorkOrders.OrderDefinition?, number)
	local state = stateOf(profile)
	local id = activeId(state)
	if not id then
		return nil, 0
	end
	return WorkOrders.get(id), state.active[id] or 0
end

local function report(player: Player, order: WorkOrders.OrderDefinition, progress: number)
	eventRemote:FireClient(player, "progress", {
		id = order.id,
		name = order.name,
		summary = WorkOrders.describe(order),
		progress = progress,
		count = order.objective.count,
	})
end

local function refreshCollect(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local order, progress = activeOrder(profile)
	if not order or order.objective.kind ~= "collect" then
		return
	end

	local held = profile.currencies.ingredients[order.objective.target] or 0
	local updated = math.min(order.objective.count, held)
	if updated == progress then
		return
	end

	stateOf(profile).active[order.id] = updated
	report(player, order, updated)
	if updated >= order.objective.count then
		NotifyService.send(player, `{order.name} is done. Take it back to Yoroi-san.`, "reward")
	end
end

local function advance(player: Player, kind: string, target: string, amount: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local order, progress = activeOrder(profile)
	if not order or order.objective.kind ~= kind or order.objective.target ~= target then
		return
	end
	if progress >= order.objective.count then
		return
	end

	local state = stateOf(profile)
	local updated = math.min(order.objective.count, progress + amount)
	state.active[order.id] = updated

	report(player, order, updated)

	if updated >= order.objective.count then
		NotifyService.send(player, `{order.name} is done. Take it back to Yoroi-san.`, "reward")
	end
end

local function applyGear(player: Player, profile: any)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute(LANTERN_ATTRIBUTE, profile.gear and profile.gear.lantern == true)
end

local function grant(player: Player, profile: any, order: WorkOrders.OrderDefinition)
	local reward = order.reward

	if reward.yen then
		CurrencyService.award(profile, "yen", BigNumber.fromNumber(reward.yen))
	end

	if reward.skill and reward.skillAmount then
		SkillService.award(player, profile, reward.skill, BigNumber.fromNumber(reward.skillAmount))
	end

	local payout: { { id: string, count: number } } = reward.ingredients or {}
	for _, entry in payout do
		if Ingredients.get(entry.id) then
			local held = profile.currencies.ingredients
			held[entry.id] = (held[entry.id] or 0) + entry.count
		end
	end

	local unlock = reward.unlock
	if unlock then
		if unlock.kind == "recipe" then
			profile.recipes[unlock.id] = true
		elseif unlock.kind == "companion" then
			profile.companions.owned = profile.companions.owned or {}
			profile.companions.owned[unlock.id] = true
		elseif unlock.kind == "tool" then
			profile.gear[unlock.id] = true
			applyGear(player, profile)
		end
		NotifyService.send(player, `{unlock.label} unlocked!`, "unlock")
	end
end

local function wasOffered(player: Player, id: string): boolean
	local list: { string } = offered[player] or {}
	for _, candidate in list do
		if candidate == id then
			return true
		end
	end
	return false
end

local function onAccept(player: Player, id: any)
	if type(id) ~= "string" or not wasOffered(player, id) then
		return
	end
	local profile = DataService.get(player)
	local order = WorkOrders.get(id)
	if not profile or not order then
		return
	end

	local state = stateOf(profile)
	if activeId(state) then
		return
	end

	local generatedRank = WorkOrders.rankOf(id)
	if generatedRank then
		if generatedRank ~= state.rank then
			return
		end
	elseif hasCompleted(state, id) then
		return
	end

	state.active = { [id] = 0 }
	NotifyService.send(player, `Took on "{order.name}".`, "info")
	sendBoard(player, false)

	if order.objective.kind == "reach" then
		local character = player.Character
		local level = character and character:GetAttribute(LEVEL_ATTRIBUTE)
		if type(level) == "number" and level >= (tonumber(order.objective.target) or math.huge) then
			advance(player, "reach", order.objective.target, 1)
		end
	elseif order.objective.kind == "collect" then
		refreshCollect(player)
	end
end

local function onTurnIn(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local state = stateOf(profile)
	local order = WorkOrders.get(id)
	if not order or state.active[id] == nil then
		return
	end
	if (state.active[id] or 0) < order.objective.count then
		return
	end

	if order.objective.kind == "collect" then
		local held = profile.currencies.ingredients
		local have = held[order.objective.target] or 0
		if have < order.objective.count then
			NotifyService.send(player, "You are not carrying them any more. Go and get some.", "locked")
			state.active[id] = math.min(have, order.objective.count)
			sendBoard(player, false)
			return
		end
		held[order.objective.target] = have - order.objective.count
	end

	state.active = {}
	if WorkOrders.rankOf(id) then
		state.rank += 1
	else
		table.insert(state.completed, id)
	end

	grant(player, profile, order)
	NotifyService.send(player, `"{order.name}" complete.`, "reward")
	eventRemote:FireClient(player, "completed", { id = id, name = order.name })
	sendBoard(player, false)
end

local function watchDepth()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			local character = player.Character
			if not profile or not character then
				continue
			end

			local order = activeOrder(profile)
			if not order or order.objective.kind ~= "reach" then
				continue
			end

			local level = character:GetAttribute(LEVEL_ATTRIBUTE)
			local wanted = tonumber(order.objective.target)
			if type(level) == "number" and wanted and level >= wanted then
				advance(player, "reach", order.objective.target, 1)
			end
		end
	end
end

function WorkOrderService.init()
	openRemote = Remotes.event("Order", "Open")
	acceptRemote = Remotes.event("Order", "Accept")
	turnInRemote = Remotes.event("Order", "TurnIn")
	eventRemote = Remotes.event("Order", "Event")

	acceptRemote.OnServerEvent:Connect(onAccept)
	turnInRemote.OnServerEvent:Connect(onTurnIn)

	ForagingService.onPulled(function(player)
		refreshCollect(player)
	end)

	HarvestNodes.onHarvested(function(player)
		refreshCollect(player)
	end)

	MobService.onKilled(function(definition, _slot, killer)
		if killer then
			advance(killer, "defeat", definition.id, 1)
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			local profile = DataService.get(player)
			if profile then
				applyGear(player, profile)
			end
		end)

		task.spawn(function()
			if DataService.await(player, 10) then
				sendBoard(player, false)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)

	Players.PlayerRemoving:Connect(function(player)
		offered[player] = nil
	end)

	task.spawn(function()
		local market = Workspace:WaitForChild("Market", 60)
		local prompt = if market then (market :: Instance):FindFirstChild("OrderBoardPrompt", true) else nil
		if not (prompt and prompt:IsA("ProximityPrompt")) then
			warn("[WorkOrderService] no OrderBoardPrompt found; the booth cannot be talked to")
			return
		end
		prompt.Triggered:Connect(function(player)
			WorkOrderService.open(player)
		end)
	end)

	task.spawn(watchDepth)
end

return WorkOrderService

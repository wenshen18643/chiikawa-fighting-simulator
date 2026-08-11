--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Skills = require(Shared.Modules.Config.Skills)
local WorkOrders = require(Shared.Modules.Config.WorkOrders)
local CookingService = require(script.Parent.CookingService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local ForagingService = require(script.Parent.ForagingService)
local HarvestNodes = require(script.Parent.HarvestNodes)
local MobService = require(script.Parent.MobService)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)
local WorkOrderService = {}
local openRemote: RemoteEvent
local acceptRemote: RemoteEvent
local turnInRemote: RemoteEvent
local eventRemote: RemoteEvent
local offered: { [Player]: { string } } = {}
local reported: { [Player]: { [string]: number } } = {}
local tracked: { [string]: boolean } = {}

for _, skillId in Skills.ORDER do
	tracked[skillId] = true
end

local function stateOf(profile: any)
	local state = profile.workOrders
	state.completed = state.completed or {}
	state.active = state.active or {}

	state.rank = state.rank or 0
	state.trainTier = state.trainTier or {}

	local order = state.activeOrder
	if type(order) ~= "table" then
		order = {}
		state.activeOrder = order
	end

	for index = #order, 1, -1 do
		if state.active[order[index]] == nil then
			table.remove(order, index)
		end
	end
	for id in state.active do
		if not table.find(order, id) then
			table.insert(order, id)
		end
	end
	return state
end

local function dropActive(state: any, id: string)
	state.active[id] = nil
	local index = table.find(state.activeOrder, id)
	if index then
		table.remove(state.activeOrder, index)
	end
end

local function tierOf(state: any, skillId: string): number
	local tier = state.trainTier[skillId]
	return if type(tier) == "number" then tier else 0
end

local function hasCompleted(state: any, id: string): boolean
	for _, done in state.completed do
		if done == id then
			return true
		end
	end
	return false
end

local function chainDone(state: any): boolean
	for _, order in WorkOrders.CHAIN do
		if not hasCompleted(state, order.id) then
			return false
		end
	end
	return true
end

local function mainOrders(profile: any): { WorkOrders.OrderDefinition }
	local state = stateOf(profile)

	for _, order in WorkOrders.CHAIN do
		if not hasCompleted(state, order.id) then
			return { order }
		end
	end

	return WorkOrders.board(state.rank)
end

local function trainProgressOf(profile: any, skillId: string, tier: number): number
	return WorkOrders.trainProgress(SkillService.get(profile, skillId), tier)
end

local function progressOf(profile: any, order: WorkOrders.OrderDefinition): number
	local skillId, tier = WorkOrders.trainOf(order.id)
	if skillId and tier then
		return trainProgressOf(profile, skillId, tier)
	end
	return stateOf(profile).active[order.id] or 0
end

local function boardFor(profile: any): { WorkOrders.OrderDefinition }
	local state = stateOf(profile)
	for index = #state.activeOrder, 1, -1 do
		local id = state.activeOrder[index]
		if not WorkOrders.get(id) then
			state.active[id] = nil
			table.remove(state.activeOrder, index)
		end
	end

	local offers = mainOrders(profile)
	for _, skillId in Skills.ORDER do
		table.insert(offers, WorkOrders.trainOrder(skillId, tierOf(state, skillId)))
	end

	local board = {}
	for _, order in offers do
		if state.active[order.id] == nil or progressOf(profile, order) >= order.objective.count then
			table.insert(board, order)
		end
	end
	return board
end

local function payloadFor(profile: any)
	local state = stateOf(profile)
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
			progress = progressOf(profile, order),
			accepted = state.active[order.id] ~= nil,
		})
	end

	local active = {}
	local trackedEntries = {}
	for _, id in state.activeOrder do
		local order = WorkOrders.get(id)
		if order then
			table.insert(active, id)
			table.insert(trackedEntries, {
				id = order.id,
				name = order.name,
				summary = WorkOrders.describe(order),
				kind = order.objective.kind,
				progress = progressOf(profile, order),
				count = order.objective.count,
			})
		end
	end

	return ids, {
		orders = entries,
		active = active,
		tracked = trackedEntries,
		full = #active >= WorkOrders.MAX_ACTIVE,
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

local function report(player: Player, order: WorkOrders.OrderDefinition, progress: number)
	eventRemote:FireClient(player, "progress", {
		id = order.id,
		name = order.name,
		summary = WorkOrders.describe(order),
		kind = order.objective.kind,
		progress = progress,
		count = order.objective.count,
	})
end

local function refreshCollect(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local state = stateOf(profile)
	local held = profile.currencies.ingredients
	for _, id in state.activeOrder do
		local order = WorkOrders.get(id)
		if order and order.objective.kind == "collect" then
			local updated = math.min(order.objective.count, held[order.objective.target] or 0)
			if updated ~= (state.active[id] or 0) then
				state.active[id] = updated
				report(player, order, updated)
				if updated >= order.objective.count then
					NotifyService.send(player, `{order.name} is done. Take it back to Yoroi-san.`, "reward")
				end
			end
		end
	end
end

local function advance(player: Player, kind: string, target: string, amount: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local state = stateOf(profile)
	for _, id in state.activeOrder do
		local order = WorkOrders.get(id)
		local objective = order and order.objective
		if order and objective and objective.kind == kind and objective.target == target then
			local progress = state.active[id] or 0
			if progress < objective.count then
				local updated = math.min(objective.count, progress + amount)
				state.active[id] = updated
				report(player, order, updated)
				if updated >= objective.count then
					NotifyService.send(player, `{order.name} is done. Take it back to Yoroi-san.`, "reward")
				end
			end
		end
	end
end

local function advanceTrain(player: Player, profile: any, skillId: string)
	local state = stateOf(profile)
	local tier = tierOf(state, skillId)
	local order = WorkOrders.trainOrder(skillId, tier)
	if state.active[order.id] == nil then
		return
	end

	local progress = trainProgressOf(profile, skillId, tier)
	local seen = reported[player]
	if not seen then
		seen = {}
		reported[player] = seen
	end

	local last = seen[skillId]
	if last == progress then
		return
	end
	seen[skillId] = progress

	report(player, order, progress)

	if progress >= order.objective.count and (last or 0) < order.objective.count then
		NotifyService.send(player, `{order.name} is done. Take it back to Yoroi-san.`, "reward")
		sendBoard(player, false)
	end
end

local function grant(player: Player, profile: any, order: WorkOrders.OrderDefinition)
	local reward = order.reward

	if reward.yen then
		CurrencyService.award(profile, "yen", BigNumber.fromNumber(reward.yen))
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
	if state.active[id] ~= nil then
		return
	end
	if #state.activeOrder >= WorkOrders.MAX_ACTIVE then
		NotifyService.send(player, `Hands full. {WorkOrders.MAX_ACTIVE} jobs at a time.`, "locked")
		return
	end

	local drillSkill, drillTier = WorkOrders.trainOf(id)
	local generatedRank = WorkOrders.rankOf(id)
	if drillSkill and drillTier then
		if not tracked[drillSkill] or drillTier ~= tierOf(state, drillSkill) then
			return
		end
	elseif generatedRank then
		if generatedRank ~= state.rank then
			return
		end
	elseif hasCompleted(state, id) then
		return
	end

	state.active[id] = 0
	table.insert(state.activeOrder, id)
	NotifyService.send(player, `Took on "{order.name}".`, "info")
	sendBoard(player, false)

	if order.objective.kind == "collect" then
		refreshCollect(player)
	elseif drillSkill then
		advanceTrain(player, profile, drillSkill)
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
	local skillId, tier = WorkOrders.trainOf(id)
	if skillId and tier then
		if not tracked[skillId] or tier ~= tierOf(state, skillId) or state.active[id] == nil then
			return
		end

		local drill = WorkOrders.trainOrder(skillId, tier)
		if trainProgressOf(profile, skillId, tier) < drill.objective.count then
			return
		end

		dropActive(state, id)
		state.trainTier[skillId] = tier + 1
		local seen = reported[player]
		if seen then
			seen[skillId] = nil
		end

		grant(player, profile, drill)
		NotifyService.send(player, `"{drill.name}" complete.`, "reward")
		eventRemote:FireClient(player, "completed", { id = id, name = drill.name })
		sendBoard(player, false)
		return
	end

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

	dropActive(state, id)
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

	CookingService.onCooked(function(player, recipeId)
		advance(player, "cook", recipeId, 1)
	end)

	SkillService.onAward(advanceTrain)

	local function onPlayer(player: Player)
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
		reported[player] = nil
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
end

return WorkOrderService

--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)

local CurrencyService = require(script.Parent.CurrencyService)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)

export type Node = {
	id: number,
	model: Model,
	centre: Vector3,
	ingredient: Ingredients.IngredientDefinition,
	clicks: number,
	yield: number,
	progress: { [Player]: number },
	spent: boolean,
	retired: boolean,
}

local HarvestNodes = {}
HarvestNodes.__index = HarvestNodes

local forageEvent = Remotes.event("Forage", "Event")
local registries = {}
local harvestedCallbacks: { (Player, Ingredients.IngredientDefinition, number) -> () } = {}

function HarvestNodes.onHarvested(callback: (Player, Ingredients.IngredientDefinition, number) -> ())
	table.insert(harvestedCallbacks, callback)
end

function HarvestNodes.notifyStockChanged(player: Player, definition: Ingredients.IngredientDefinition, delta: number)
	for _, callback in harvestedCallbacks do
		task.spawn(callback, player, definition, delta)
	end
end

function HarvestNodes.new(config: { [string]: any })
	local registry = setmetatable({
		tag = config.tag,
		slot = config.slot,
		skill = config.skill,
		reach = config.reach or 24,
		verb = config.verb or "Gathered",
		nodes = {} :: { Node },
		nextId = 1,
		onSpent = config.onSpent,
		onProgress = config.onProgress,
		onReset = config.onReset,
	}, HarvestNodes)

	table.insert(registries, registry)
	return registry
end

function HarvestNodes:add(model: Model, ingredientId: string, centre: Vector3, baseClicks: number): Node?
	local definition = Ingredients.get(ingredientId)
	if not definition then
		warn(`[HarvestNodes] unknown ingredient "{ingredientId}"`)
		return nil
	end

	local node: Node = {
		id = self.nextId,
		model = model,
		centre = centre,
		ingredient = definition,
		clicks = baseClicks,
		yield = 1,
		progress = {},
		spent = false,
		retired = false,
	}
	self.nextId += 1

	model:SetAttribute("HarvestNodeId", node.id)
	CollectionService:AddTag(model, self.tag)
	table.insert(self.nodes, node)

	return node
end

function HarvestNodes:setIngredient(node: Node, ingredientId: string): boolean
	local definition = Ingredients.get(ingredientId)
	if not definition then
		return false
	end
	node.ingredient = definition
	return true
end

function HarvestNodes:clear()
	for _, node in self.nodes do
		node.retired = true
		if node.model.Parent then
			node.model:Destroy()
		end
	end
	table.clear(self.nodes)
end

function HarvestNodes:nearest(position: Vector3, maxDistance: number?): Node?
	local limit = maxDistance or self.reach
	local best: Node? = nil
	local bestDistance = limit * limit

	for _, node in self.nodes do
		if node.spent or node.retired or not node.model.Parent then
			continue
		end
		local delta = node.centre - position
		local flat = delta.X * delta.X + delta.Z * delta.Z
		if flat <= bestDistance then
			bestDistance = flat
			best = node
		end
	end

	return best
end

function HarvestNodes:clicksNeeded(profile: any, node: Node): number
	local base = Formulas.harvestClicks(profile, self.slot, node.clicks)
	local current = profile.skills[self.skill]
	local exponent = if BigNumber.isValid(current) then math.floor(math.max(BigNumber.log10(current), 0)) else 0
	local behind = math.max(0, node.ingredient.gateExponent - exponent)
	return base + behind * 2
end

function HarvestNodes:land(player: Player, profile: any, node: Node, bonusXp: number)
	local definition = node.ingredient
	local yield = Formulas.harvestYield(profile, self.slot) * node.yield

	node.spent = true
	node.progress = {}

	profile.currencies.ingredients[definition.id] = (profile.currencies.ingredients[definition.id] or 0) + yield

	local gain =
		BigNumber.mulNumber(Formulas.gainPerAction(profile, self.skill, nil), definition.xpMultiplier * yield + bonusXp)
	SkillService.award(player, profile, self.skill, gain)

	local yen = Formulas.yenForGain(self.skill, gain)
	if not BigNumber.isZero(yen) then
		CurrencyService.award(profile, "yen", yen)
	end

	forageEvent:FireClient(player, "success", definition.id, gain, node.centre)

	if definition.rarity == "super" or definition.rarity == "legendary" then
		local suffix = if yield > 1 then ` x{yield}` else ""
		NotifyService.send(player, `{self.verb} {definition.name}{suffix}!`, "reward")
	end

	for _, callback in harvestedCallbacks do
		task.spawn(callback, player, definition, yield)
	end

	if self.onSpent then
		self.onSpent(node, player)
	end

	task.delay(definition.regrowSeconds, function()
		if node.retired or not node.model.Parent then
			return
		end
		node.spent = false
		if self.onReset then
			self.onReset(node)
		end
	end)
end

function HarvestNodes:click(player: Player, profile: any, node: Node, landXp: number): boolean
	if node.spent or node.retired then
		return false
	end

	local current = (node.progress[player] or 0) + 1
	node.progress[player] = current

	local needed = self:clicksNeeded(profile, node)
	if current >= needed then
		self:land(player, profile, node, landXp)
		return true
	end

	forageEvent:FireClient(player, "progress", node.ingredient.id, current, needed, node.centre)

	if self.onProgress then
		self.onProgress(node, player, current, needed)
	end

	return true
end

Players.PlayerRemoving:Connect(function(player)
	for _, registry in registries do
		for _, node in registry.nodes do
			node.progress[player] = nil
		end
	end
end)

return HarvestNodes

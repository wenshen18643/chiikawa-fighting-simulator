--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Ingredients = require(script.Parent.Ingredients)
local Mobs = require(script.Parent.Mobs)
local Recipes = require(script.Parent.Recipes)
local Skills = require(script.Parent.Skills)

export type Objective = {
	kind: "collect" | "defeat" | "train" | "cook",
	target: string,
	count: number,
	tier: number?,
}

export type Reward = {
	yen: number?,
	ingredients: { { id: string, count: number } }?,
	unlock: { kind: string, id: string, label: string }?,
}

export type OrderDefinition = {
	id: string,
	name: string,
	blurb: string,
	objective: Objective,
	reward: Reward,
	grade: string?,
}

local WorkOrders = {}

WorkOrders.CHAIN = {
	{
		id = "pantry_start",
		name = "Something For The Pot",
		blurb = "The paddy out past the fence is nobody's. Pull eight rice and bring them here.",
		objective = { kind = "collect", target = "wildRice", count = 8 },
		reward = { yen = 250 },
	},
	{
		id = "first_supper",
		name = "First Supper",
		blurb = "Rice, two of them, in the pot. Make one onigiri. Everyone starts there.",
		objective = { kind = "cook", target = "onigiri", count = 1 },
		reward = { yen = 300 },
	},
	{
		id = "mushroom_run",
		name = "Mushroom Run",
		blurb = "The Hollow is thick with them this week. Ten browns, off the ground, in a basket.",
		objective = { kind = "collect", target = "brownMushroom", count = 10 },
		reward = { yen = 300 },
	},
	{
		id = "frog_cull",
		name = "Frog Cull",
		blurb = "The frogs puff at anybody who walks past the Hollow. Thin them out.",
		objective = { kind = "defeat", target = "mushroom_frog", count = 8 },
		reward = { yen = 600 },
	},
	{
		id = "field_lunch",
		name = "Field Lunch",
		blurb = "Two dango. Carrot and rice. The ones working the fields eat before they start.",
		objective = { kind = "cook", target = "dango", count = 2 },
		reward = { yen = 700 },
	},
	{
		id = "duck_drive",
		name = "Duck Drive",
		blurb = "Six ducks have decided the paddy belongs to them. Correct them.",
		objective = { kind = "defeat", target = "duck", count = 6 },
		reward = {
			yen = 1000,
			ingredients = { { id = "whiteMushroom", count = 6 } },
		},
	},
	{
		id = "glowcap_haul",
		name = "Glowcap Haul",
		blurb = "The cook wants the pale ones out of the thicket. Fifteen. Do not eat them on the way.",
		objective = { kind = "collect", target = "whiteMushroom", count = 15 },
		reward = {
			yen = 1350,
			unlock = { kind = "recipe", id = "glowcapStew", label = "Glowcap Stew" },
		},
	},
	{
		id = "stew_service",
		name = "Stew Service",
		blurb = "You have the recipe now, so use it. Two pots of glowcap stew for the night shift.",
		objective = { kind = "cook", target = "glowcapStew", count = 2 },
		reward = { yen = 2000 },
	},
	{
		id = "pack_leader",
		name = "Pack Leader",
		blurb = "The wolves came down off the ridge and have not gone back up. Twelve of them.",
		objective = { kind = "defeat", target = "wolf", count = 12 },
		reward = {
			yen = 5000,
			ingredients = { { id = "moonlightCap", count = 3 } },
			unlock = { kind = "companion", id = "sporeling", label = "Sporeling" },
		},
	},
	{
		id = "first_seam",
		name = "First Seam",
		blurb = "You came up in my quarry, so you can work it. Chalk. Twenty lumps. Start at the top step.",
		objective = { kind = "collect", target = "chalkStone", count = 20 },
		reward = { yen = 1600 },
	},
	{
		id = "shore_up",
		name = "Shore It Up",
		blurb = "The east face is soft. I need iron for the braces before it comes down on somebody.",
		objective = { kind = "collect", target = "ironOre", count = 15 },
		reward = {
			yen = 2250,
			unlock = { kind = "tool", id = "pickaxe2", label = "Steel Pick" },
		},
	},
	{
		id = "miners_lunch",
		name = "Miner's Lunch",
		blurb = "Three bowls of ramen for the east face crew. Sausage, rice, potato. They eat at noon.",
		objective = { kind = "cook", target = "ramen", count = 3 },
		reward = { yen = 3200 },
	},
	{
		id = "second_step",
		name = "The Second Step",
		blurb = "Copper sits under the chalk, one terrace down. Mind the drop on your way back up.",
		objective = { kind = "collect", target = "copperOre", count = 12 },
		reward = {
			yen = 4000,
			unlock = { kind = "tool", id = "pickaxe3", label = "Quarryman's Pick" },
		},
	},
	{
		id = "moonstone",
		name = "Moonstone",
		blurb = "Bottom step, where the pit meets her old floor. It only shines down there. Four will do.",
		objective = { kind = "collect", target = "moonOre", count = 4 },
		reward = {
			yen = 15000,
			unlock = { kind = "tool", id = "pickaxe4", label = "Moonstone Pick" },
		},
	},
} :: { OrderDefinition }

WorkOrders.BY_ID = {} :: { [string]: OrderDefinition }
WorkOrders.CHAIN_INDEX = {} :: { [string]: number }

for index, order in WorkOrders.CHAIN do
	WorkOrders.BY_ID[order.id] = order
	WorkOrders.CHAIN_INDEX[order.id] = index
end

export type Grade = {
	label: string,
	span: number,
	collect: { string },
	defeat: { string },
	cook: { string },
	collectCount: { number },
	defeatCount: { number },
	cookCount: { number },
}

WorkOrders.GRADES = {
	{
		label = "5級",
		span = 6,
		collect = { "carrot", "potato", "rice" },
		defeat = { "mushroom_frog", "duck" },
		cook = { "onigiri", "dango" },
		collectCount = { 8, 20 },
		defeatCount = { 4, 10 },
		cookCount = { 1, 3 },
	},
	{
		label = "4級",
		span = 8,
		collect = { "brownMushroom", "carrot", "rice" },
		defeat = { "duck", "wolf" },
		cook = { "dango", "yogurtBerry", "forestTea" },
		collectCount = { 12, 28 },
		defeatCount = { 5, 12 },
		cookCount = { 2, 4 },
	},
	{
		label = "3級",
		span = 10,
		collect = { "brownMushroom", "whiteMushroom", "potato" },
		defeat = { "wolf", "mushroom_frog" },
		cook = { "forestTea", "pancakes", "meatSkewer" },
		collectCount = { 15, 34 },
		defeatCount = { 6, 15 },
		cookCount = { 2, 5 },
	},
	{
		label = "2級",
		span = 12,
		collect = { "whiteMushroom", "pinkSausage", "brownMushroom" },
		defeat = { "wolf", "duck" },
		cook = { "ramen", "yogurtVanilla", "duckGreens" },
		collectCount = { 18, 40 },
		defeatCount = { 8, 18 },
		cookCount = { 3, 6 },
	},
	{
		label = "1級",
		span = 14,
		collect = { "pinkSausage", "whiteBerry", "whiteMushroom" },
		defeat = { "wolf", "mushroom_frog" },
		cook = { "huntersStew", "scholarsJerky", "ramen" },
		collectCount = { 20, 46 },
		defeatCount = { 10, 22 },
		cookCount = { 3, 7 },
	},

	{
		label = "特級",
		span = 20,
		collect = { "goldSausage", "moonlightCap", "whiteBerry", "pinkSausage" },
		defeat = { "wolf", "duck", "mushroom_frog" },
		cook = { "championPlatter", "huntersStew", "duckGreens" },
		collectCount = { 25, 60 },
		defeatCount = { 12, 28 },
		cookCount = { 4, 8 },
	},
} :: { Grade }

WorkOrders.BOARD_SIZE = 3
WorkOrders.MAX_ACTIVE = 1

local YEN_BASE = 450
local GROWTH = 1.11
local TRAIN_PREFIX = "tr"
local TRAIN_BASE_EXPONENT = 2
local TRAIN_STEPS = 100
local TRAIN_YEN_BASE = 250
local TRAIN_YEN_GROWTH = 4
local TRAIN_YEN_CAP = 1e15

local VERBS = {
	collect = { weight = 1 },
	defeat = { weight = 1.2 },
	cook = { weight = 1.4 },
}

local BLURBS = {
	collect = {
		"The kitchen is short again. {count} of the {name}, and do not eat them on the way.",
		"{count} {name}. Count them yourself before you put them on my counter.",
		"Somebody ordered {count} {name} and then somebody else ate them. Again.",
		"{name}, {count} of. It is not interesting work. It is work.",
	},
	defeat = {
		"{count} of the {name}. Nobody is asking you to enjoy it.",
		"The {name} are back where they were told not to be. {count} of them.",
		"{count} {name}. Sasumata first, questions after.",
		"Thin the {name} out. {count} will do for today.",
	},
	train = {
		"Train {name} by {count}. Nobody gets good sitting on my counter.",
		"Put {count} more into {name}. Do not come back before the work is done.",
		"{name}, up by {count}. How you get there is your business.",
		"You are soft. Training {name} by {count} will fix some of that.",
	},
	cook = {
		"{count} of the {name}. The pot is over there and it is not going to stir itself.",
		"Kitchen wants {count} {name} before the shift ends. Do not burn them.",
		"{count} {name}. Somebody has to feed this town and today it is you.",
		"{name}, {count} plates. Cook them properly, people are eating this.",
	},
}

local ID_PREFIX = "wo"
local candidateCache: { [number]: { Objective } } = {}

local function candidatesFor(index: number, grade: Grade): { Objective }
	local cached = candidateCache[index]
	if cached then
		return cached
	end

	local list: { Objective } = {}
	for _, target in grade.collect do
		table.insert(list, { kind = "collect", target = target, count = 0 })
	end
	for _, target in grade.defeat do
		table.insert(list, { kind = "defeat", target = target, count = 0 })
	end
	for _, target in grade.cook do
		table.insert(list, { kind = "cook", target = target, count = 0 })
	end

	candidateCache[index] = list
	return list
end

local function gradeFor(rank: number): (number, Grade, number)
	local remaining = rank
	for index, grade in WorkOrders.GRADES do
		if remaining < grade.span or index == #WorkOrders.GRADES then
			return index, grade, math.clamp(remaining / grade.span, 0, 1)
		end
		remaining -= grade.span
	end
	local last = #WorkOrders.GRADES
	return last, WorkOrders.GRADES[last], 1
end

local function band(range: { number }, t: number): number
	return math.floor(range[1] + (range[2] - range[1]) * t + 0.5)
end

local function shuffled(rank: number, pool: { Objective }): { Objective }
	local rng = Random.new(rank * 7919 + 104729)
	local order = table.clone(pool)
	for index = #order, 2, -1 do
		local swap = rng:NextInteger(1, index)
		order[index], order[swap] = order[swap], order[index]
	end
	return order
end

function WorkOrders.targetName(objective: Objective): string
	if objective.kind == "collect" then
		local definition = Ingredients.get(objective.target)
		return if definition then definition.name else objective.target
	elseif objective.kind == "defeat" then
		local definition = Mobs.get(objective.target)
		return if definition then definition.name else objective.target
	elseif objective.kind == "train" then
		local definition = Skills.get(objective.target)
		return if definition then definition.name else objective.target
	end
	local definition = Recipes.get(objective.target)
	return if definition then definition.name else objective.target
end

function WorkOrders.formatCount(count: number): string
	if count < 10000 then
		return tostring(math.floor(count))
	end

	local text = BigNumber.toString(BigNumber.fromNumber(count))
	local mantissa, suffix = string.match(text, "^([%d%.]+)(%a*)$")
	if type(mantissa) ~= "string" or type(suffix) ~= "string" or not string.find(mantissa, "%.") then
		return text
	end

	local trimmed = string.gsub(string.gsub(mantissa, "0+$", ""), "%.$", "")
	return trimmed .. suffix
end

WorkOrders.TRAIN_STEPS = TRAIN_STEPS

function WorkOrders.trainTarget(tier: number): BigNumber.BigNum
	return BigNumber.pow10(math.max(tier, 0) + TRAIN_BASE_EXPONENT)
end

function WorkOrders.trainProgress(total: BigNumber.BigNum?, tier: number): number
	if not BigNumber.isValid(total) or BigNumber.isZero(total :: BigNumber.BigNum) then
		return 0
	end

	local value = total :: BigNumber.BigNum
	local target = WorkOrders.trainTarget(tier)
	if BigNumber.gte(value, target) then
		return TRAIN_STEPS
	end

	local decades = BigNumber.log10(value) - BigNumber.log10(target)
	return math.clamp(math.floor(10 ^ decades * TRAIN_STEPS), 0, TRAIN_STEPS)
end

function WorkOrders.trainOrder(skillId: string, tier: number): OrderDefinition
	local definition = Skills.get(skillId)
	local name = if definition then definition.name else skillId
	local target = BigNumber.toString(WorkOrders.trainTarget(tier))
	local lines = BLURBS.train

	return {
		id = `{TRAIN_PREFIX}:{skillId}:{tier}`,
		name = `{name} Drill`,
		blurb = string.gsub(string.gsub(lines[tier % #lines + 1], "{count}", target), "{name}", name),
		objective = { kind = "train", target = skillId, count = TRAIN_STEPS, tier = tier },
		reward = { yen = math.min(TRAIN_YEN_BASE * TRAIN_YEN_GROWTH ^ tier, TRAIN_YEN_CAP) },
	}
end

function WorkOrders.trainOf(id: string): (string?, number?)
	local skillId, tier = string.match(id, `^{TRAIN_PREFIX}:(%a+):(%d+)$`)
	if not skillId or not tier then
		return nil, nil
	end
	return skillId, tonumber(tier)
end

function WorkOrders.generate(rank: number, slot: number): OrderDefinition?
	local index, grade, t = gradeFor(rank)
	local pool = shuffled(rank, candidatesFor(index, grade))
	local pick = pool[slot]
	if not pick then
		return nil
	end

	local objective: Objective = {
		kind = pick.kind,
		target = pick.target,
		count = if pick.kind == "collect"
			then band(grade.collectCount, t)
			elseif pick.kind == "defeat" then band(grade.defeatCount, t)
			else band(grade.cookCount, t),
	}

	local verb = VERBS[pick.kind]
	local scale = GROWTH ^ rank * verb.weight
	local name = WorkOrders.targetName(objective)
	local rng = Random.new(rank * 131 + slot)
	local lines = BLURBS[pick.kind]

	local reward: Reward = {
		yen = math.max(100, math.floor(YEN_BASE * scale / 100) * 100),
	}

	if rng:NextNumber() < 0.3 then
		local bonus = grade.collect[rng:NextInteger(1, #grade.collect)]
		reward.ingredients = { { id = bonus, count = rng:NextInteger(2, 5) } }
	end

	return {
		id = `{ID_PREFIX}:{rank}:{slot}`,
		name = if pick.kind == "collect"
			then `{name} Run`
			elseif pick.kind == "defeat" then `{name} Cull`
			else `{name} Service`,
		blurb = string.gsub(
			string.gsub(lines[rng:NextInteger(1, #lines)], "{count}", WorkOrders.formatCount(objective.count)),
			"{name}",
			name
		),
		objective = objective,
		reward = reward,
		grade = grade.label,
	}
end

function WorkOrders.board(rank: number): { OrderDefinition }
	local orders = {}
	for slot = 1, WorkOrders.BOARD_SIZE do
		local order = WorkOrders.generate(rank, slot)
		if order then
			table.insert(orders, order)
		end
	end
	return orders
end

function WorkOrders.rankOf(id: string): number?
	local rank = string.match(id, `^{ID_PREFIX}:(%d+):%d+$`)
	return if rank then tonumber(rank) else nil
end

function WorkOrders.get(id: string): OrderDefinition?
	local static = WorkOrders.BY_ID[id]
	if static then
		return static
	end

	local skillId, tier = WorkOrders.trainOf(id)
	if skillId and tier then
		return WorkOrders.trainOrder(skillId, tier)
	end

	local rank, slot = string.match(id, `^{ID_PREFIX}:(%d+):(%d+)$`)
	if not rank or not slot then
		return nil
	end
	return WorkOrders.generate(tonumber(rank) :: number, tonumber(slot) :: number)
end

function WorkOrders.describe(order: OrderDefinition): string
	local objective = order.objective
	local name = WorkOrders.targetName(objective)
	if objective.kind == "collect" then
		return `Collect {objective.count} {name}`
	elseif objective.kind == "cook" then
		return `Cook {objective.count} {name}`
	elseif objective.kind == "train" then
		return `Train {name} by {BigNumber.toString(WorkOrders.trainTarget(objective.tier or 0))}`
	end
	return `Defeat {objective.count} {name}`
end

return WorkOrders

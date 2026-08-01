--!strict

local Cave = require(script.Parent.Cave)
local Ingredients = require(script.Parent.Ingredients)
local Mobs = require(script.Parent.Mobs)

export type Objective = {
	kind: "collect" | "defeat" | "reach",
	target: string,
	count: number,
}

export type Reward = {
	yen: number?,
	skill: string?,
	skillAmount: number?,
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
		id = "mushroom_run",
		name = "Mushroom Run",
		blurb = "There is a hole in the Mushroom Hollow. Things grow down there. Bring some back.",
		objective = { kind = "collect", target = "brownMushroom", count = 10 },
		reward = { yen = 1200, skill = "kusatori", skillAmount = 260 },
	},
	{
		id = "spore_cull",
		name = "Spore Cull",
		blurb = "The little ones puff at anybody who walks past. Thin them out.",
		objective = { kind = "defeat", target = "cave_sporeling", count = 8 },
		reward = { yen = 2400, skill = "tobatsu", skillAmount = 520 },
	},

	{
		id = "deeper",
		name = "Deeper",
		blurb = "There is a second floor under the first. Go and stand on it, then come back and tell me.",
		objective = { kind = "reach", target = "2", count = 1 },
		reward = {
			yen = 3000,
			unlock = { kind = "tool", id = "lantern", label = "Lantern" },
		},
	},
	{
		id = "wisp_catch",
		name = "Chasing Lights",
		blurb = "The lights down there run from you. Catch two. Do not ask me what they are.",
		objective = { kind = "defeat", target = "cave_wisp", count = 2 },
		reward = {
			yen = 4200,
			skill = "tobatsu",
			skillAmount = 900,
			ingredients = { { id = "whiteMushroom", count = 6 } },
		},
	},
	{
		id = "glowcap_haul",
		name = "Glowcap Haul",
		blurb = "The cook wants the ones that shine. Fifteen. Do not eat them on the way up.",
		objective = { kind = "collect", target = "whiteMushroom", count = 15 },
		reward = {
			yen = 5400,
			unlock = { kind = "recipe", id = "glowcapStew", label = "Glowcap Stew" },
		},
	},
	{
		id = "cap_mother",
		name = "The Cap Mother",
		blurb = "Something is holding the bottom floor. It has been there longer than the town has.",
		objective = { kind = "defeat", target = "cave_mycelia", count = 1 },
		reward = {
			yen = 20000,
			skill = "tobatsu",
			skillAmount = 6000,
			ingredients = { { id = "moonlightCap", count = 3 } },
			unlock = { kind = "companion", id = "sporeling", label = "Sporeling" },
		},
	},
	{
		id = "first_seam",
		name = "First Seam",
		blurb = "You came up in my quarry, so you can work it. Chalk. Twenty lumps. Start at the top step.",
		objective = { kind = "collect", target = "chalkStone", count = 20 },
		reward = { yen = 6500, skill = "tobatsu", skillAmount = 1200 },
	},
	{
		id = "shore_up",
		name = "Shore It Up",
		blurb = "The east face is soft. I need iron for the braces before it comes down on somebody.",
		objective = { kind = "collect", target = "ironOre", count = 15 },
		reward = {
			yen = 9000,
			unlock = { kind = "tool", id = "pickaxe2", label = "Steel Pick" },
		},
	},
	{
		id = "still_water",
		name = "Still Water",
		blurb = "Nobody eats rock. There is a lake east of here. Bring the cook something out of it.",
		objective = { kind = "collect", target = "crucian", count = 12 },
		reward = {
			yen = 11000,
			skill = "resilience",
			skillAmount = 2600,
			unlock = { kind = "tool", id = "rod2", label = "Braided Rod" },
		},
	},
	{
		id = "second_step",
		name = "The Second Step",
		blurb = "Copper sits under the chalk, one terrace down. Mind the drop on your way back up.",
		objective = { kind = "collect", target = "copperOre", count = 12 },
		reward = {
			yen = 16000,
			skill = "tobatsu",
			skillAmount = 5200,
			unlock = { kind = "tool", id = "pickaxe3", label = "Quarryman's Pick" },
		},
	},
	{
		id = "lakekeeper",
		name = "Lakekeeper",
		blurb = "The big orange ones only rise at the end of the pier, and only for somebody patient.",
		objective = { kind = "collect", target = "koi", count = 3 },
		reward = {
			yen = 24000,
			skill = "resilience",
			skillAmount = 9000,
			unlock = { kind = "tool", id = "rod3", label = "Lakekeeper's Rod" },
		},
	},
	{
		id = "moonstone",
		name = "Moonstone",
		blurb = "Bottom step, where the pit meets her old floor. It only shines down there. Four will do.",
		objective = { kind = "collect", target = "moonOre", count = 4 },
		reward = {
			yen = 60000,
			skill = "tobatsu",
			skillAmount = 26000,
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
	reach: { string },
	collectCount: { number },
	defeatCount: { number },
}

WorkOrders.GRADES = {
	{
		label = "5級",
		span = 6,
		collect = { "carrot", "potato", "rice" },
		defeat = { "mushroom_frog", "duck" },
		reach = {},
		collectCount = { 8, 20 },
		defeatCount = { 4, 10 },
	},
	{
		label = "4級",
		span = 8,
		collect = { "blueBerry", "purpleBerry", "rice" },
		defeat = { "duck", "wolf" },
		reach = {},
		collectCount = { 12, 28 },
		defeatCount = { 5, 12 },
	},
	{
		label = "3級",
		span = 10,
		collect = { "brownMushroom", "blackBerry", "purpleBerry" },
		defeat = { "wolf", "cave_sporeling" },
		reach = { "1" },
		collectCount = { 15, 34 },
		defeatCount = { 6, 15 },
	},
	{
		label = "2級",
		span = 12,
		collect = { "whiteMushroom", "blackBerry", "brownMushroom" },
		defeat = { "cave_sporeling", "cave_pebblejaw" },
		reach = { "2" },
		collectCount = { 18, 40 },
		defeatCount = { 8, 18 },
	},
	{
		label = "1級",
		span = 14,
		collect = { "pinkSausage", "whiteBerry", "whiteMushroom" },
		defeat = { "cave_pebblejaw", "cave_wisp" },
		reach = { "2", "3" },
		collectCount = { 20, 46 },
		defeatCount = { 10, 22 },
	},

	{
		label = "特級",
		span = 20,
		collect = { "goldSausage", "moonlightCap", "whiteBerry", "pinkSausage" },
		defeat = { "cave_wisp", "cave_pebblejaw", "wolf" },
		reach = { "3" },
		collectCount = { 25, 60 },
		defeatCount = { 12, 28 },
	},
} :: { Grade }

WorkOrders.BOARD_SIZE = 3

local YEN_BASE = 1800
local SKILL_BASE = 420
local GROWTH = 1.11

local VERBS = {
	collect = { weight = 1, skill = "kusatori" },
	defeat = { weight = 1.2, skill = "tobatsu" },
	reach = { weight = 0.7, skill = "resilience" },
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
	reach = {
		"Get down to {name} and stand there a moment. Then come back.",
		"Somebody has to check {name} is still where we left it. Today it is you.",
		"{name}. Walk it, do not run it. Come back and tell me what you saw.",
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
	for _, target in grade.reach do
		table.insert(list, { kind = "reach", target = target, count = 1 })
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
	end
	local level = Cave.get(tonumber(objective.target) or 0)
	return if level then level.name else `floor {objective.target}`
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
			else 1,
	}

	local verb = VERBS[pick.kind]
	local scale = GROWTH ^ rank * verb.weight
	local name = WorkOrders.targetName(objective)
	local rng = Random.new(rank * 131 + slot)
	local lines = BLURBS[pick.kind]

	local reward: Reward = {
		yen = math.max(100, math.floor(YEN_BASE * scale / 100) * 100),
		skill = verb.skill,
		skillAmount = math.max(10, math.floor(SKILL_BASE * scale / 10) * 10),
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
			else `Down to {name}`,
		blurb = string.gsub(
			string.gsub(lines[rng:NextInteger(1, #lines)], "{count}", tostring(objective.count)),
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
	local rank, slot = string.match(id, `^{ID_PREFIX}:(%d+):(%d+)$`)
	if not rank or not slot then
		return nil
	end
	return WorkOrders.generate(tonumber(rank) :: number, tonumber(slot) :: number)
end

function WorkOrders.describe(order: OrderDefinition): string
	local objective = order.objective
	local name = WorkOrders.targetName(objective)
	if objective.kind == "reach" then
		return `Reach {name}`
	elseif objective.kind == "collect" then
		return `Collect {objective.count} {name}`
	end
	return `Defeat {objective.count} {name}`
end

return WorkOrders

--!strict

--[[
	Yoroi-san's work orders.

	The profile has carried a `workOrders` slot since the schema was written and
	nothing has ever filled it, which is exactly the right shape for this: a
	list of what you have done and one thing you are doing.

	Two kinds live here. The CHAIN is a fixed sequence that teaches the cave --
	it hands out the lantern before the floor that needs one, and points at the
	boss only once you have met everything that guards her. Everything after it
	is GENERATED, so the booth never runs out and never repeats a rank.

	An order asks for one thing. Three verbs cover the whole game: bring me
	some, kill some, get somewhere. Anything a player cannot state in one line
	is a quest log, and a quest log is a different game.
]]

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

--[[
	One at a time, in this order. The player never chooses from the chain: the
	board offers the next rung and nothing else, so "what now" is never a
	question the cave asks.
]]
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
	--[[
		The lantern arrives one rung BEFORE the floor that needs it. A key
		handed out at the door it opens is a formality; handed out early it is
		a reason to go and find the door.
	]]
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
} :: { OrderDefinition }

WorkOrders.BY_ID = {} :: { [string]: OrderDefinition }
WorkOrders.CHAIN_INDEX = {} :: { [string]: number }

for index, order in WorkOrders.CHAIN do
	WorkOrders.BY_ID[order.id] = order
	WorkOrders.CHAIN_INDEX[order.id] = index
end

--------------------------------------------------------------------------------
-- The grades
--------------------------------------------------------------------------------

--[[
	Everything after the chain, forever.

	Yoroi-san grades work the way the exam hall grades people: you start on 5級
	pulling carrots out of the roadside and you end on 特級 in the dark under
	the town. A grade is a POOL of targets and a BAND of counts -- nothing else
	-- so making the ladder longer is adding a row here, not writing orders.

	Two rules keep the pools honest, and both are facts about other files:

	  * only things that come BACK are targets. Mycelia, the sausage guardians
	    and the BIG trees all carry `respawn = false` (Config/Mobs), so an
	    endless order aimed at one is an order that can be handed out twice and
	    completed once.
	  * a target is only in a grade the player can already stand in. The cave
	    floors arrive one grade at a time, in the order the chain opened them.
]]
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
	--[[
		The last grade never ends. Its counts saturate at the top of the band
		one span past its start, so the grind stops growing while the pay does
		not -- an order that wants four hundred mushrooms is not harder, it is
		just longer, and nobody has ever enjoyed one.
	]]
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

--[[
	The pay curve runs on the ABSOLUTE rank rather than on the position inside a
	grade, so promotion is a raise instead of a pay cut: the first 3級 order is
	worth more than the last 4級 one.
]]
local YEN_BASE = 1800
local SKILL_BASE = 420
local GROWTH = 1.11

-- What each verb is worth against the others, and which skill it trains.
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

--------------------------------------------------------------------------------
-- Generation
--------------------------------------------------------------------------------

--[[
	A generated order is stored NOWHERE.

	Its id spells out where it came from -- "wo:12:2" is slot 2 of rank 12 --
	and the same seed rebuilds it identically on any server at any time, so the
	profile carries one number (how many have been handed in) instead of a list
	of ids that grows for as long as the player keeps playing.
]]
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

-- Which grade a rank sits in, and how far through it (0 at the bottom rung, 1
-- at the top). The last grade absorbs everything past the ladder.
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

--[[
	The board's three slots are a seeded shuffle of the grade's whole pool
	rather than three independent picks, which is what stops a board reading
	"20 carrots / 24 carrots / 18 carrots".
]]
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

	-- A sack of something on top, now and then. A reward that always looks the
	-- same is a reward the player stops reading.
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

-- What the booth offers at a given rank. Fewer than BOARD_SIZE only if a grade
-- is authored with a pool smaller than the board.
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

-- The rank an id was generated at, or nil if it names a chain order. The id
-- format lives in this file only: everything else asks.
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

--[[
	Human-readable "what does this want", built here rather than on the client
	so the board, the HUD tracker and any toast all say the same words.
]]
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

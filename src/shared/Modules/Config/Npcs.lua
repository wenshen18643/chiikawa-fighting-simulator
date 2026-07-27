--[[
	The cast. See docs/GAME.md §9.4 and §0.

	NAMES ARE PLACEHOLDERS. Per §0 the IP path is still undecided, so these are
	original descriptive names in the right tonal register rather than the canon
	cast. When §0 is answered, this is the ONLY file that needs renaming —
	nothing else in the codebase hardcodes a character name.

	`build` describes the mascot silhouette procedurally (NpcService assembles
	it from parts) so the game has real characters standing in it before any
	modelling work exists. Swapping in authored models later means adding a
	`modelId` field and nothing else changes.

	`offset` is from the area origin, and is now measured in HUNDREDS of studs
	rather than tens: the areas grew from 620 studs across to between 2,600 and
	6,000, so the old offsets all sat inside the central plaza — which in Town is
	where the safe-zone cottage now stands. Everyone is placed either just
	outside the plaza, where you meet them on the way to a district, or beside
	the landmark they belong to.
]]

export type NpcBuild = {
	bodyColor: Color3,
	bellyColor: Color3,
	earStyle: "round" | "tall" | "pointed" | "none",
	earColor: Color3?,
	height: number,
	blush: boolean,
}

export type NpcDefinition = {
	id: string,
	name: string,
	role: string,
	regionId: number,
	offset: Vector3, -- from the region origin
	build: NpcBuild,
	lines: { string },
}

local Npcs = {}

local WHITE = Color3.fromRGB(250, 248, 244)
local CREAM = Color3.fromRGB(244, 236, 222)
local BLUE = Color3.fromRGB(142, 198, 226)
local PINK = Color3.fromRGB(244, 196, 206)
local YELLOW = Color3.fromRGB(246, 216, 140)
local BROWN = Color3.fromRGB(196, 156, 116)
local ARMOUR = Color3.fromRGB(178, 186, 198)

Npcs.DEFINITIONS = {
	-- Region 1: the starting town.
	{
		id = "little_one",
		name = "Little One",
		role = "your friend",
		regionId = 1,
		offset = Vector3.new(-78, 0, 186),
		build = { bodyColor = WHITE, bellyColor = CREAM, earStyle = "round", height = 3.2, blush = true },
		lines = {
			"Weeds! There are so many weeds.",
			"I got Grade 5. I studied really hard.",
			"If you get tired, you can just sit down.",
		},
	},
	{
		id = "halfsie",
		name = "Halfsie",
		role = "cheerful",
		regionId = 1,
		offset = Vector3.new(78, 0, 186),
		build = { bodyColor = WHITE, bellyColor = BLUE, earStyle = "tall", earColor = BLUE, height = 3.6, blush = true },
		lines = {
			"The pay is per minute, so standing around still counts!",
			"Higher grade means better wages. That's the whole trick.",
			"Wanna go to the Woods later? I found a cave.",
		},
	},
	{
		id = "labour_official",
		name = "Labour Official",
		role = "assigns work and pay",
		regionId = 1,
		offset = Vector3.new(0, 0, -196),
		build = { bodyColor = ARMOUR, bellyColor = ARMOUR, earStyle = "none", height = 5.2, blush = false },
		lines = {
			"Work is posted daily. Take what you can carry.",
			"Wages are paid per minute. No overtime is expected of you.",
			"The certification exam hall opens on the quarter hour.",
		},
	},
	{
		id = "ramen_cook",
		name = "Ramen Cook",
		role = "runs the shop",
		regionId = 1,
		offset = Vector3.new(-592, 0, 606),
		build = { bodyColor = ARMOUR, bellyColor = YELLOW, earStyle = "none", height = 5.0, blush = false },
		lines = {
			"Hot bowl? It'll do more for you than a cold one.",
			"Eat properly. The weeds will still be there.",
		},
	},

	-- Region 2: the woods.
	{
		id = "hoppy",
		name = "Hoppy",
		role = "loud",
		regionId = 2,
		offset = Vector3.new(-104, 0, 232),
		build = {
			bodyColor = CREAM,
			bellyColor = WHITE,
			earStyle = "tall",
			earColor = CREAM,
			height = 3.4,
			blush = false,
		},
		lines = { "YAH!", "URA!", "...ha?" },
	},
	{
		id = "forager",
		name = "Forager",
		role = "knows the woods",
		regionId = 2,
		offset = Vector3.new(-720, 0, 610),
		build = { bodyColor = BROWN, bellyColor = CREAM, earStyle = "round", height = 3.4, blush = true },
		lines = {
			"Mushrooms here. Don't eat the ones that look back at you.",
			"Critters are gentle. Just shoo them along.",
		},
	},

	-- Region 3: riverside market.
	{
		id = "shopkeep",
		name = "Shopkeep",
		role = "sells things",
		regionId = 3,
		offset = Vector3.new(0, 0, 906),
		build = { bodyColor = PINK, bellyColor = WHITE, earStyle = "round", height = 3.6, blush = true },
		lines = {
			"Charm gets you a discount. I don't make the rules.",
			"Festival's soon. There'll be stalls.",
		},
	},
	{
		id = "pochette_official",
		name = "Pochette Official",
		role = "makes things by hand",
		regionId = 3,
		offset = Vector3.new(-150, 0, 246),
		build = { bodyColor = ARMOUR, bellyColor = PINK, earStyle = "none", height = 5.0, blush = false },
		lines = {
			"Everything here is handmade. Including the mistakes.",
			"Bring materials and I'll see what can be done.",
		},
	},

	-- Region 4: the mountain.
	{
		id = "bath_keeper",
		name = "Bath Keeper",
		role = "minds the hot springs",
		regionId = 4,
		offset = Vector3.new(-1100, 0, 1120),
		build = { bodyColor = WHITE, bellyColor = PINK, earStyle = "pointed", height = 3.8, blush = true },
		lines = {
			"Cold outside, warm inside. That's the whole mountain.",
			"Grit is just staying put a bit longer than is comfortable.",
		},
	},

	-- Region 5: the island.
	{
		id = "shore_cook",
		name = "Shore Cook",
		role = "seaside kitchen",
		regionId = 5,
		offset = Vector3.new(-1264, 0, 1266),
		build = { bodyColor = YELLOW, bellyColor = WHITE, earStyle = "pointed", height = 3.8, blush = true },
		lines = {
			"Salt, heat, patience. Mostly patience.",
			"The ferry takes ages. Bring something to do.",
		},
	},

	-- Region 6: the ruins.
	{
		id = "quiet_one",
		name = "Quiet One",
		role = "has been here a while",
		regionId = 6,
		offset = Vector3.new(0, 0, 1410),
		build = { bodyColor = CREAM, bellyColor = CREAM, earStyle = "round", height = 3.4, blush = false },
		lines = {
			"...",
			"The weeds here are older than the walls.",
			"You got far. Well done.",
		},
	},
} :: { NpcDefinition }

function Npcs.get(id: string): NpcDefinition?
	for _, npc in Npcs.DEFINITIONS do
		if npc.id == id then
			return npc
		end
	end
	return nil
end

function Npcs.getInRegion(regionId: number): { NpcDefinition }
	local result = {}
	for _, npc in Npcs.DEFINITIONS do
		if npc.regionId == regionId then
			table.insert(result, npc)
		end
	end
	return result
end

return Npcs

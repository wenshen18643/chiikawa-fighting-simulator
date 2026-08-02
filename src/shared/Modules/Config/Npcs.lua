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
	offset: Vector3,
	build: NpcBuild,
	lines: { string },
}

local Npcs = {}
local WHITE = Color3.fromRGB(250, 248, 244)
local CREAM = Color3.fromRGB(244, 236, 222)
local PINK = Color3.fromRGB(244, 196, 206)
local YELLOW = Color3.fromRGB(246, 216, 140)
local BROWN = Color3.fromRGB(196, 156, 116)
local ARMOUR = Color3.fromRGB(178, 186, 198)

Npcs.DEFINITIONS = {
	{
		id = "ramen_cook",
		name = "Ramen Cook",
		role = "runs the shop",
		regionId = 1,
		offset = Vector3.new(-232, 0, 268),
		build = { bodyColor = ARMOUR, bellyColor = YELLOW, earStyle = "none", height = 5.0, blush = false },
		lines = {
			"Hot bowl? It'll do more for you than a cold one.",
			"Eat properly. The weeds will still be there.",
		},
	},

	{
		id = "forager",
		name = "Forager",
		role = "knows where things grow",
		regionId = 1,
		offset = Vector3.new(44, 0, 196),
		build = { bodyColor = BROWN, bellyColor = CREAM, earStyle = "round", height = 3.4, blush = true },
		lines = {
			"Carrots and potatoes are under the soil. You have to dig for those.",
			"Mushrooms out past the pads. Don't eat the ones that look back at you.",
			"Sausages grow on trees out east. You'll need stronger hands first.",
		},
	},
	{
		id = "pochette_official",
		name = "Pochette Official",
		role = "makes things by hand",
		regionId = 1,
		offset = Vector3.new(124, 0, 20),
		build = { bodyColor = ARMOUR, bellyColor = PINK, earStyle = "none", height = 5.0, blush = false },
		lines = {
			"Everything here is handmade. Including the mistakes.",
			"Bring materials and I'll see what can be done.",
		},
	},

	{
		id = "bath_keeper",
		name = "Bath Keeper",
		role = "minds the waterfall",
		regionId = 1,
		offset = Vector3.new(396, 0, -280),
		build = { bodyColor = WHITE, bellyColor = PINK, earStyle = "pointed", height = 3.8, blush = true },
		lines = {
			"Cold water, warm heart. Sit under it a while.",
			"Resilience is just staying put a bit longer than is comfortable.",
		},
	},
	{
		id = "shore_cook",
		name = "Shore Cook",
		role = "helps at the kitchen",
		regionId = 1,
		offset = Vector3.new(34, 0, -108),
		build = { bodyColor = YELLOW, bellyColor = WHITE, earStyle = "pointed", height = 3.8, blush = true },
		lines = {
			"Salt, heat, patience. Mostly patience.",
			"Bring me anything you dug up. I'll tell you what it goes in.",
		},
	},
	{
		id = "quiet_one",
		name = "Quiet One",
		role = "has been here a while",
		regionId = 1,
		offset = Vector3.new(-212, 0, 452),
		build = { bodyColor = CREAM, bellyColor = CREAM, earStyle = "round", height = 3.4, blush = false },
		lines = {
			"...",
			"The weeds here are older than the fence.",
			"You keep going. That's the whole of it.",
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

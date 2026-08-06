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

Npcs.DEFINITIONS = {
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

return Npcs

--[[
	Worksite ladders for Chiikawa stats.
]]

local Skills = require(script.Parent.Skills)

export type WorksiteDefinition = {
	id: string,
	skill: string,
	tier: number,
	name: string,
	homeRegion: number,
	requirement: { m: number, e: number },
	multiplier: number,
}

local Worksites = {}

local TIERS = {
	{ tier = 1, requirement = { m = 0, e = 0 }, multiplier = 2, homeRegion = 1 },
	{ tier = 2, requirement = { m = 1, e = 4 }, multiplier = 6, homeRegion = 1 },
	{ tier = 3, requirement = { m = 1, e = 5 }, multiplier = 25, homeRegion = 2 },
	{ tier = 4, requirement = { m = 1, e = 6 }, multiplier = 50, homeRegion = 3 },
	{ tier = 5, requirement = { m = 1, e = 7 }, multiplier = 500, homeRegion = 4 },
	{ tier = 6, requirement = { m = 1, e = 8 }, multiplier = 1000, homeRegion = 5 },
	{ tier = 7, requirement = { m = 1, e = 9 }, multiplier = 5000, homeRegion = 6 },
}

local NAMES = {
	tobatsu = {
		"Sasumata Yard",
		"Training Dummy Grounds",
		"Misty Beast Trail",
		"Chimera Cave",
		"Mountain Subjugation",
		"Grand Sentinel Arena",
		"Legendary Sasumata Field",
	},
	resilience = {
		"Waterfall Springs",
		"Crying Boulder",
		"Rainy Cliffside",
		"Storm Mountain Peak",
		"Chimera Impact Zone",
		"Endless Waterfall",
		"Iron Resilience Shrine",
	},
	kusatori = {
		"Roadside Weed Patch",
		"Kusatori Park",
		"Overgrown Riverbank",
		"Terraced Meadow",
		"The Giant Weed Field",
		"Ancient Botanical Ruins",
		"The Endless Kusatori Prairie",
	},
	examprep = {
		"Tiny Study Desk",
		"Pochette Study Nook",
		"Library Corner",
		"Exam Hall Alcove",
		"Master Intelligence Atelier",
		"Grand Academy Hall",
		"The Endless Study Desk",
	},
}

-- Map aliases to primary Chiikawa stat names
NAMES.strength = NAMES.tobatsu
NAMES.subjugation = NAMES.tobatsu
NAMES.durability = NAMES.resilience
NAMES.grit = NAMES.resilience
NAMES.agility = NAMES.kusatori
NAMES.weeding = NAMES.kusatori
NAMES.special = NAMES.examprep
NAMES.craft = NAMES.examprep

Worksites.DEFINITIONS = {} :: { WorksiteDefinition }
Worksites.BY_ID = {} :: { [string]: WorksiteDefinition }
Worksites.BY_SKILL = {} :: { [string]: { WorksiteDefinition } }

for _, skillId in Skills.ORDER do
	local names = NAMES[skillId]
	assert(names, `Worksites: no name list for skill "{skillId}"`)

	local ladder = {}
	for _, tier in TIERS do
		local name = names[tier.tier]
		assert(name, `Worksites: {skillId} is missing a name for tier {tier.tier}`)

		local definition: WorksiteDefinition = {
			id = `{skillId}_{tier.tier}`,
			skill = skillId,
			tier = tier.tier,
			name = name,
			homeRegion = tier.homeRegion,
			requirement = tier.requirement,
			multiplier = tier.multiplier,
		}

		table.insert(ladder, definition)
		table.insert(Worksites.DEFINITIONS, definition)
		Worksites.BY_ID[definition.id] = definition
	end
	Worksites.BY_SKILL[skillId] = ladder
end

-- Aliases for lookup backwards compatibility
Worksites.BY_SKILL.strength = Worksites.BY_SKILL.tobatsu
Worksites.BY_SKILL.subjugation = Worksites.BY_SKILL.tobatsu
Worksites.BY_SKILL.durability = Worksites.BY_SKILL.resilience
Worksites.BY_SKILL.grit = Worksites.BY_SKILL.resilience
Worksites.BY_SKILL.agility = Worksites.BY_SKILL.kusatori
Worksites.BY_SKILL.weeding = Worksites.BY_SKILL.kusatori
Worksites.BY_SKILL.special = Worksites.BY_SKILL.examprep
Worksites.BY_SKILL.craft = Worksites.BY_SKILL.examprep

function Worksites.get(worksiteId: string): WorksiteDefinition?
	return Worksites.BY_ID[worksiteId]
end

function Worksites.getLadder(skillId: string): { WorksiteDefinition }
	return Worksites.BY_SKILL[skillId] or {}
end

function Worksites.getInRegion(regionId: number): { WorksiteDefinition }
	local result = {}
	for _, skillId in Skills.ORDER do
		for _, definition in Worksites.BY_SKILL[skillId] or {} do
			if definition.homeRegion <= regionId then
				table.insert(result, definition)
			end
		end
	end
	return result
end

function Worksites.getInRegionForSkill(regionId: number, skillId: string): { WorksiteDefinition }
	local result = {}
	for _, definition in Worksites.BY_SKILL[skillId] or {} do
		if definition.homeRegion <= regionId then
			table.insert(result, definition)
		end
	end
	return result
end

function Worksites.topTierInRegion(regionId: number, skillId: string): WorksiteDefinition?
	local available = Worksites.getInRegionForSkill(regionId, skillId)
	return available[#available]
end

return Worksites

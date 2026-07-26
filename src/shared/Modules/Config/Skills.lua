--[[
	The 4 Chiikawa training stats. See docs/Things_to_change.md.

	1. Tobatsu (Subduing) — Swinging a Sasumata weapon
	2. Resilience (Crying / Waterfall) — Enduring pressure & tears
	3. Kusatori (Weed Pulling) — Ripping weeds out of the ground
	4. Exam Prep (Studying) — Studying at a tiny desk
]]

export type SkillId = "tobatsu" | "resilience" | "kusatori" | "examprep" | "strength" | "durability" | "agility" | "special" | "weeding" | "subjugation" | "grit" | "craft"

export type SkillDefinition = {
	id: string,
	name: string,
	verb: string, -- shown on the work prompt
	action: "click" | "hold" | "rhythm",
	order: number, -- display order in the HUD
	color: Color3,
	description: string,
}

local Skills = {}

Skills.ORDER = { "tobatsu", "resilience", "kusatori", "examprep" } :: { SkillId }

Skills.DEFINITIONS = {
	tobatsu = {
		id = "tobatsu",
		name = "Tobatsu",
		verb = "Swing",
		action = "click",
		order = 1,
		color = Color3.fromRGB(235, 90, 80),
		description = "Subduing monsters. Swinging a Sasumata fork weapon at training dummies.",
	},
	resilience = {
		id = "resilience",
		name = "Resilience",
		verb = "Endure",
		action = "click",
		order = 2,
		color = Color3.fromRGB(80, 180, 240),
		description = "Crying & enduring pressure under waterfalls and Chimera hits.",
	},
	kusatori = {
		id = "kusatori",
		name = "Kusatori",
		verb = "Pull",
		action = "click",
		order = 3,
		color = Color3.fromRGB(126, 190, 104),
		description = "Weed pulling. Sprinting around ripping weeds out of the ground.",
	},
	examprep = {
		id = "examprep",
		name = "Exam Prep",
		verb = "Study",
		action = "click",
		order = 4,
		color = Color3.fromRGB(240, 140, 210),
		description = "Studying at a tiny desk with booklets and pencils.",
	},
} :: { [string]: SkillDefinition }

-- Aliases for legacy & internal IDs so all references resolve smoothly
Skills.DEFINITIONS.strength = Skills.DEFINITIONS.tobatsu
Skills.DEFINITIONS.subjugation = Skills.DEFINITIONS.tobatsu
Skills.DEFINITIONS.durability = Skills.DEFINITIONS.resilience
Skills.DEFINITIONS.grit = Skills.DEFINITIONS.resilience
Skills.DEFINITIONS.agility = Skills.DEFINITIONS.kusatori
Skills.DEFINITIONS.weeding = Skills.DEFINITIONS.kusatori
Skills.DEFINITIONS.special = Skills.DEFINITIONS.examprep
Skills.DEFINITIONS.craft = Skills.DEFINITIONS.examprep

function Skills.canonicalize(skillId: string): string
	local def = Skills.DEFINITIONS[skillId]
	if def then
		return def.id
	end
	return skillId
end

function Skills.get(skillId: string): SkillDefinition?
	return Skills.DEFINITIONS[skillId]
end

function Skills.exists(skillId: string): boolean
	return Skills.DEFINITIONS[skillId] ~= nil
end

return Skills

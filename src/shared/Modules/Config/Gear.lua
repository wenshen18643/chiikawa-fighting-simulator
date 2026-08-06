--!strict

export type GearDefinition = {
	id: string,
	name: string,
	slot: string,
	tier: number,
	yield: number,
	effort: number,
	glyph: string,
}

local Gear = {}

local DEFINITIONS = {
	pickaxe2 = {
		id = "pickaxe2",
		name = "Steel Pick",
		slot = "pickaxe",
		tier = 2,
		yield = 3,
		effort = 0.8,
		glyph = "pickaxe",
	},
	pickaxe3 = {
		id = "pickaxe3",
		name = "Quarryman's Pick",
		slot = "pickaxe",
		tier = 3,
		yield = 9,
		effort = 0.62,
		glyph = "pickaxe",
	},
	pickaxe4 = {
		id = "pickaxe4",
		name = "Moonstone Pick",
		slot = "pickaxe",
		tier = 4,
		yield = 28,
		effort = 0.48,
		glyph = "pickaxe",
	},
} :: { [string]: GearDefinition }

local BARE = {
	pickaxe = {
		id = "pickaxe1",
		name = "Bare Hands",
		slot = "pickaxe",
		tier = 1,
		yield = 1,
		effort = 1,
		glyph = "pickaxe",
	},
} :: { [string]: GearDefinition }

local function equipped(profile: any, slot: string): GearDefinition?
	local best = BARE[slot]
	local owned = profile and profile.gear
	if not owned then
		return best
	end

	for id, has in owned do
		if has == true then
			local definition = DEFINITIONS[id]
			if definition and definition.slot == slot and (not best or definition.tier > best.tier) then
				best = definition
			end
		end
	end
	return best
end

function Gear.yieldMultiplier(profile: any, slot: string): number
	local definition = equipped(profile, slot)
	return if definition then definition.yield else 1
end

function Gear.effortScale(profile: any, slot: string): number
	local definition = equipped(profile, slot)
	return if definition then definition.effort else 1
end

return Gear

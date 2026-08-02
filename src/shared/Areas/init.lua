local Areas = {}
local Area = require(script.Area)

export type AreaDefinition = Area.AreaDefinition
export type DecorateContext = Area.DecorateContext

local ORDER = { "Town" }

Areas.ALL = {} :: { AreaDefinition }
Areas.BY_ID = {} :: { [number]: AreaDefinition }
Areas.BY_KEY = {} :: { [string]: AreaDefinition }

for index, moduleName in ORDER do
	local module = script:FindFirstChild(moduleName)
	assert(module, `Areas: ORDER lists "{moduleName}" but no such module exists`)

	local area = require(module) :: AreaDefinition
	assert(area.id == index, `Areas: "{moduleName}" has id {area.id} but sits at position {index} in ORDER`)
	assert(not Areas.BY_KEY[area.key], `Areas: duplicate key "{area.key}"`)

	table.insert(Areas.ALL, area)
	Areas.BY_ID[area.id] = area
	Areas.BY_KEY[area.key] = area
end

Areas.STARTING_AREA = 1

for _, area in Areas.ALL do
	if area.bridgeTo == nil then
		continue
	end

	local neighbour = Areas.BY_KEY[area.bridgeTo]
	assert(neighbour, `Areas: "{area.key}" bridges to "{area.bridgeTo}", which does not exist`)
	assert(neighbour.id ~= area.id, `Areas: "{area.key}" bridges to itself`)
	assert(
		neighbour.origin.X > area.origin.X,
		`Areas: "{area.key}" bridges east to "{neighbour.key}", but that area sits to its west`
	)

	local gap = (neighbour.origin.X - neighbour.terrain.islandSize / 2) - (area.origin.X + area.terrain.islandSize / 2)
	assert(
		gap > 0,
		`Areas: "{area.key}" and "{neighbour.key}" overlap by {math.floor(-gap)} studs - `
			.. "their islandSize or origins are wrong"
	)
end

function Areas.get(id: number): AreaDefinition?
	return Areas.BY_ID[id]
end

function Areas.eastOf(area: AreaDefinition): AreaDefinition?
	return area.bridgeTo and Areas.BY_KEY[area.bridgeTo] or nil
end

Areas.helpers = Area.helpers

return Areas

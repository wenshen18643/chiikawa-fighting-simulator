--!strict

local Cave = require(script.Parent.Cave)
local Sections = require(script.Parent.Sections)
local Quarry = {}

Quarry.LEVEL_INDEX = 3

Quarry.PIT = {
	radius = 86,
	floorRadius = 30,
	terraces = 3,
	stepDown = 7,
	clearRadius = 92,
	reserveRadius = 98,
}

Quarry.VEIN = {
	count = 14,
	minSpacing = 18,
	swings = 7,
	respawn = 95,
	height = 4.6,
}

Quarry.CLICK_XP = 1
Quarry.LAND_XP = 5
Quarry.COOLDOWN = 0.7

Quarry.SEAM = {
	{ id = "chalkStone", weight = 32, terrace = 1 },
	{ id = "ironOre", weight = 28, terrace = 1 },
	{ id = "copperOre", weight = 20, terrace = 2 },
	{ id = "quartzOre", weight = 13, terrace = 2 },
	{ id = "moonOre", weight = 7, terrace = 3 },
}

Quarry.FOREMAN = {
	offset = Vector2.new(-72, 58),
	sellRadius = 16,
}

function Quarry.level(): Cave.LevelDefinition?
	return Cave.get(Quarry.LEVEL_INDEX)
end

function Quarry.cell(): Sections.Cell?
	local level = Quarry.level()
	return if level then Sections.byCoord(level.coord) else nil
end

function Quarry.centre(): Vector2?
	local level = Quarry.level()
	if not level then
		return nil
	end
	local marker = Cave.first(level, Cave.SURFACE)
	if not marker then
		return nil
	end
	local at = Cave.cellPosition(level, marker.row, marker.col)
	return if at then Vector2.new(at.X, at.Z) else nil
end

function Quarry.terraceRadius(index: number): number
	local span = Quarry.PIT.radius - Quarry.PIT.floorRadius
	return Quarry.PIT.radius - span * ((index - 1) / Quarry.PIT.terraces)
end

function Quarry.terraceDepth(index: number): number
	return -Quarry.PIT.stepDown * index
end

function Quarry.floorDepth(): number
	return Quarry.terraceDepth(Quarry.PIT.terraces)
end

function Quarry.contains(x: number, z: number): boolean
	local centre = Quarry.centre()
	if not centre then
		return false
	end
	local dx, dz = x - centre.X, z - centre.Y
	return dx * dx + dz * dz <= Quarry.PIT.radius * Quarry.PIT.radius
end

function Quarry.foremanPosition(): Vector2?
	local centre = Quarry.centre()
	if not centre then
		return nil
	end
	return centre + Quarry.FOREMAN.offset * (Quarry.PIT.radius / 86)
end

function Quarry.rollSeam(rng: Random, terrace: number): string
	local pool = {}
	local total = 0
	for _, entry in Quarry.SEAM do
		if entry.terrace <= terrace then
			table.insert(pool, entry)
			total += entry.weight
		end
	end
	if #pool == 0 then
		return Quarry.SEAM[1].id
	end

	local pick = rng:NextNumber() * total
	for _, entry in pool do
		pick -= entry.weight
		if pick <= 0 then
			return entry.id
		end
	end
	return pool[1].id
end

function Quarry.check(): { string }
	local problems = {}
	local level = Quarry.level()
	if not level then
		table.insert(problems, `Quarry: no cave level {Quarry.LEVEL_INDEX} to surface from`)
		return problems
	end

	local cell = Quarry.cell()
	local centre = Quarry.centre()
	if not cell then
		table.insert(
			problems,
			`Quarry: level {Quarry.LEVEL_INDEX} names section "{level.coord}", which is not on the board`
		)
		return problems
	end
	if not centre then
		table.insert(
			problems,
			`Quarry: level {Quarry.LEVEL_INDEX} ("{level.name}") has no "{Cave.SURFACE}" marker to open the pit on`
		)
		return problems
	end

	local slackX = math.min(centre.X - cell.minX, cell.maxX - centre.X)
	local slackZ = math.min(centre.Y - cell.minZ, cell.maxZ - centre.Y)
	local slack = math.min(slackX, slackZ)
	if slack < Quarry.PIT.radius then
		local message = `Quarry: pit radius {Quarry.PIT.radius} does not fit; the surface marker sits `
		message ..= `{math.floor(slack)} studs from the edge of "{level.coord}". `
		message ..= "Move the marker or shrink PIT.radius."
		table.insert(problems, message)
	end

	return problems
end

return Quarry

--!strict

local Sections = require(script.Parent.Sections)
local Fishing = {}

Fishing.CELL_COORD = "F2"

Fishing.LAKE = {
	radius = 78,
	depth = 9,
	bedThickness = 6,
	bedClearance = 2,
	surfaceDrop = 1.5,
	reserveRadius = 96,
}

Fishing.PIER = {
	reach = 52,
	width = 11,
	deckY = 3.2,
	postEvery = 13,
	railHeight = 3.4,
}

Fishing.SPOT = {
	count = 5,
	radius = 26,
	ringInset = 14,
	bobberDrift = 1.6,
}

Fishing.CAST_CLICKS = 9
Fishing.CLICK_XP = 1
Fishing.LAND_XP = 4
Fishing.COOLDOWN = 0.9
Fishing.RARE_CHANCE = 0.18
Fishing.LEGENDARY_CHANCE = 0.04

Fishing.STOCK = {
	{ id = "bitterling", weight = 34 },
	{ id = "crucian", weight = 26 },
	{ id = "pondSnail", weight = 14 },
	{ id = "sweetfish", weight = 12 },
	{ id = "koi", weight = 8 },
	{ id = "moonScale", weight = 2 },
}

function Fishing.cell(): Sections.Cell?
	return Sections.byCoord(Fishing.CELL_COORD)
end

function Fishing.centre(): Vector2?
	local cell = Fishing.cell()
	if not cell then
		return nil
	end
	return Vector2.new(cell.cx, cell.cz)
end

function Fishing.pierBase(): Vector2?
	local centre = Fishing.centre()
	if not centre then
		return nil
	end
	return Vector2.new(centre.X - Fishing.LAKE.radius - 8, centre.Y)
end

function Fishing.pierTip(): Vector2?
	local base = Fishing.pierBase()
	if not base then
		return nil
	end
	return Vector2.new(base.X + Fishing.PIER.reach, base.Y)
end

function Fishing.spotPositions(): { Vector2 }
	local centre = Fishing.centre()
	local tip = Fishing.pierTip()
	if not centre or not tip then
		return {}
	end

	local spots = { tip }
	local ring = Fishing.LAKE.radius - Fishing.SPOT.ringInset
	for index = 1, Fishing.SPOT.count - 1 do
		local angle = math.pi * 0.35 + (index - 1) / (Fishing.SPOT.count - 1) * math.pi * 1.3
		table.insert(spots, Vector2.new(centre.X + math.cos(angle) * ring, centre.Y + math.sin(angle) * ring))
	end
	return spots
end

function Fishing.roll(rng: Random): string
	local total = 0
	for _, entry in Fishing.STOCK do
		total += entry.weight
	end

	local pick = rng:NextNumber() * total
	for _, entry in Fishing.STOCK do
		pick -= entry.weight
		if pick <= 0 then
			return entry.id
		end
	end
	return Fishing.STOCK[1].id
end

return Fishing

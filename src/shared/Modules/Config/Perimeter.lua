local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sections = require(ReplicatedStorage.Shared.Modules.Config.Sections)
local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)
local Perimeter = {}

Perimeter.CELLS = { "D4", "E4", "D5", "E5" }
Perimeter.GATE_HALF_WIDTH = Streets.NORTH_ROAD_HALF
Perimeter.BAND = 44
Perimeter.BLOCK_HEIGHT = 260

export type Run = {
	side: string,
	axis: string,
	cx: number,
	cz: number,
	length: number,
	outX: number,
	outZ: number,
	yaw: number,
}

export type Side = {
	name: string,
	axis: string,
	outX: number,
	outZ: number,
}

local SIDES: { Side } = {
	{ name = "North", axis = "x", outX = 0, outZ = 1 },
	{ name = "South", axis = "x", outX = 0, outZ = -1 },
	{ name = "East", axis = "z", outX = 1, outZ = 0 },
	{ name = "West", axis = "z", outX = -1, outZ = 0 },
}

local function computeBounds(): (Vector2, Vector2)
	local minX, minZ = math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge

	for _, coord in Perimeter.CELLS do
		local cell = Sections.byCoord(coord)
		assert(cell, `Perimeter: "{coord}" is not a section coordinate`)
		minX, minZ = math.min(minX, cell.minX), math.min(minZ, cell.minZ)
		maxX, maxZ = math.max(maxX, cell.maxX), math.max(maxZ, cell.maxZ)
	end

	return Vector2.new(minX, minZ), Vector2.new(maxX, maxZ)
end

Perimeter.MIN, Perimeter.MAX = computeBounds()
Perimeter.CENTRE = (Perimeter.MIN + Perimeter.MAX) / 2
Perimeter.SIZE = Perimeter.MAX - Perimeter.MIN

assert(
	Perimeter.MAX.Y == Streets.GATEHOUSE_Z,
	`Perimeter: wall sits at z={Perimeter.MAX.Y} but Streets.GATEHOUSE_Z is {Streets.GATEHOUSE_Z}`
)

Perimeter.GATE = {
	x = Perimeter.CENTRE.X,
	z = Perimeter.MAX.Y,
	halfWidth = Perimeter.GATE_HALF_WIDTH,
	outX = 0,
	outZ = 1,
	yaw = 0,
}

local function sideLine(side: Side): (number, number, number)
	if side.axis == "x" then
		local fixed = if side.outZ > 0 then Perimeter.MAX.Y else Perimeter.MIN.Y
		return fixed, Perimeter.MIN.X, Perimeter.MAX.X
	end
	local fixed = if side.outX > 0 then Perimeter.MAX.X else Perimeter.MIN.X
	return fixed, Perimeter.MIN.Y, Perimeter.MAX.Y
end

local function holdsGate(side: Side): boolean
	return side.outX == Perimeter.GATE.outX and side.outZ == Perimeter.GATE.outZ
end

function Perimeter.runs(): { Run }
	local result: { Run } = {}

	for _, side in SIDES do
		local fixed, from, to = sideLine(side)
		local spans = { { from, to } }

		if holdsGate(side) then
			local centre = if side.axis == "x" then Perimeter.GATE.x else Perimeter.GATE.z
			spans = {
				{ from, centre - Perimeter.GATE.halfWidth },
				{ centre + Perimeter.GATE.halfWidth, to },
			}
		end

		for _, span in spans do
			local length = span[2] - span[1]
			if length > 1 then
				local along = (span[1] + span[2]) / 2
				table.insert(result, {
					side = side.name,
					axis = side.axis,
					cx = if side.axis == "x" then along else fixed,
					cz = if side.axis == "x" then fixed else along,
					length = length,
					outX = side.outX,
					outZ = side.outZ,
					yaw = math.atan2(side.outX, side.outZ),
				})
			end
		end
	end

	return result
end

function Perimeter.pointOn(run: Run, fraction: number): (number, number)
	local offset = (fraction - 0.5) * run.length
	if run.axis == "x" then
		return run.cx + offset, run.cz
	end
	return run.cx, run.cz + offset
end

function Perimeter.corners(): { Vector2 }
	return {
		Vector2.new(Perimeter.MIN.X, Perimeter.MIN.Y),
		Vector2.new(Perimeter.MAX.X, Perimeter.MIN.Y),
		Vector2.new(Perimeter.MAX.X, Perimeter.MAX.Y),
		Vector2.new(Perimeter.MIN.X, Perimeter.MAX.Y),
	}
end

function Perimeter.outwardDistance(x: number, z: number): number
	return math.max(
		math.abs(x - Perimeter.CENTRE.X) - Perimeter.SIZE.X / 2,
		math.abs(z - Perimeter.CENTRE.Y) - Perimeter.SIZE.Y / 2
	)
end

function Perimeter.reservedZones(): { { [string]: any } }
	local zones = {}
	local halfX, halfZ = Perimeter.SIZE.X / 2, Perimeter.SIZE.Y / 2

	for _, side in SIDES do
		local fixed, from, to = sideLine(side)
		local along = (from + to) / 2
		table.insert(zones, {
			kind = "rect",
			x = if side.axis == "x" then along else fixed,
			z = if side.axis == "x" then fixed else along,
			halfX = if side.axis == "x" then halfX + Perimeter.BAND else Perimeter.BAND,
			halfZ = if side.axis == "x" then Perimeter.BAND else halfZ + Perimeter.BAND,
		})
	end

	return zones
end

return Perimeter

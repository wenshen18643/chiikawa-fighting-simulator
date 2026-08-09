local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Modules.Constants)
local Streets = {}

Streets.SURFACE_Y = Constants.WORLD.PLATFORM_TOP
Streets.THICKNESS = 5

Streets.MATERIAL = Enum.Material.Cobblestone
Streets.COLOR = Color3.fromRGB(224, 216, 203)
Streets.SQUARE_COLOR = Color3.fromRGB(232, 223, 208)

Streets.HEDGE_HEIGHT = 3.2
Streets.HEDGE_WIDTH = 2.4
Streets.HEDGE_SEGMENT = 6
Streets.HEDGE_SKIRT = 4
Streets.HEDGE_COLOR = Color3.fromRGB(126, 176, 104)
Streets.HEDGE_CROWN = Color3.fromRGB(150, 198, 126)

Streets.VERGE_OFFSET = Streets.HEDGE_WIDTH / 2

export type Paved = {
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	rise: number?,
}

export type Verge = {
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
}

Streets.WIDTH = 20
Streets.HALF_WIDTH = Streets.WIDTH / 2
Streets.GATE_STUB = 5
Streets.BRANCH_LENGTH = 26
Streets.APRON_DEPTH = 15
Streets.APRON_STEPS = 3

Streets.RING = { halfX = 103, southZ = -97, northZ = 143, gateZ = 90 }

Streets.NORTH_ROAD_HALF = 17
Streets.GATEHOUSE_Z = 212
Streets.GATEHOUSE_DEPTH = 30
Streets.NORTH_ROAD_END = Streets.GATEHOUSE_Z - Streets.GATEHOUSE_DEPTH / 2

local RING = Streets.RING
local W = Streets.WIDTH
local HALF = Streets.HALF_WIDTH
local NORTH_HALF = Streets.NORTH_ROAD_HALF
local STUB = Streets.GATE_STUB
local BRANCH = Streets.BRANCH_LENGTH
local RING_INNER_X = RING.halfX - W
local RING_INNER_SOUTH = RING.southZ + W
local GATE_MIN_Z = RING.gateZ - HALF
local GATE_MAX_Z = RING.gateZ + HALF

Streets.SQUARE = { name = "MarketSquare", minX = -150, maxX = 150, minZ = -188, maxZ = -108 } :: Paved

Streets.PAVING = {
	{ name = "RingNorth", minX = -RING.halfX, maxX = RING.halfX, minZ = RING.northZ, maxZ = RING.northZ + W },
	{
		name = "RingSouth",
		minX = -RING.halfX,
		maxX = RING.halfX,
		minZ = RING.southZ,
		maxZ = RING_INNER_SOUTH,
		rise = 0.06,
	},
	{ name = "RingWest", minX = -RING.halfX, maxX = -RING_INNER_X, minZ = RING_INNER_SOUTH, maxZ = RING.northZ },
	{ name = "RingEast", minX = RING_INNER_X, maxX = RING.halfX, minZ = RING_INNER_SOUTH, maxZ = RING.northZ },

	{ name = "NorthGate", minX = -NORTH_HALF, maxX = NORTH_HALF, minZ = RING.northZ - STUB, maxZ = RING.northZ },
	{ name = "SouthGate", minX = -HALF, maxX = HALF, minZ = RING_INNER_SOUTH, maxZ = RING_INNER_SOUTH + STUB },
	{ name = "EastGate", minX = RING_INNER_X - STUB, maxX = RING_INNER_X, minZ = GATE_MIN_Z, maxZ = GATE_MAX_Z },
	{ name = "WestGate", minX = -RING_INNER_X, maxX = -RING_INNER_X + STUB, minZ = GATE_MIN_Z, maxZ = GATE_MAX_Z },

	{
		name = "NorthRoad",
		minX = -Streets.NORTH_ROAD_HALF,
		maxX = Streets.NORTH_ROAD_HALF,
		minZ = RING.northZ + W,
		maxZ = Streets.NORTH_ROAD_END,
	},
	{ name = "LibraryRoad", minX = RING.halfX, maxX = RING.halfX + BRANCH, minZ = GATE_MIN_Z, maxZ = GATE_MAX_Z },
	{
		name = "KitchenRoad",
		minX = -(RING.halfX + BRANCH),
		maxX = -RING.halfX,
		minZ = GATE_MIN_Z,
		maxZ = GATE_MAX_Z,
	},
	{ name = "MarketSpur", minX = -HALF, maxX = HALF, minZ = Streets.SQUARE.maxZ, maxZ = RING.southZ },
} :: { Paved }

Streets.BRANCH_END = RING.halfX + BRANCH
Streets.APRON_START = Streets.BRANCH_END - Streets.APRON_DEPTH

local function addApron(name: string, sign: number, frontageHalf: number)
	local slice = Streets.APRON_DEPTH / Streets.APRON_STEPS
	local start = sign * Streets.APRON_START

	for index = 1, Streets.APRON_STEPS do
		local near = start + sign * slice * (index - 1)
		local far = near + sign * slice
		local half = HALF + (frontageHalf - HALF) * (index / Streets.APRON_STEPS)

		table.insert(Streets.PAVING, {
			name = `{name}Apron{index}`,
			minX = math.min(near, far),
			maxX = math.max(near, far),
			minZ = RING.gateZ - half,
			maxZ = RING.gateZ + half,
		})
	end
end

addApron("Library", 1, 42)
addApron("Kitchen", -1, 26)

Streets.PAVING_BY_NAME = {} :: { [string]: Paved }
for _, area in Streets.PAVING do
	Streets.PAVING_BY_NAME[area.name] = area
end

local LIP = Streets.VERGE_OFFSET
local RING_KERB_X = RING.halfX + LIP
local RING_KERB_NORTH = RING.northZ + W + LIP
local RING_KERB_SOUTH = RING.southZ - LIP
local LANE_KERB_X = HALF + LIP
local NORTH_LANE_KERB_X = Streets.NORTH_ROAD_HALF + LIP
local NORTH_KERB_END = Streets.NORTH_ROAD_END
local GATE_KERB_NEAR = GATE_MIN_Z - LIP
local GATE_KERB_FAR = GATE_MAX_Z + LIP
local BRANCH_KERB_X = Streets.APRON_START

Streets.VERGES = {
	{ fromX = -RING_KERB_X, fromZ = RING_KERB_NORTH, toX = -NORTH_LANE_KERB_X, toZ = RING_KERB_NORTH },
	{ fromX = NORTH_LANE_KERB_X, fromZ = RING_KERB_NORTH, toX = RING_KERB_X, toZ = RING_KERB_NORTH },

	{ fromX = -NORTH_LANE_KERB_X, fromZ = RING_KERB_NORTH, toX = -NORTH_LANE_KERB_X, toZ = NORTH_KERB_END },
	{ fromX = NORTH_LANE_KERB_X, fromZ = RING_KERB_NORTH, toX = NORTH_LANE_KERB_X, toZ = NORTH_KERB_END },

	{ fromX = -RING_KERB_X, fromZ = RING_KERB_SOUTH, toX = -LANE_KERB_X, toZ = RING_KERB_SOUTH },
	{ fromX = LANE_KERB_X, fromZ = RING_KERB_SOUTH, toX = RING_KERB_X, toZ = RING_KERB_SOUTH },

	{ fromX = -RING_KERB_X, fromZ = RING_KERB_SOUTH, toX = -RING_KERB_X, toZ = GATE_KERB_NEAR },
	{ fromX = -RING_KERB_X, fromZ = GATE_KERB_FAR, toX = -RING_KERB_X, toZ = RING_KERB_NORTH },

	{ fromX = RING_KERB_X, fromZ = RING_KERB_SOUTH, toX = RING_KERB_X, toZ = GATE_KERB_NEAR },
	{ fromX = RING_KERB_X, fromZ = GATE_KERB_FAR, toX = RING_KERB_X, toZ = RING_KERB_NORTH },

	{ fromX = RING_KERB_X, fromZ = GATE_KERB_NEAR, toX = BRANCH_KERB_X, toZ = GATE_KERB_NEAR },
	{ fromX = RING_KERB_X, fromZ = GATE_KERB_FAR, toX = BRANCH_KERB_X, toZ = GATE_KERB_FAR },

	{ fromX = -BRANCH_KERB_X, fromZ = GATE_KERB_NEAR, toX = -RING_KERB_X, toZ = GATE_KERB_NEAR },
	{ fromX = -BRANCH_KERB_X, fromZ = GATE_KERB_FAR, toX = -RING_KERB_X, toZ = GATE_KERB_FAR },

	{ fromX = -LANE_KERB_X, fromZ = Streets.SQUARE.maxZ, toX = -LANE_KERB_X, toZ = RING_KERB_SOUTH },
	{ fromX = LANE_KERB_X, fromZ = Streets.SQUARE.maxZ, toX = LANE_KERB_X, toZ = RING_KERB_SOUTH },
} :: { Verge }

local function within(area: Paved, x: number, z: number, margin: number): boolean
	return x >= area.minX - margin
		and x <= area.maxX + margin
		and z >= area.minZ - margin
		and z <= area.maxZ + margin
end

function Streets.isPaved(x: number, z: number, margin: number?): boolean
	local pad = margin or 0

	for _, area in Streets.PAVING do
		if within(area, x, z, pad) then
			return true
		end
	end
	if within(Streets.SQUARE, x, z, pad) then
		return true
	end

	for _, verge in Streets.VERGES do
		local reach = pad + Streets.VERGE_OFFSET
		if
			x >= math.min(verge.fromX, verge.toX) - reach
			and x <= math.max(verge.fromX, verge.toX) + reach
			and z >= math.min(verge.fromZ, verge.toZ) - reach
			and z <= math.max(verge.fromZ, verge.toZ) + reach
		then
			return true
		end
	end

	return false
end

function Streets.reservedZones(margin: number?): { { [string]: any } }
	local pad = margin or 5
	local zones = {}

	local function box(x: number, z: number, halfX: number, halfZ: number)
		table.insert(zones, { kind = "rect", x = x, z = z, halfX = halfX + pad, halfZ = halfZ + pad })
	end

	local function rect(area: Paved)
		box(
			(area.minX + area.maxX) / 2,
			(area.minZ + area.maxZ) / 2,
			(area.maxX - area.minX) / 2,
			(area.maxZ - area.minZ) / 2
		)
	end

	for _, area in Streets.PAVING do
		rect(area)
	end
	rect(Streets.SQUARE)

	for _, verge in Streets.VERGES do
		box(
			(verge.fromX + verge.toX) / 2,
			(verge.fromZ + verge.toZ) / 2,
			math.abs(verge.toX - verge.fromX) / 2 + Streets.VERGE_OFFSET,
			math.abs(verge.toZ - verge.fromZ) / 2 + Streets.VERGE_OFFSET
		)
	end

	return zones
end

return Streets

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

Streets.LAMP_SPACING = 38
Streets.LAMP_INSET = 4

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
	facing: number,
	lamps: boolean?,
	hedge: boolean?,
}

Streets.PAVING = {
	{ name = "RingNorth", minX = -103, maxX = 103, minZ = 143, maxZ = 157 },
	{ name = "RingSouth", minX = -103, maxX = 103, minZ = -77, maxZ = -63, rise = 0.06 },
	{ name = "RingWest", minX = -103, maxX = -89, minZ = -63, maxZ = 143 },
	{ name = "RingEast", minX = 89, maxX = 103, minZ = -63, maxZ = 143 },

	{ name = "NorthGate", minX = -7, maxX = 7, minZ = 138, maxZ = 143 },
	{ name = "EastGate", minX = 84, maxX = 89, minZ = 83, maxZ = 97 },
	{ name = "WestGate", minX = -89, maxX = -84, minZ = 83, maxZ = 97 },

	{ name = "NorthRoad", minX = -7, maxX = 7, minZ = 157, maxZ = 200 },
	{ name = "LibraryRoad", minX = 103, maxX = 119, minZ = 83, maxZ = 97 },
	{ name = "KitchenRoad", minX = -129, maxX = -103, minZ = 83, maxZ = 97 },
	{ name = "MarketSpur", minX = -103, maxX = -89, minZ = -92, maxZ = -77 },
} :: { Paved }

Streets.SQUARE = { name = "MarketSquare", minX = -144, maxX = -48, minZ = -188, maxZ = -92 } :: Paved

Streets.PAVING_BY_NAME = {} :: { [string]: Paved }
for _, area in Streets.PAVING do
	Streets.PAVING_BY_NAME[area.name] = area
end

Streets.VERGES = {
	{ fromX = -104.2, fromZ = 158.2, toX = -8.2, toZ = 158.2, facing = 180, lamps = true },
	{ fromX = 8.2, fromZ = 158.2, toX = 104.2, toZ = 158.2, facing = 180, lamps = true },

	{ fromX = -87.8, fromZ = -78.2, toX = 104.2, toZ = -78.2, facing = 0, lamps = true },

	{ fromX = -104.2, fromZ = -90.8, toX = -104.2, toZ = 81.8, facing = 90, lamps = true },
	{ fromX = -104.2, fromZ = 98.2, toX = -104.2, toZ = 158.2, facing = 90, lamps = true },

	{ fromX = 104.2, fromZ = -78.2, toX = 104.2, toZ = 81.8, facing = -90, lamps = true },
	{ fromX = 104.2, fromZ = 98.2, toX = 104.2, toZ = 158.2, facing = -90, lamps = true },

	{ fromX = -8.2, fromZ = 158.2, toX = -8.2, toZ = 200, facing = 90 },
	{ fromX = 8.2, fromZ = 158.2, toX = 8.2, toZ = 200, facing = -90 },

	{ fromX = 104.2, fromZ = 81.8, toX = 119, toZ = 81.8, facing = 0, lamps = true },
	{ fromX = 104.2, fromZ = 98.2, toX = 119, toZ = 98.2, facing = 180, lamps = true },

	{ fromX = -129, fromZ = 81.8, toX = -104.2, toZ = 81.8, facing = 0, lamps = true },
	{ fromX = -129, fromZ = 98.2, toX = -104.2, toZ = 98.2, facing = 180, lamps = true },

	{ fromX = -87.8, fromZ = -90.8, toX = -87.8, toZ = -78.2, facing = -90, hedge = false },

	{ fromX = -145.2, fromZ = -90.8, toX = -104.2, toZ = -90.8, facing = 180, lamps = true, hedge = false },
	{ fromX = -87.8, fromZ = -90.8, toX = -46.8, toZ = -90.8, facing = 180, lamps = true, hedge = false },

	{ fromX = -145.2, fromZ = -189.2, toX = -46.8, toZ = -189.2, facing = 0, lamps = true, hedge = false },
	{ fromX = -145.2, fromZ = -189.2, toX = -145.2, toZ = -90.8, facing = 90, lamps = true, hedge = false },
	{ fromX = -46.8, fromZ = -189.2, toX = -46.8, toZ = -90.8, facing = -90, lamps = true, hedge = false },
} :: { Verge }

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

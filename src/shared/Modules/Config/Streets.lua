--[[
	The town's paved surfaces, as data.

	--------------------------------------------------------------------------
	WHY RECTANGLES AND NOT CENTRELINES
	--------------------------------------------------------------------------

	The first version described each street as a centreline with a width and let
	the builder extrude a slab from it. Every junction was then two slabs on the
	same ground at the same height, and the four ring corners were double-covered
	over a full 14x14 square -- coplanar faces, so they z-fought along every seam,
	and the kerbs ran straight through the crossing traffic.

	So a street is an AXIS-ALIGNED RECTANGLE here, and the rectangles are authored
	not to overlap: the ring's long sides stop where its short sides begin, and a
	road that crosses the ring is split either side of it rather than laid over it.
	Nothing overlaps, so nothing needs a z-ordering trick to survive.

	--------------------------------------------------------------------------
	EVERYTHING PAVED SITS ON ONE PLANE
	--------------------------------------------------------------------------

	Constants.WORLD puts terrain at -2 and every plaza surface at +1, so the town
	square has always had a three-stud lip around it. Streets seated on the
	terrain would have met that lip head-on: a road running into the square either
	steps up three studs or disappears under it.

	So paving is seated at SURFACE_Y -- the same +1 the plaza presents -- and made
	deep enough to bury its own underside in the terrain below. Roads and square
	are then one continuous walking surface, and the three-stud edge happens at the
	OUTSIDE of the street where the hedge hides it, which is what a kerb is.

	`rise` is the one exception, and it is for one thing: the plaza is a disc of
	radius 85 centred on the house, which reaches past the fence and across the
	ring's south side. That crossing is a genuine overlap between two paved
	surfaces, so the ring is lifted a hair to win it cleanly.

	--------------------------------------------------------------------------
	WHAT MAKES IT READ AS CONNECTED
	--------------------------------------------------------------------------

	Every route is a straight, unbroken run from a gate in the garden fence to a
	door. The gates moved to meet the streets rather than the streets bending to
	meet the gates: the east gate is opposite the library door and the west gate
	is opposite the kitchen's, so from either you can see where the road goes.

	HEDGES are what turn a strip of paving into a street. They sit FLUSH against
	the carriageway edge -- not on a verge a few studs away, which would leave a
	three-stud trench between road and hedge -- and they are broken at every
	junction. They also carry the street furniture: lanterns and benches are
	placed off the hedge line, inset back onto the pavement, so a bench is always
	beside a road and facing it rather than dropped on a lawn at a random angle.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Modules.Constants)

local Streets = {}

-- The plane every paved surface in town presents, plaza included.
Streets.SURFACE_Y = Constants.WORLD.PLATFORM_TOP
-- Deep enough to bury the underside in terrain three studs below.
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

-- How far a hedge line sits from the carriageway it edges: its own half-width,
-- so the two touch exactly.
Streets.VERGE_OFFSET = Streets.HEDGE_WIDTH / 2

Streets.LAMP_SPACING = 38
Streets.LAMP_INSET = 4
Streets.BENCH_SPACING = 56
Streets.BENCH_INSET = 5

export type Paved = {
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	rise: number?,
}

--[[
	A hedge line. `facing` is the yaw, in degrees, that looks at the road it
	edges -- so a hedge on the ring's north side faces 180, back south across the
	carriageway, and anything placed off it inherits that.
]]
export type Verge = {
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	facing: number,
	lamps: boolean?,
	benches: boolean?,
}

--------------------------------------------------------------------------------
-- Carriageways
--------------------------------------------------------------------------------

--[[
	Ring centrelines are X = +/-96 and Z = -70 and 150, all 14 wide. The long
	sides are cut back to Z -63..143 so the four corners belong to the short
	sides alone.

	There is no south gate stub. The plaza is 85 studs across and the fence's back
	line is at Z -58, so the square already paves the whole distance from that
	gate to the ring -- a stub there would be a slab laid on top of a slab.
]]
Streets.PAVING = {
	{ name = "RingNorth", minX = -103, maxX = 103, minZ = 143, maxZ = 157 },
	{ name = "RingSouth", minX = -103, maxX = 103, minZ = -77, maxZ = -63, rise = 0.06 },
	{ name = "RingWest", minX = -103, maxX = -89, minZ = -63, maxZ = 143 },
	{ name = "RingEast", minX = 89, maxX = 103, minZ = -63, maxZ = 143 },

	-- Fence to ring. Short on purpose: inside the fence is lawn, not pavement.
	{ name = "NorthGate", minX = -7, maxX = 7, minZ = 138, maxZ = 143 },
	{ name = "EastGate", minX = 84, maxX = 89, minZ = 83, maxZ = 97 },
	{ name = "WestGate", minX = -89, maxX = -84, minZ = 83, maxZ = 97 },

	-- Ring to somewhere.
	{ name = "NorthRoad", minX = -7, maxX = 7, minZ = 157, maxZ = 200 },
	{ name = "LibraryRoad", minX = 103, maxX = 119, minZ = 83, maxZ = 97 },
	{ name = "KitchenRoad", minX = -129, maxX = -103, minZ = 83, maxZ = 97 },
	{ name = "MarketSpur", minX = -103, maxX = -89, minZ = -92, maxZ = -77 },
} :: { Paved }

Streets.SQUARE = { name = "MarketSquare", minX = -144, maxX = -48, minZ = -188, maxZ = -92 } :: Paved

--------------------------------------------------------------------------------
-- Hedges
--------------------------------------------------------------------------------

--[[
	Only the OUTER edge of the ring is hedged. Its inner edge already has the
	garden fence a few studs away, and a hedge there would be a second wall
	against the first with a footpath's worth of grass trapped between them.

	The gate stubs are five studs long and carry nothing: a hedge on them would be
	two bushes standing in a doorway.
]]
Streets.VERGES = {
	-- Ring north, broken where the north road passes through.
	{ fromX = -104.2, fromZ = 158.2, toX = -8.2, toZ = 158.2, facing = 180, lamps = true, benches = true },
	{ fromX = 8.2, fromZ = 158.2, toX = 104.2, toZ = 158.2, facing = 180, lamps = true, benches = true },

	-- Ring south, broken where the market spur drops away.
	{ fromX = -87.8, fromZ = -78.2, toX = 104.2, toZ = -78.2, facing = 0, lamps = true, benches = true },

	-- Ring west, running on down the spur's west side. Broken at the kitchen road.
	{ fromX = -104.2, fromZ = -90.8, toX = -104.2, toZ = 81.8, facing = 90, lamps = true },
	{ fromX = -104.2, fromZ = 98.2, toX = -104.2, toZ = 158.2, facing = 90, lamps = true },

	-- Ring east. Broken at the library road.
	{ fromX = 104.2, fromZ = -78.2, toX = 104.2, toZ = 81.8, facing = -90, lamps = true },
	{ fromX = 104.2, fromZ = 98.2, toX = 104.2, toZ = 158.2, facing = -90, lamps = true },

	-- The road north out of town.
	{ fromX = -8.2, fromZ = 158.2, toX = -8.2, toZ = 200, facing = 90, lamps = true },
	{ fromX = 8.2, fromZ = 158.2, toX = 8.2, toZ = 200, facing = -90, lamps = true },

	-- The library road.
	{ fromX = 104.2, fromZ = 81.8, toX = 119, toZ = 81.8, facing = 0, lamps = true },
	{ fromX = 104.2, fromZ = 98.2, toX = 119, toZ = 98.2, facing = 180, lamps = true },

	-- The kitchen road.
	{ fromX = -129, fromZ = 81.8, toX = -104.2, toZ = 81.8, facing = 0, lamps = true },
	{ fromX = -129, fromZ = 98.2, toX = -104.2, toZ = 98.2, facing = 180, lamps = true },

	-- The market spur's east side; its west side is the ring west run above.
	{ fromX = -87.8, fromZ = -90.8, toX = -87.8, toZ = -78.2, facing = -90 },

	-- Around the square, leaving the spur's mouth open.
	{ fromX = -145.2, fromZ = -90.8, toX = -104.2, toZ = -90.8, facing = 180, lamps = true },
	{ fromX = -87.8, fromZ = -90.8, toX = -46.8, toZ = -90.8, facing = 180, lamps = true },
	{ fromX = -145.2, fromZ = -189.2, toX = -46.8, toZ = -189.2, facing = 0, lamps = true, benches = true },
	{ fromX = -145.2, fromZ = -189.2, toX = -145.2, toZ = -90.8, facing = 90, lamps = true, benches = true },
	{ fromX = -46.8, fromZ = -189.2, toX = -46.8, toZ = -90.8, facing = -90, lamps = true, benches = true },
} :: { Verge }

--------------------------------------------------------------------------------
-- Reserves
--------------------------------------------------------------------------------

--[[
	Zones matching every paved surface and every hedge, so scatter never lands in
	a carriageway or inside a hedge, and so TerrainBuilder flattens the ground
	they sit on.

	Shaped for Layout.isReserved rather than typed against it: Layout requires
	this module, so the dependency cannot point the other way.
]]
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

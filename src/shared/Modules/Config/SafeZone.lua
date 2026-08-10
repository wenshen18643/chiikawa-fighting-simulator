local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Modules.Constants)
local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)
local SafeZone = {}
local FENCE_POST = 1.3
local FENCE_KERB = FENCE_POST / 2

SafeZone.DOME = {
	radius = 56,
	height = 62,
	wall = 2.4,
	rings = 20,
	segmentArc = 10,
	bulge = 0.86,
	overlap = 1.14,
}

SafeZone.FLOOR_Y = 0.75

SafeZone.RUG = { diameter = 52, z = -24 }

SafeZone.OPENINGS = {
	{ name = "Door", azimuth = 0, halfAngle = 12, bottom = 0, top = 26, kind = "door" },
	{ name = "WindowE", azimuth = 76, halfAngle = 10, bottom = 12, top = 26, kind = "round" },
	{ name = "WindowW", azimuth = -76, halfAngle = 10, bottom = 12, top = 26, kind = "round" },
	{ name = "WindowN", azimuth = 180, halfAngle = 10, bottom = 12, top = 26, kind = "round" },
	{ name = "LoftWindow", azimuth = 0, halfAngle = 12, bottom = 34, top = 47, kind = "round" },
}

SafeZone.LOFT = {
	y = 30,
	slab = 0.8,
	frontZ = -8,
	inset = 2.6,
	strips = 28,
	railHeight = 4.2,
	postSpacing = 10,
}

SafeZone.STAIR = {
	steps = 24,
	x = -30,
	footZ = 38,
	width = 9,
	tread = 1.1,
	stringer = 0.9,
	railHeight = 3.4,
	railPosts = 7,
	clearance = 1.2,
}

function SafeZone.stairGap(): (number, number)
	local stair = SafeZone.STAIR
	local reach = stair.width / 2 + stair.clearance
	return stair.x - reach, stair.x + reach
end

SafeZone.palette = {
	shell = Color3.fromRGB(250, 247, 242),
	shellShade = Color3.fromRGB(236, 229, 220),
	trim = Color3.fromRGB(244, 186, 190),
	trimDeep = Color3.fromRGB(224, 152, 158),
	mint = Color3.fromRGB(186, 224, 212),
	honey = Color3.fromRGB(252, 226, 166),
	timber = Color3.fromRGB(198, 154, 116),
	timberDark = Color3.fromRGB(156, 116, 84),
	floor = Color3.fromRGB(232, 208, 176),
	glass = Color3.fromRGB(206, 232, 240),
	fabric = Color3.fromRGB(248, 214, 214),
	linen = Color3.fromRGB(253, 250, 246),
	leaf = Color3.fromRGB(146, 200, 122),
	stone = Color3.fromRGB(232, 224, 210),
}

SafeZone.VOLUME = {
	size = Vector3.new(200, 140, 236),
	centreOffset = Vector3.new(0, 56, 30),
}

SafeZone.STAND = { x = 0, z = -10, yaw = -90, fit = 12, plushieYaw = 180 }

SafeZone.LAMPS = {
	{ x = 0, z = 0, y = 30, range = 42, brightness = 1.2, size = 5 },
	{ x = -26, z = -14, y = 20, range = 24, brightness = 0.7, size = 3.6 },
	{ x = 26, z = -14, y = 20, range = 24, brightness = 0.7, size = 3.6 },
	{ x = -26, z = 16, y = 20, range = 24, brightness = 0.7, size = 3.6 },
	{ x = 26, z = 16, y = 20, range = 24, brightness = 0.7, size = 3.6 },
	{ x = -9, z = -12, y = 9, range = 18, brightness = 0.5, size = 3.6, on = "loft" },
}

SafeZone.SPAWN_OFFSET = Vector3.new(0, 3.5, 2)
SafeZone.SPAWN_LOOK = Vector3.new(0, 0, -1)
SafeZone.DOORSTEP_OFFSET = Vector3.new(0, 3.5, 68)

export type Placement = {
	asset: string,
	x: number,
	z: number,
	fit: number,
	y: number?,
	yaw: number?,
	pitch: number?,
	roll: number?,
	sink: number?,
	name: string?,
	on: string?,
	drapeOver: string?,
}

SafeZone.FOOD = {
	ramen = 13,
	dangoPlatter = 15,
	dango = 10,
	onigiri = 9,
	pancakes = 10,
	yogurtBerry = 8,
	yogurtVanilla = 8,
}

SafeZone.SURFACE = {
	lowTable = 3.57,
	cloth = 3.82,
	picnicTable = 3.08,
}

SafeZone.interior = {
	{ asset = "lowTable", x = 0, z = -24, fit = 13, name = "LowTable" },
	{ asset = "tableCloth", x = 0, z = -24, fit = 14.5, y = SafeZone.SURFACE.lowTable, drapeOver = "LowTable" },
	{ asset = "floorCushion", x = -9, z = -24, fit = 5, yaw = 90 },
	{ asset = "floorCushion", x = 9, z = -24, fit = 5, yaw = -90 },
	{ asset = "floorCushion", x = 0, z = -33, fit = 5, yaw = 180 },

	{ asset = "ramen", x = 0, z = -24, fit = SafeZone.FOOD.ramen, y = SafeZone.SURFACE.cloth },
	{ asset = "teaPot", x = -5.5, z = -18.5, fit = 4.5, y = SafeZone.SURFACE.cloth },
	{ asset = "teaCup", x = 4.5, z = -18, fit = 2.4, y = SafeZone.SURFACE.cloth },
	{ asset = "teaCup", x = 6, z = -19.5, fit = 2.4, y = SafeZone.SURFACE.cloth },

	{ asset = "dangoPlatter", x = 24, z = 10, fit = SafeZone.FOOD.dangoPlatter },
	{ asset = "onigiri", x = -16, z = 18, fit = SafeZone.FOOD.onigiri },
	{ asset = "kettle", x = 10, z = -40, fit = 5, yaw = 150 },
	{ asset = "gachaGuy", x = 34, z = -8, fit = 10, yaw = 90, name = "GachaGuy" },
	{ asset = "weaponsGachaGuy", x = 34, z = 8, fit = 10, yaw = 90, name = "WeaponsGachaGuy" },
} :: { Placement }

export type Furnishing = {
	kind: string,

	azimuth: number?,
	inset: number?,

	x: number?,
	z: number?,
	yaw: number?,
	y: number?,

	span: number?,
	from: number?,
	to: number?,
	on: string?,
	seed: number?,
}

SafeZone.FURNITURE = {
	{ kind = "hearth", azimuth = 150, inset = 2, span = 18, y = 16 },
	{ kind = "counter", azimuth = 250, inset = 2.5, span = 26, y = 15 },
	{ kind = "bookcase", azimuth = 197, inset = 2, span = 16, seed = 11, y = 14 },
	{ kind = "wardrobe", azimuth = 116, inset = 2, y = 18 },
	{ kind = "dresser", azimuth = 58, inset = 2, span = 14, y = 11 },
	{ kind = "genkan", x = 0, z = 45, span = 30 },
	{ kind = "crates", x = -44, z = 8, yaw = 285 },

	{ kind = "planter", x = 21, z = 33 },
	{ kind = "planter", x = -21, z = 33 },
	{ kind = "planter", x = 44, z = 10 },
	{ kind = "planter", x = -26, z = -40 },

	{ kind = "loftRug", x = -4, z = -26, span = 22, on = "loft" },
	{ kind = "sideTable", x = 4, z = -33, yaw = -90, on = "loft" },
	{ kind = "bookcase", x = -24, z = -30, yaw = 200, span = 12, seed = 29, y = 8, on = "loft" },
	{ kind = "plushPile", x = 9, z = -20, on = "loft" },
} :: { Furnishing }

SafeZone.WALL_ART = {
	{ kind = "frames", azimuth = -42, y = 13 },
	{ kind = "frames", azimuth = 42, y = 13 },
	{ kind = "clock", azimuth = 180, y = 21 },
	{ kind = "garland", from = -58, to = 58, y = 27 },
	{ kind = "garland", from = 122, to = 238, y = 19 },
} :: { Furnishing }

SafeZone.exterior = {
	{ asset = "sakuraTree", x = -58, z = 72, fit = 46, yaw = 25 },
	{ asset = "sakuraTree", x = 58, z = 72, fit = 46, yaw = -40 },
	{ asset = "sakuraTree", x = -60, z = -54, fit = 40, yaw = 150 },
	{ asset = "sakuraTree", x = 60, z = -54, fit = 40, yaw = -150 },

	{ asset = "lanternTall", x = -13, z = 99, fit = 22 },
	{ asset = "lanternTall", x = 13, z = 99, fit = 22 },
	{ asset = "mailBox", x = 19, z = 95, fit = 7, yaw = -20 },

	{ asset = "grassPatch", x = 40, z = 66, fit = 9, sink = 0.6 },
	{ asset = "grassPatch", x = 44.5, z = 68, fit = 7, yaw = 40, sink = 0.6 },

	{ asset = "picnicTable", x = 52, z = 56, fit = 12, yaw = -22 },
	{ asset = "dango", x = 52, z = 56, fit = SafeZone.FOOD.dango, y = SafeZone.SURFACE.picnicTable, yaw = -22 },

	{ asset = "yogurtVanilla", x = 42, z = 51, fit = SafeZone.FOOD.yogurtVanilla, pitch = 90 },
	{ asset = "pancakes", x = 66, z = 50, fit = SafeZone.FOOD.pancakes, yaw = 15 },
	{ asset = "yogurtBerry", x = 46, z = 68, fit = SafeZone.FOOD.yogurtBerry, yaw = -30 },

	{ asset = "shopBlue", x = -40, z = 100, fit = 20, yaw = 34 },
	{ asset = "shopRed", x = 40, z = 100, fit = 18, yaw = -34 },
} :: { Placement }

SafeZone.garden = {
	halfX = Streets.RING.halfX - Streets.WIDTH - FENCE_KERB,
	backZ = Streets.RING.southZ + Streets.WIDTH + FENCE_KERB,
	frontZ = Streets.RING.northZ - FENCE_KERB,
	sideGateZ = Streets.RING.gateZ,

	baseY = Constants.WORLD.TERRAIN_TOP - Constants.WORLD.PLATFORM_TOP,
	fenceHeight = 7.5,
	fencePost = FENCE_POST,
	postSpacing = 9,
	gateGap = Streets.HALF_WIDTH + FENCE_KERB,
	frontGateGap = Streets.NORTH_ROAD_HALF + FENCE_KERB,

	grassInset = 5,
	grassSpacing = 16,
	grassJitter = 5,
	grassFit = { 14, 20 },
}

function SafeZone.profile(t: number): (number, number)
	local dome = SafeZone.DOME
	local angle = t * math.pi / 2
	return dome.radius * math.cos(angle) ^ dome.bulge, dome.height * math.sin(angle)
end

function SafeZone.interiorRadiusAt(y: number): number
	local dome = SafeZone.DOME
	if y >= dome.height then
		return 0
	end
	local t = math.asin(math.clamp(y / dome.height, 0, 1)) / (math.pi / 2)
	local radius = select(1, SafeZone.profile(t))
	return math.max(radius - dome.wall, 0)
end

return SafeZone

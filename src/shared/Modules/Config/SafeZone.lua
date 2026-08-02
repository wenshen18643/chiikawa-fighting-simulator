local SafeZone = {}

SafeZone.DOME = {
	radius = 32,
	height = 37,
	wall = 2.2,
	rings = 16,
	segmentArc = 7.0,
	bulge = 0.86,
	overlap = 1.14,
}

SafeZone.FLOOR_Y = 0.75

SafeZone.OPENINGS = {
	{ name = "Door", azimuth = 0, halfAngle = 14, bottom = 0, top = 17.5, kind = "door" },
	{ name = "WindowE", azimuth = 76, halfAngle = 10, bottom = 7.5, top = 16.5, kind = "round" },
	{ name = "WindowW", azimuth = -76, halfAngle = 10, bottom = 7.5, top = 16.5, kind = "round" },
	{ name = "WindowN", azimuth = 180, halfAngle = 10, bottom = 7.5, top = 16.5, kind = "round" },
	{ name = "LoftWindow", azimuth = 0, halfAngle = 12, bottom = 21.5, top = 29, kind = "round" },
}

SafeZone.LOFT = {
	y = 18.5,
	slab = 0.8,
	frontZ = -4,
	inset = 2.6,
	strips = 20,
	railHeight = 4.2,
}

SafeZone.STAIR = {
	steps = 15,
	fromAzimuth = 128,
	sweep = 132,
	radius = 23.5,
	width = 7.5,
	length = 6.4,
}

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
	size = Vector3.new(184, 132, 212),
	centreOffset = Vector3.new(0, 52, 40),
}

SafeZone.SPAWN_OFFSET = Vector3.new(0, 3.5, -17)
SafeZone.DOORSTEP_OFFSET = Vector3.new(0, 3.5, 42)

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
	{ asset = "lowTable", x = 0, z = -3, fit = 13, name = "LowTable" },
	{ asset = "tableCloth", x = 0, z = -3, fit = 14.5, y = SafeZone.SURFACE.lowTable, drapeOver = "LowTable" },
	{ asset = "floorCushion", x = -9, z = -3, fit = 5, yaw = 90 },
	{ asset = "floorCushion", x = 9, z = -3, fit = 5, yaw = -90 },
	{ asset = "floorCushion", x = 0, z = -12, fit = 5, yaw = 180 },

	{ asset = "ramen", x = 0, z = -3, fit = SafeZone.FOOD.ramen, y = SafeZone.SURFACE.cloth },
	{ asset = "teaPot", x = -5.5, z = 2.5, fit = 4.5, y = SafeZone.SURFACE.cloth },
	{ asset = "teaCup", x = 4.5, z = 3, fit = 2.4, y = SafeZone.SURFACE.cloth },
	{ asset = "teaCup", x = 6, z = 1.5, fit = 2.4, y = SafeZone.SURFACE.cloth },

	{ asset = "dangoPlatter", x = 17, z = 10, fit = SafeZone.FOOD.dangoPlatter },
	{ asset = "onigiri", x = -16, z = 14, fit = SafeZone.FOOD.onigiri },
	{ asset = "kettle", x = -20, z = 3, fit = 5 },
} :: { Placement }

SafeZone.exterior = {
	{ asset = "sakuraTree", x = -42, z = 62, fit = 54, yaw = 25 },
	{ asset = "sakuraTree", x = 42, z = 62, fit = 50, yaw = -40 },
	{ asset = "sakuraTree", x = -26, z = -54, fit = 44, yaw = 150 },

	{ asset = "lanternTall", x = -13, z = 99, fit = 22 },
	{ asset = "lanternTall", x = 13, z = 99, fit = 22 },
	{ asset = "mailBox", x = 19, z = 95, fit = 7, yaw = -20 },

	{ asset = "laundryLine", x = -48, z = 8, fit = 30, yaw = 8 },

	{ asset = "wateringCan", x = 24, z = 36, fit = 5, yaw = 180, pitch = -35 },
	{ asset = "grassPatch", x = 24, z = 42, fit = 9, sink = 0.6 },
	{ asset = "grassPatch", x = 28.5, z = 44, fit = 7, yaw = 40, sink = 0.6 },

	{ asset = "picnicTable", x = 52, z = 56, fit = 12, yaw = -22 },
	{ asset = "dango", x = 52, z = 56, fit = SafeZone.FOOD.dango, y = SafeZone.SURFACE.picnicTable, yaw = -22 },

	{ asset = "yogurtVanilla", x = 42, z = 51, fit = SafeZone.FOOD.yogurtVanilla, pitch = 90 },
	{ asset = "pancakes", x = 66, z = 50, fit = SafeZone.FOOD.pancakes, yaw = 15 },
	{ asset = "yogurtBerry", x = 46, z = 68, fit = SafeZone.FOOD.yogurtBerry, yaw = -30 },

	{ asset = "shopBlue", x = -40, z = 100, fit = 20, yaw = 34 },
	{ asset = "shopRed", x = 40, z = 100, fit = 18, yaw = -34 },
} :: { Placement }

SafeZone.garden = {
	fenceInset = 8,
	fenceHeight = 5.5,
	postSpacing = 7.5,
	gateGap = 11,

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

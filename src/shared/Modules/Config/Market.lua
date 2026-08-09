local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)
local Market = {}

Market.CENTRE =
	Vector2.new((Streets.SQUARE.minX + Streets.SQUARE.maxX) / 2, (Streets.SQUARE.minZ + Streets.SQUARE.maxZ) / 2)

Market.HALF =
	Vector2.new((Streets.SQUARE.maxX - Streets.SQUARE.minX) / 2, (Streets.SQUARE.maxZ - Streets.SQUARE.minZ) / 2)

Market.TERRACE = 7

export type Placement = {
	asset: string,
	x: number,
	z: number,
	fit: number,
	yaw: number?,
	name: string?,
}

export type Stall = {
	style: string,
	x: number,
	z: number,
	yaw: number,
	name: string?,
}

export type StallStyle = {
	canopy: Color3,
	stripe: Color3,
	timber: Color3,
	trim: Color3,
	tile: Color3,
	roof: string,
	topper: string,
}

Market.UPGRADE_COUNTER = "UpgradeCounter"
Market.JOB_BOOTH = "JobBooth"

Market.FACE_SOUTH = 0
Market.FACE_NORTH = 180

Market.STALL = {
	width = 16,
	depth = 10,
	plinth = 0.6,
	counterHeight = 4.2,
	counterDepth = 2.4,
	backHeight = 7.6,
	sideHeight = 5.2,
	postThickness = 0.9,
	postHeight = 8,
	awningDepth = 5,
	awningPitch = 16,
	awningStripes = 6,
	signHeight = 2.2,
	roofOverhang = 1.6,
	roofRise = 2.2,
	roofThickness = 0.5,
	roofSegments = 5,
}

Market.STALL_STYLES = {
	ramen = {
		canopy = Color3.fromRGB(214, 78, 74),
		stripe = Color3.fromRGB(252, 240, 224),
		timber = Color3.fromRGB(104, 62, 44),
		trim = Color3.fromRGB(247, 200, 96),
		tile = Color3.fromRGB(150, 66, 62),
		roof = "pagoda",
		topper = "lantern",
	},
	sweets = {
		canopy = Color3.fromRGB(246, 138, 178),
		stripe = Color3.fromRGB(255, 250, 250),
		timber = Color3.fromRGB(214, 186, 156),
		trim = Color3.fromRGB(150, 224, 206),
		tile = Color3.fromRGB(226, 118, 158),
		roof = "arch",
		topper = "ball",
	},
	tea = {
		canopy = Color3.fromRGB(92, 168, 122),
		stripe = Color3.fromRGB(246, 240, 220),
		timber = Color3.fromRGB(176, 150, 100),
		trim = Color3.fromRGB(246, 196, 106),
		tile = Color3.fromRGB(68, 132, 96),
		roof = "gable",
		topper = "pennant",
	},
	fish = {
		canopy = Color3.fromRGB(74, 146, 206),
		stripe = Color3.fromRGB(250, 252, 255),
		timber = Color3.fromRGB(128, 130, 134),
		trim = Color3.fromRGB(250, 146, 110),
		tile = Color3.fromRGB(54, 112, 166),
		roof = "gable",
		topper = "pennant",
	},
	flower = {
		canopy = Color3.fromRGB(176, 146, 224),
		stripe = Color3.fromRGB(255, 250, 255),
		timber = Color3.fromRGB(216, 190, 160),
		trim = Color3.fromRGB(244, 158, 186),
		tile = Color3.fromRGB(144, 118, 190),
		roof = "arch",
		topper = "ball",
	},
	toy = {
		canopy = Color3.fromRGB(250, 198, 72),
		stripe = Color3.fromRGB(250, 138, 62),
		timber = Color3.fromRGB(162, 96, 68),
		trim = Color3.fromRGB(126, 200, 234),
		tile = Color3.fromRGB(206, 152, 48),
		roof = "pagoda",
		topper = "pennant",
	},
	upgrade = {
		canopy = Color3.fromRGB(240, 170, 90),
		stripe = Color3.fromRGB(252, 240, 220),
		timber = Color3.fromRGB(104, 62, 44),
		trim = Color3.fromRGB(246, 178, 158),
		tile = Color3.fromRGB(196, 130, 62),
		roof = "pagoda",
		topper = "lantern",
	},
	work = {
		canopy = Color3.fromRGB(122, 158, 96),
		stripe = Color3.fromRGB(246, 240, 220),
		timber = Color3.fromRGB(104, 62, 44),
		trim = Color3.fromRGB(246, 196, 106),
		tile = Color3.fromRGB(94, 124, 74),
		roof = "gable",
		topper = "lantern",
	},
} :: { [string]: StallStyle }

local NORTH_ROW = 27
local SOUTH_ROW = -27

Market.STALLS = {
	{ style = "upgrade", x = -30, z = NORTH_ROW, yaw = Market.FACE_SOUTH, name = Market.UPGRADE_COUNTER },
	{ style = "work", x = 30, z = NORTH_ROW, yaw = Market.FACE_SOUTH, name = Market.JOB_BOOTH },

	{ style = "ramen", x = -114, z = NORTH_ROW, yaw = Market.FACE_SOUTH },
	{ style = "sweets", x = -72, z = NORTH_ROW, yaw = Market.FACE_SOUTH },
	{ style = "fish", x = 72, z = NORTH_ROW, yaw = Market.FACE_SOUTH },
	{ style = "flower", x = 114, z = NORTH_ROW, yaw = Market.FACE_SOUTH },

	{ style = "toy", x = -114, z = SOUTH_ROW, yaw = Market.FACE_NORTH },
	{ style = "tea", x = -76, z = SOUTH_ROW, yaw = Market.FACE_NORTH },
	{ style = "ramen", x = -38, z = SOUTH_ROW, yaw = Market.FACE_NORTH },
	{ style = "sweets", x = 0, z = SOUTH_ROW, yaw = Market.FACE_NORTH },
	{ style = "fish", x = 38, z = SOUTH_ROW, yaw = Market.FACE_NORTH },
	{ style = "flower", x = 76, z = SOUTH_ROW, yaw = Market.FACE_NORTH },
	{ style = "tea", x = 114, z = SOUTH_ROW, yaw = Market.FACE_NORTH },
} :: { Stall }

Market.props = {
	{ asset = "picnicTable", x = -56, z = 0, fit = 9 },
	{ asset = "picnicTable", x = 56, z = 0, fit = 9 },

	{ asset = "lanternTall", x = -136, z = 30, fit = 22 },
	{ asset = "lanternTall", x = 136, z = 30, fit = 22 },
	{ asset = "lanternTall", x = -136, z = -30, fit = 22 },
	{ asset = "lanternTall", x = 136, z = -30, fit = 22 },
	{ asset = "lanternTall", x = -96, z = 0, fit = 22 },
	{ asset = "lanternTall", x = 96, z = 0, fit = 22 },
} :: { Placement }

Market.beast = { asset = "yoroiBeast", x = 48, z = 14, fit = 7, yaw = 200 } :: Placement

Market.YOROI = {
	booth = Market.JOB_BOOTH,
	alongCounter = 0,
	insideDepth = 0.8,
	height = 8.5,
}

function Market.yawFor(row: Placement): number
	return row.yaw or 0
end

return Market

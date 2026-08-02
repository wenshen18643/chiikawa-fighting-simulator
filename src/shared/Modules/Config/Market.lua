local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)

local Market = {}

Market.CENTRE =
	Vector2.new((Streets.SQUARE.minX + Streets.SQUARE.maxX) / 2, (Streets.SQUARE.minZ + Streets.SQUARE.maxZ) / 2)

export type Placement = {
	asset: string,
	x: number,
	z: number,
	fit: number,
	yaw: number?,
	name: string?,
}

Market.UPGRADE_COUNTER = "UpgradeCounter"
Market.JOB_BOOTH = "JobBooth"

Market.stalls = {
	{ asset = "shopStall", x = -28, z = 24, fit = 13, yaw = 0, name = Market.UPGRADE_COUNTER },
	{ asset = "shopStall", x = 28, z = 24, fit = 13, yaw = 180, name = Market.JOB_BOOTH },

	{ asset = "shopBlue", x = -40, z = -8, fit = 20, yaw = 0 },
	{ asset = "shopRed", x = 40, z = -8, fit = 18, yaw = 180 },

	{ asset = "shopRed", x = -26, z = -38, fit = 18, yaw = -90 },
	{ asset = "shopStall", x = 0, z = -40, fit = 12, yaw = -90 },
	{ asset = "shopBlue", x = 26, z = -38, fit = 18, yaw = -90 },

	{ asset = "lanternTall", x = -40, z = 40, fit = 22 },
	{ asset = "lanternTall", x = 40, z = 40, fit = 22 },
	{ asset = "lanternTall", x = -40, z = -40, fit = 22 },
	{ asset = "lanternTall", x = 40, z = -40, fit = 22 },

	{ asset = "mailBox", x = 16, z = 42, fit = 7, yaw = 200 },
} :: { Placement }

Market.beast = { asset = "yoroiBeast", x = 42, z = 14, fit = 7, yaw = 200 } :: Placement

Market.YOROI = {
	booth = Market.JOB_BOOTH,
	alongCounter = 1.7,
	outFromCounter = 0.35,
	facingOffset = 180,
	height = 8.5,
}

return Market

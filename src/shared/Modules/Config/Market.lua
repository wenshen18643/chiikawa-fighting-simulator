local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)
local Market = {}

Market.CENTRE =
	Vector2.new((Streets.SQUARE.minX + Streets.SQUARE.maxX) / 2, (Streets.SQUARE.minZ + Streets.SQUARE.maxZ) / 2)

Market.HALF =
	Vector2.new((Streets.SQUARE.maxX - Streets.SQUARE.minX) / 2, (Streets.SQUARE.maxZ - Streets.SQUARE.minZ) / 2)

Market.ENTRANCE = Vector2.new(
	(Streets.PAVING_BY_NAME.MarketSpur.minX + Streets.PAVING_BY_NAME.MarketSpur.maxX) / 2 - Market.CENTRE.X,
	Streets.SQUARE.maxZ - Market.CENTRE.Y
)

Market.STALL_FRONT_OFFSET = -90

Market.TERRACE = 7

export type Placement = {
	asset: string,
	x: number,
	z: number,
	fit: number,
	yaw: number?,
	faceEntrance: boolean?,
	name: string?,
}

Market.UPGRADE_COUNTER = "UpgradeCounter"
Market.JOB_BOOTH = "JobBooth"

Market.stalls = {
	{ asset = "shopStall", x = -28, z = 24, fit = 13, faceEntrance = true, name = Market.UPGRADE_COUNTER },
	{ asset = "shopStall", x = 28, z = 24, fit = 13, faceEntrance = true, name = Market.JOB_BOOTH },

	{ asset = "shopBlue", x = -40, z = -8, fit = 20, faceEntrance = true },
	{ asset = "shopRed", x = 40, z = -8, fit = 18, faceEntrance = true },

	{ asset = "shopRed", x = -26, z = -38, fit = 18, faceEntrance = true },
	{ asset = "shopStall", x = 0, z = -40, fit = 12, faceEntrance = true },
	{ asset = "shopBlue", x = 26, z = -38, fit = 18, faceEntrance = true },

	{ asset = "lanternTall", x = -40, z = 40, fit = 22 },
	{ asset = "lanternTall", x = 40, z = 40, fit = 22 },
	{ asset = "lanternTall", x = -40, z = -40, fit = 22 },
	{ asset = "lanternTall", x = 40, z = -40, fit = 22 },

	{ asset = "mailBox", x = 16, z = 34, fit = 7, yaw = 200 },
} :: { Placement }

Market.beast = { asset = "yoroiBeast", x = 42, z = 14, fit = 7, yaw = 200 } :: Placement

Market.YOROI = {
	booth = Market.JOB_BOOTH,
	alongCounter = 0,
	outFromCounter = 1.45,
	facingOffset = -Market.STALL_FRONT_OFFSET,
	height = 8.5,
}

function Market.faceEntranceYaw(x: number, z: number): number
	local span = Market.ENTRANCE - Vector2.new(x, z)
	if span.Magnitude < 0.01 then
		return Market.STALL_FRONT_OFFSET
	end
	local direction = span.Unit
	return math.deg(math.atan2(-direction.X, -direction.Y)) + Market.STALL_FRONT_OFFSET
end

function Market.yawFor(row: Placement): number
	if row.faceEntrance then
		return Market.faceEntranceYaw(row.x, row.z)
	end
	return row.yaw or 0
end

return Market

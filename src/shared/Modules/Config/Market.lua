--[[
	The market square, as data.

	Two counters and a ring of shopfronts around the paving Streets already lays
	down in C3. Everything here is an offset from the SQUARE's centre rather than
	a world coordinate, so moving the square in Streets.lua moves the market with
	it -- the previous arrangement, a shop arc written in world coordinates in
	Town.lua, is exactly the thing that ended up running through the kitchen.

	`fit` is the target size of the model's LARGEST dimension, the same single
	sizing control the safe zone uses. `yaw` is degrees; a stall serves along its
	own +X, so a stall on the west side of the square wants yaw 90 to face in.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)

local Market = {}

--[[
	The square is authored in Streets as a rectangle, because that is what the
	paving pass needs. Everything below is an offset from its CENTRE, so the
	square can be moved or resized in one place and the stalls follow.
]]
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

--[[
	The layout.

	The spur comes down off the ring and enters at local (0, +48) -- dead centre
	of the north edge, in a corridor fourteen studs wide. NOTHING is placed in
	that corridor: you walk in off the high street and the two counters are
	immediately left and right of you, facing each other across the way in.

	Serving direction, derived once so the yaws below are not guesses. A stall
	serves along its own +X, and CFrame.Angles(0, t, 0) sends +X to
	(cos t, 0, -sin t). So t = 0 serves east, 180 serves west, -90 serves north
	and 90 serves south. Every stall here faces the middle of the square.
]]
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

-- The beast sits out of the way of the counter its keeper works.
Market.beast = { asset = "yoroiBeast", x = 42, z = 14, fit = 7, yaw = 200 } :: Placement

--[[
	Where the attendant stands, in units of the booth's own half-extents rather
	than in studs. `alongCounter` runs down the booth's long axis; past 1.0 is past
	the end of it. `outFromCounter` runs across the serving side.

	Written this way so resizing or re-yawing the booth carries the attendant with
	it. The rig faces its own -X while the booth serves its own +X, which is what
	`facingOffset` of 180 is correcting.
]]
Market.YOROI = {
	booth = Market.JOB_BOOTH,
	alongCounter = 1.7,
	outFromCounter = 0.35,
	facingOffset = 180,
	height = 8.5,
}

return Market

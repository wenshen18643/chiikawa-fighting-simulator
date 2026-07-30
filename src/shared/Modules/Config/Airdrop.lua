--!strict

local Airdrop = {}

Airdrop.STEP = 1 / 20

Airdrop.CRUISE_HEIGHT = 210
Airdrop.BELLY = 9
Airdrop.APPROACH = 460
Airdrop.DEPART = 380
Airdrop.PLANE_SPEED = 105

Airdrop.FREEFALL = 0.55
Airdrop.GRAVITY = 110
Airdrop.CHUTE_SPEED = 34
Airdrop.CHUTE_BRAKE = 5
Airdrop.POP_TIME = 0.28

Airdrop.SWAY = 7
Airdrop.SWAY_SPEED = 1.5
Airdrop.SWAY_FADE = 60

Airdrop.CANOPY_SPAN = 1.9
Airdrop.CANOPY_MIN = 14
Airdrop.CORD_DROP = 0.7

Airdrop.PLANE_COLOR = Color3.fromRGB(250, 246, 240)
Airdrop.PLANE_TRIM = Color3.fromRGB(244, 158, 172)
Airdrop.PLANE_METAL = Color3.fromRGB(206, 214, 226)
Airdrop.PROP_COLOR = Color3.fromRGB(252, 226, 166)
Airdrop.CORD_COLOR = Color3.fromRGB(238, 230, 216)
Airdrop.VENT_COLOR = Color3.fromRGB(253, 250, 246)

Airdrop.CANOPY_COLORS = {
	Color3.fromRGB(244, 158, 172),
	Color3.fromRGB(150, 200, 230),
	Color3.fromRGB(250, 210, 120),
	Color3.fromRGB(168, 220, 176),
	Color3.fromRGB(206, 172, 226),
}

return Airdrop

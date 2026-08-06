--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinLook = require(Shared.Modules.SkinLook)
local SkinLooks = {}

export type Entry = {
	id: string,
	name: string,
	characterId: string,
	rarity: string,
	showcase: boolean?,
	look: SkinLook.Look,
}

local BALL = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local MARBLE = Enum.Material.Marble
local WOOD = Enum.Material.Wood
local FORCE = Enum.Material.ForceField
local GRASS = Enum.Material.Grass
local SLATE = Enum.Material.Slate
local ICE = Enum.Material.Ice

local function C(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function P(
	anchor: string,
	size: Vector3,
	offset: Vector3,
	colour: Color3,
	extra: { [string]: any }?
): SkinLook.PartSpec
	local spec: { [string]: any } = {
		anchor = anchor,
		size = size,
		offset = offset,
		color = colour,
	}
	if extra then
		for key, value in extra do
			spec[key] = value
		end
	end
	return (spec :: any) :: SkinLook.PartSpec
end

local function ring(anchor: string, thickness: number, radius: number, height: number, colour: Color3, spin: number, extra: { [string]: any }?): SkinLook.PartSpec
	local merged: { [string]: any } = {
		shape = BALL,
		spin = spin,
		orbit = { radius = radius, height = height, count = 12 },
	}
	if extra then
		for key, value in extra do
			merged[key] = value
		end
	end
	return P(anchor, Vector3.one * thickness, Vector3.zero, colour, merged)
end

local ENTRIES: { Entry } = {
	{
		id = "chiikawa_common_01",
		name = "Soot Smudge",
		characterId = "chiikawa",
		rarity = "common",
		look = {
			palette = { all = C(196, 190, 188), ears = C(132, 126, 126), legs = C(150, 144, 144) },
		},
	},
	{
		id = "chiikawa_common_02",
		name = "Milk Tea",
		characterId = "chiikawa",
		rarity = "common",
		look = {
			palette = { all = C(232, 208, 176), ears = C(198, 164, 126) },
		},
	},
	{
		id = "chiikawa_common_03",
		name = "Matcha Dust",
		characterId = "chiikawa",
		rarity = "common",
		look = {
			palette = { all = C(214, 226, 180), legs = C(160, 186, 126), ears = C(178, 200, 140) },
		},
	},

	{
		id = "chiikawa_uncommon_01",
		name = "Strawberry Cap",
		characterId = "chiikawa",
		rarity = "uncommon",
		look = {
			palette = { all = C(252, 224, 226), ears = C(240, 158, 168), limbs = C(246, 190, 196) },
			parts = {
				P("head", Vector3.new(0.72, 0.34, 0.72), Vector3.new(0, 0.66, 0), C(226, 66, 78), { shape = BALL }),
				P("head", Vector3.new(0.1, 0.16, 0.1), Vector3.new(0, 0.86, 0), C(120, 170, 96)),
			},
		},
	},
	{
		id = "chiikawa_uncommon_02",
		name = "Sakura Ribbon",
		characterId = "chiikawa",
		rarity = "uncommon",
		look = {
			palette = { all = C(255, 240, 244), ears = C(248, 190, 206) },
			parts = {
				P("earL", Vector3.new(1.5, 0.9, 0.5), Vector3.new(-0.6, 0.4, 0), C(244, 132, 160), { angles = Vector3.new(0, 0, 22) }),
				P("earL", Vector3.new(0.5, 0.5, 0.7), Vector3.new(-0.1, 0.4, 0), C(228, 96, 130), { shape = BALL }),
			},
		},
	},
	{
		id = "chiikawa_uncommon_03",
		name = "Patch Job",
		characterId = "chiikawa",
		rarity = "uncommon",
		look = {
			palette = { all = C(250, 244, 232), limbs = C(226, 214, 194) },
			parts = {
				P("head", Vector3.new(0.42, 0.14, 0.06), Vector3.new(-0.3, 0.22, -0.52), C(255, 252, 246), { angles = Vector3.new(0, 0, -18) }),
				P("head", Vector3.new(0.42, 0.14, 0.06), Vector3.new(-0.3, 0.22, -0.52), C(255, 252, 246), { angles = Vector3.new(0, 0, 18) }),
			},
		},
	},

	{
		id = "chiikawa_rare_01",
		name = "Frost Nibbler",
		characterId = "chiikawa",
		rarity = "rare",
		look = {
			palette = { all = C(206, 234, 248), ears = C(150, 200, 232), limbs = C(178, 218, 242) },
			material = { head = ICE, ears = GLASS },
			reflectance = { head = 0.18 },
			parts = {
				P("head", Vector3.new(0.1, 0.5, 0.1), Vector3.new(-0.22, 0.72, 0), C(226, 246, 255), { angles = Vector3.new(0, 0, -16), material = GLASS }),
				P("head", Vector3.new(0.12, 0.66, 0.12), Vector3.new(0, 0.8, 0), C(226, 246, 255), { material = GLASS }),
				P("head", Vector3.new(0.1, 0.44, 0.1), Vector3.new(0.22, 0.68, 0), C(226, 246, 255), { angles = Vector3.new(0, 0, 16), material = GLASS }),
			},
			aura = {
				particle = { color = C(226, 246, 255), rate = 6, size = 0.3, speed = 1.2, lifetime = 1.6, spread = 40 },
			},
		},
	},
	{
		id = "chiikawa_rare_02",
		name = "Lantern Watch",
		characterId = "chiikawa",
		rarity = "rare",
		look = {
			palette = { all = C(246, 224, 186), ears = C(206, 150, 96), limbs = C(226, 190, 140) },
			material = { limbs = FABRIC },
			parts = {
				P("armR", Vector3.new(0.5, 1.4, 0.5), Vector3.new(0.2, -0.9, 0), C(96, 74, 62)),
				P("armR", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0.2, -1.7, 0), C(255, 214, 130), { material = NEON }),
				P("head", Vector3.new(0.66, 0.16, 0.66), Vector3.new(0, 0.6, 0), C(120, 92, 74)),
			},
			aura = {
				particle = { color = C(255, 198, 110), rate = 5, size = 0.22, speed = 1.4, lifetime = 1.4, spread = 30 },
			},
		},
	},
	{
		id = "chiikawa_rare_03",
		name = "Mossback",
		characterId = "chiikawa",
		rarity = "rare",
		look = {
			palette = { all = C(178, 196, 148), ears = C(120, 146, 96), limbs = C(150, 174, 118) },
			material = { body = GRASS, head = GRASS },
			parts = {
				P("head", Vector3.new(0.16, 0.4, 0.16), Vector3.new(-0.24, 0.7, -0.1), C(126, 176, 100), { angles = Vector3.new(-14, 0, -20) }),
				P("head", Vector3.new(0.18, 0.5, 0.18), Vector3.new(0, 0.74, 0.06), C(148, 196, 116), { angles = Vector3.new(10, 0, 0) }),
				P("head", Vector3.new(0.14, 0.36, 0.14), Vector3.new(0.24, 0.68, -0.08), C(126, 176, 100), { angles = Vector3.new(-12, 0, 18) }),
				P("body", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.34, 0.2, -0.4), C(230, 236, 210), { shape = BALL }),
			},
			aura = {
				particle = { color = C(206, 232, 172), rate = 5, size = 0.24, speed = 0.8, lifetime = 2, spread = 55 },
			},
		},
	},

	{
		id = "chiikawa_epic_01",
		name = "Clockwork Courier",
		characterId = "chiikawa",
		rarity = "epic",
		look = {
			palette = { all = C(206, 168, 108), ears = C(150, 116, 70), limbs = C(126, 100, 64) },
			material = { all = METAL },
			reflectance = { body = 0.22, head = 0.16 },
			parts = {
				P("body", Vector3.new(0.18, 0.9, 0.9), Vector3.new(0, 0.06, -0.62), C(168, 128, 76), { shape = CYLINDER, angles = Vector3.new(0, 90, 0), material = METAL }),
				P("body", Vector3.new(0.24, 0.5, 0.5), Vector3.new(0, 0.06, -0.78), C(255, 206, 120), { shape = CYLINDER, angles = Vector3.new(0, 90, 0), material = NEON }),
				P("head", Vector3.new(0.06, 0.5, 0.06), Vector3.new(-0.26, 0.78, 0), C(96, 78, 56), { angles = Vector3.new(0, 0, -14) }),
				P("head", Vector3.new(0.06, 0.5, 0.06), Vector3.new(0.26, 0.78, 0), C(96, 78, 56), { angles = Vector3.new(0, 0, 14) }),
				P("head", Vector3.new(0.16, 0.16, 0.16), Vector3.new(-0.26, 1.02, 0), C(255, 206, 120), { shape = BALL, material = NEON }),
				P("head", Vector3.new(1.02, 0.2, 1.02), Vector3.new(0, 0.12, 0), C(120, 96, 66), { material = METAL }),
			},
			aura = {
				particle = { color = C(255, 214, 140), rate = 6, size = 0.26, speed = 1.1, lifetime = 1.5, spread = 35 },
				light = { color = C(255, 196, 104), brightness = 1.6, range = 12 },
			},
			scale = 1.04,
		},
	},
	{
		id = "chiikawa_epic_02",
		name = "Tide Caller",
		characterId = "chiikawa",
		rarity = "epic",
		look = {
			palette = { all = C(96, 168, 178), ears = C(56, 116, 132), limbs = C(72, 142, 158) },
			material = { head = GLASS, ears = GLASS },
			reflectance = { head = 0.24 },
			parts = {
				P("head", Vector3.new(0.12, 0.62, 0.12), Vector3.new(-0.4, 0.6, -0.16), C(140, 232, 226), { angles = Vector3.new(-18, 0, -34), material = GLASS }),
				P("head", Vector3.new(0.12, 0.78, 0.12), Vector3.new(-0.2, 0.74, -0.08), C(178, 244, 236), { angles = Vector3.new(-8, 0, -16), material = GLASS }),
				P("head", Vector3.new(0.12, 0.78, 0.12), Vector3.new(0.2, 0.74, -0.08), C(178, 244, 236), { angles = Vector3.new(-8, 0, 16), material = GLASS }),
				P("head", Vector3.new(0.12, 0.62, 0.12), Vector3.new(0.4, 0.6, -0.16), C(140, 232, 226), { angles = Vector3.new(-18, 0, 34), material = GLASS }),
				P("armL", Vector3.new(1.3, 0.7, 1.3), Vector3.new(-0.2, 0.4, 0), C(226, 246, 240), { shape = BALL }),
				P("armR", Vector3.new(1.3, 0.7, 1.3), Vector3.new(0.2, 0.4, 0), C(226, 246, 240), { shape = BALL }),
			},
			aura = {
				particle = { color = C(178, 244, 236), rate = 7, size = 0.3, speed = 1, lifetime = 2.2, spread = 45 },
				light = { color = C(112, 216, 224), brightness = 1.8, range = 14 },
			},
			scale = 1.03,
		},
	},
	{
		id = "chiikawa_epic_03",
		name = "Ember Mantle",
		characterId = "chiikawa",
		rarity = "epic",
		showcase = true,
		look = {
			palette = { all = C(58, 52, 56), ears = C(226, 106, 54), limbs = C(240, 128, 60) },
			material = { limbs = NEON, ears = NEON, body = SLATE },
			parts = {
				P("body", Vector3.new(1.2, 1.05, 0.16), Vector3.new(0, 0.02, -0.58), C(84, 40, 36), { material = FABRIC }),
				P("body", Vector3.new(0.9, 0.5, 0.14), Vector3.new(-0.36, -0.44, -0.56), C(112, 48, 40), { angles = Vector3.new(0, 0, 12), material = FABRIC }),
				P("body", Vector3.new(0.9, 0.5, 0.14), Vector3.new(0.36, -0.44, -0.56), C(112, 48, 40), { angles = Vector3.new(0, 0, -12), material = FABRIC }),
				P("head", Vector3.new(0.14, 0.66, 0.14), Vector3.new(-0.32, 0.74, -0.06), C(255, 148, 72), { angles = Vector3.new(-10, 0, -26), material = NEON }),
				P("head", Vector3.new(0.14, 0.66, 0.14), Vector3.new(0.32, 0.74, -0.06), C(255, 148, 72), { angles = Vector3.new(-10, 0, 26), material = NEON }),
			},
			aura = {
				particle = { color = C(255, 152, 74), rate = 8, size = 0.28, speed = 1.8, lifetime = 1.3, spread = 30 },
				light = { color = C(255, 130, 60), brightness = 2.2, range = 15 },
			},
			scale = 1.05,
		},
	},

	{
		id = "chiikawa_legendary_01",
		name = "Starlit Sovereign",
		characterId = "chiikawa",
		rarity = "legendary",
		look = {
			palette = { all = C(255, 252, 240), ears = C(255, 226, 150), limbs = C(255, 240, 200) },
			material = { body = FORCE, head = FORCE },
			reflectance = { head = 0.3 },
			parts = {
				P("head", Vector3.new(0.08, 0.9, 0.08), Vector3.new(0, 0.92, 0), C(255, 214, 118), { material = NEON }),
				P("head", Vector3.new(0.08, 0.7, 0.08), Vector3.new(-0.28, 0.82, 0), C(255, 214, 118), { angles = Vector3.new(0, 0, -16), material = NEON }),
				P("head", Vector3.new(0.08, 0.7, 0.08), Vector3.new(0.28, 0.82, 0), C(255, 214, 118), { angles = Vector3.new(0, 0, 16), material = NEON }),
				P("head", Vector3.new(0.08, 0.52, 0.08), Vector3.new(-0.48, 0.7, 0), C(255, 232, 168), { angles = Vector3.new(0, 0, -32), material = NEON }),
				P("head", Vector3.new(0.08, 0.52, 0.08), Vector3.new(0.48, 0.7, 0), C(255, 232, 168), { angles = Vector3.new(0, 0, 32), material = NEON }),
				P("head", Vector3.new(1.16, 0.14, 1.16), Vector3.new(0, 0.56, 0), C(255, 198, 96), { material = NEON }),
				P("head", Vector3.new(0.14, 0.14, 0.14), Vector3.new(0, 0.4, 0), C(255, 246, 210), {
					shape = BALL,
					material = NEON,
					spin = 52,
					orbit = { radius = 0.86, height = 0.5, count = 5 },
				}),
			},
			aura = {
				particle = { color = C(255, 236, 176), rate = 9, size = 0.32, speed = 1.2, lifetime = 2.4, spread = 50 },
				light = { color = C(255, 214, 128), brightness = 2.6, range = 18 },
				trail = { color = C(255, 226, 150), lifetime = 0.55 },
				highlight = { fill = C(255, 236, 176), outline = C(255, 206, 108), fillTransparency = 0.86 },
			},
			scale = 1.1,
		},
	},
	{
		id = "chiikawa_legendary_02",
		name = "Void Kitten",
		characterId = "chiikawa",
		rarity = "legendary",
		look = {
			palette = { all = C(26, 22, 34), ears = C(150, 96, 226), limbs = C(46, 38, 62) },
			material = { body = SLATE, ears = NEON },
			parts = {
				P("head", Vector3.new(0.86, 0.1, 0.24), Vector3.new(0, 0.1, -0.44), C(178, 118, 255), { material = NEON }),
				ring("body", 0.16, 1.15, 0.1, C(158, 100, 246), 34, { angles = Vector3.new(0, 0, 8) }),
				ring("body", 0.13, 1.55, -0.15, C(122, 74, 210), -22, { angles = Vector3.new(0, 0, -6) }),
				ring("body", 0.1, 1.9, 0.35, C(96, 58, 174), 16),
			},
			aura = {
				particle = { color = C(166, 110, 250), rate = 7, size = 0.3, speed = 0.9, lifetime = 2.6, spread = 60 },
				light = { color = C(140, 88, 236), brightness = 2.2, range = 16 },
				trail = { color = C(140, 88, 236), lifetime = 0.7 },
				highlight = { fill = C(96, 58, 174), outline = C(178, 118, 255), fillTransparency = 0.78 },
			},
			scale = 1.05,
		},
	},
	{
		id = "chiikawa_legendary_03",
		name = "Petalfall Spirit",
		characterId = "chiikawa",
		rarity = "legendary",
		showcase = true,
		look = {
			palette = { all = C(255, 226, 236), ears = C(248, 158, 190), limbs = C(252, 200, 220) },
			material = { all = FORCE },
			parts = {
				P("head", Vector3.new(0.2, 0.06, 0.14), Vector3.new(0, 0.2, 0), C(255, 168, 200), {
					spin = 26,
					orbit = { radius = 1.5, height = 0.2, count = 10 },
					angles = Vector3.new(0, 0, 28),
				}),
				P("body", Vector3.new(0.22, 0.06, 0.16), Vector3.new(0, 0, 0), C(255, 200, 222), {
					spin = -18,
					orbit = { radius = 1.9, height = -0.3, count = 6 },
					angles = Vector3.new(0, 0, -20),
				}),
			},
			aura = {
				particle = { color = C(255, 190, 214), rate = 10, size = 0.34, speed = 0.7, lifetime = 3, spread = 70 },
				light = { color = C(255, 176, 206), brightness = 1.9, range = 15 },
				trail = { color = C(255, 200, 222), lifetime = 0.8 },
				highlight = { fill = C(255, 226, 236), outline = C(255, 158, 194), fillTransparency = 0.72 },
			},
			scale = 1.08,
		},
	},

	{
		id = "hachiware_common_01",
		name = "Chalk Sketch",
		characterId = "hachiware",
		rarity = "common",
		look = {
			palette = { all = C(238, 236, 232), body = C(206, 204, 202), limbs = C(222, 220, 216) },
		},
	},
	{
		id = "hachiware_common_02",
		name = "Denim Day",
		characterId = "hachiware",
		rarity = "common",
		look = {
			palette = { body = C(58, 82, 128), arms = C(108, 138, 186), legs = C(78, 104, 152), head = C(226, 230, 238) },
		},
	},
	{
		id = "hachiware_common_03",
		name = "Autumn Knit",
		characterId = "hachiware",
		rarity = "common",
		look = {
			palette = { body = C(168, 82, 54), arms = C(212, 158, 70), legs = C(122, 88, 58), head = C(240, 226, 206) },
			material = { body = FABRIC },
		},
	},

	{
		id = "hachiware_uncommon_01",
		name = "Scout Scarf",
		characterId = "hachiware",
		rarity = "uncommon",
		look = {
			palette = { body = C(126, 132, 96), arms = C(158, 162, 124), legs = C(96, 100, 74), head = C(236, 232, 220) },
			material = { body = FABRIC },
			parts = {
				P("body", Vector3.new(1.14, 0.2, 1.2), Vector3.new(0, 0.44, 0), C(206, 86, 74), { material = FABRIC }),
				P("body", Vector3.new(0.24, 0.5, 0.16), Vector3.new(-0.24, 0.14, -0.56), C(206, 86, 74), { material = FABRIC }),
			},
		},
	},
	{
		id = "hachiware_uncommon_02",
		name = "Paper Crown",
		characterId = "hachiware",
		rarity = "uncommon",
		look = {
			palette = { all = C(248, 244, 234), body = C(226, 220, 206), limbs = C(238, 232, 220) },
			parts = {
				P("head", Vector3.new(1.05, 0.18, 1.05), Vector3.new(0, 0.56, 0), C(252, 238, 196)),
				P("head", Vector3.new(0.14, 0.3, 0.14), Vector3.new(0, 0.74, 0.4), C(252, 238, 196), { angles = Vector3.new(16, 0, 0) }),
				P("head", Vector3.new(0.14, 0.3, 0.14), Vector3.new(-0.36, 0.74, 0.18), C(252, 238, 196), { angles = Vector3.new(10, 0, -14) }),
				P("head", Vector3.new(0.14, 0.3, 0.14), Vector3.new(0.36, 0.74, 0.18), C(252, 238, 196), { angles = Vector3.new(10, 0, 14) }),
			},
		},
	},
	{
		id = "hachiware_uncommon_03",
		name = "Bee Stripes",
		characterId = "hachiware",
		rarity = "uncommon",
		look = {
			palette = { body = C(248, 200, 62), arms = C(42, 38, 36), legs = C(42, 38, 36), head = C(250, 230, 168) },
			parts = {
				P("body", Vector3.new(1.06, 0.16, 1.06), Vector3.new(0, 0.2, 0), C(42, 38, 36)),
				P("body", Vector3.new(1.06, 0.16, 1.06), Vector3.new(0, -0.12, 0), C(42, 38, 36)),
				P("body", Vector3.new(0.5, 0.7, 0.08), Vector3.new(-0.42, 0.3, -0.6), C(236, 244, 250), { transparency = 0.45, angles = Vector3.new(0, 0, 24) }),
				P("body", Vector3.new(0.5, 0.7, 0.08), Vector3.new(0.42, 0.3, -0.6), C(236, 244, 250), { transparency = 0.45, angles = Vector3.new(0, 0, -24) }),
			},
		},
	},

	{
		id = "hachiware_rare_01",
		name = "Storm Runner",
		characterId = "hachiware",
		rarity = "rare",
		look = {
			palette = { body = C(58, 66, 82), arms = C(96, 226, 240), legs = C(44, 52, 66), head = C(178, 190, 206) },
			material = { arms = NEON, body = METAL },
			reflectance = { body = 0.2 },
			parts = {
				P("body", Vector3.new(0.42, 0.24, 1.1), Vector3.new(-0.6, 0.4, 0), C(72, 82, 100), { material = METAL }),
				P("body", Vector3.new(0.42, 0.24, 1.1), Vector3.new(0.6, 0.4, 0), C(72, 82, 100), { material = METAL }),
				P("head", Vector3.new(1.08, 0.16, 0.3), Vector3.new(0, 0.16, -0.44), C(96, 226, 240), { material = NEON }),
			},
			aura = {
				particle = { color = C(140, 236, 248), rate = 6, size = 0.24, speed = 1.6, lifetime = 1.2, spread = 30 },
			},
		},
	},
	{
		id = "hachiware_rare_02",
		name = "Porcelain",
		characterId = "hachiware",
		rarity = "rare",
		look = {
			palette = { all = C(250, 248, 244), body = C(240, 238, 234), limbs = C(246, 244, 240) },
			material = { body = MARBLE, head = MARBLE },
			reflectance = { body = 0.14, head = 0.14 },
			parts = {
				P("armL", Vector3.new(1.16, 0.14, 1.16), Vector3.new(0, -0.32, 0), C(214, 178, 96), { material = METAL, reflectance = 0.3 }),
				P("armR", Vector3.new(1.16, 0.14, 1.16), Vector3.new(0, -0.32, 0), C(214, 178, 96), { material = METAL, reflectance = 0.3 }),
				P("body", Vector3.new(1.08, 0.12, 1.1), Vector3.new(0, 0.46, 0), C(214, 178, 96), { material = METAL, reflectance = 0.3 }),
			},
			aura = {
				particle = { color = C(240, 214, 150), rate = 4, size = 0.18, speed = 0.6, lifetime = 2, spread = 55 },
			},
		},
	},
	{
		id = "hachiware_rare_03",
		name = "Lava Prospector",
		characterId = "hachiware",
		rarity = "rare",
		look = {
			palette = { body = C(52, 46, 46), arms = C(78, 68, 66), legs = C(226, 108, 48), head = C(148, 138, 134) },
			material = { legs = NEON, body = SLATE },
			parts = {
				P("head", Vector3.new(1.1, 0.34, 1.1), Vector3.new(0, 0.5, 0), C(238, 176, 62)),
				P("head", Vector3.new(0.28, 0.28, 0.24), Vector3.new(0, 0.5, 0.56), C(255, 236, 176), { shape = BALL, material = NEON }),
			},
			aura = {
				particle = { color = C(255, 148, 72), rate = 6, size = 0.24, speed = 1.4, lifetime = 1.4, spread = 35 },
				light = { color = C(255, 140, 64), brightness = 1.4, range = 11 },
			},
		},
	},

	{
		id = "hachiware_epic_01",
		name = "Sky Corsair",
		characterId = "hachiware",
		rarity = "epic",
		look = {
			palette = { body = C(34, 46, 82), arms = C(58, 76, 122), legs = C(26, 34, 60), head = C(226, 218, 200) },
			material = { body = FABRIC, arms = FABRIC },
			parts = {
				P("body", Vector3.new(0.24, 1.5, 0.9), Vector3.new(-0.66, 0.3, -0.3), C(196, 214, 240), { transparency = 0.28, angles = Vector3.new(0, 24, 22) }),
				P("body", Vector3.new(0.24, 1.5, 0.9), Vector3.new(0.66, 0.3, -0.3), C(196, 214, 240), { transparency = 0.28, angles = Vector3.new(0, -24, -22) }),
				P("head", Vector3.new(1.24, 0.16, 1.24), Vector3.new(0, 0.54, 0), C(30, 38, 66)),
				P("head", Vector3.new(0.6, 0.34, 1.3), Vector3.new(0, 0.66, 0), C(30, 38, 66), { angles = Vector3.new(0, 0, 6) }),
				P("armL", Vector3.new(1.18, 0.18, 1.18), Vector3.new(0, -0.3, 0), C(212, 200, 176)),
				P("armR", Vector3.new(1.18, 0.18, 1.18), Vector3.new(0, -0.3, 0), C(212, 200, 176)),
			},
			aura = {
				particle = { color = C(210, 228, 248), rate = 6, size = 0.3, speed = 1.2, lifetime = 1.8, spread = 45 },
				light = { color = C(140, 180, 240), brightness = 1.5, range = 13 },
			},
			scale = 1.04,
		},
	},
	{
		id = "hachiware_epic_02",
		name = "Gilded Automaton",
		characterId = "hachiware",
		rarity = "epic",
		look = {
			palette = { all = C(206, 170, 96), body = C(178, 142, 74), limbs = C(150, 120, 64) },
			material = { all = METAL },
			reflectance = { body = 0.3, head = 0.24, limbs = 0.28 },
			parts = {
				P("body", Vector3.new(0.16, 0.42, 0.42), Vector3.new(0, 0.16, 0.56), C(255, 216, 128), { shape = CYLINDER, angles = Vector3.new(0, 90, 0), material = NEON }),
				P("body", Vector3.new(0.34, 0.9, 0.16), Vector3.new(-0.44, 0.1, -0.58), C(150, 120, 64), { angles = Vector3.new(0, 0, 14) }),
				P("body", Vector3.new(0.34, 0.9, 0.16), Vector3.new(0.44, 0.1, -0.58), C(150, 120, 64), { angles = Vector3.new(0, 0, -14) }),
				P("body", Vector3.new(0.26, 0.7, 0.14), Vector3.new(-0.16, -0.1, -0.62), C(178, 142, 74)),
				P("body", Vector3.new(0.26, 0.7, 0.14), Vector3.new(0.16, -0.1, -0.62), C(178, 142, 74)),
				P("head", Vector3.new(0.08, 0.6, 0.08), Vector3.new(0, 0.82, 0), C(255, 216, 128), { material = NEON }),
			},
			aura = {
				particle = { color = C(255, 224, 156), rate = 6, size = 0.24, speed = 1, lifetime = 1.6, spread = 30 },
				light = { color = C(255, 206, 112), brightness = 2, range = 14 },
			},
			scale = 1.05,
		},
	},
	{
		id = "hachiware_epic_03",
		name = "Forest Warden",
		characterId = "hachiware",
		rarity = "epic",
		showcase = true,
		look = {
			palette = { body = C(88, 72, 54), arms = C(112, 92, 66), legs = C(66, 54, 42), head = C(196, 186, 158) },
			material = { body = WOOD, arms = WOOD, legs = WOOD },
			parts = {
				P("head", Vector3.new(0.1, 0.66, 0.1), Vector3.new(-0.34, 0.76, 0), C(150, 128, 92), { angles = Vector3.new(0, 0, -22) }),
				P("head", Vector3.new(0.1, 0.66, 0.1), Vector3.new(0.34, 0.76, 0), C(150, 128, 92), { angles = Vector3.new(0, 0, 22) }),
				P("head", Vector3.new(0.08, 0.4, 0.08), Vector3.new(-0.54, 1, 0), C(150, 128, 92), { angles = Vector3.new(0, 0, -48) }),
				P("head", Vector3.new(0.08, 0.4, 0.08), Vector3.new(0.54, 1, 0), C(150, 128, 92), { angles = Vector3.new(0, 0, 48) }),
				P("body", Vector3.new(1.16, 1.1, 0.18), Vector3.new(0, 0.02, -0.58), C(96, 126, 82), { material = GRASS }),
				P("body", Vector3.new(0.5, 0.5, 0.2), Vector3.new(0, 0.42, 0.52), C(198, 226, 168), { shape = BALL, material = GRASS }),
			},
			aura = {
				particle = { color = C(198, 232, 168), rate = 6, size = 0.28, speed = 0.7, lifetime = 2.4, spread = 60 },
				light = { color = C(150, 216, 130), brightness = 1.6, range = 13 },
			},
			scale = 1.04,
		},
	},

	{
		id = "hachiware_legendary_01",
		name = "Aurora Herald",
		characterId = "hachiware",
		rarity = "legendary",
		look = {
			palette = { all = C(224, 246, 250), body = C(150, 226, 240), limbs = C(186, 236, 246) },
			material = { body = FORCE, head = FORCE, limbs = FORCE },
			parts = {
				P("body", Vector3.new(0.12, 2.4, 0.12), Vector3.new(0, 0.5, 0), C(120, 236, 248), {
					material = NEON,
					spin = 22,
					orbit = { radius = 0.72, height = 0.5, count = 6 },
				}),
				P("head", Vector3.new(1.4, 0.1, 1.4), Vector3.new(0, 0.78, 0), C(168, 244, 252), { material = NEON, spin = 44 }),
				P("head", Vector3.new(1.05, 0.08, 1.05), Vector3.new(0, 0.92, 0), C(226, 250, 255), { material = NEON, spin = -60 }),
			},
			aura = {
				particle = { color = C(168, 244, 252), rate = 10, size = 0.32, speed = 1.4, lifetime = 2.4, spread = 40 },
				light = { color = C(120, 226, 248), brightness = 2.8, range = 19 },
				trail = { color = C(150, 236, 250), lifetime = 0.65 },
				highlight = { fill = C(200, 248, 255), outline = C(96, 214, 244), fillTransparency = 0.8 },
			},
			scale = 1.1,
		},
	},
	{
		id = "hachiware_legendary_02",
		name = "Obsidian Edge",
		characterId = "hachiware",
		rarity = "legendary",
		look = {
			palette = { all = C(24, 22, 26), body = C(16, 14, 18), limbs = C(34, 30, 36) },
			material = { all = METAL },
			reflectance = { body = 0.28, limbs = 0.24, head = 0.2 },
			parts = {
				P("body", Vector3.new(0.14, 1.6, 0.5), Vector3.new(0, 0.1, 0), C(236, 62, 62), {
					material = NEON,
					angles = Vector3.new(0, 0, 32),
					spin = -68,
					orbit = { radius = 1.35, height = 0.1, count = 4 },
				}),
				P("body", Vector3.new(0.9, 0.14, 0.3), Vector3.new(0, 0.46, -0.5), C(236, 62, 62), { material = NEON }),
				P("head", Vector3.new(1.12, 0.12, 0.26), Vector3.new(0, 0.1, -0.46), C(236, 62, 62), { material = NEON }),
			},
			aura = {
				particle = { color = C(236, 72, 72), rate = 8, size = 0.26, speed = 2, lifetime = 1.1, spread = 25 },
				light = { color = C(226, 54, 54), brightness = 2.4, range = 15 },
				trail = { color = C(236, 62, 62), lifetime = 0.5 },
				highlight = { fill = C(30, 26, 30), outline = C(236, 62, 62), fillTransparency = 0.7 },
			},
			scale = 1.06,
		},
	},
	{
		id = "hachiware_legendary_03",
		name = "Lantern God",
		characterId = "hachiware",
		rarity = "legendary",
		showcase = true,
		look = {
			palette = { all = C(252, 246, 232), body = C(238, 226, 200), limbs = C(246, 236, 214) },
			material = { body = FORCE, head = FORCE },
			parts = {
				P("body", Vector3.new(0.4, 0.62, 0.4), Vector3.new(0, 0.6, 0), C(255, 190, 96), {
					material = NEON,
					spin = 18,
					orbit = { radius = 1.5, height = 0.55, count = 4 },
				}),
				P("body", Vector3.new(0.3, 0.46, 0.3), Vector3.new(0, -0.2, 0), C(255, 214, 138), {
					material = NEON,
					spin = -26,
					orbit = { radius = 1.9, height = -0.2, count = 3 },
				}),
				P("body", Vector3.new(0.1, 2.6, 2.6), Vector3.new(0, -1.1, 0), C(255, 206, 120), { shape = CYLINDER, angles = Vector3.new(0, 0, 90), material = NEON, transparency = 0.4 }),
			},
			aura = {
				particle = { color = C(255, 208, 128), rate = 9, size = 0.3, speed = 0.9, lifetime = 2.8, spread = 55 },
				light = { color = C(255, 190, 96), brightness = 2.8, range = 20 },
				trail = { color = C(255, 206, 120), lifetime = 0.75 },
				highlight = { fill = C(255, 236, 190), outline = C(255, 186, 88), fillTransparency = 0.84 },
			},
			scale = 1.12,
		},
	},

	{
		id = "usagi_common_01",
		name = "Dusk Hare",
		characterId = "usagi",
		rarity = "common",
		look = {
			palette = { coat = C(198, 186, 216), blush = C(206, 158, 190) },
		},
	},
	{
		id = "usagi_common_02",
		name = "Charcoal Hare",
		characterId = "usagi",
		rarity = "common",
		look = {
			palette = { coat = C(178, 176, 174), dark = C(38, 36, 40), trim = C(226, 224, 220) },
		},
	},
	{
		id = "usagi_common_03",
		name = "Peach Fizz",
		characterId = "usagi",
		rarity = "common",
		look = {
			palette = { coat = C(255, 216, 178), blush = C(250, 146, 146) },
		},
	},

	{
		id = "usagi_uncommon_01",
		name = "Clover Tuft",
		characterId = "usagi",
		rarity = "uncommon",
		look = {
			palette = { coat = C(196, 226, 168), trim = C(238, 246, 226), blush = C(196, 224, 156) },
			parts = {
				P("earL", Vector3.new(0.5, 0.5, 0.16), Vector3.new(0, 0.6, 0), C(110, 176, 92), { shape = BALL }),
				P("earL", Vector3.new(0.5, 0.5, 0.16), Vector3.new(-0.34, 0.5, 0), C(110, 176, 92), { shape = BALL }),
				P("earL", Vector3.new(0.5, 0.5, 0.16), Vector3.new(0.34, 0.5, 0), C(110, 176, 92), { shape = BALL }),
			},
		},
	},
	{
		id = "usagi_uncommon_02",
		name = "Carrot Crown",
		characterId = "usagi",
		rarity = "uncommon",
		look = {
			palette = { coat = C(255, 202, 148), trim = C(255, 238, 216), dark = C(72, 46, 32) },
			parts = {
				P("head", Vector3.new(0.24, 0.6, 0.24), Vector3.new(0, 0.74, 0), C(240, 134, 54), { angles = Vector3.new(0, 0, 180) }),
				P("head", Vector3.new(0.12, 0.26, 0.12), Vector3.new(-0.1, 0.46, 0), C(112, 176, 88), { angles = Vector3.new(0, 0, -22) }),
				P("head", Vector3.new(0.12, 0.26, 0.12), Vector3.new(0.1, 0.46, 0), C(112, 176, 88), { angles = Vector3.new(0, 0, 22) }),
			},
		},
	},
	{
		id = "usagi_uncommon_03",
		name = "Ink Splash",
		characterId = "usagi",
		rarity = "uncommon",
		look = {
			palette = { coat = C(246, 244, 240), dark = C(20, 20, 24), trim = C(200, 198, 196), blush = C(150, 150, 156) },
			parts = {
				P("body", Vector3.new(0.4, 0.4, 0.4), Vector3.new(-0.28, 0.16, 0.44), C(20, 20, 24), { shape = BALL }),
				P("body", Vector3.new(0.22, 0.22, 0.22), Vector3.new(-0.5, -0.1, 0.42), C(20, 20, 24), { shape = BALL }),
				P("body", Vector3.new(0.14, 0.14, 0.14), Vector3.new(-0.18, -0.24, 0.46), C(20, 20, 24), { shape = BALL }),
			},
		},
	},

	{
		id = "usagi_rare_01",
		name = "Moonlit Hare",
		characterId = "usagi",
		rarity = "rare",
		look = {
			palette = { coat = C(222, 228, 244), trim = C(250, 252, 255), dark = C(44, 50, 74), blush = C(196, 206, 240) },
			material = { trim = GLASS },
			reflectance = { coat = 0.12 },
			parts = {
				P("head", Vector3.new(0.5, 0.5, 0.1), Vector3.new(0, 0.72, 0), C(238, 240, 214), { shape = BALL, material = NEON }),
				P("head", Vector3.new(0.36, 0.36, 0.14), Vector3.new(0.12, 0.76, 0.02), C(222, 228, 244), { shape = BALL }),
				P("earL", Vector3.new(0.34, 0.34, 0.34), Vector3.new(0, 0.62, 0), C(238, 240, 214), { shape = BALL, material = NEON }),
			},
			aura = {
				particle = { color = C(226, 232, 250), rate = 5, size = 0.24, speed = 0.7, lifetime = 2.4, spread = 55 },
			},
		},
	},
	{
		id = "usagi_rare_02",
		name = "Thunder Hop",
		characterId = "usagi",
		rarity = "rare",
		look = {
			palette = { coat = C(150, 156, 172), dark = C(248, 226, 70), trim = C(224, 228, 236), blush = C(248, 226, 70) },
			material = { dark = NEON },
			parts = {
				P("earL", Vector3.new(0.16, 0.6, 0.16), Vector3.new(0, 0.62, 0), C(255, 236, 96), { angles = Vector3.new(0, 0, 18), material = NEON }),
				P("earR", Vector3.new(0.16, 0.6, 0.16), Vector3.new(0, 0.62, 0), C(255, 236, 96), { angles = Vector3.new(0, 0, -18), material = NEON }),
				P("body", Vector3.new(1.06, 0.12, 1.08), Vector3.new(0, 0.42, 0), C(255, 236, 96), { material = NEON }),
			},
			aura = {
				particle = { color = C(255, 240, 120), rate = 7, size = 0.22, speed = 2, lifetime = 0.9, spread = 25 },
			},
		},
	},
	{
		id = "usagi_rare_03",
		name = "Candy Wrapper",
		characterId = "usagi",
		rarity = "rare",
		look = {
			palette = { coat = C(255, 176, 208), trim = C(255, 244, 250), dark = C(158, 58, 118), blush = C(255, 140, 186) },
			material = { trim = GLASS },
			reflectance = { coat = 0.1 },
			parts = {
				P("earL", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 0.6, 0), C(255, 244, 250), { shape = BALL, material = GLASS }),
				P("earR", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 0.6, 0), C(255, 244, 250), { shape = BALL, material = GLASS }),
				P("head", Vector3.new(0.9, 0.5, 0.2), Vector3.new(-0.4, 0.34, 0), C(250, 96, 158), { angles = Vector3.new(0, 0, 26) }),
			},
			aura = {
				particle = { color = C(255, 200, 226), rate = 6, size = 0.2, speed = 0.9, lifetime = 1.8, spread = 60 },
			},
		},
	},

	{
		id = "usagi_epic_01",
		name = "Warlord Hare",
		characterId = "usagi",
		rarity = "epic",
		look = {
			palette = { coat = C(158, 46, 48), dark = C(34, 30, 32), trim = C(212, 178, 108), blush = C(212, 90, 78) },
			material = { dark = METAL, trim = METAL },
			reflectance = { trim = 0.28 },
			parts = {
				P("body", Vector3.new(0.44, 0.26, 1.1), Vector3.new(-0.56, 0.36, 0), C(212, 178, 108), { material = METAL }),
				P("body", Vector3.new(0.44, 0.26, 1.1), Vector3.new(0.56, 0.36, 0), C(212, 178, 108), { material = METAL }),
				P("head", Vector3.new(0.1, 0.6, 0.1), Vector3.new(-0.3, 0.74, 0), C(212, 178, 108), { angles = Vector3.new(0, 0, -26), material = METAL }),
				P("head", Vector3.new(0.1, 0.6, 0.1), Vector3.new(0.3, 0.74, 0), C(212, 178, 108), { angles = Vector3.new(0, 0, 26), material = METAL }),
				P("head", Vector3.new(1.08, 0.2, 1.08), Vector3.new(0, 0.5, 0), C(34, 30, 32), { material = METAL }),
				P("body", Vector3.new(0.7, 1.3, 0.1), Vector3.new(0, 0.5, -0.6), C(158, 46, 48), { material = FABRIC }),
			},
			aura = {
				particle = { color = C(236, 104, 84), rate = 6, size = 0.26, speed = 1.3, lifetime = 1.5, spread = 35 },
				light = { color = C(226, 78, 62), brightness = 1.8, range = 13 },
			},
			scale = 1.05,
		},
	},
	{
		id = "usagi_epic_02",
		name = "Glacier Hare",
		characterId = "usagi",
		rarity = "epic",
		look = {
			palette = { coat = C(196, 230, 246), dark = C(40, 86, 116), trim = C(240, 252, 255), blush = C(160, 216, 240) },
			material = { coat = ICE, trim = GLASS },
			reflectance = { coat = 0.2, trim = 0.3 },
			parts = {
				P("body", Vector3.new(0.16, 0.9, 0.16), Vector3.new(-0.3, 0.36, -0.5), C(214, 244, 255), { angles = Vector3.new(-22, 0, -18), material = GLASS }),
				P("body", Vector3.new(0.18, 1.1, 0.18), Vector3.new(0, 0.46, -0.54), C(232, 250, 255), { angles = Vector3.new(-18, 0, 0), material = GLASS }),
				P("body", Vector3.new(0.16, 0.9, 0.16), Vector3.new(0.3, 0.36, -0.5), C(214, 244, 255), { angles = Vector3.new(-22, 0, 18), material = GLASS }),
				P("body", Vector3.new(0.12, 0.6, 0.12), Vector3.new(-0.52, 0.2, -0.44), C(196, 236, 252), { angles = Vector3.new(-24, 0, -34), material = GLASS }),
				P("earL", Vector3.new(0.3, 0.5, 0.3), Vector3.new(0, 0.6, 0), C(232, 250, 255), { material = GLASS }),
				P("earR", Vector3.new(0.3, 0.5, 0.3), Vector3.new(0, 0.6, 0), C(232, 250, 255), { material = GLASS }),
			},
			aura = {
				particle = { color = C(226, 246, 255), rate = 7, size = 0.28, speed = 0.8, lifetime = 2.6, spread = 55 },
				light = { color = C(150, 220, 246), brightness = 1.9, range = 14 },
			},
			scale = 1.04,
		},
	},
	{
		id = "usagi_epic_03",
		name = "Circuit Hare",
		characterId = "usagi",
		rarity = "epic",
		showcase = true,
		look = {
			palette = { coat = C(38, 42, 48), dark = C(20, 22, 26), trim = C(146, 246, 130), blush = C(146, 246, 130) },
			material = { trim = NEON, coat = METAL },
			reflectance = { coat = 0.22 },
			parts = {
				P("body", Vector3.new(0.1, 0.7, 0.5), Vector3.new(-0.46, 0.3, -0.3), C(146, 246, 130), { material = NEON }),
				P("body", Vector3.new(0.1, 0.7, 0.5), Vector3.new(0.46, 0.3, -0.3), C(146, 246, 130), { material = NEON }),
				P("body", Vector3.new(0.36, 0.36, 0.2), Vector3.new(0, 0.3, 0.5), C(146, 246, 130), { shape = BALL, material = NEON }),
				P("earL", Vector3.new(0.14, 0.5, 0.14), Vector3.new(0, 0.62, 0), C(146, 246, 130), { material = NEON }),
				P("earR", Vector3.new(0.14, 0.5, 0.14), Vector3.new(0, 0.62, 0), C(146, 246, 130), { material = NEON }),
				P("body", Vector3.new(1.04, 0.08, 1.06), Vector3.new(0, -0.2, 0), C(146, 246, 130), { material = NEON }),
			},
			aura = {
				particle = { color = C(160, 250, 146), rate = 7, size = 0.2, speed = 1.6, lifetime = 1.2, spread = 28 },
				light = { color = C(130, 240, 118), brightness = 2, range = 13 },
			},
			scale = 1.03,
		},
	},

	{
		id = "usagi_legendary_01",
		name = "Celestial Hare",
		characterId = "usagi",
		rarity = "legendary",
		look = {
			palette = { coat = C(252, 248, 236), dark = C(64, 58, 96), trim = C(255, 226, 150), blush = C(230, 214, 255) },
			material = { coat = FORCE, trim = NEON },
			parts = {
				P("body", Vector3.new(0.12, 1.1, 0.12), Vector3.new(0, 0.5, -0.56), C(255, 226, 150), { angles = Vector3.new(-16, 0, 0), material = NEON }),
				P("body", Vector3.new(0.1, 0.8, 0.1), Vector3.new(-0.34, 0.4, -0.52), C(255, 240, 190), { angles = Vector3.new(-16, 0, -24), material = NEON }),
				P("body", Vector3.new(0.1, 0.8, 0.1), Vector3.new(0.34, 0.4, -0.52), C(255, 240, 190), { angles = Vector3.new(-16, 0, 24), material = NEON }),
				P("head", Vector3.new(0.16, 0.16, 0.16), Vector3.new(0, 0.4, 0), C(255, 246, 214), {
					shape = BALL,
					material = NEON,
					spin = 48,
					orbit = { radius = 1, height = 0.45, count = 6 },
				}),
			},
			aura = {
				particle = { color = C(255, 238, 186), rate = 9, size = 0.3, speed = 1.1, lifetime = 2.6, spread = 50 },
				light = { color = C(255, 220, 140), brightness = 2.6, range = 18 },
				trail = { color = C(255, 232, 170), lifetime = 0.6 },
				highlight = { fill = C(255, 244, 206), outline = C(255, 212, 122), fillTransparency = 0.85 },
			},
			scale = 1.1,
		},
	},
	{
		id = "usagi_legendary_02",
		name = "Yokai Hare",
		characterId = "usagi",
		rarity = "legendary",
		look = {
			palette = { coat = C(48, 40, 76), dark = C(20, 16, 34), trim = C(184, 120, 255), blush = C(226, 96, 168) },
			material = { coat = FORCE, trim = NEON, dark = SLATE },
			parts = {
				P("body", Vector3.new(0.2, 1.5, 0.2), Vector3.new(0, 0.2, -0.6), C(184, 120, 255), { angles = Vector3.new(-30, 0, 0), material = NEON }),
				P("body", Vector3.new(0.18, 1.2, 0.18), Vector3.new(-0.4, 0.14, -0.54), C(158, 96, 236), { angles = Vector3.new(-28, 0, -30), material = NEON }),
				P("body", Vector3.new(0.18, 1.2, 0.18), Vector3.new(0.4, 0.14, -0.54), C(158, 96, 236), { angles = Vector3.new(-28, 0, 30), material = NEON }),
				P("head", Vector3.new(0.24, 0.24, 0.24), Vector3.new(0, 0.5, 0), C(214, 160, 255), {
					shape = BALL,
					material = NEON,
					spin = 36,
					orbit = { radius = 1.15, height = 0.5, count = 3 },
				}),
				P("body", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0, 0.1, 0), C(226, 96, 168), {
					shape = BALL,
					material = NEON,
					spin = -54,
					orbit = { radius = 1.7, height = 0.1, count = 2 },
				}),
			},
			aura = {
				particle = { color = C(190, 130, 255), rate = 9, size = 0.3, speed = 1, lifetime = 2.8, spread = 60 },
				light = { color = C(166, 104, 250), brightness = 2.5, range = 17 },
				trail = { color = C(184, 120, 255), lifetime = 0.7 },
				highlight = { fill = C(64, 46, 108), outline = C(196, 140, 255), fillTransparency = 0.74 },
			},
			scale = 1.08,
		},
	},
	{
		id = "usagi_legendary_03",
		name = "Golden Hour Hare",
		characterId = "usagi",
		rarity = "legendary",
		showcase = true,
		look = {
			palette = { coat = C(255, 216, 152), dark = C(146, 82, 30), trim = C(255, 246, 214), blush = C(255, 168, 118) },
			material = { coat = FORCE, trim = NEON },
			reflectance = { coat = 0.16 },
			parts = {
				P("head", Vector3.new(0.09, 1.1, 0.09), Vector3.new(0, 0.9, 0), C(255, 214, 118), { material = NEON }),
				P("head", Vector3.new(0.09, 0.9, 0.09), Vector3.new(-0.42, 0.78, 0), C(255, 214, 118), { angles = Vector3.new(0, 0, -34), material = NEON }),
				P("head", Vector3.new(0.09, 0.9, 0.09), Vector3.new(0.42, 0.78, 0), C(255, 214, 118), { angles = Vector3.new(0, 0, 34), material = NEON }),
				P("head", Vector3.new(0.09, 0.7, 0.09), Vector3.new(-0.7, 0.5, 0), C(255, 232, 168), { angles = Vector3.new(0, 0, -62), material = NEON }),
				P("head", Vector3.new(0.09, 0.7, 0.09), Vector3.new(0.7, 0.5, 0), C(255, 232, 168), { angles = Vector3.new(0, 0, 62), material = NEON }),
				P("head", Vector3.new(0.09, 0.7, 0.09), Vector3.new(0, 0.66, -0.6), C(255, 232, 168), { angles = Vector3.new(-56, 0, 0), material = NEON }),
				P("head", Vector3.new(0.09, 0.7, 0.09), Vector3.new(0, 0.66, 0.6), C(255, 232, 168), { angles = Vector3.new(56, 0, 0), material = NEON }),
				P("head", Vector3.new(1.5, 0.1, 1.5), Vector3.new(0, 0.4, 0), C(255, 198, 96), { material = NEON, spin = 14, transparency = 0.3 }),
			},
			aura = {
				particle = { color = C(255, 220, 150), rate = 10, size = 0.34, speed = 1.2, lifetime = 2.4, spread = 45 },
				light = { color = C(255, 194, 96), brightness = 2.9, range = 20 },
				trail = { color = C(255, 214, 130), lifetime = 0.7 },
				highlight = { fill = C(255, 234, 180), outline = C(255, 190, 88), fillTransparency = 0.82 },
			},
			scale = 1.12,
		},
	},
}

local byId: { [string]: Entry } = {}
for _, entry in ENTRIES do
	byId[entry.id] = entry
end

SkinLooks.ENTRIES = ENTRIES

function SkinLooks.get(id: string): SkinLook.Look?
	local entry = byId[id]
	return if entry then entry.look else nil
end

function SkinLooks.entry(id: string): Entry?
	return byId[id]
end

return SkinLooks

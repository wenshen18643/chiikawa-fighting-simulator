--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponLook = require(Shared.Modules.WeaponLook)
local WeaponLooks = {}

export type Entry = {
	id: string,
	name: string,
	weaponId: string,
	rarity: string,
	origin: string,
	blurb: string,
	showcase: boolean?,
	look: WeaponLook.Look,
}

local BALL = Enum.PartType.Ball
local WEDGE = Enum.PartType.Wedge
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local FABRIC = Enum.Material.Fabric
local SLATE = Enum.Material.Slate
local ICE = Enum.Material.Ice
local FORCE = Enum.Material.ForceField
local MARBLE = Enum.Material.Marble

local function C(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function P(size: Vector3, offset: Vector3, colour: Color3, extra: { [string]: any }?): WeaponLook.PartSpec
	local spec: { [string]: any } = {
		size = size,
		offset = offset,
		color = colour,
	}
	if extra then
		for key, value in extra do
			spec[key] = value
		end
	end
	return (spec :: any) :: WeaponLook.PartSpec
end

local AURA_TIERS = {
	rare = { rate = 3, size = 0.16, speed = 0.7, life = 1.2, spread = 34 },
	epic = { rate = 6, size = 0.24, speed = 1.2, life = 1.8, spread = 44, brightness = 1.7, range = 12 },
	legendary = {
		rate = 8,
		size = 0.3,
		speed = 1.4,
		life = 2.4,
		spread = 52,
		brightness = 2.4,
		range = 16,
		trail = 0.6,
		fill = 0.8,
	},
}

local function aura(tier: string, main: Color3, accent: Color3): WeaponLook.AuraSpec
	local step = AURA_TIERS[tier]
	local spec: { [string]: any } = {
		particle = {
			color = main,
			rate = step.rate,
			size = step.size,
			speed = step.speed,
			lifetime = step.life,
			spread = step.spread,
		},
	}
	if step.brightness then
		spec.light = { color = accent, brightness = step.brightness, range = step.range }
	end
	if step.trail then
		spec.trail = { color = main, lifetime = step.trail }
		spec.highlight = { fill = main, outline = accent, fillTransparency = step.fill }
	end
	return (spec :: any) :: WeaponLook.AuraSpec
end

local function charmCord(cord: Color3, bell: Color3): { WeaponLook.PartSpec }
	return {
		P(Vector3.new(0.18, 0.1, 0.18), Vector3.new(0, 1.52, 0.16), cord),
		P(Vector3.new(0.035, 0.44, 0.035), Vector3.new(0, 1.3, 0.2), cord),
		P(Vector3.new(0.24, 0.24, 0.24), Vector3.new(0, 1, 0.2), bell, { shape = BALL }),
		P(Vector3.new(0.12, 0.12, 0.12), Vector3.new(0, 0.82, 0.2), cord, { shape = BALL }),
	}
end

local function hangingLantern(frame: Color3, paper: Color3): { WeaponLook.PartSpec }
	return {
		P(Vector3.new(0.7, 0.06, 0.06), Vector3.new(0.3, 1.98, 0), frame),
		P(Vector3.new(0.04, 0.24, 0.04), Vector3.new(0.6, 1.84, 0), frame),
		P(Vector3.new(0.26, 0.07, 0.26), Vector3.new(0.6, 1.68, 0), frame),
		P(Vector3.new(0.44, 0.56, 0.44), Vector3.new(0.6, 1.38, 0), paper, { shape = BALL }),
		P(Vector3.new(0.2, 0.06, 0.2), Vector3.new(0.6, 1.08, 0), frame),
	}
end

local function bandedHaft(band: Color3, strap: Color3): { WeaponLook.PartSpec }
	return {
		P(Vector3.new(0.28, 0.1, 0.28), Vector3.new(0, 0.55, 0), band),
		P(Vector3.new(0.28, 0.1, 0.28), Vector3.new(0, 0.2, 0), band),
		P(Vector3.new(0.08, 0.08, 0.08), Vector3.new(0.13, 0.55, 0), band, { shape = BALL }),
		P(Vector3.new(0.08, 0.08, 0.08), Vector3.new(0.13, 0.2, 0), band, { shape = BALL }),
		P(Vector3.new(0.06, 0.34, 0.06), Vector3.new(0, -0.15, 0.14), strap, {
			angles = Vector3.new(14, 0, 0),
		}),
		P(Vector3.new(0.16, 0.2, 0.16), Vector3.new(0, -0.36, 0.2), strap, { shape = BALL }),
	}
end

local ENTRIES: { Entry } = {
	{
		id = "sasumata_stale",
		name = "Stale Sasumata",
		weaponId = "sasumata",
		rarity = "common",
		origin = "canon",
		blurb = "The dull brown fork everyone starts with. Splintered, but yours.",
		look = WeaponLook.DEFAULT,
	},
	{
		id = "sasumata_common_grey",
		name = "Shopkeeper's Grey",
		weaponId = "sasumata",
		rarity = "common",
		origin = "canon",
		blurb = "The plain grey fork the old bookshop owner carries.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(148, 146, 144),
				head = C(132, 130, 128),
				edge = C(102, 100, 100),
				grip = C(176, 168, 154),
				cap = C(102, 100, 100),
			},
			material = { grip = FABRIC },
		},
	},
	{
		id = "club_common_rental",
		name = "Rental Club",
		weaponId = "club",
		rarity = "common",
		origin = "canon",
		blurb = "Borrowed from the weapon shop. Tag still on it.",
		look = {
			frame = "club",
			palette = {
				haft = C(154, 122, 86),
				head = C(140, 110, 76),
				edge = C(112, 86, 58),
				grip = C(168, 148, 118),
				cap = C(112, 86, 58),
			},
			material = { all = WOOD, grip = FABRIC },
			parts = {
				P(Vector3.new(0.28, 0.34, 0.03), Vector3.new(0.2, -1.02, 0), C(222, 214, 196), {
					angles = Vector3.new(0, 0, -14),
				}),
				P(Vector3.new(0.04, 0.22, 0.04), Vector3.new(0.14, -0.86, 0), C(176, 156, 126), {
					angles = Vector3.new(0, 0, -34),
				}),
			},
		},
	},
	{
		id = "club_common_acorn",
		name = "Acorn Knock",
		weaponId = "club",
		rarity = "common",
		origin = "cute",
		blurb = "An acorn on a stick. Somehow it works.",
		look = {
			frame = "club",
			palette = {
				haft = C(138, 108, 74),
				head = C(166, 132, 92),
				edge = C(124, 96, 64),
				grip = C(160, 140, 112),
				cap = C(104, 80, 54),
			},
			material = { all = WOOD, grip = FABRIC },
			parts = {
				P(Vector3.new(0.6, 0.34, 0.6), Vector3.new(0, 1.74, 0), C(96, 72, 48)),
				P(Vector3.new(0.1, 0.24, 0.1), Vector3.new(0, 2, 0), C(96, 72, 48)),
			},
		},
	},
	{
		id = "mallet_common_workshop",
		name = "Workshop Mallet",
		weaponId = "mallet",
		rarity = "common",
		origin = "canon",
		blurb = "Standard issue for a big group hunt.",
		look = {
			frame = "mallet",
			palette = {
				haft = C(152, 120, 84),
				head = C(168, 136, 96),
				edge = C(122, 94, 62),
				grip = C(168, 148, 118),
				cap = C(122, 94, 62),
			},
			material = { all = WOOD, grip = FABRIC },
		},
	},
	{
		id = "axe_common_hatchet",
		name = "Chipped Hatchet",
		weaponId = "axe",
		rarity = "common",
		origin = "canon",
		blurb = "Blunt, notched, and older than anyone on the hunt line.",
		look = {
			frame = "axe",
			palette = {
				haft = C(146, 116, 84),
				head = C(112, 110, 108),
				edge = C(138, 136, 134),
				grip = C(158, 138, 110),
				cap = C(112, 86, 58),
			},
			material = { haft = WOOD, grip = FABRIC },
		},
	},

	{
		id = "sasumata_uncommon_pink",
		name = "Strawberry Patrol",
		weaponId = "sasumata",
		rarity = "uncommon",
		origin = "canon",
		blurb = "The pink sasumata Chiikawa saved up for.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(243, 167, 193),
				head = C(243, 167, 193),
				edge = C(226, 124, 158),
				grip = C(252, 247, 240),
				cap = C(226, 124, 158),
			},
			material = { grip = FABRIC },
		},
	},
	{
		id = "sasumata_uncommon_blue",
		name = "Hachiware Blue",
		weaponId = "sasumata",
		rarity = "uncommon",
		origin = "canon",
		blurb = "The blue one Hachiware bought first.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(122, 186, 238),
				head = C(122, 186, 238),
				edge = C(62, 124, 196),
				grip = C(238, 248, 255),
				cap = C(62, 124, 196),
			},
			material = { grip = FABRIC },
		},
	},
	{
		id = "sasumata_uncommon_melon",
		name = "Melon Defender",
		weaponId = "sasumata",
		rarity = "uncommon",
		origin = "cute",
		blurb = "Rind green with a sweet mint grip.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(137, 216, 167),
				head = C(137, 216, 167),
				edge = C(66, 151, 105),
				grip = C(235, 255, 224),
				cap = C(66, 151, 105),
			},
			material = { grip = FABRIC },
		},
	},
	{
		id = "club_uncommon_soda",
		name = "Soda Pop Club",
		weaponId = "club",
		rarity = "uncommon",
		origin = "cute",
		blurb = "Fizzy blue, sticky grip, smells faintly of melon soda.",
		look = {
			frame = "club",
			palette = {
				haft = C(126, 206, 240),
				head = C(158, 224, 250),
				edge = C(255, 246, 176),
				grip = C(250, 252, 255),
				cap = C(255, 246, 176),
			},
			material = { grip = FABRIC },
		},
	},
	{
		id = "binyoyo_uncommon_classic",
		name = "Binyoyo",
		weaponId = "binyoyo",
		rarity = "uncommon",
		origin = "canon",
		blurb = "Springy, egg-tipped, and famously not very effective.",
		look = {
			frame = "binyoyo",
			palette = {
				haft = C(206, 214, 226),
				head = C(250, 246, 236),
				edge = C(255, 255, 255),
				grip = C(206, 178, 140),
				cap = C(178, 190, 208),
			},
			material = { haft = METAL, grip = FABRIC },
		},
	},
	{
		id = "mallet_uncommon_mochi",
		name = "Mochi Pounder",
		weaponId = "mallet",
		rarity = "uncommon",
		origin = "cute",
		blurb = "For pounding rice cakes. Or whatever else turns up.",
		look = {
			frame = "mallet",
			palette = {
				haft = C(246, 196, 206),
				head = C(255, 250, 246),
				edge = C(248, 216, 224),
				grip = C(236, 160, 180),
				cap = C(236, 160, 180),
			},
			material = { head = MARBLE, grip = FABRIC },
			parts = {
				P(Vector3.new(0.26, 0.26, 0.26), Vector3.new(0.34, 1.48, 0.1), C(255, 252, 250), { shape = BALL }),
				P(Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.42, 1.44, -0.08), C(255, 252, 250), { shape = BALL }),
			},
		},
	},

	{
		id = "sasumata_rare_charm_ember",
		name = "Ember Charmfork",
		weaponId = "sasumata",
		rarity = "rare",
		origin = "cool",
		blurb = "Shrine charm knotted to the neck. The bell is louder than it should be.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(122, 62, 54),
				head = C(146, 76, 62),
				edge = C(198, 108, 76),
				grip = C(228, 196, 160),
				cap = C(198, 108, 76),
			},
			material = { grip = FABRIC },
			parts = charmCord(C(198, 74, 66), C(224, 176, 92)),
			aura = aura("rare", C(238, 168, 118), C(220, 120, 80)),
		},
	},
	{
		id = "sasumata_rare_charm_moss",
		name = "Moss Charmfork",
		weaponId = "sasumata",
		rarity = "rare",
		origin = "cool",
		blurb = "Same charm, temple-garden colours. Smells like wet stone.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(74, 96, 66),
				head = C(92, 116, 80),
				edge = C(140, 170, 112),
				grip = C(226, 224, 200),
				cap = C(140, 170, 112),
			},
			material = { grip = FABRIC },
			parts = charmCord(C(108, 148, 92), C(232, 226, 198)),
			aura = aura("rare", C(178, 212, 148), C(120, 158, 104)),
		},
	},
	{
		id = "sasumata_rare_charm_dusk",
		name = "Dusk Charmfork",
		weaponId = "sasumata",
		rarity = "rare",
		origin = "cool",
		blurb = "Night-patrol colours. The bead is chipped on one side.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(72, 78, 110),
				head = C(88, 94, 128),
				edge = C(138, 146, 186),
				grip = C(214, 218, 236),
				cap = C(138, 146, 186),
			},
			material = { grip = FABRIC },
			parts = charmCord(C(96, 104, 148), C(196, 204, 232)),
			aura = aura("rare", C(178, 190, 232), C(112, 124, 176)),
		},
	},
	{
		id = "club_rare_lantern_red",
		name = "Red Lantern Club",
		weaponId = "club",
		rarity = "rare",
		origin = "canon",
		blurb = "A festival lantern lashed to a club. Nobody asked why.",
		look = {
			frame = "club",
			palette = {
				haft = C(108, 78, 58),
				head = C(126, 92, 68),
				edge = C(88, 62, 46),
				grip = C(186, 156, 120),
				cap = C(88, 62, 46),
			},
			material = { haft = WOOD, head = WOOD, grip = FABRIC },
			parts = hangingLantern(C(72, 54, 44), C(214, 82, 74)),
			aura = aura("rare", C(248, 158, 126), C(214, 96, 78)),
		},
	},
	{
		id = "club_rare_lantern_jade",
		name = "Jade Lantern Club",
		weaponId = "club",
		rarity = "rare",
		origin = "cool",
		blurb = "Same lantern, greener paper. Slightly dented on the swing side.",
		look = {
			frame = "club",
			palette = {
				haft = C(96, 88, 70),
				head = C(112, 104, 82),
				edge = C(78, 72, 56),
				grip = C(180, 172, 142),
				cap = C(78, 72, 56),
			},
			material = { haft = WOOD, head = WOOD, grip = FABRIC },
			parts = hangingLantern(C(66, 62, 50), C(108, 190, 156)),
			aura = aura("rare", C(160, 226, 198), C(96, 172, 142)),
		},
	},
	{
		id = "axe_rare_riveted_iron",
		name = "Riveted Axe",
		weaponId = "axe",
		rarity = "rare",
		origin = "canon",
		blurb = "Banded, rivetted, and finished with somebody else's luck tassel.",
		look = {
			frame = "axe",
			palette = {
				haft = C(120, 92, 66),
				head = C(114, 118, 126),
				edge = C(190, 196, 206),
				grip = C(152, 124, 94),
				cap = C(96, 74, 52),
			},
			material = { haft = WOOD, head = METAL, edge = METAL, grip = FABRIC },
			reflectance = { edge = 0.1 },
			parts = bandedHaft(C(104, 108, 118), C(196, 92, 74)),
			aura = aura("rare", C(206, 212, 222), C(150, 158, 172)),
		},
	},
	{
		id = "axe_rare_riveted_brass",
		name = "Brass-Banded Axe",
		weaponId = "axe",
		rarity = "rare",
		origin = "cool",
		blurb = "The bands were re-cast in brass. The tassel is new, at least.",
		look = {
			frame = "axe",
			palette = {
				haft = C(96, 76, 62),
				head = C(126, 108, 74),
				edge = C(214, 190, 132),
				grip = C(146, 122, 92),
				cap = C(96, 74, 52),
			},
			material = { haft = WOOD, head = METAL, edge = METAL, grip = FABRIC },
			reflectance = { edge = 0.14 },
			parts = bandedHaft(C(190, 152, 78), C(84, 118, 156)),
			aura = aura("rare", C(240, 208, 138), C(184, 146, 76)),
		},
	},

	{
		id = "sasumata_epic_wisteria",
		name = "Wisteria Moon",
		weaponId = "sasumata",
		rarity = "epic",
		origin = "cool",
		blurb = "Night-shift issue. A moon disc rides the neck and petals circle the prongs.",
		look = {
			frame = "sasumata",
			palette = {
				haft = C(182, 139, 235),
				head = C(182, 139, 235),
				edge = C(103, 67, 168),
				grip = C(245, 225, 255),
				cap = C(103, 67, 168),
			},
			material = { all = METAL, grip = NEON },
			reflectance = { haft = 0.18, head = 0.18 },
			parts = {
				P(Vector3.new(0.44, 0.44, 0.09), Vector3.new(0, 1.5, 0.18), C(244, 232, 255), {
					shape = BALL,
					material = NEON,
				}),
				P(Vector3.new(0.14, 0.28, 0.05), Vector3.new(0, 2.3, 0), C(226, 196, 255), {
					shape = WEDGE,
					material = NEON,
					spin = 34,
					orbit = { radius = 0.52, height = 0, count = 4 },
				}),
			},
			aura = aura("epic", C(214, 186, 255), C(168, 122, 240)),
		},
	},
	{
		id = "staff_epic_usagi",
		name = "Usagi's Discharge Rod",
		weaponId = "staff",
		rarity = "epic",
		origin = "canon",
		blurb = "Fires from both ends. Face mark drawn on by hand, sparks orbit the top.",
		look = {
			frame = "staff",
			palette = {
				haft = C(248, 222, 118),
				head = C(126, 130, 138),
				edge = C(255, 240, 158),
				grip = C(196, 160, 96),
				cap = C(252, 248, 236),
			},
			material = { head = METAL, edge = NEON, grip = FABRIC },
			parts = {
				P(Vector3.new(0.07, 0.07, 0.03), Vector3.new(-0.07, 0.83, -0.17), C(46, 42, 40), { shape = BALL }),
				P(Vector3.new(0.07, 0.07, 0.03), Vector3.new(0.07, 0.83, -0.17), C(46, 42, 40), { shape = BALL }),
				P(Vector3.new(0.13, 0.04, 0.03), Vector3.new(0, 0.71, -0.17), C(46, 42, 40)),
				P(Vector3.new(0.12, 0.12, 0.12), Vector3.new(0, 2.14, 0), C(255, 240, 158), {
					shape = BALL,
					material = NEON,
					spin = 90,
					orbit = { radius = 0.4, height = 0, count = 3 },
				}),
			},
			aura = aura("epic", C(255, 240, 158), C(255, 226, 120)),
		},
	},
	{
		id = "sword_epic_unranked",
		name = "Unranked Steel",
		weaponId = "sword",
		rarity = "epic",
		origin = "canon",
		blurb = "A real blade with winged fittings. No face mark until you place top four.",
		look = {
			frame = "sword",
			palette = {
				haft = C(88, 68, 60),
				head = C(206, 212, 222),
				edge = C(240, 246, 252),
				grip = C(126, 96, 74),
				cap = C(168, 172, 180),
			},
			material = { head = METAL, edge = METAL, cap = METAL, grip = FABRIC },
			reflectance = { head = 0.2, edge = 0.24, cap = 0.2 },
			parts = {
				P(Vector3.new(0.3, 0.24, 0.1), Vector3.new(-0.56, 0.6, 0), C(214, 220, 230), {
					shape = WEDGE,
					material = METAL,
					angles = Vector3.new(0, 0, 28),
				}),
				P(Vector3.new(0.3, 0.24, 0.1), Vector3.new(0.56, 0.6, 0), C(214, 220, 230), {
					shape = WEDGE,
					material = METAL,
					angles = Vector3.new(0, 180, -28),
				}),
				P(Vector3.new(0.18, 0.18, 0.08), Vector3.new(0, 0.5, -0.16), C(146, 206, 244), {
					shape = BALL,
					material = NEON,
				}),
			},
			aura = aura("epic", C(226, 236, 248), C(196, 216, 244)),
		},
	},
	{
		id = "morningstar_epic_comet",
		name = "Comet Thistle",
		weaponId = "morningstar",
		rarity = "epic",
		origin = "cool",
		blurb = "The head drags a ring of sparks around with it.",
		look = {
			frame = "morningstar",
			palette = {
				haft = C(38, 44, 60),
				head = C(64, 96, 152),
				edge = C(140, 222, 255),
				grip = C(56, 70, 96),
				cap = C(64, 96, 152),
			},
			material = { head = METAL, edge = NEON, cap = METAL, grip = FABRIC },
			reflectance = { head = 0.22 },
			parts = {
				P(Vector3.new(0.14, 0.14, 0.14), Vector3.new(0, 2.3, 0), C(180, 236, 255), {
					shape = BALL,
					material = NEON,
					spin = 62,
					orbit = { radius = 0.78, height = 0, count = 4 },
				}),
			},
			aura = aura("epic", C(160, 226, 255), C(120, 208, 255)),
		},
	},
	{
		id = "wand_epic_sugar",
		name = "Sugar Wand",
		weaponId = "wand",
		rarity = "epic",
		origin = "canon",
		blurb = "Magical Girl issue: heart, wings, and three little hearts on patrol.",
		look = {
			frame = "wand",
			palette = {
				haft = C(255, 250, 244),
				head = C(250, 132, 172),
				edge = C(255, 253, 250),
				grip = C(246, 172, 200),
				cap = C(255, 226, 150),
			},
			material = { edge = FORCE, cap = NEON, grip = FABRIC },
			parts = {
				P(Vector3.new(0.16, 0.16, 0.05), Vector3.new(0, 1.28, -0.1), C(255, 246, 250), { shape = BALL }),
				P(Vector3.new(0.3, 0.12, 0.12), Vector3.new(0, 0.16, 0.15), C(255, 214, 232)),
				P(Vector3.new(0.15, 0.15, 0.06), Vector3.new(0, 1.28, 0), C(255, 186, 214), {
					shape = BALL,
					material = NEON,
					spin = 46,
					orbit = { radius = 0.62, height = 0, count = 3 },
				}),
			},
			aura = aura("epic", C(255, 198, 224), C(255, 168, 204)),
		},
	},
	{
		id = "binyoyo_epic_pudding",
		name = "Pudding Binyoyo",
		weaponId = "binyoyo",
		rarity = "epic",
		origin = "cute",
		blurb = "Wobbles on impact. Cherry included, sprinkles orbit for free.",
		look = {
			frame = "binyoyo",
			palette = {
				haft = C(250, 240, 220),
				head = C(252, 226, 170),
				edge = C(255, 250, 236),
				grip = C(226, 186, 130),
				cap = C(198, 132, 70),
			},
			material = { haft = MARBLE, grip = FABRIC },
			parts = {
				P(Vector3.new(0.6, 0.2, 0.6), Vector3.new(0, 1.24, 0), C(186, 122, 62), { shape = BALL }),
				P(Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, 1.98, 0), C(226, 62, 78), { shape = BALL }),
				P(Vector3.new(0.05, 0.22, 0.05), Vector3.new(0.04, 2.16, 0), C(120, 170, 96), {
					angles = Vector3.new(0, 0, -16),
				}),
				P(Vector3.new(0.12, 0.06, 0.06), Vector3.new(0, 1.56, 0), C(255, 248, 236), {
					material = NEON,
					spin = 38,
					orbit = { radius = 0.6, height = 0, count = 4 },
				}),
			},
			aura = aura("epic", C(255, 226, 170), C(240, 190, 120)),
		},
	},

	{
		id = "sasumata_legendary_fang",
		name = "Rakko's Golden Fang",
		weaponId = "sasumata",
		rarity = "legendary",
		origin = "cool",
		blurb = "Gilded to the tips, finned at the collar, trailing gold wherever it swings.",
		look = {
			frame = "sasumata",
			scale = 1.05,
			palette = {
				haft = C(247, 199, 74),
				head = C(247, 199, 74),
				edge = C(207, 86, 56),
				grip = C(255, 247, 192),
				cap = C(207, 86, 56),
			},
			material = { all = METAL, grip = NEON },
			reflectance = { haft = 0.24, head = 0.24 },
			parts = {
				P(Vector3.new(0.52, 0.12, 0.3), Vector3.new(0, 1.44, 0), C(255, 226, 150), { material = METAL }),
				P(Vector3.new(0.16, 0.42, 0.1), Vector3.new(-0.34, 1.16, 0), C(255, 226, 150), {
					shape = WEDGE,
					material = METAL,
					angles = Vector3.new(0, 0, 22),
				}),
				P(Vector3.new(0.16, 0.42, 0.1), Vector3.new(0.34, 1.16, 0), C(255, 226, 150), {
					shape = WEDGE,
					material = METAL,
					angles = Vector3.new(0, 180, -22),
				}),
				P(Vector3.new(0.13, 0.13, 0.13), Vector3.new(0, 2.2, 0), C(255, 238, 176), {
					shape = BALL,
					material = NEON,
					spin = 48,
					orbit = { radius = 0.8, height = 0, count = 5 },
				}),
			},
			aura = aura("legendary", C(255, 226, 150), C(255, 202, 96)),
		},
	},
	{
		id = "sword_legendary_ranker",
		name = "Rakko's Ranker Blade",
		weaponId = "sword",
		rarity = "legendary",
		origin = "canon",
		blurb = "Top-four only: the face mark is engraved, the guard has gold wings.",
		look = {
			frame = "sword",
			scale = 1.05,
			palette = {
				haft = C(72, 54, 48),
				head = C(224, 232, 244),
				edge = C(255, 255, 255),
				grip = C(126, 92, 66),
				cap = C(228, 186, 96),
			},
			material = { head = METAL, edge = NEON, cap = METAL, grip = FABRIC },
			reflectance = { head = 0.3, cap = 0.28 },
			parts = {
				P(Vector3.new(0.24, 0.24, 0.03), Vector3.new(0, 0.92, -0.07), C(228, 186, 96), { shape = BALL }),
				P(Vector3.new(0.05, 0.05, 0.03), Vector3.new(-0.06, 0.96, -0.09), C(72, 54, 48), { shape = BALL }),
				P(Vector3.new(0.05, 0.05, 0.03), Vector3.new(0.06, 0.96, -0.09), C(72, 54, 48), { shape = BALL }),
				P(Vector3.new(0.1, 0.03, 0.03), Vector3.new(0, 0.85, -0.09), C(72, 54, 48)),
				P(Vector3.new(0.34, 0.26, 0.1), Vector3.new(-0.64, 0.56, 0), C(240, 208, 132), {
					shape = WEDGE,
					material = METAL,
					angles = Vector3.new(0, 0, 30),
				}),
				P(Vector3.new(0.34, 0.26, 0.1), Vector3.new(0.64, 0.56, 0), C(240, 208, 132), {
					shape = WEDGE,
					material = METAL,
					angles = Vector3.new(0, 180, -30),
				}),
				P(Vector3.new(0.12, 0.12, 0.12), Vector3.new(0, 3.24, 0), C(246, 250, 255), {
					shape = BALL,
					material = NEON,
					spin = 40,
					orbit = { radius = 0.5, height = 0, count = 3 },
				}),
			},
			aura = aura("legendary", C(236, 244, 255), C(228, 186, 96)),
		},
	},
	{
		id = "staff_legendary_thunder",
		name = "Thunderclap Rod",
		weaponId = "staff",
		rarity = "legendary",
		origin = "cool",
		blurb = "Both nozzles arc at once, finned midshaft. Stand clear of either end.",
		look = {
			frame = "staff",
			scale = 1.05,
			palette = {
				haft = C(34, 38, 52),
				head = C(58, 68, 92),
				edge = C(146, 240, 255),
				grip = C(46, 54, 74),
				cap = C(146, 240, 255),
			},
			material = { haft = SLATE, head = METAL, edge = NEON, cap = NEON, grip = FABRIC },
			reflectance = { head = 0.24 },
			parts = {
				P(Vector3.new(0.1, 0.52, 0.24), Vector3.new(-0.18, 0.62, 0), C(90, 172, 208), {
					material = METAL,
					angles = Vector3.new(0, 0, 14),
				}),
				P(Vector3.new(0.1, 0.52, 0.24), Vector3.new(0.18, 0.62, 0), C(90, 172, 208), {
					material = METAL,
					angles = Vector3.new(0, 0, -14),
				}),
				P(Vector3.new(0.1, 0.1, 0.1), Vector3.new(0, 2.14, 0), C(196, 248, 255), {
					shape = BALL,
					material = NEON,
					spin = 84,
					orbit = { radius = 0.44, height = 0, count = 3 },
				}),
				P(Vector3.new(0.1, 0.1, 0.1), Vector3.new(0, -2.14, 0), C(196, 248, 255), {
					shape = BALL,
					material = NEON,
					spin = -84,
					orbit = { radius = 0.44, height = 0, count = 3 },
				}),
			},
			aura = aura("legendary", C(170, 244, 255), C(120, 226, 255)),
		},
	},
	{
		id = "wand_legendary_dark",
		name = "Momonga's Dark Wand",
		weaponId = "wand",
		rarity = "legendary",
		origin = "canon",
		blurb = "Skull instead of a heart, demon wings instead of angel ones.",
		look = {
			frame = "wand",
			scale = 1.05,
			palette = {
				haft = C(38, 30, 48),
				head = C(240, 236, 228),
				edge = C(122, 68, 176),
				grip = C(158, 96, 226),
				cap = C(196, 132, 255),
			},
			material = { haft = SLATE, edge = SLATE, cap = NEON, grip = FABRIC },
			parts = {
				P(Vector3.new(0.1, 0.1, 0.05), Vector3.new(-0.13, 1.32, -0.09), C(28, 24, 34), { shape = BALL }),
				P(Vector3.new(0.1, 0.1, 0.05), Vector3.new(0.13, 1.32, -0.09), C(28, 24, 34), { shape = BALL }),
				P(Vector3.new(0.16, 0.05, 0.05), Vector3.new(0, 1.06, -0.09), C(28, 24, 34)),
				P(Vector3.new(0.09, 0.26, 0.09), Vector3.new(-0.22, 1.56, 0), C(196, 132, 255), {
					angles = Vector3.new(0, 0, 26),
					material = NEON,
				}),
				P(Vector3.new(0.09, 0.26, 0.09), Vector3.new(0.22, 1.56, 0), C(196, 132, 255), {
					angles = Vector3.new(0, 0, -26),
					material = NEON,
				}),
				P(Vector3.new(0.12, 0.12, 0.12), Vector3.new(0, 1.28, 0), C(186, 128, 255), {
					shape = BALL,
					material = NEON,
					spin = -52,
					orbit = { radius = 0.72, height = 0, count = 4 },
				}),
			},
			aura = aura("legendary", C(186, 128, 255), C(158, 96, 236)),
		},
	},
	{
		id = "binyoyo_legendary_star",
		name = "Starlight Binyoyo",
		weaponId = "binyoyo",
		rarity = "legendary",
		origin = "cute",
		blurb = "Still barely works. Now it has its own constellation.",
		look = {
			frame = "binyoyo",
			scale = 1.05,
			palette = {
				haft = C(226, 236, 255),
				head = C(255, 252, 246),
				edge = C(255, 255, 255),
				grip = C(196, 206, 246),
				cap = C(255, 226, 150),
			},
			material = { haft = ICE, head = FORCE, cap = NEON, grip = FABRIC },
			reflectance = { haft = 0.22 },
			parts = {
				P(Vector3.new(0.14, 0.14, 0.14), Vector3.new(0, 1.56, 0), C(255, 238, 176), {
					shape = BALL,
					material = NEON,
					spin = 40,
					orbit = { radius = 0.72, height = 0, count = 5 },
				}),
				P(Vector3.new(0.1, 0.1, 0.1), Vector3.new(0, 1.98, 0), C(226, 240, 255), {
					shape = BALL,
					material = NEON,
					spin = -56,
					orbit = { radius = 0.4, height = 0, count = 3 },
				}),
				P(Vector3.new(0.22, 0.18, 0.08), Vector3.new(0, 2.2, 0), C(255, 226, 150), {
					shape = WEDGE,
					material = NEON,
					spin = -30,
				}),
			},
			aura = aura("legendary", C(255, 240, 196), C(255, 220, 140)),
		},
	},
	{
		id = "club_legendary_candy",
		name = "Candy Crown Bat",
		weaponId = "club",
		rarity = "legendary",
		origin = "cute",
		blurb = "Hard candy, harder swing, and a ring of sweets that never lands.",
		look = {
			frame = "club",
			scale = 1.05,
			palette = {
				haft = C(255, 246, 250),
				head = C(255, 240, 246),
				edge = C(250, 140, 180),
				grip = C(196, 232, 255),
				cap = C(250, 140, 180),
			},
			material = { all = GLASS, grip = FABRIC },
			reflectance = { haft = 0.14, head = 0.14 },
			parts = {
				P(Vector3.new(0.58, 0.16, 0.58), Vector3.new(0, 0.82, 0), C(250, 140, 180), {
					angles = Vector3.new(0, 0, 14),
				}),
				P(Vector3.new(0.58, 0.16, 0.58), Vector3.new(0, 1.18, 0), C(146, 216, 255), {
					angles = Vector3.new(0, 0, 14),
				}),
				P(Vector3.new(0.58, 0.16, 0.58), Vector3.new(0, 1.54, 0), C(250, 140, 180), {
					angles = Vector3.new(0, 0, 14),
				}),
				P(Vector3.new(0.16, 0.16, 0.16), Vector3.new(0, 2.02, 0), C(255, 214, 236), {
					shape = BALL,
					material = NEON,
					spin = 44,
					orbit = { radius = 0.66, height = 0, count = 5 },
				}),
			},
			aura = aura("legendary", C(255, 208, 230), C(250, 140, 180)),
		},
	},
}

local byId: { [string]: Entry } = {}
for _, entry in ENTRIES do
	byId[entry.id] = entry
end

WeaponLooks.ENTRIES = ENTRIES
WeaponLooks.DEFAULT_ID = "sasumata_stale"

function WeaponLooks.entry(id: string): Entry?
	return byId[id]
end

function WeaponLooks.get(id: string): WeaponLook.Look?
	local entry = byId[id]
	return if entry then entry.look else nil
end

return WeaponLooks

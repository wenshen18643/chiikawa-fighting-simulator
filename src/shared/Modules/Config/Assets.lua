local Assets = {}

export type AssetSpec = {
	id: number,
	kind: string,

	template: string?,

	scale: number?,

	collide: boolean?,

	canopy: boolean?,

	exclude: { string }?,
}

Assets.MODELS = {
	tree = { id = 0, kind = "model", scale = 1, collide = false, canopy = true },
	grass = { id = 0, kind = "model", scale = 1, collide = false },
	stone = { id = 0, kind = "model", scale = 1, collide = false },

	log = { id = 9731248486, kind = "model", scale = 1, collide = false },
	bush = { id = 11337757315, kind = "model", scale = 1, collide = false },
	house = { id = 136868946197723, kind = "model", scale = 1, collide = true },
	terrain = { id = 97974769788038, kind = "model", scale = 1, collide = false },

	naturePack = { id = 82060619904561, kind = "pack", scale = 1, collide = false, exclude = { "wand" } },

	hachiware = { id = 126588941317056, kind = "model", template = "Hachiware", scale = 1 },

	usagi = { id = 88154057398500, kind = "model", template = "Usagi", scale = 1 },

	chiikawa = { id = 103908480888538, kind = "model", template = "Chiikawa", scale = 1 },

	mushroomFrog = { id = 0, kind = "model", template = "MushroomFrog", scale = 1, collide = false },
	duck = { id = 0, kind = "model", template = "Duck", scale = 1, collide = false },
	wolf = { id = 0, kind = "model", template = "Wolf", scale = 1, collide = false },

	sakuraTree = { id = 0, kind = "model", template = "SakuraTree", scale = 1, canopy = true },

	grassPatch = { id = 0, kind = "model", template = "GrassPatch", scale = 1, collide = false },
	friendStand = { id = 0, kind = "model", template = "FriendStand", scale = 1 },
	fish = { id = 0, kind = "model", template = "Fish", scale = 1, collide = false },
	oreChunk = { id = 0, kind = "model", template = "OreChunk", scale = 1, collide = false },
	strawberryDoor = { id = 0, kind = "model", template = "StrawberryDoor", scale = 1 },
	lantern = { id = 0, kind = "model", template = "Lantern", scale = 1 },
	lanternTall = { id = 0, kind = "model", template = "LanternTall", scale = 1 },
	mailBox = { id = 0, kind = "model", template = "MailBox", scale = 1 },
	laundryLine = { id = 0, kind = "model", template = "LaundryLine", scale = 1 },
	wateringCan = { id = 0, kind = "model", template = "WateringCan", scale = 1 },
	picnicTable = { id = 0, kind = "model", template = "PicnicTable", scale = 1 },
	lowTable = { id = 0, kind = "model", template = "LowTable", scale = 1 },
	tableCloth = { id = 0, kind = "model", template = "TableCloth", scale = 1 },
	floorCushion = { id = 0, kind = "model", template = "FloorCushion", scale = 1 },
	kettle = { id = 0, kind = "model", template = "Kettle", scale = 1 },
	teaPot = { id = 0, kind = "model", template = "TeaPot", scale = 1 },
	teaCup = { id = 0, kind = "model", template = "TeaCup", scale = 1 },

	shopBlue = { id = 0, kind = "model", template = "ShopBlue", scale = 1 },
	shopRed = { id = 0, kind = "model", template = "ShopRed", scale = 1 },
	shopStall = { id = 0, kind = "model", template = "ShopStall", scale = 1 },

	house1 = { id = 0, kind = "model", template = "House1", scale = 1 },
	house2 = { id = 0, kind = "model", template = "House2", scale = 1 },
	house3 = { id = 0, kind = "model", template = "House3", scale = 1 },
	fountain = { id = 0, kind = "model", template = "Fountain", scale = 1 },
	flowerBed1 = { id = 0, kind = "model", template = "FlowerBed1", scale = 1, collide = false },
	flowerBed2 = { id = 0, kind = "model", template = "FlowerBed2", scale = 1, collide = false },
	flowerBed3 = { id = 0, kind = "model", template = "FlowerBed3", scale = 1, collide = false },
	pinkBench = { id = 0, kind = "model", template = "PinkBench", scale = 1 },
	bridge = { id = 0, kind = "model", template = "Bridge", scale = 1 },

	ramen = { id = 0, kind = "model", template = "Ramen", scale = 1 },
	onigiri = { id = 0, kind = "model", template = "Onigiri", scale = 1 },
	dango = { id = 0, kind = "model", template = "Dango", scale = 1 },
	dangoPlatter = { id = 0, kind = "model", template = "DangoPlatter", scale = 1 },
	pancakes = { id = 0, kind = "model", template = "Pancakes", scale = 1 },
	yogurtBerry = { id = 0, kind = "model", template = "YogurtBerry", scale = 1 },

	yogurtVanilla = { id = 0, kind = "model", template = "YogurtVanilla", scale = 1 },

	yoroiKnight = { id = 0, kind = "model", template = "YoroiKnight", scale = 1 },
	yoroiBeast = { id = 0, kind = "model", template = "YoroiBeast", scale = 1 },

	blackBerryBush = { id = 0, kind = "model", template = "BlackBerryBush", scale = 1, collide = false },
	blueBerryBush = { id = 0, kind = "model", template = "BlueBerryBush", scale = 1, collide = false },
	whiteBerryBush = { id = 0, kind = "model", template = "WhiteBerryBush", scale = 1, collide = false },
	purpleBerryBush = { id = 0, kind = "model", template = "PurpleBerryBush", scale = 1, collide = false },
	brownMushroom = { id = 0, kind = "model", template = "BrownMushroom", scale = 1, collide = false },
	whiteMushroom = { id = 0, kind = "model", template = "WhiteMushroom", scale = 1, collide = false },
	pinkSausageTree = { id = 0, kind = "model", template = "PinkSausageTree", scale = 1, collide = true },
	yellowSausageTree = { id = 0, kind = "model", template = "YellowSausageTree", scale = 1, collide = true },
	riceCookerSprout = { id = 0, kind = "model", template = "RiceCookerSprout", scale = 1, collide = false },
	rice = { id = 0, kind = "model", template = "Rice", scale = 1, collide = false },
	carrot = { id = 0, kind = "model", template = "Carrot", scale = 1, collide = false },
	potato = { id = 0, kind = "model", template = "Potato", scale = 1, collide = false },
	cookingPot = { id = 0, kind = "model", template = "CookingPot", scale = 1, collide = true },
} :: { [string]: AssetSpec }

function Assets.get(key: string): AssetSpec?
	return Assets.MODELS[key]
end

local function isResolvable(spec: AssetSpec): boolean
	return spec.template ~= nil or (spec.id ~= nil and spec.id > 0)
end

function Assets.configured(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if isResolvable(spec) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function Assets.blank(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if not isResolvable(spec) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function Assets.local_(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if spec.template then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

return Assets

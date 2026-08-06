local Assets = {}

export type AssetSpec = {
	template: string,

	scale: number?,

	collide: boolean?,

	canopy: boolean?,
}

Assets.MODELS = {
	hachiware = { template = "Hachiware", scale = 1 },

	usagi = { template = "Usagi", scale = 1 },

	chiikawa = { template = "Chiikawa", scale = 1 },

	mushroomFrog = { template = "MushroomFrog", scale = 1, collide = false },
	duck = { template = "Duck", scale = 1, collide = false },
	wolf = { template = "Wolf", scale = 1, collide = false },

	sakuraTree = { template = "SakuraTree", scale = 1, canopy = true },

	grassPatch = { template = "GrassPatch", scale = 1, collide = false },
	friendStand = { template = "FriendStand", scale = 1 },
	gachaGuy = { template = "GachaGuy", scale = 1, collide = false },
	weaponsGachaGuy = { template = "GachaGuy", scale = 1, collide = false },
	oreChunk = { template = "OreChunk", scale = 1, collide = false },
	strawberryDoor = { template = "StrawberryDoor", scale = 1 },
	lantern = { template = "Lantern", scale = 1 },
	lanternTall = { template = "LanternTall", scale = 1 },
	mailBox = { template = "MailBox", scale = 1 },
	picnicTable = { template = "PicnicTable", scale = 1 },
	lowTable = { template = "LowTable", scale = 1 },
	tableCloth = { template = "TableCloth", scale = 1 },
	floorCushion = { template = "FloorCushion", scale = 1 },
	kettle = { template = "Kettle", scale = 1 },
	teaPot = { template = "TeaPot", scale = 1 },
	teaCup = { template = "TeaCup", scale = 1 },

	shopBlue = { template = "ShopBlue", scale = 1 },
	shopRed = { template = "ShopRed", scale = 1 },
	shopStall = { template = "ShopStall", scale = 1 },

	house1 = { template = "House1", scale = 1 },
	house2 = { template = "House2", scale = 1 },
	house3 = { template = "House3", scale = 1 },
	fountain = { template = "Fountain", scale = 1 },
	flowerBed1 = { template = "FlowerBed1", scale = 1, collide = false },
	flowerBed2 = { template = "FlowerBed2", scale = 1, collide = false },
	flowerBed3 = { template = "FlowerBed3", scale = 1, collide = false },
	bridge = { template = "Bridge", scale = 1 },

	ramen = { template = "Ramen", scale = 1 },
	onigiri = { template = "Onigiri", scale = 1 },
	dango = { template = "Dango", scale = 1 },
	dangoPlatter = { template = "DangoPlatter", scale = 1 },
	pancakes = { template = "Pancakes", scale = 1 },
	yogurtBerry = { template = "YogurtBerry", scale = 1 },

	yogurtVanilla = { template = "YogurtVanilla", scale = 1 },

	yoroiKnight = { template = "YoroiKnight", scale = 1 },
	yoroiBeast = { template = "YoroiBeast", scale = 1 },

	blackBerryBush = { template = "BlackBerryBush", scale = 1, collide = false },
	blueBerryBush = { template = "BlueBerryBush", scale = 1, collide = false },
	whiteBerryBush = { template = "WhiteBerryBush", scale = 1, collide = false },
	purpleBerryBush = { template = "PurpleBerryBush", scale = 1, collide = false },
	brownMushroom = { template = "BrownMushroom", scale = 1, collide = false },
	whiteMushroom = { template = "WhiteMushroom", scale = 1, collide = false },
	pinkSausageTree = { template = "PinkSausageTree", scale = 1, collide = true },
	yellowSausageTree = { template = "YellowSausageTree", scale = 1, collide = true },
	riceCookerSprout = { template = "RiceCookerSprout", scale = 1, collide = false },
	rice = { template = "Rice", scale = 1, collide = false },
	carrot = { template = "Carrot", scale = 1, collide = false },
	potato = { template = "Potato", scale = 1, collide = false },
	cookingPot = { template = "CookingPot", scale = 1, collide = true },
} :: { [string]: AssetSpec }

function Assets.get(key: string): AssetSpec?
	return Assets.MODELS[key]
end

function Assets.keys(): { string }
	local keys = {}
	for key in Assets.MODELS do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return Assets

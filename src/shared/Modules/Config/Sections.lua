local Sections = {}

Sections.SIZE = 212
Sections.GRID = 6
Sections.HALF = Sections.GRID * Sections.SIZE / 2
Sections.SCATTER_LIMIT = 560

export type Cell = {
	i: number,
	j: number,
	coord: string,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	cx: number,
	cz: number,
	theme: string,
}

local COLUMNS = "ABCDEF"

function Sections.coord(i: number, j: number): string
	return COLUMNS:sub(i, i) .. tostring(j)
end

function Sections.parse(coord: string): (number?, number?)
	local letter, rank = tostring(coord):upper():match("^(%a)(%d+)$")
	if not letter then
		return nil, nil
	end
	local i = COLUMNS:find(letter, 1, true)
	local j = tonumber(rank)
	if not i or not j or j < 1 or j > Sections.GRID then
		return nil, nil
	end
	return i, j
end

local MAP = {
	{ "sakura", "sakura", "sakura", "bare", "bare", "meadow" },
	{ "flower", "ramen", "farm", "bare", "bare", "flower" },
	{ "meadow", "berry", "kitchen", "library", "bare", "grove" },
	{ "meadow", "bramble", "market", "bare", "bare", "grove" },
	{ "meadow", "sausage", "sausage", "mushroom", "snow", "lake" },
	{ "meadow", "sausage", "sausage", "grove", "quarry", "meadowQuiet" },
}

function Sections.themeAt(i: number, j: number): string?
	if i < 1 or i > Sections.GRID or j < 1 or j > Sections.GRID then
		return nil
	end
	return MAP[Sections.GRID + 1 - j][i]
end

function Sections.cell(i: number, j: number): Cell?
	local theme = Sections.themeAt(i, j)
	if not theme then
		return nil
	end
	local minX = -Sections.HALF + (i - 1) * Sections.SIZE
	local minZ = -Sections.HALF + (j - 1) * Sections.SIZE
	return {
		i = i,
		j = j,
		coord = Sections.coord(i, j),
		minX = minX,
		minZ = minZ,
		maxX = minX + Sections.SIZE,
		maxZ = minZ + Sections.SIZE,
		cx = minX + Sections.SIZE / 2,
		cz = minZ + Sections.SIZE / 2,
		theme = theme,
	}
end

function Sections.cellAt(x: number, z: number): Cell?
	local i = math.floor((x + Sections.HALF) / Sections.SIZE) + 1
	local j = math.floor((z + Sections.HALF) / Sections.SIZE) + 1
	return Sections.cell(i, j)
end

function Sections.byCoord(coord: string): Cell?
	local i, j = Sections.parse(coord)
	if not i or not j then
		return nil
	end
	return Sections.cell(i, j)
end

function Sections.isWild(x: number, z: number): boolean
	local cell = Sections.cellAt(x, z)
	local theme = cell and Sections.THEMES[cell.theme]
	return theme ~= nil and theme.wild == true
end

function Sections.cells(): { Cell }
	local result = {}
	for j = 1, Sections.GRID do
		for i = 1, Sections.GRID do
			local cell = Sections.cell(i, j)
			if cell then
				table.insert(result, cell)
			end
		end
	end
	return result
end

function Sections.cellsNearestFirst(): { Cell }
	local result = Sections.cells()
	table.sort(result, function(a, b)
		return a.cx * a.cx + a.cz * a.cz < b.cx * b.cx + b.cz * b.cz
	end)
	return result
end

Sections.THEMES = {
	meadow = {
		name = "Wild Meadow",
		sub = "soft grass, softer naps",
		material = "LeafyGrass",
		recipe = {
			{ kind = "tree", count = 10, h = { 9, 16 }, canopy = { 10, 15 } },
			{ kind = "bush", count = 12, s = { 3, 6 } },
			{ kind = "stone", count = 6, s = { 3, 6 } },
			{ kind = "log", count = 3, l = { 6, 10 } },
			{ kind = "grass", count = 24 },
			{ kind = "grassPatch", count = 5, h = { 1.6, 2.4 } },
			{ kind = "flower", count = 6 },
			{ kind = "coded", fn = "pond", count = 1 },
			{ kind = "coded", fn = "boulder", count = 1 },
			{ kind = "house", count = 1 },
		},
	},
	grove = {
		name = "The Grove",
		sub = "mind the shade",
		material = "LeafyGrass",
		recipe = {
			{ kind = "tree", count = 26, h = { 10, 17 }, canopy = { 9, 14 } },
			{ kind = "bush", count = 10, s = { 3, 6 } },
			{ kind = "log", count = 4, l = { 6, 10 } },
			{ kind = "stone", count = 5, s = { 3, 6 } },
			{ kind = "grass", count = 18 },
			{ kind = "grassPatch", count = 4, h = { 1.6, 2.4 } },
			{ kind = "coded", fn = "boulder", count = 1 },
			{ kind = "house", count = 1 },
		},
	},
	town = {
		name = "Town",
		sub = "home sweet home",
		material = "Grass",
		recipe = {
			{ kind = "house", count = 2 },
			{ kind = "prop", key = "pinkBench", count = 3, h = { 3.2, 3.2 }, faceOrigin = true },
			{ kind = "prop", key = "lantern", count = 6, h = { 4.4, 4.6 } },
			{ kind = "prop", key = "mailBox", count = 2, h = { 3.6, 3.6 } },
			{ kind = "prop", key = "laundryLine", count = 1, h = { 5.5, 5.5 } },
			{ kind = "flower", count = 5 },
			{ kind = "grass", count = 12 },
			{ kind = "grassPatch", count = 3, h = { 1.6, 2.4 } },
		},
	},

	library = {
		name = "Library",
		sub = "quiet, and then an exam",
		material = "Grass",
		arch = false,
		recipe = {
			{ kind = "desk", count = 3 },
			{ kind = "coded", fn = "bookStack", count = 4 },
			{ kind = "prop", key = "sakuraTree", count = 5, h = { 15, 20 } },
			{ kind = "flower", count = 5 },
			{ kind = "grassPatch", count = 5, h = { 1.6, 2.4 } },
			{ kind = "grass", count = 12 },
		},
	},
	kitchen = {
		name = "Kitchen",
		sub = "something is always on",
		material = "Grass",
		arch = false,
		recipe = {
			{ kind = "coded", fn = "berryCrate", count = 4 },
			{ kind = "prop", key = "wateringCan", count = 1, h = { 1.5, 1.8 } },
			{ kind = "prop", key = "sakuraTree", count = 3, h = { 14, 18 } },
			{ kind = "flower", count = 5 },
			{ kind = "grassPatch", count = 5, h = { 1.6, 2.4 } },
			{ kind = "grass", count = 12 },
		},
	},
	market = {
		name = "Market Square",
		sub = "spend it while you have it",
		material = "Grass",
		arch = false,
		recipe = {
			{ kind = "prop", key = "sakuraTree", count = 7, h = { 15, 21 } },
			{ kind = "tree", count = 5, h = { 10, 15 }, canopy = { 9, 13 } },
			{ kind = "prop", key = "lantern", count = 10, h = { 4.4, 4.6 } },
			{ kind = "prop", key = "lanternTall", count = 4, h = { 6.5, 6.5 } },
			{ kind = "prop", key = "pinkBench", count = 5, h = { 3.2, 3.2 }, faceOrigin = true },
			{ kind = "prop", key = "picnicTable", count = 2, h = { 3.4, 3.4 }, faceOrigin = true },
			{ kind = "prop", key = "shopStall", count = 2, h = { 7, 7 } },
			{ kind = "coded", fn = "berryCrate", count = 6 },
			{ kind = "coded", fn = "stoneLantern", count = 4 },
			{ kind = "prop", key = "mailBox", count = 1, h = { 3.6, 3.6 } },
			{ kind = "bush", count = 10, s = { 3, 5.5 } },
			{ kind = "flower", count = 14 },
			{ kind = "coded", fn = "tulip", count = 14 },
			{ kind = "grassPatch", count = 9, h = { 1.6, 2.4 } },
			{ kind = "grass", count = 20 },
			{ kind = "stone", count = 4, s = { 3, 5 } },
		},
	},
	bare = {
		name = "Open Ground",
		sub = "nothing here yet",
		material = "LeafyGrass",
		bare = true,
		recipe = {},
	},
	farm = {
		name = "Farm Land",
		sub = "mind the crops",
		material = "Ground",
		fence = true,
		recipe = {
			{ kind = "coded", fn = "tilledRow", count = 6 },
			{ kind = "prop", key = "carrot", count = 12, h = { 1.6, 2.2 }, upright = true },
			{ kind = "prop", key = "potato", count = 10, h = { 1.4, 1.9 }, upright = true },
			{ kind = "prop", key = "riceCookerSprout", count = 4, h = { 3, 3.4 }, upright = true },
			{ kind = "coded", fn = "hayBale", count = 4 },
			{ kind = "coded", fn = "scarecrow", count = 2 },
			{ kind = "prop", key = "wateringCan", count = 2, h = { 1.5, 1.8 } },
			{ kind = "grass", count = 16 },
			{ kind = "flower", count = 3 },
			{ kind = "house", count = 1 },
		},
	},
	berry = {
		name = "Berry Land",
		sub = "pick your fill",
		material = "Grass",
		arch = true,
		recipe = {
			{ kind = "prop", key = "blueBerryBush", count = 7, h = { 3.4, 4.2 }, upright = true },
			{ kind = "prop", key = "purpleBerryBush", count = 6, h = { 3.4, 4.2 }, upright = true },
			{ kind = "prop", key = "whiteBerryBush", count = 2, h = { 3.8, 4.4 }, upright = true },
			{ kind = "coded", fn = "berryCrate", count = 3 },
			{ kind = "flower", count = 6 },
			{ kind = "grassPatch", count = 6, h = { 1.6, 2.4 } },
			{ kind = "grass", count = 16 },
			{ kind = "bush", count = 6, s = { 3, 5 } },
		},
	},
	bramble = {
		name = "Bramble Hollow",
		sub = "watch your paws",
		material = "Mud",
		recipe = {
			{ kind = "prop", key = "blackBerryBush", count = 8, h = { 3.6, 4.4 }, upright = true },
			{ kind = "prop", key = "purpleBerryBush", count = 4, h = { 3.4, 4 }, upright = true },
			{ kind = "bush", count = 12, s = { 3.5, 6 } },
			{ kind = "log", count = 5, l = { 6, 10 } },
			{ kind = "stone", count = 6, s = { 3, 6 } },
			{ kind = "tree", count = 6, h = { 10, 14 }, canopy = { 9, 13 } },
			{ kind = "grass", count = 12 },
			{ kind = "coded", fn = "boulder", count = 1 },
		},
	},

	sausage = {
		name = "Sausage Forest",
		sub = "they grow on trees",
		material = "Grass",
		wild = true,
		relief = { amp = 7, scale = 58, subdivide = 10 },
		recipe = {
			{ kind = "bush", count = 58, s = { 3, 9 } },
			{ kind = "grass", count = 74 },
			{ kind = "grassPatch", count = 28, h = { 1.6, 3 } },
			{ kind = "flower", count = 20 },
			{ kind = "stone", count = 20, s = { 2.5, 6.5 } },
			{ kind = "log", count = 20, l = { 6, 13 } },
			{ kind = "prop", key = "brownMushroom", count = 22, h = { 1.8, 3.2 }, upright = true },
			{ kind = "coded", fn = "boulder", count = 3 },
		},
	},
	mushroom = {
		name = "Mushroom Hollow",
		sub = "mind the caps",
		material = "Mud",
		arch = true,
		recipe = {
			{ kind = "coded", fn = "giantMushroom", count = 5 },
			{ kind = "prop", key = "brownMushroom", count = 9, h = { 2, 3 }, upright = true },
			{ kind = "prop", key = "whiteMushroom", count = 5, h = { 2.4, 3.2 }, upright = true },
			{ kind = "log", count = 4, l = { 6, 10 } },
			{ kind = "stone", count = 6, s = { 3, 6 } },
			{ kind = "bush", count = 5, s = { 3, 5 } },
			{ kind = "grass", count = 12 },
		},
	},
	snow = {
		name = "Snow Thicket",
		sub = "white berries, white caps",
		material = "Snow",
		arch = true,
		recipe = {
			{ kind = "coded", fn = "snowTree", count = 9 },
			{ kind = "prop", key = "whiteBerryBush", count = 6, h = { 3.6, 4.4 }, upright = true },
			{ kind = "prop", key = "whiteMushroom", count = 6, h = { 2.4, 3.2 }, upright = true },
			{ kind = "stone", count = 6, s = { 3, 6 } },
			{ kind = "bush", count = 4, s = { 3, 5 } },
			{ kind = "coded", fn = "boulder", count = 2 },
			{ kind = "grass", count = 8 },
		},
	},
	sakura = {
		name = "Sakura Heights",
		sub = "petals on the wind",
		material = "Grass",
		arch = true,
		recipe = {
			{ kind = "prop", key = "sakuraTree", count = 8, h = { 16, 24 } },
			{ kind = "prop", key = "pinkBench", count = 3, h = { 3.2, 3.2 }, faceOrigin = true },
			{ kind = "prop", key = "picnicTable", count = 2, h = { 3.4, 3.4 }, faceOrigin = true },
			{ kind = "prop", key = "dango", count = 1, h = { 9, 9 }, edible = true },
			{ kind = "flower", count = 6 },
			{ kind = "grassPatch", count = 6, h = { 1.6, 2.4 } },
			{ kind = "grass", count = 16 },
			{ kind = "stone", count = 3, s = { 3, 5 } },
		},
	},
	tea = {
		name = "Tea Garden",
		sub = "steep a while",
		material = "Sand",
		arch = true,
		recipe = {
			{ kind = "prop", key = "lowTable", count = 3, h = { 6.5, 7.5 } },
			{ kind = "prop", key = "teaPot", count = 3, h = { 3.2, 3.8 } },
			{ kind = "prop", key = "teaCup", count = 6, h = { 1.6, 2 } },
			{ kind = "prop", key = "floorCushion", count = 6, h = { 3.2, 3.8 } },
			{ kind = "coded", fn = "stoneLantern", count = 5 },
			{ kind = "coded", fn = "sandDisc", count = 3 },
			{ kind = "prop", key = "sakuraTree", count = 2, h = { 14, 18 } },
			{ kind = "stone", count = 6, s = { 3, 6 } },
			{ kind = "grass", count = 10 },
		},
	},
	flower = {
		name = "Flower Fields",
		sub = "mind the bees",
		material = "Grass",
		recipe = {
			{ kind = "flower", count = 14 },
			{ kind = "coded", fn = "tulip", count = 18 },
			{ kind = "grassPatch", count = 7, h = { 1.6, 2.4 } },
			{ kind = "grass", count = 20 },
			{ kind = "bush", count = 4, s = { 3, 5 } },
			{ kind = "stone", count = 3, s = { 3, 5 } },
			{ kind = "prop", key = "lantern", count = 3, h = { 4.4, 4.6 } },
		},
	},
	picnic = {
		name = "Picnic Fields",
		sub = "bring an appetite",
		material = "Grass",
		recipe = {
			{ kind = "prop", key = "picnicTable", count = 3, h = { 3.4, 3.4 }, faceOrigin = true },
			{ kind = "prop", key = "pancakes", count = 1, h = { 9, 9 } },
			{ kind = "prop", key = "yogurtBerry", count = 1, h = { 7, 7 } },
			{ kind = "prop", key = "yogurtVanilla", count = 1, h = { 7, 7 }, pitch = 90 },
			{ kind = "prop", key = "dangoPlatter", count = 1, h = { 9, 9 }, edible = true },
			{ kind = "prop", key = "friendStand", count = 1, h = { 8, 8 } },
			{ kind = "prop", key = "pinkBench", count = 3, h = { 3.2, 3.2 }, faceOrigin = true },
			{ kind = "prop", key = "sakuraTree", count = 3, h = { 14, 18 } },
			{ kind = "flower", count = 5 },
			{ kind = "grass", count = 12 },
			{ kind = "grassPatch", count = 4, h = { 1.6, 2.4 } },
		},
	},
	ramen = {
		name = "Ramen Quarter",
		sub = "hot bowls ahead",
		material = "Cobblestone",
		arch = true,
		recipe = {
			{ kind = "prop", key = "shopRed", count = 3, h = { 9, 11 } },
			{ kind = "prop", key = "shopBlue", count = 2, h = { 9, 11 } },
			{ kind = "prop", key = "shopStall", count = 2, h = { 7, 7 } },
			{ kind = "prop", key = "ramen", count = 3, h = { 8, 10 } },
			{ kind = "prop", key = "lowTable", count = 2, h = { 6, 7 } },
			{ kind = "prop", key = "floorCushion", count = 3, h = { 3.2, 3.8 } },
			{ kind = "prop", key = "lantern", count = 10, h = { 4.4, 4.6 } },
			{ kind = "prop", key = "lanternTall", count = 3, h = { 6.5, 6.5 } },
			{ kind = "grass", count = 8 },
		},
	},
	study = {
		name = "Exam Grounds",
		sub = "grades 5 to 1",
		material = "Grass",
		recipe = {
			{ kind = "desk", count = 3 },
			{ kind = "coded", fn = "bookStack", count = 6 },
			{ kind = "prop", key = "lantern", count = 6, h = { 4.4, 4.6 } },
			{ kind = "tree", count = 5, h = { 9, 14 }, canopy = { 9, 13 } },
			{ kind = "bush", count = 6, s = { 3, 5 } },
			{ kind = "grass", count = 12 },
			{ kind = "flower", count = 3 },
		},
	},
	rocky = {
		name = "Rocky Knoll",
		sub = "watch your step",
		material = "Rock",
		recipe = {
			{ kind = "stone", count = 16, s = { 4, 9 } },
			{ kind = "coded", fn = "cairn", count = 5 },
			{ kind = "coded", fn = "boulder", count = 4 },
			{ kind = "log", count = 2, l = { 6, 10 } },
			{ kind = "bush", count = 4, s = { 3, 5 } },
			{ kind = "grass", count = 6 },
		},
	},
	meadowQuiet = {
		name = "Quiet Meadow",
		sub = "nobody built here",
		material = "LeafyGrass",
		recipe = {
			{ kind = "tree", count = 13, h = { 9, 17 }, canopy = { 10, 16 } },
			{ kind = "bush", count = 16, s = { 3, 7 } },
			{ kind = "stone", count = 8, s = { 3, 6 } },
			{ kind = "log", count = 5, l = { 6, 11 } },
			{ kind = "grass", count = 30 },
			{ kind = "grassPatch", count = 8, h = { 1.6, 2.6 } },
			{ kind = "flower", count = 9 },
			{ kind = "coded", fn = "boulder", count = 2 },
		},
	},
	lake = {
		name = "Still Water",
		sub = "something is biting",
		material = "Sand",
		recipe = {
			{ kind = "coded", fn = "reedClump", count = 16 },
			{ kind = "coded", fn = "cattailStand", count = 10 },
			{ kind = "coded", fn = "mooringPost", count = 4 },
			{ kind = "coded", fn = "rowBoat", count = 1 },
			{ kind = "coded", fn = "boulder", count = 2 },
			{ kind = "stone", count = 9, s = { 3, 6 } },
			{ kind = "log", count = 4, l = { 6, 11 } },
			{ kind = "tree", count = 6, h = { 10, 15 }, canopy = { 9, 13 } },
			{ kind = "grassPatch", count = 10, h = { 1.6, 2.6 } },
			{ kind = "grass", count = 18 },
			{ kind = "flower", count = 5 },
		},
	},
	quarry = {
		name = "The Quarry",
		sub = "mind the drop",
		material = "Slate",
		recipe = {
			{ kind = "coded", fn = "spoilHeap", count = 6 },
			{ kind = "coded", fn = "timberScaffold", count = 4 },
			{ kind = "coded", fn = "quarryCart", count = 2 },
			{ kind = "coded", fn = "cairn", count = 3 },
			{ kind = "coded", fn = "boulder", count = 5 },
			{ kind = "stone", count = 18, s = { 4, 10 } },
			{ kind = "log", count = 3, l = { 6, 10 } },
			{ kind = "bush", count = 4, s = { 3, 5 } },
			{ kind = "grass", count = 5 },
		},
	},
}

return Sections

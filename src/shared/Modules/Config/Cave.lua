--!strict

local Sections = require(script.Parent.Sections)
local Cave = {}

Cave.GRID = 13
Cave.CELL = 16
Cave.MARGIN = (Sections.SIZE - Cave.GRID * Cave.CELL) / 2

Cave.SURFACE_LIGHT = {
	ambient = Color3.fromRGB(96, 95, 100),
	outdoorAmbient = Color3.fromRGB(118, 117, 122),
	brightness = 1.9,
	fogEnd = 8500,
	fogColor = Color3.fromRGB(214, 226, 236),
}

Cave.CEILING = 24
Cave.ROOM_CEILING = 34
Cave.BOSS_CEILING = 46

Cave.WALL = "#"
Cave.CORRIDOR = "."
Cave.ROOM = "O"
Cave.ENTRANCE = "E"
Cave.DOWN = "^"
Cave.LANDING = "v"
Cave.GLOWCAP = "G"
Cave.MOONCAP = "M"
Cave.BOSS = "B"
Cave.SURFACE = "X"

Cave.OPEN = (
	{
		["."] = true,
		["O"] = true,
		["E"] = true,
		["^"] = true,
		["v"] = true,
		["G"] = true,
		["M"] = true,
		["B"] = true,
		["X"] = true,
		["s"] = true,
		["p"] = true,
		["w"] = true,
	}
) :: { [string]: boolean }

Cave.CEILING_FOR = ({
	["O"] = Cave.ROOM_CEILING,
	["B"] = Cave.BOSS_CEILING,
}) :: { [string]: number }

Cave.SPAWN_CHARS = ({
	s = "cave_sporeling",
	p = "cave_pebblejaw",
	w = "cave_wisp",
}) :: { [string]: string }

Cave.SPAWN_COUNT = ({
	s = 3,
	p = 2,
	w = 1,
}) :: { [string]: number }

Cave.BOSS_MOB = "cave_mycelia"

Cave.CLUMP_CHARS = ({
	G = "cave_glowcap",
	M = "cave_mooncap",
}) :: { [string]: string }

Cave.SHAFT = {
	bore = 50,

	radius = 30,
	width = 18,
	thickness = 2,

	stepAngle = 15,

	slopeDegrees = 15,

	headroom = 18,

	pillarRadius = 20.5,
	railHeight = 4,
	railEvery = 2,
	lightEvery = 5,
}

Cave.MOUTH_DRESSING = {
	ringRadius = 64,
	stones = 14,
	stoneHeight = { 9, 21 },
	stoneWidth = { 7, 15 },
	gateHeight = 34,
	gateWidth = 8,
	barrierSize = Vector3.new(22, 12, 2),

	gapDegrees = 30,
	lanterns = 6,
	caps = 20,

	capRadius = { 58, 96 },
}

Cave.MOUTH = {
	offset = Vector2.new(0, 0),
	search = 24,
	searchLimit = 8,

	clearRadius = 100,

	lip = 6,
}

Cave.SURFACE_SEAL = {
	thickness = 2,
	overlap = 4,
	doorwayWidth = 22,
	doorwayInset = 8,
}

export type LevelDefinition = {
	index: number,
	coord: string,
	name: string,
	floorY: number,
	grid: { string },
	light: {
		ambient: Color3,
		outdoorAmbient: Color3,
		brightness: number,
		fogEnd: number,
		fogColor: Color3,
	},
}

Cave.LEVELS = {
	{
		index = 1,
		coord = "D2",
		name = "Spore Shallows",
		floorY = -60,
		grid = {
			"#############",
			"#GG.......GG#",
			"#.#.#####.#.#",
			"#..OOOOOOO..#",
			"#.#OOOOOOO#.#",
			"#..OOOOOOO..#",
			"#.#OOOEOOO#.#",
			"#..OOOOOOO..#",
			"#.#OOOOOOO#.#",
			"#..OOOOOOO..#",
			"#.#.#####.#.#",
			"#Gs.......s^#",
			"#############",
		},
		light = {
			ambient = Color3.fromRGB(74, 70, 86),
			outdoorAmbient = Color3.fromRGB(58, 56, 72),
			brightness = 1,
			fogEnd = 220,
			fogColor = Color3.fromRGB(46, 44, 58),
		},
	},
	{
		index = 2,
		coord = "E2",
		name = "The Winding",
		floorY = -110,
		grid = {
			"#############",
			"#...#...#..G#",
			"#.#.#.#.#.#.#",
			"#.#...#p..#.#",
			"#.#####.###.#",
			"#w..#...#.G.#",
			"#.#.#.#.#.#.#",
			"#.#.#.#.#.#p#",
			"#.#.#.#...#.#",
			"#.#...#.###.#",
			"#.###p#.#..w#",
			"v...#.^.#.#.#",
			"#############",
		},
		light = {
			ambient = Color3.fromRGB(40, 38, 50),
			outdoorAmbient = Color3.fromRGB(26, 25, 34),
			brightness = 0.5,
			fogEnd = 130,
			fogColor = Color3.fromRGB(24, 23, 32),
		},
	},
	{
		index = 3,
		coord = "E1",
		name = "The Cap Mother's Floor",
		floorY = -160,
		grid = {
			"#############",
			"#M..#.v.#..M#",
			"#.#.#.#.#.#.#",
			"#.#.....#.#.#",
			"#.###.#.#.#.#",
			"#...#.#.s.#.#",
			"#.#.#.#.#.#.#",
			"#.#.s.X.#...#",
			"#.###.###.#.#",
			"#...#BBBBB#.#",
			"#.###BBBBB#.#",
			"#.s.#BBBBB#.#",
			"#############",
		},
		light = {
			ambient = Color3.fromRGB(12, 11, 16),
			outdoorAmbient = Color3.fromRGB(6, 6, 10),
			brightness = 0.15,
			fogEnd = 70,
			fogColor = Color3.fromRGB(8, 8, 12),
		},
	},
} :: { LevelDefinition }

Cave.PLINTH_BOTTOM = -196
Cave.PLINTH_TOP = -14

function Cave.get(index: number): LevelDefinition?
	return Cave.LEVELS[index]
end

function Cave.check(): { string }
	local problems = {}
	local seen: { [string]: number } = {}

	for _, level in Cave.LEVELS do
		local cell = Sections.byCoord(level.coord)
		if not cell then
			table.insert(
				problems,
				`level {level.index} ({level.name}) names section "{level.coord}", which is not on the board`
			)
			continue
		end
		if seen[level.coord] then
			table.insert(
				problems,
				`level {level.index} and level {seen[level.coord]} are both in section "{level.coord}"; `
					.. "two levels in one square would carve through each other"
			)
		end
		seen[level.coord] = level.index
	end

	for index = 1, #Cave.LEVELS - 1 do
		local upper = Cave.LEVELS[index]
		local lower = Cave.LEVELS[index + 1]
		local a = Sections.byCoord(upper.coord)
		local b = Sections.byCoord(lower.coord)
		if not a or not b then
			continue
		end

		local gap = math.max(math.abs(a.i - b.i), math.abs(a.j - b.j))
		if gap > 1 then
			table.insert(
				problems,
				`levels {index} ("{upper.coord}") and {index + 1} ("{lower.coord}") are {gap} sections apart; `
					.. "the descent tunnel between them would cross everything in between"
			)
		end

		if lower.floorY + Cave.BOSS_CEILING >= upper.floorY then
			table.insert(
				problems,
				`level {index + 1} ceiling reaches {lower.floorY + Cave.BOSS_CEILING}, at or above level {index}'s `
					.. `floor of {upper.floorY}; lower the deeper floorY`
			)
		end
	end

	return problems
end

function Cave.mouthCell(): Sections.Cell?
	local first = Cave.LEVELS[1]
	return if first then Sections.byCoord(first.coord) else nil
end

function Cave.charAt(level: LevelDefinition, row: number, col: number): string
	if row < 1 or row > Cave.GRID or col < 1 or col > Cave.GRID then
		return Cave.WALL
	end
	return level.grid[row]:sub(col, col)
end

function Cave.isOpen(level: LevelDefinition, row: number, col: number): boolean
	return Cave.OPEN[Cave.charAt(level, row, col)] == true
end

function Cave.cellPosition(level: LevelDefinition, row: number, col: number): Vector3?
	local cell = Sections.byCoord(level.coord)
	if not cell then
		return nil
	end
	local x = cell.minX + Cave.MARGIN + (col - 0.5) * Cave.CELL
	local z = cell.maxZ - Cave.MARGIN - (row - 0.5) * Cave.CELL
	return Vector3.new(x, level.floorY, z)
end

function Cave.find(level: LevelDefinition, char: string): { { row: number, col: number } }
	local found = {}
	for row = 1, Cave.GRID do
		for col = 1, Cave.GRID do
			if Cave.charAt(level, row, col) == char then
				table.insert(found, { row = row, col = col })
			end
		end
	end
	return found
end

function Cave.first(level: LevelDefinition, char: string): { row: number, col: number }?
	return Cave.find(level, char)[1]
end

function Cave.bossCentre(level: LevelDefinition): Vector3?
	local cells = Cave.find(level, Cave.BOSS)
	if #cells == 0 then
		return nil
	end
	local row, col = 0, 0
	for _, entry in cells do
		row += entry.row
		col += entry.col
	end
	return Cave.cellPosition(level, row / #cells, col / #cells)
end

function Cave.levelAt(position: Vector3): LevelDefinition?
	for _, level in Cave.LEVELS do
		local cell = Sections.byCoord(level.coord)
		if
			cell
			and position.X >= cell.minX
			and position.X <= cell.maxX
			and position.Z >= cell.minZ
			and position.Z <= cell.maxZ
			and position.Y <= level.floorY + Cave.BOSS_CEILING
			and position.Y >= level.floorY - Cave.CELL
		then
			return level
		end
	end
	return nil
end

function Cave.reachable(level: LevelDefinition): ({ [number]: boolean }, number)
	local start = Cave.first(level, Cave.ENTRANCE) or Cave.first(level, Cave.LANDING)
	local seen: { [number]: boolean } = {}
	local total = 0

	for row = 1, Cave.GRID do
		for col = 1, Cave.GRID do
			if Cave.isOpen(level, row, col) then
				total += 1
			end
		end
	end

	if not start then
		return seen, total
	end

	local queue = { start }
	seen[start.row * 100 + start.col] = true

	local head = 1
	while head <= #queue do
		local at = queue[head]
		head += 1
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local row, col = at.row + step[1], at.col + step[2]
			local key = row * 100 + col
			if not seen[key] and Cave.isOpen(level, row, col) then
				seen[key] = true
				table.insert(queue, { row = row, col = col })
			end
		end
	end

	return seen, total
end

return Cave

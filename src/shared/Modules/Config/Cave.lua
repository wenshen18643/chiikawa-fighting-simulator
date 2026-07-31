--!strict

--[[
	The mushroom cave: three board sections carved out from underneath, one
	level per section, each deeper than the last.

	The whole cave is DATA. Every corridor, every clump and every spawn is a
	character in a grid here, so the maze can be read, redrawn and argued with
	without opening Studio -- and so the client's cave map can be drawn from the
	same source the server carved from, the way Minimap already draws the
	surface from Config/Layout. Two descriptions of one place always drift.

	Grids are stored top row first, where the top row is the HIGHEST Z, matching
	Sections.MAP. A level is 13 x 13 cells of 16 studs, which is 208 studs
	inside a 212-stud section: a 2-stud rind of untouched rock all the way
	round, so no level ever breaks out through the side of its own cell.

	Levels do not share XZ, so a ramp between them cannot be a hole in a floor.
	A descent is instead a short tunnel at the UPPER level's depth, running to a
	spiral shaft sunk at the lower level's landing. The tunnel's headroom stops
	well above the lower level's ceiling, which is what keeps the two from
	punching into each other -- see SHAFT and CaveService.

	--------------------------------------------------------------------------------
	MOVING THE CAVE
	--------------------------------------------------------------------------------

	Change the `coord` on a level below. That is the whole procedure.

	Every other place a section is named derives from these three strings: the
	rock plinth, the carve, the sinkhole, the mob spawns, the mushroom clumps and
	the client's cave map all ask Sections.byCoord(level.coord). There is
	deliberately no second copy of "which section is the cave in" to keep in
	sync -- the entrance used to carry its own and it is gone.

	Cave.check() is run by CaveService at startup and will say so, by name, if
	the new coords are unknown, doubled up, or so far apart that the tunnel
	between two levels would cross half the board.
]]

local Sections = require(script.Parent.Sections)

local Cave = {}

Cave.GRID = 13
Cave.CELL = 16
Cave.MARGIN = (Sections.SIZE - Cave.GRID * Cave.CELL) / 2

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

Cave.OPEN = ({
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
}) :: { [string]: boolean }

Cave.CEILING_FOR = ({
	["O"] = Cave.ROOM_CEILING,
	["B"] = Cave.BOSS_CEILING,
}) :: { [string]: number }

Cave.SPAWN_CHARS = ({
	s = "cave_sporeling",
	p = "cave_pebblejaw",
	w = "cave_wisp",
}) :: { [string]: string }

--[[
	How many stand at one letter. Sporelings come in threes because a single
	one is a speed bump; a Pebblejaw pair is already a corridor you think twice
	about; a wisp is alone or it is a lamp rather than a thing you chase.

	Nine Sporelings, six Pebblejaws, two wisps and the Cap Mother: twenty-seven
	across three levels, against the sausage forest's ninety.
]]
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

--[[
	The way down, and the way back up.

	--------------------------------------------------------------------------------
	THE RAMP IS BUILT, NOT CARVED
	--------------------------------------------------------------------------------

	It used to be terrain: a helix of air carved into rock, walked on the rock
	left underneath. That trapped players twice, for the same reason both times.
	The walkable surface only existed as an ABSENCE, so anything else carved in
	the same footprint deleted it -- first a 30-stud ball at the mouth that ate
	the top thirty studs of staircase, then a 56-stud landing box that ate the
	bottom twenty-four. Both times the player could walk in and not climb out.

	Terrain also could not hold the shape. Voxels are four studs; a rise of one
	and a half is below the resolution the engine stores, so what got built was
	never quite what the numbers said.

	So the shaft is now a wide carved VOID with an anchored spiral ramp standing
	inside it. A part cannot be accidentally deleted by a later fill, it is
	exactly the size it says, and it can be lit and railed and read as a made
	thing -- which is what a player needs, because this is the only way in or out.
]]
Cave.SHAFT = {
	-- Half-width of the carved void. Comfortably clear of the ramp's outer edge
	-- so no future carve can reach the walkable surface.
	bore = 36,
	-- Centreline of the ramp, and how wide the walkable slab is.
	radius = 22,
	width = 14,
	thickness = 2,
	-- Degrees of turn per built segment. Smaller is smoother and costs parts.
	stepAngle = 15,
	-- Rise over run, as an angle. Fifteen degrees is a walk; the engine will
	-- take far worse, but this is meant to read as a ramp rather than a climb.
	slopeDegrees = 15,
	-- Headroom above the ramp, and how far the void extends past the top step.
	headroom = 18,
	-- Meets the ramp's inner edge (radius - width/2 = 15). Any smaller leaves an
	-- open slot down the centre of the shaft to fall through.
	pillarRadius = 14.5,
	railHeight = 4,
	railEvery = 2,
	lightEvery = 5,
}

--[[
	What the mouth looks like from fifty studs away.

	The first build put a hole in a field and nothing else, and a hole is
	invisible until you are standing over it -- there is no silhouette, no
	landmark, nothing to walk towards. So the entrance gets a broken ring of
	standing rock with a gap where the ramp goes in, two taller stones marking
	that gap, lanterns, and glowing caps spilling out of it.

	The ring is BROKEN ON PURPOSE. A closed ring reads as a wall; a gap reads as
	a door, and it points at the top of the ramp.
]]
Cave.MOUTH_DRESSING = {
	--[[
		OUTSIDE THE BORE, including its corners. The shaft is carved as an
		octagon whose widest point is about 8% past `bore` (39 studs at bore 36),
		so a ring any tighter than that stands its stones over open air.
	]]
	ringRadius = 46,
	stones = 11,
	stoneHeight = { 7, 16 },
	stoneWidth = { 6, 13 },
	gateHeight = 26,
	gateWidth = 7,
	-- Degrees either side of the entry bearing left clear of standing stone.
	gapDegrees = 34,
	lanterns = 4,
	caps = 14,
	-- Also clear of the bore, for the same reason as the ring.
	capRadius = { 42, 74 },
}

--[[
	Where the sinkhole opens, as an offset from the ENTRANCE LEVEL's cell centre.

	There is no `coord` here on purpose. The mouth belongs to whichever section
	Cave.LEVELS[1] names, so moving the cave moves its entrance with it and the
	two cannot disagree.

	The offset is a PREFERENCE, not a coordinate: the skill districts radiate
	from the plaza and cross the section grid, so CaveService validates the spot
	against Layout.isReserved and walks it outward until it clears one.

	`clearRadius` is how much surface dressing is swept away around the hole.
	The scenery pass seats its props by raycast long before this carves the
	ground out from under them, so without the sweep the mouth wears a halo of
	mushrooms and stones hanging in mid-air.
]]
Cave.MOUTH = {
	offset = Vector2.new(-52, 44),
	search = 24,
	searchLimit = 8,
	-- Wider than the stone ring, so the dressing lands on swept ground.
	clearRadius = 80,
	-- How far above the measured ground the ramp's top step starts, so the way
	-- in is a notch you can see and walk into rather than a seam in the grass.
	lip = 6,
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
			"#E...#...G..#",
			"#.#.#.#.###.#",
			"#.#.....#s..#",
			"#.#####.#.#.#",
			"#G..s.#...#.#",
			"###.#.###.#.#",
			"#...#...#.#G#",
			"#.###.#.#.#.#",
			"#.#G..#...#.#",
			"#.#.#####.#.#",
			"#...s.....#.^",
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
			"#...#.#.s.#X#",
			"#.#.#.#.#.#.#",
			"#.#.s...#...#",
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

--[[
	Everything that can go wrong when the cave is moved, in one list.

	Returns the complaints rather than warning, so CaveService can decide what
	is fatal. Changing a `coord` is a one-word edit with three ways to be
	quietly wrong -- a section that does not exist, two levels stacked in the
	same square, or levels so far apart that the connecting tunnel runs under
	half the board -- and none of the three is visible from the config.
]]
function Cave.check(): { string }
	local problems = {}
	local seen: { [string]: number } = {}

	for _, level in Cave.LEVELS do
		local cell = Sections.byCoord(level.coord)
		if not cell then
			table.insert(problems, `level {level.index} ({level.name}) names section "{level.coord}", which is not on the board`)
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

		--[[
			The descent tunnel runs at the upper level's depth from its own
			section into the one below it. Neighbouring sections keep that to a
			few studs; opposite corners of the board make it a two-thousand-stud
			corridor through everything in between.
		]]
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

--[[
	The section the sinkhole opens in: whichever one the first level is in.
	Derived rather than configured, so the entrance cannot be left behind in an
	empty field when the cave moves.
]]
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

--[[
	Grid cell to world position. Row 1 is the HIGHEST Z, so rows count down in
	Z the same way Sections.themeAt counts its own map down.
]]
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

--[[
	The boss room is a block of B rather than one cell, so its centre is the
	mean of the block: Mycelia is rooted at the middle of the floor it defends,
	not at whichever B the scan happened to reach first.
]]
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

--[[
	Every carved cell reachable from the level's own way in, walking only the
	four compass directions. A grid typo that seals the boss behind rock is a
	bug you find here at startup, not one a player finds forty minutes in.
]]
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

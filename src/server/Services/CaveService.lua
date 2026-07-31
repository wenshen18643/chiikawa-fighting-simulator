--!strict

--[[
	The mushroom cave: carves it, fills it, and answers "which level is this
	player standing on".

	The world's ground is a SHELL eight studs thick, so there is nothing under
	the board to hollow out. The cave therefore arrives in two passes: a solid
	rock PLINTH sunk beneath its three sections, and then air carved back out of
	it. Carving before filling would carve open sky.

	Everything about the shape comes out of Config/Cave. This file knows how to
	turn a character into a hole and nothing else about what the maze looks
	like, which is what lets the client draw the same maze from the same grid.

	It rides the background pass for the same reason TerrainBuilder does: a
	hundred thousand voxels is several frames, and nothing down here is
	reachable in the seconds that takes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Budget = require(Shared.Modules.Budget)
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Cave = require(Shared.Modules.Config.Cave)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)
local Sections = require(Shared.Modules.Config.Sections)
local UI = require(Shared.UI)

local ForagingService = require(script.Parent.ForagingService)
local MobService = require(script.Parent.MobService)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local WorldService = require(script.Parent.WorldService)

local CaveService = {}

local WORLD = Constants.WORLD
local LEVEL_ATTRIBUTE = "CaveLevel"

local STONE = Color3.fromRGB(104, 100, 112)
local STONE_DARK = Color3.fromRGB(66, 63, 74)
local GLOW_COLOR = Color3.fromRGB(178, 226, 208)

local folder: Folder
local mouthPosition: Vector3? = nil

CaveService.ready = false
local readySignal = Instance.new("BindableEvent")

function CaveService.awaitReady()
	if CaveService.ready then
		return
	end
	readySignal.Event:Wait()
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

--[[
	A grid typo that seals the boss behind rock is a bug worth finding at
	startup rather than forty minutes into somebody's expedition, so every
	carved cell must be walkable from the level's own way in before a single
	voxel is touched.
]]
local function validate(): boolean
	local ok = true

	--[[
		Everything that breaks when the cave is MOVED, said by name. Changing a
		level's `coord` is a one-word edit with three quiet ways to be wrong, and
		none of them is visible from the config -- see Cave.check.
	]]
	for _, problem in Cave.check() do
		warn(`[CaveService] {problem}`)
		ok = false
	end

	for _, level in Cave.LEVELS do
		if not Sections.byCoord(level.coord) then
			continue
		end

		local seen, total = Cave.reachable(level)
		local reached = 0
		for _ in seen do
			reached += 1
		end
		if reached ~= total then
			warn(
				`[CaveService] level {level.index} ({level.name}) has {total - reached} unreachable cells `
					.. `of {total}; check Config/Cave for a sealed corridor`
			)
			ok = false
		end
	end

	for index = 1, #Cave.LEVELS - 1 do
		if not Cave.first(Cave.LEVELS[index], Cave.DOWN) then
			warn(`[CaveService] level {index} has no "{Cave.DOWN}" descent`)
			ok = false
		end
		if not Cave.first(Cave.LEVELS[index + 1], Cave.LANDING) then
			warn(`[CaveService] level {index + 1} has no "{Cave.LANDING}" landing`)
			ok = false
		end
	end

	return ok
end

--------------------------------------------------------------------------------
-- Carving
--------------------------------------------------------------------------------

type Step = () -> ()

local function carveBox(centre: Vector3, size: Vector3)
	Workspace.Terrain:FillBlock(CFrame.new(centre), size, Enum.Material.Air)
end

--[[
	A straight tunnel between two points at the same depth, laid as overlapping
	boxes rather than one long one: a single FillBlock cannot be rotated onto an
	arbitrary bearing without also rotating its voxel grid, which leaves stepped
	walls a player snags on.
]]
local function carveTunnel(from: Vector3, to: Vector3, width: number, headroom: number, step: Step)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.01 then
		return
	end

	local spacing = width * 0.5
	local count = math.max(1, math.ceil(length / spacing))
	for index = 0, count do
		local at = from:Lerp(to, index / count)
		carveBox(Vector3.new(at.X, at.Y + headroom / 2, at.Z), Vector3.new(width, headroom, width))
		step()
	end
end

local function rock(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[
	A lamp on the ramp.

	Built rather than cloned: the way out of the cave must not depend on an
	upload being available today. It is also the only light in the shaft, so it
	carries an actual PointLight rather than just glowing.
]]
local function sconce(parent: Instance, at: CFrame)
	local post = rock(parent, "Sconce", Vector3.new(0.8, 5, 0.8), at * CFrame.new(0, 2.5, 0), STONE_DARK)

	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Size = Vector3.new(2.2, 2.8, 2.2)
	crystal.CFrame = at * CFrame.new(0, 5.4, 0) * CFrame.Angles(0, math.rad(24), math.rad(12))
	crystal.Color = GLOW_COLOR
	crystal.Material = Enum.Material.Neon
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.CanQuery = false
	crystal.Parent = parent

	local light = Instance.new("PointLight")
	light.Brightness = 2.2
	light.Range = 40
	light.Color = GLOW_COLOR
	light.Shadows = false
	light.Parent = crystal

	return post
end

--[[
	The shaft: a wide carved void with a spiral ramp STANDING in it.

	The ramp is anchored parts, not rock left between carves. Two players were
	trapped by the carved version, both times because something else carved in
	the same footprint deleted the walkable surface -- a ball at the top, then a
	landing box at the bottom. A part cannot be deleted by a fill, so that whole
	class of bug is gone rather than fixed.

	The void is bored `bore` studs wide against a ramp that reaches 29, which
	leaves seven studs of slack: room for a later carve to be sloppy without
	touching anything anybody stands on.

	Returns the world position and bearing of the TOP of the ramp, which is what
	the surface dressing points its gateway at.
]]
local function buildShaft(
	parent: Instance,
	x: number,
	z: number,
	topY: number,
	bottomY: number,
	step: Step
): (Vector3, number)
	local shaft = Cave.SHAFT
	local drop = math.max(topY - bottomY, 1)

	--[[
		Bored as an OCTAGON: one prism, plus the same prism turned forty-five
		degrees.

		A single square prism has corners 41% further out than its faces, and
		the ring of standing stones at the surface would then be sitting over
		four empty corners with nothing under them -- the floating-scenery bug
		again, self-inflicted. Two fills bring the worst case down to 8% and read
		as a round shaft besides. A stack of discs would be rounder still and is
		forty overlapping fills at voxel scale, which is a lottery.
	]]
	local bore = Vector3.new(shaft.bore * 2, (topY + shaft.headroom) - bottomY, shaft.bore * 2)
	local boreAt = CFrame.new(x, (topY + shaft.headroom + bottomY) / 2, z)
	Workspace.Terrain:FillBlock(boreAt, bore, Enum.Material.Air)
	Workspace.Terrain:FillBlock(boreAt * CFrame.Angles(0, math.rad(45), 0), bore, Enum.Material.Air)
	step()

	local shaftFolder = Instance.new("Folder")
	shaftFolder.Name = `Shaft_{math.floor(x)}_{math.floor(z)}`
	shaftFolder.Parent = parent

	--[[
		The core the ramp winds around.

		ROUND, and sized to meet the ramp's inner edge. A square pillar of the
		same half-width has corners a further 41% out, which would stand in the
		walkway at four points on every turn; and a core narrower than the ramp's
		inner edge leaves an open slot down the middle of the shaft for a player
		to walk off. Shape.Cylinder runs along the part's X, so it is turned
		upright and its length is the first component of Size.
	]]
	local core = rock(
		shaftFolder,
		"Core",
		Vector3.new(drop + shaft.headroom, shaft.pillarRadius * 2, shaft.pillarRadius * 2),
		CFrame.new(x, bottomY + (drop + shaft.headroom) / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		STONE_DARK
	)
	core.Shape = Enum.PartType.Cylinder

	--[[
		Segment count comes from the SLOPE, not the other way round: pick how
		steep it is allowed to be, then take as many turns as that needs. A ramp
		sized by turns instead would get steeper every time a level moved deeper.
	]]
	local arc = math.rad(shaft.stepAngle) * shaft.radius
	local rise = arc * math.tan(math.rad(shaft.slopeDegrees))
	local segments = math.max(1, math.ceil(drop / rise))

	local topAngle = 0
	local topPosition = Vector3.new(x + shaft.radius, topY, z)

	for index = 0, segments - 1 do
		local a0 = math.rad(index * shaft.stepAngle)
		local a1 = math.rad((index + 1) * shaft.stepAngle)
		local y0 = topY - (index / segments) * drop
		local y1 = topY - ((index + 1) / segments) * drop

		local p0 = Vector3.new(x + math.cos(a0) * shaft.radius, y0, z + math.sin(a0) * shaft.radius)
		local p1 = Vector3.new(x + math.cos(a1) * shaft.radius, y1, z + math.sin(a1) * shaft.radius)
		local mid = (p0 + p1) / 2
		local span = (p1 - p0).Magnitude

		if index == 0 then
			topPosition = p0
			topAngle = a0
		end

		--[[
			lookAt puts the part's -Z along the run, so the slab's LENGTH is its
			Z and the pitch of the slope comes free from the direction vector.
			Segments overlap by a stud so a seam can never become a lip a player
			catches their feet on.
		]]
		local slab = rock(
			shaftFolder,
			"Ramp",
			Vector3.new(shaft.width, shaft.thickness, span + 1),
			CFrame.lookAt(mid, mid + (p1 - p0)),
			STONE
		)
		slab.Material = Enum.Material.Rock

		if index % shaft.railEvery == 0 then
			local outward = Vector3.new(math.cos(a0), 0, math.sin(a0))
			rock(
				shaftFolder,
				"Rail",
				Vector3.new(1.1, shaft.railHeight, 1.1),
				CFrame.new(p0 + outward * (shaft.width / 2 - 0.8) + Vector3.new(0, shaft.railHeight / 2, 0)),
				STONE_DARK
			)
		end

		if index % shaft.lightEvery == 0 then
			local inward = Vector3.new(-math.cos(a0), 0, -math.sin(a0))
			sconce(shaftFolder, CFrame.new(p0 + inward * (shaft.width / 2 - 1)))
		end

		step()
	end

	-- A flat pad where the ramp meets the floor, so the last segment lands on
	-- something level instead of ending in mid air over the corridor mouth.
	rock(
		shaftFolder,
		"Landing",
		Vector3.new(shaft.radius * 2 + shaft.width, shaft.thickness, shaft.radius * 2 + shaft.width),
		CFrame.new(x, bottomY - shaft.thickness / 2, z),
		STONE
	)

	return topPosition, topAngle
end

local function carveLevel(level: Cave.LevelDefinition, step: Step)
	for row = 1, Cave.GRID do
		for col = 1, Cave.GRID do
			local char = Cave.charAt(level, row, col)
			if not Cave.OPEN[char] then
				continue
			end
			local at = Cave.cellPosition(level, row, col)
			if not at then
				continue
			end
			local ceiling = Cave.CEILING_FOR[char] or Cave.CEILING
			carveBox(
				Vector3.new(at.X, level.floorY + ceiling / 2, at.Z),
				Vector3.new(Cave.CELL + 1, ceiling, Cave.CELL + 1)
			)
			step()
		end
	end
end

--[[
	Takes the surface away from over a hole.

	The scenery pass seats every prop by raycast, and it runs long before this
	carves the ground out from under them -- so a mushroom that was standing on
	D2 an hour of server time ago is now hanging in the air over a shaft. The
	dressing has no idea the cave exists and should not have to.

	Only what is ABOVE the hole and near it goes. The radius is generous on
	purpose: a stone half over the rim reads worse than no stone at all, because
	it is the one the player walks into on their way in.
]]
local function clearSurface(centre: Vector3, radius: number)
	ForagingService.clearArea(centre, radius)

	local world = Workspace:FindFirstChild("World")
	if not world then
		return
	end

	local doomed: { Instance } = {}
	for _, descendant in world:GetDescendants() do
		if not descendant:IsA("Model") and not descendant:IsA("BasePart") then
			continue
		end
		-- Models are judged whole, so a prop is never half-deleted; skipping
		-- parts that have a Model ancestor is what keeps the two from fighting.
		if descendant:IsA("BasePart") and descendant:FindFirstAncestorOfClass("Model") then
			continue
		end

		local ok, pivot = pcall(function()
			return descendant:GetPivot().Position
		end)
		if not ok then
			continue
		end

		local planar = Vector3.new(pivot.X - centre.X, 0, pivot.Z - centre.Z).Magnitude
		if planar <= radius and pivot.Y > centre.Y - Cave.CELL then
			table.insert(doomed, descendant)
		end
	end

	for _, instance in doomed do
		instance:Destroy()
	end
end

--[[
	Makes the mouth findable.

	A hole in a field has no silhouette. From any distance at all it is just
	grass, so a player crosses the whole section without ever learning the cave
	is there -- which was the report, and it is a level-design bug rather than a
	rendering one.

	So the entrance is given a landmark: a broken ring of standing stone, two
	tall gate stones flanking the top of the ramp, lanterns, and glowing caps
	spilling out of the hole. The ring is BROKEN ON PURPOSE -- a closed one
	reads as a wall, a gap reads as a door, and the gap is aimed down the ramp.
]]
local function decorateMouth(parent: Instance, centre: Vector3, entryAngle: number)
	local dressing = Cave.MOUTH_DRESSING
	local rng = Random.new(4211)

	local mouthFolder = Instance.new("Folder")
	mouthFolder.Name = "Mouth"
	mouthFolder.Parent = parent

	for index = 0, dressing.stones - 1 do
		local angle = (index / dressing.stones) * math.pi * 2

		-- Nothing stands in the doorway. Compared on the shorter way round the
		-- circle, so the gap does not break when the entry bearing is near zero.
		local delta = math.abs((angle - entryAngle + math.pi) % (math.pi * 2) - math.pi)
		if math.deg(delta) < dressing.gapDegrees then
			continue
		end

		local height = rng:NextNumber(dressing.stoneHeight[1], dressing.stoneHeight[2])
		local width = rng:NextNumber(dressing.stoneWidth[1], dressing.stoneWidth[2])
		local reach = dressing.ringRadius * rng:NextNumber(0.9, 1.12)
		local at = centre + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)

		rock(
			mouthFolder,
			"Standing",
			Vector3.new(width, height, width * rng:NextNumber(0.6, 0.95)),
			CFrame.new(at + Vector3.new(0, height / 2 - 2, 0))
				* CFrame.Angles(
					math.rad(rng:NextNumber(-7, 7)),
					rng:NextNumber(0, math.pi * 2),
					math.rad(rng:NextNumber(-7, 7))
				),
			STONE
		)
	end

	-- The gateway. Two stones taller than everything around them, either side of
	-- the ramp head: the thing you actually see from across the section.
	for _, side in { -1, 1 } do
		local angle = entryAngle + side * math.rad(dressing.gapDegrees * 0.8)
		local at = centre + Vector3.new(math.cos(angle) * dressing.ringRadius, 0, math.sin(angle) * dressing.ringRadius)
		rock(
			mouthFolder,
			"Gate",
			Vector3.new(dressing.gateWidth, dressing.gateHeight, dressing.gateWidth),
			CFrame.new(at + Vector3.new(0, dressing.gateHeight / 2 - 3, 0))
				* CFrame.Angles(0, angle, math.rad(side * 4)),
			STONE_DARK
		)
	end

	--[[
		The lintel, across the top of the two gate stones. It is what turns two
		rocks into a doorway, and it is readable as a doorway from much further
		away than either stone is on its own.
	]]
	local lintelAt = centre
		+ Vector3.new(math.cos(entryAngle), 0, math.sin(entryAngle)) * dressing.ringRadius
		+ Vector3.new(0, dressing.gateHeight - 4, 0)
	rock(
		mouthFolder,
		"Lintel",
		Vector3.new(dressing.gateWidth * 1.2, 3.5, dressing.ringRadius * 1.15),
		CFrame.new(lintelAt) * CFrame.Angles(0, -entryAngle, 0),
		STONE_DARK
	)

	for index = 0, dressing.lanterns - 1 do
		local angle = entryAngle + (index - (dressing.lanterns - 1) / 2) * math.rad(26)
		local reach = dressing.ringRadius * 1.16
		sconce(
			mouthFolder,
			CFrame.new(centre + Vector3.new(math.cos(angle) * reach, -1, math.sin(angle) * reach))
		)
	end

	--[[
		Caps spilling out of the hole, thinning with distance. They are the clue
		that reads at ground level once the stones have got the player's
		attention: whatever grows down there is growing up here too.
	]]
	for _ = 1, dressing.caps do
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = rng:NextNumber(dressing.capRadius[1], dressing.capRadius[2])
		local at = centre + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
		local size = rng:NextNumber(1.6, 3.4)

		local stalk = Instance.new("Part")
		stalk.Name = "CapStalk"
		stalk.Size = Vector3.new(size * 0.32, size, size * 0.32)
		stalk.CFrame = CFrame.new(at + Vector3.new(0, size / 2 - 0.4, 0))
		stalk.Color = Color3.fromRGB(232, 224, 208)
		stalk.Material = Enum.Material.SmoothPlastic
		stalk.Anchored = true
		stalk.CanCollide = false
		stalk.CanQuery = false
		stalk.Parent = mouthFolder

		local cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Shape = Enum.PartType.Ball
		cap.Size = Vector3.new(size * 0.9, size * 0.9, size * 0.9)
		cap.CFrame = CFrame.new(at + Vector3.new(0, size - 0.2, 0))
		cap.Color = GLOW_COLOR
		cap.Material = Enum.Material.Neon
		cap.Anchored = true
		cap.CanCollide = false
		cap.CanQuery = false
		cap.Parent = mouthFolder
	end

	UI.sign(mouthFolder:FindFirstChild("Lintel") :: BasePart, {
		name = "CaveSign",
		title = "Mushroom Cave",
		subtitle = "mind the caps",
		offset = Vector3.new(0, 7, 0),
		extent = UDim2.fromScale(22, 6),
		maxDistance = 400,
	})
end

--[[
	Where the sinkhole opens.

	The skill districts radiate from the plaza and cross the section grid, so
	the spot written in config is a PREFERENCE: a mouth inside a reserved zone
	would sit in a worksite pad or on the road. Walk outward until it clears
	one, and say so if it never does.
]]
local function findMouth(area: Areas.AreaDefinition, level: Cave.LevelDefinition): Vector3
	local entrance = Cave.first(level, Cave.ENTRANCE)
	local landing = if entrance then Cave.cellPosition(level, entrance.row, entrance.col) else nil
	-- The mouth belongs to whichever section the first level is in, so moving
	-- the cave moves its entrance and the two cannot drift apart.
	local cell = Cave.mouthCell()
	local fallback = Vector3.new(
		if cell then cell.cx else 0,
		WORLD.TERRAIN_TOP,
		if cell then cell.cz else 0
	)
	if not cell then
		return fallback
	end

	local zones = Layout.reservedZones(area)
	local origin = Vector2.new(cell.cx + Cave.MOUTH.offset.X, cell.cz + Cave.MOUTH.offset.Y)

	for ring = 0, Cave.MOUTH.searchLimit do
		local steps = if ring == 0 then 1 else ring * 6
		for index = 0, steps - 1 do
			local angle = (index / steps) * math.pi * 2
			local x = origin.X + math.cos(angle) * ring * Cave.MOUTH.search
			local z = origin.Y + math.sin(angle) * ring * Cave.MOUTH.search
			local margin = Cave.SHAFT.radius + Cave.SHAFT.width
			local inside = x >= cell.minX + margin
				and x <= cell.maxX - margin
				and z >= cell.minZ + margin
				and z <= cell.maxZ - margin
			if inside and not Layout.isReserved(zones, x, z) then
				return Vector3.new(x, WORLD.TERRAIN_TOP, z)
			end
		end
	end

	warn(
		`[CaveService] every candidate sinkhole in "{level.coord}" is inside a reserved zone; `
			.. "opening it over the entrance cell anyway -- expect it to land on a pad or a road"
	)
	return if landing then Vector3.new(landing.X, WORLD.TERRAIN_TOP, landing.Z) else fallback
end

local function carve(area: Areas.AreaDefinition, step: Step)
	for _, level in Cave.LEVELS do
		local cell = Sections.byCoord(level.coord)
		if not cell then
			continue
		end
		local top = Cave.PLINTH_TOP
		local bottom = Cave.PLINTH_BOTTOM
		TerrainBuilder.fill(
			Vector3.new(cell.cx, (top + bottom) / 2, cell.cz),
			Vector3.new(Sections.SIZE, top - bottom, Sections.SIZE),
			Enum.Material.Rock,
			step
		)
	end

	for _, level in Cave.LEVELS do
		carveLevel(level, step)
	end

	local first = Cave.LEVELS[1]
	local mouth = findMouth(area, first)

	--[[
		Started from the MEASURED ground, not from TERRAIN_TOP.

		TERRAIN_TOP is where the flat crust is filled to; the relief pass then
		raises hills on top of it, so a shaft begun at TERRAIN_TOP starts life
		buried under however much hill happens to be standing there. The ramp's
		top step is then carved a `lip` above the real surface, which leaves an
		open notch in the ground rather than a seam flush with it: that notch is
		the way in, and it is the only way in, so it has to be visible.
	]]
	local groundY = ForagingService.groundAt(mouth.X, mouth.Z)
	mouth = Vector3.new(mouth.X, groundY, mouth.Z)
	mouthPosition = mouth

	--[[
		Cleared BEFORE the stones go up, not after: the sweep deletes anything
		standing in the disc, and the gateway is the first thing standing in it.
	]]
	clearSurface(mouth, Cave.MOUTH.clearRadius)

	local rampTop, entryAngle = buildShaft(folder, mouth.X, mouth.Z, groundY, first.floorY, step)
	decorateMouth(folder, Vector3.new(mouth.X, rampTop.Y, mouth.Z), entryAngle)

	local entrance = Cave.first(first, Cave.ENTRANCE)
	local entranceAt = if entrance then Cave.cellPosition(first, entrance.row, entrance.col) else nil
	if entranceAt then
		carveTunnel(
			Vector3.new(mouth.X, first.floorY, mouth.Z),
			entranceAt,
			Cave.CELL,
			Cave.CEILING,
			step
		)
	end

	for index = 1, #Cave.LEVELS - 1 do
		local upper = Cave.LEVELS[index]
		local lower = Cave.LEVELS[index + 1]
		local down = Cave.first(upper, Cave.DOWN)
		local land = Cave.first(lower, Cave.LANDING)
		if not down or not land then
			continue
		end
		local head = Cave.cellPosition(upper, down.row, down.col)
		local foot = Cave.cellPosition(lower, land.row, land.col)
		if not head or not foot then
			continue
		end

		--[[
			The descent is a tunnel at the UPPER level's depth running to a shaft
			sunk over the LOWER level's landing. Levels never share XZ, so a ramp
			between them cannot be a hole in a floor -- and running the tunnel
			high keeps it clear of the lower level's ceiling by twenty-odd studs.
		]]
		carveTunnel(
			head,
			Vector3.new(foot.X, upper.floorY, foot.Z),
			Cave.CELL,
			Cave.CEILING,
			step
		)
		buildShaft(folder, foot.X, foot.Z, upper.floorY, lower.floorY, step)
	end

	local deepest = Cave.LEVELS[#Cave.LEVELS]
	local surface = Cave.first(deepest, Cave.SURFACE)
	local surfaceAt = if surface then Cave.cellPosition(deepest, surface.row, surface.col) else nil
	if surfaceAt then
		-- The way out of the knoll. Found, not given: nothing signposts it. Same
		-- rules as the mouth -- measured ground, open notch, no ball.
		local exitGround = ForagingService.groundAt(surfaceAt.X, surfaceAt.Z)
		clearSurface(Vector3.new(surfaceAt.X, exitGround, surfaceAt.Z), Cave.MOUTH.clearRadius)
		local exitTop, exitAngle = buildShaft(folder, surfaceAt.X, surfaceAt.Z, exitGround, deepest.floorY, step)
		decorateMouth(folder, Vector3.new(surfaceAt.X, exitTop.Y, surfaceAt.Z), exitAngle)
	end
end

--------------------------------------------------------------------------------
-- Contents
--------------------------------------------------------------------------------

local function plantClumps(level: Cave.LevelDefinition, step: Step)
	local rng = Random.new(level.index * 7717)

	for char, clumpId in Cave.CLUMP_CHARS do
		local clump = Ingredients.CLUMPS[clumpId]
		if not clump then
			continue
		end

		for _, at in Cave.find(level, char) do
			local centre = Cave.cellPosition(level, at.row, at.col)
			if not centre then
				continue
			end
			local plan = Ingredients.clumpPlan({
				clumps = clump.perClump,
				ingredients = clump.ingredients,
			} :: any)

			for index, ingredientId in plan do
				local def = Ingredients.get(ingredientId)
				if not def then
					continue
				end
				local angle = (index / #plan) * math.pi * 2 + rng:NextNumber(0, 0.6)
				local radius = rng:NextNumber(1.5, Cave.CELL * 0.36)
				ForagingService.plant(def, Vector3.new(
					centre.X + math.cos(angle) * radius,
					level.floorY,
					centre.Z + math.sin(angle) * radius
				), {
					parent = folder,
					yaw = rng:NextNumber(0, 360),
					yield = clump.yieldScale,
					glow = clump.glow,
					upright = true,
					sink = 0.08,
				} :: any)
				step()
			end
		end
	end
end

local function deployMobs()
	local cframes: { [string]: { CFrame } } = {}

	for _, level in Cave.LEVELS do
		for char, mobId in Cave.SPAWN_CHARS do
			local perSpawn = Cave.SPAWN_COUNT[char] or 1
			for _, at in Cave.find(level, char) do
				local centre = Cave.cellPosition(level, at.row, at.col)
				if not centre then
					continue
				end
				cframes[mobId] = cframes[mobId] or {}
				for index = 1, perSpawn do
					local angle = (index / perSpawn) * math.pi * 2
					local spread = if perSpawn > 1 then Cave.CELL * 0.3 else 0
					table.insert(
						cframes[mobId],
						CFrame.new(
							centre.X + math.cos(angle) * spread,
							level.floorY,
							centre.Z + math.sin(angle) * spread
						)
					)
				end
			end
		end
	end

	for mobId, list in cframes do
		MobService.deploy(mobId, list)
	end

	local deepest = Cave.LEVELS[#Cave.LEVELS]
	local boss = Cave.bossCentre(deepest)
	if boss then
		MobService.deploy(Cave.BOSS_MOB, { CFrame.new(boss.X, deepest.floorY, boss.Z) })
	end
end

--------------------------------------------------------------------------------
-- Where a player is
--------------------------------------------------------------------------------

function CaveService.levelAt(position: Vector3): Cave.LevelDefinition?
	return Cave.levelAt(position)
end

function CaveService.levelOf(player: Player): number
	local character = player.Character
	if not character then
		return 0
	end
	local value = character:GetAttribute(LEVEL_ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

function CaveService.mouth(): Vector3?
	return mouthPosition
end

--[[
	Published as a character attribute rather than a remote.

	Attributes replicate on change, and this one changes when somebody crosses
	a floor -- perhaps twice a minute. A remote per check would be a broadcast
	every two seconds per player to say nothing has happened. The client's
	lighting swap and the work-order tracker both read it.
]]
--[[
	The lantern is a real light on a real part, not a client-side glow.

	A light only its owner can see would make a party of four walk in four
	separate darknesses, and the first thing anybody does with a lantern is
	hold it up for somebody else. It is lit only underground: carried through
	town in daylight it is a hotspot on the grass and a lighting cost for
	nothing.
]]
local function setLantern(character: Model, on: boolean)
	local existing = character:FindFirstChild("Lantern")
	if not on then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	local lantern = Instance.new("Part")
	lantern.Name = "Lantern"
	lantern.Size = Vector3.new(0.9, 1.3, 0.9)
	lantern.Color = Color3.fromRGB(248, 224, 158)
	lantern.Material = Enum.Material.Neon
	lantern.CanCollide = false
	lantern.CanQuery = false
	lantern.CanTouch = false
	lantern.Massless = true
	lantern.CFrame = root.CFrame * CFrame.new(1.6, 0.4, 0)
	lantern.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = lantern
	weld.Parent = lantern

	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 46
	light.Color = Color3.fromRGB(255, 236, 194)
	light.Shadows = false
	light.Parent = lantern
end

local function watchPlayers()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (character and root and root:IsA("BasePart")) then
				continue
			end
			local level = Cave.levelAt(root.Position)
			local index = if level then level.index else 0
			if character:GetAttribute(LEVEL_ATTRIBUTE) ~= index then
				character:SetAttribute(LEVEL_ATTRIBUTE, index)
			end
			setLantern(character, index > 0 and character:GetAttribute("HasLantern") == true)
		end
	end
end

--------------------------------------------------------------------------------

function CaveService.init()
	local existing = Workspace:FindFirstChild("Cave")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Cave"
	folder.Parent = Workspace

	if not validate() then
		warn("[CaveService] the maze failed validation; not carving it")
		CaveService.ready = true
		readySignal:Fire()
		return
	end

	task.spawn(function()
		WorldService.awaitDressed()
		ForagingService.awaitReady()

		local step = Budget.stepper()
		local area = Areas.get(Areas.STARTING_AREA)
		if area then
			carve(area, step)
		end

		for _, level in Cave.LEVELS do
			plantClumps(level, step)
		end
		deployMobs()

		CaveService.ready = true
		readySignal:Fire()
	end)

	task.spawn(watchPlayers)
end

return CaveService

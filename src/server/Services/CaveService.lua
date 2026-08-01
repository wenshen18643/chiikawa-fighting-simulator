--!strict

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
local Quarry = require(Shared.Modules.Config.Quarry)
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

local function validate(): boolean
	local ok = true

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

type Step = () -> ()

local function carveBox(centre: Vector3, size: Vector3)
	Workspace.Terrain:FillBlock(CFrame.new(centre), size, Enum.Material.Air)
end

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

	local bore = Vector3.new(shaft.bore * 2, (topY + shaft.headroom) - bottomY, shaft.bore * 2)
	local boreAt = CFrame.new(x, (topY + shaft.headroom + bottomY) / 2, z)
	Workspace.Terrain:FillBlock(boreAt, bore, Enum.Material.Air)
	Workspace.Terrain:FillBlock(boreAt * CFrame.Angles(0, math.rad(45), 0), bore, Enum.Material.Air)
	step()

	local shaftFolder = Instance.new("Folder")
	shaftFolder.Name = `Shaft_{math.floor(x)}_{math.floor(z)}`
	shaftFolder.Parent = parent

	local core = rock(
		shaftFolder,
		"Core",
		Vector3.new(drop + shaft.headroom, shaft.pillarRadius * 2, shaft.pillarRadius * 2),
		CFrame.new(x, bottomY + (drop + shaft.headroom) / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		STONE_DARK
	)
	core.Shape = Enum.PartType.Cylinder

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

local function decorateMouth(parent: Instance, centre: Vector3, entryAngle: number)
	local dressing = Cave.MOUTH_DRESSING
	local rng = Random.new(4211)

	local mouthFolder = Instance.new("Folder")
	mouthFolder.Name = "Mouth"
	mouthFolder.Parent = parent

	for index = 0, dressing.stones - 1 do
		local angle = (index / dressing.stones) * math.pi * 2

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
		sconce(mouthFolder, CFrame.new(centre + Vector3.new(math.cos(angle) * reach, -1, math.sin(angle) * reach)))
	end

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

local function findMouth(area: Areas.AreaDefinition, level: Cave.LevelDefinition): Vector3
	local entrance = Cave.first(level, Cave.ENTRANCE)
	local landing = if entrance then Cave.cellPosition(level, entrance.row, entrance.col) else nil

	local cell = Cave.mouthCell()
	local fallback = Vector3.new(if cell then cell.cx else 0, WORLD.TERRAIN_TOP, if cell then cell.cz else 0)
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

	local groundY = ForagingService.groundAt(mouth.X, mouth.Z)
	mouth = Vector3.new(mouth.X, groundY, mouth.Z)
	mouthPosition = mouth

	clearSurface(mouth, Cave.MOUTH.clearRadius)

	local rampTop, entryAngle = buildShaft(folder, mouth.X, mouth.Z, groundY, first.floorY, step)
	decorateMouth(folder, Vector3.new(mouth.X, rampTop.Y, mouth.Z), entryAngle)

	local entrance = Cave.first(first, Cave.ENTRANCE)
	local entranceAt = if entrance then Cave.cellPosition(first, entrance.row, entrance.col) else nil
	if entranceAt then
		carveTunnel(Vector3.new(mouth.X, first.floorY, mouth.Z), entranceAt, Cave.CELL, Cave.CEILING, step)
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

		carveTunnel(head, Vector3.new(foot.X, upper.floorY, foot.Z), Cave.CELL, Cave.CEILING, step)
		buildShaft(folder, foot.X, foot.Z, upper.floorY, lower.floorY, step)
	end

	local deepest = Cave.LEVELS[#Cave.LEVELS]
	local surface = Cave.first(deepest, Cave.SURFACE)
	local surfaceAt = if surface then Cave.cellPosition(deepest, surface.row, surface.col) else nil
	if surfaceAt then
		local inPit = Quarry.contains(surfaceAt.X - area.origin.X, surfaceAt.Z - area.origin.Z)
		local exitGround = if inPit
			then area.origin.Y + WORLD.TERRAIN_TOP + Quarry.floorDepth()
			else ForagingService.groundAt(surfaceAt.X, surfaceAt.Z)
		local sweep = if inPit then Quarry.PIT.clearRadius else Cave.MOUTH.clearRadius

		clearSurface(Vector3.new(surfaceAt.X, exitGround, surfaceAt.Z), sweep)
		local exitTop, exitAngle = buildShaft(folder, surfaceAt.X, surfaceAt.Z, exitGround, deepest.floorY, step)
		if not inPit then
			decorateMouth(folder, Vector3.new(surfaceAt.X, exitTop.Y, surfaceAt.Z), exitAngle)
		end
	end
end

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
				ForagingService.plant(
					def,
					Vector3.new(centre.X + math.cos(angle) * radius, level.floorY, centre.Z + math.sin(angle) * radius),
					{
						parent = folder,
						yaw = rng:NextNumber(0, 360),
						yield = clump.yieldScale,
						glow = clump.glow,
						upright = true,
						sink = 0.08,
					} :: any
				)
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

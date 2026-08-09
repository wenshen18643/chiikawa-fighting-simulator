local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Budget = require(Shared.Modules.Budget)
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Perimeter = require(Shared.Modules.Config.Perimeter)
local Streets = require(Shared.Modules.Config.Streets)
local UI = require(Shared.UI)
local WorldService = require(script.Parent.WorldService)
local PerimeterService = {}
local WORLD = Constants.WORLD
local BASE_Y = WORLD.TERRAIN_TOP

local PALETTE = {
	stone = Color3.fromRGB(178, 173, 163),
	stoneDeep = Color3.fromRGB(142, 138, 129),
	plaster = Color3.fromRGB(248, 243, 234),
	tile = Color3.fromRGB(96, 108, 130),
	tileDeep = Color3.fromRGB(72, 82, 102),
	timber = Color3.fromRGB(152, 108, 80),
	blossom = Color3.fromRGB(244, 186, 190),
	lantern = Color3.fromRGB(252, 226, 166),
	banner = Color3.fromRGB(226, 128, 146),
	cobble = Color3.fromRGB(224, 216, 203),
}

local COURSES = {
	{ name = "Footing", height = 18, thickness = 26, color = PALETTE.stoneDeep, material = Enum.Material.Slate },
	{ name = "Batter", height = 16, thickness = 21, color = PALETTE.stone, material = Enum.Material.Slate },
	{ name = "Plaster", height = 20, thickness = 16, color = PALETTE.plaster, material = Enum.Material.Concrete },
}

local COPING = { height = 4, thickness = 25, color = PALETTE.tile, material = Enum.Material.Slate }
local WALL_TOP = 58
local PILASTER_SPACING = 62
local GATE_HALF = Perimeter.GATE.halfWidth

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function slab(parent: Instance, name: string, x: number, y: number, z: number, size: Vector3, config: { [string]: any })
	return part({
		Name = name,
		Size = size,
		Position = Vector3.new(x, y + size.Y / 2, z),
		Color = config.color,
		Material = config.material or Enum.Material.SmoothPlastic,
		CanCollide = config.collide ~= false,
		CanQuery = config.collide ~= false,
		CastShadow = config.shadow ~= false,
		Transparency = config.transparency or 0,
		Parent = parent,
	})
end

local function spanSize(run: Perimeter.Run, length: number, height: number, thickness: number): Vector3
	if run.axis == "x" then
		return Vector3.new(length, height, thickness)
	end
	return Vector3.new(thickness, height, length)
end

local function buildCourses(run: Perimeter.Run, parent: Folder, step: () -> ())
	local y = BASE_Y

	for _, course in COURSES do
		slab(parent, `{run.side}_{course.name}`, run.cx, y, run.cz, spanSize(run, run.length, course.height, course.thickness), course)
		y += course.height
		step()
	end

	slab(parent, `{run.side}_Coping`, run.cx, y, run.cz, spanSize(run, run.length, COPING.height, COPING.thickness), COPING)
	step()
end

local function buildDetail(run: Perimeter.Run, parent: Folder, step: () -> ())
	local count = math.max(2, math.round(run.length / PILASTER_SPACING))
	local inX, inZ = -run.outX, -run.outZ

	for index = 1, count do
		local x, z = Perimeter.pointOn(run, (index - 0.5) / count)

		slab(parent, "Pilaster", x, BASE_Y, z, spanSize(run, 10, WALL_TOP - 6, 28), {
			color = PALETTE.stone,
			material = Enum.Material.Slate,
		})
		slab(parent, "PilasterCap", x, BASE_Y + WALL_TOP - 6, z, spanSize(run, 13, 3, 32), {
			color = PALETTE.tileDeep,
			material = Enum.Material.Slate,
		})

		slab(parent, "WallLantern", x + inX * 9.5, BASE_Y + 40, z + inZ * 9.5, Vector3.new(4, 6, 4), {
			color = PALETTE.lantern,
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})

		if index < count then
			local bx, bz = Perimeter.pointOn(run, index / count)
			slab(parent, "Banner", bx + inX * 8.6, BASE_Y + 22, bz + inZ * 8.6, spanSize(run, 15, 22, 0.6), {
				color = PALETTE.banner,
				collide = false,
				shadow = false,
			})
		end

		step()
	end
end

local TOWER = {
	{ height = 6, width = 36, color = PALETTE.stoneDeep, material = Enum.Material.Slate },
	{ height = 34, width = 31, color = PALETTE.stone, material = Enum.Material.Slate },
	{ height = 18, width = 26, color = PALETTE.plaster, material = Enum.Material.Concrete },
	{ height = 3, width = 42, color = PALETTE.tile, material = Enum.Material.Slate },
	{ height = 4, width = 34, color = PALETTE.tile, material = Enum.Material.Slate },
	{ height = 4, width = 24, color = PALETTE.tileDeep, material = Enum.Material.Slate },
	{ height = 4, width = 14, color = PALETTE.tileDeep, material = Enum.Material.Slate },
}

local function buildTower(at: Vector2, parent: Folder, step: () -> ())
	local y = BASE_Y

	for index, tier in TOWER do
		slab(parent, `Tower{index}`, at.X, y, at.Y, Vector3.new(tier.width, tier.height, tier.width), tier)
		y += tier.height
	end

	part({
		Name = "TowerFinial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = Vector3.new(at.X, y + 2, at.Y),
		Color = PALETTE.blossom,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
	})

	step()
end

local function buildGatehouse(parent: Folder)
	local gate = Perimeter.GATE
	local z = gate.z
	local pillarOffset = GATE_HALF + 8

	for _, side in { -1, 1 } do
		local x = gate.x + side * pillarOffset

		slab(parent, "GatePillar", x, BASE_Y, z, Vector3.new(16, 54, Streets.GATEHOUSE_DEPTH), {
			color = PALETTE.stone,
			material = Enum.Material.Slate,
		})
		slab(parent, "GatePillarCap", x, BASE_Y + 54, z, Vector3.new(20, 4, 34), {
			color = PALETTE.tileDeep,
			material = Enum.Material.Slate,
		})
		slab(parent, "GateLantern", gate.x + side * (GATE_HALF - 4), BASE_Y + 44, z - 6, Vector3.new(5, 8, 5), {
			color = PALETTE.lantern,
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	end

	local lintel = slab(parent, "GateLintel", gate.x, BASE_Y + 56, z, Vector3.new(70, 7, 11), {
		color = PALETTE.timber,
		material = Enum.Material.Wood,
	})

	slab(parent, "GateEave", gate.x, BASE_Y + 63, z, Vector3.new(82, 3, 38), {
		color = PALETTE.tile,
		material = Enum.Material.Slate,
	})
	slab(parent, "GateRoof", gate.x, BASE_Y + 66, z, Vector3.new(70, 4, 30), {
		color = PALETTE.tile,
		material = Enum.Material.Slate,
	})
	slab(parent, "GateRidge", gate.x, BASE_Y + 70, z, Vector3.new(54, 4, 20), {
		color = PALETTE.tileDeep,
		material = Enum.Material.Slate,
	})

	slab(parent, "GateApron", gate.x, WORLD.PLATFORM_TOP - 1, z + 12, Vector3.new(GATE_HALF * 2 + 6, 1, 58), {
		color = PALETTE.cobble,
		material = Enum.Material.Cobblestone,
		shadow = false,
	})

	UI.sign(lintel, {
		name = "TownBanner",
		title = "Town",
		subtitle = "market · kitchen · library",
		offset = Vector3.new(0, 14, 0),
		extent = UDim2.fromScale(34, 10),
		maxDistance = 700,
	})
end

local function buildBlockers(parent: Folder)
	for _, run in Perimeter.runs() do
		part({
			Name = `{run.side}_Blocker`,
			Size = spanSize(run, run.length, Perimeter.BLOCK_HEIGHT, 8),
			Position = Vector3.new(run.cx, BASE_Y + Perimeter.BLOCK_HEIGHT / 2, run.cz),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

function PerimeterService.build(): Folder?
	local region = WorldService.getRegionFolder(Areas.STARTING_AREA)
	if not region then
		warn("[PerimeterService] no region folder for the town; the rampart was not built")
		return nil
	end

	local existing = region:FindFirstChild("Perimeter")
	if existing then
		existing:Destroy()
	end

	local parent = Instance.new("Folder")
	parent.Name = "Perimeter"
	parent.Parent = region

	local step = Budget.stepper()

	for _, run in Perimeter.runs() do
		buildCourses(run, parent, step)
		buildDetail(run, parent, step)
	end

	for _, corner in Perimeter.corners() do
		buildTower(corner, parent, step)
	end

	buildGatehouse(parent)
	buildBlockers(parent)

	return parent
end

function PerimeterService.init()
	task.spawn(function()
		local start = os.clock()
		local ok, err = pcall(PerimeterService.build)
		if not ok then
			warn(`[PerimeterService] rampart failed: {err}`)
			return
		end
		print(`[PerimeterService] town rampart in {string.format("%.2f", os.clock() - start)}s`)
	end)
end

return PerimeterService

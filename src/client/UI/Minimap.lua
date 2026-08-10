local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Cave = require(Shared.Modules.Config.Cave)
local Layout = require(Shared.Modules.Config.Layout)
local Market = require(Shared.Modules.Config.Market)
local Perimeter = require(Shared.Modules.Config.Perimeter)
local Quarry = require(Shared.Modules.Config.Quarry)
local Remotes = require(Shared.Modules.Remotes)
local SausageForest = require(Shared.Modules.Config.SausageForest)
local Sections = require(Shared.Modules.Config.Sections)
local Streets = require(Shared.Modules.Config.Streets)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local Minimap = {}
local LOCAL_SIZE = 186
local STRIP_HEIGHT = 34
local REFRESH_INTERVAL = 0.25
local DISCOVER_REACH = 48
local FOG_FADE = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local root: Frame
local localView: Frame
local localTitle: TextLabel
local playerMarker: Frame
local strip: Frame
local areaLayers: { [number]: Frame } = {}
local stripCells: { [number]: Frame } = {}
local stripMarker: Frame
local builtArea: number? = nil
local accumulator = 0
local rootScale: UIScale
local changedListeners: { (boolean) -> () } = {}
local fogCells: { [string]: Frame } = {}
local discovered: { [string]: boolean } = {}
local pending: { string } = {}
local reportRemote: RemoteEvent?

local THEME_TINT: { [string]: Color3 } = {
	meadow = UI.color.leaf,
	meadowQuiet = UI.color.leaf,
	grove = UI.color.leafDeep,
	bramble = UI.color.leafDeep,
	sausage = UI.color.blush,
	sakura = UI.color.blush,
	flower = UI.color.lavender,
	berry = UI.color.lavender,
	mushroom = UI.color.sand,
	ramen = UI.color.rest,
	kitchen = UI.color.warning,
	library = UI.color.sky,
	market = UI.color.gold,
	teaCorner = UI.color.mint,
	snow = UI.color.white,
	lake = UI.color.info,
	quarry = UI.color.inkFaint,
	farm = UI.color.sand,
}

local function spanOf(area: Areas.AreaDefinition): number
	return area.terrain.islandSize
end

local function toFraction(area: Areas.AreaDefinition, x: number, z: number): Vector2
	local span = spanOf(area)
	return Vector2.new(0.5 + x / span, 0.5 + z / span)
end

local function pixels(area: Areas.AreaDefinition, studs: number): number
	return studs / spanOf(area) * LOCAL_SIZE
end

local function patch(parent: Instance, config: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.Name = config.name or "Patch"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(config.at.X, config.at.Y)
	frame.Size = UDim2.fromOffset(math.max(config.width, 1), math.max(config.height, 1))
	frame.BackgroundColor3 = config.color
	frame.BackgroundTransparency = config.transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = config.zIndex or 4
	frame.Parent = parent
	if config.radius then
		UI.corner(frame, config.radius)
	end
	return frame
end

local function rect(parent: Instance, area: Areas.AreaDefinition, config: { [string]: any }): Frame
	local minX, maxX = config.minX, config.maxX
	local minZ, maxZ = config.minZ, config.maxZ
	return patch(parent, {
		name = config.name,
		at = toFraction(area, (minX + maxX) / 2, (minZ + maxZ) / 2),
		width = pixels(area, maxX - minX),
		height = pixels(area, maxZ - minZ),
		color = config.color,
		transparency = config.transparency,
		zIndex = config.zIndex,
		radius = config.radius,
	})
end

local function marker(parent: Instance, area: Areas.AreaDefinition, config: { [string]: any })
	local disc = patch(parent, {
		name = config.name,
		at = toFraction(area, config.x, config.z),
		width = 13,
		height = 13,
		color = config.color,
		zIndex = 6,
		radius = 999,
	})
	UI.stroke(disc, UI.color.paper, 1.5)

	UI.glyph(disc, config.glyph, {
		color = UI.legible(config.color),
		extent = UDim2.fromOffset(9, 9),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		zIndex = 7,
	})
end

local function landmarksOf(area: Areas.AreaDefinition): { { [string]: any } }
	local points = {
		{ name = "Home", glyph = "home", x = 0, z = 0, color = UI.color.leafDeep },
		{
			name = "Kitchen",
			glyph = "pot",
			x = Layout.KITCHEN_OFFSET.X,
			z = Layout.KITCHEN_OFFSET.Z,
			color = UI.color.warning,
		},
		{
			name = "Library",
			glyph = "book",
			x = Layout.LIBRARY_OFFSET.X,
			z = Layout.LIBRARY_OFFSET.Z,
			color = UI.color.sky,
		},
		{ name = "Market", glyph = "coin", x = Market.CENTRE.X, z = Market.CENTRE.Y, color = UI.color.gold },
		{ name = "Gate", glyph = "pin", x = Perimeter.GATE.x, z = Perimeter.GATE.z, color = UI.color.blush },
	}

	local farm = Layout.farmAnchor(area) - area.origin
	table.insert(points, { name = "Farm", glyph = "carrot", x = farm.X, z = farm.Z, color = UI.color.rest })

	local pit = Quarry.centre()
	if pit then
		table.insert(points, { name = "Quarry", glyph = "ore", x = pit.X, z = pit.Y, color = UI.color.inkFaint })
	end

	local forest = Sections.byCoord(SausageForest.CELLS[1].coord)
	if forest then
		local arena = SausageForest.arena(forest)
		table.insert(
			points,
			{ name = "SausageForest", glyph = "sausage", x = arena.X, z = arena.Y, color = UI.color.blush }
		)
	end

	local level = Cave.LEVELS[1]
	local mouth = if level then Cave.first(level, Cave.ENTRANCE) else nil
	if level and mouth then
		local at = Cave.cellPosition(level, mouth.row, mouth.col)
		if at then
			table.insert(points, { name = "Cave", glyph = "mushroom", x = at.X, z = at.Z, color = UI.color.lavender })
		end
	end

	return points
end

local function buildTownDetail(layer: Frame, area: Areas.AreaDefinition)
	local paved = { Streets.SQUARE }
	for _, road in Streets.PAVING do
		table.insert(paved, road)
	end

	for _, road in paved do
		rect(layer, area, {
			name = road.name,
			minX = road.minX,
			maxX = road.maxX,
			minZ = road.minZ,
			maxZ = road.maxZ,
			color = UI.color.paperDeep,
			zIndex = 5,
		})
	end

	local wall = rect(layer, area, {
		name = "TownWall",
		minX = Perimeter.MIN.X,
		maxX = Perimeter.MAX.X,
		minZ = Perimeter.MIN.Y,
		maxZ = Perimeter.MAX.Y,
		color = UI.color.paper,
		transparency = 1,
		zIndex = 5,
		radius = 4,
	})
	UI.stroke(wall, UI.color.lineCard, 1.5)

	local dome = math.max(pixels(area, SafeZone.DOME.radius * 2), 8)
	patch(layer, {
		name = "SafeHouse",
		at = toFraction(area, 0, 0),
		width = dome,
		height = dome,
		color = UI.color.paperRaised,
		zIndex = 5,
		radius = 999,
	})

	for _, point in landmarksOf(area) do
		marker(layer, area, point)
	end
end

local function buildFog(layer: Frame, area: Areas.AreaDefinition)
	local side = pixels(area, Sections.SIZE)

	for _, cell in Sections.cells() do
		local key = `{area.key}:{cell.coord}`
		local tile = patch(layer, {
			name = key,
			at = toFraction(area, cell.cx, cell.cz),
			width = side + 1,
			height = side + 1,
			color = UI.color.paperSunken,
			zIndex = 8,
		})
		local edge = UI.stroke(tile, UI.color.lineSoft, 1)
		edge.Transparency = 0.55
		tile.BackgroundTransparency = if discovered[key] then 1 else 0
		fogCells[key] = tile
	end
end

local function buildLocalView(area: Areas.AreaDefinition)
	if builtArea == area.id then
		return
	end
	builtArea = area.id

	for _, layer in areaLayers do
		layer:Destroy()
	end
	table.clear(areaLayers)
	table.clear(fogCells)

	local layer = Instance.new("Frame")
	layer.Name = `Area_{area.id}`
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = area.palette.ground:Lerp(UI.color.paper, 0.55)
	layer.BorderSizePixel = 0
	layer.ClipsDescendants = true
	layer.ZIndex = 3
	layer.Parent = localView
	UI.corner(layer, UI.radius.chip)
	areaLayers[area.id] = layer

	local side = pixels(area, Sections.SIZE)
	for _, cell in Sections.cells() do
		local accent = THEME_TINT[cell.theme]
		patch(layer, {
			name = cell.coord,
			at = toFraction(area, cell.cx, cell.cz),
			width = side + 1,
			height = side + 1,
			color = if accent then area.palette.ground:Lerp(accent, 0.55) else area.palette.ground,
			zIndex = 4,
		})
	end

	if area.id == Areas.STARTING_AREA then
		buildTownDetail(layer, area)
	end

	buildFog(layer, area)
	localTitle.Text = string.upper(area.name)
end

local function reveal(key: string)
	if discovered[key] then
		return
	end
	discovered[key] = true
	table.insert(pending, key)

	local tile = fogCells[key]
	if tile then
		TweenService:Create(tile, FOG_FADE, { BackgroundTransparency = 1 }):Play()
	end
end

local function discoverAround(area: Areas.AreaDefinition, x: number, z: number)
	local here = Sections.cellAt(x, z)
	if not here then
		return
	end

	for i = here.i - 1, here.i + 1 do
		for j = here.j - 1, here.j + 1 do
			local cell = Sections.cell(i, j)
			if not cell then
				continue
			end
			local gapX = math.max(cell.minX - x, x - cell.maxX, 0)
			local gapZ = math.max(cell.minZ - z, z - cell.maxZ, 0)
			if gapX <= DISCOVER_REACH and gapZ <= DISCOVER_REACH then
				reveal(`{area.key}:{cell.coord}`)
			end
		end
	end

	if #pending > 0 and reportRemote then
		reportRemote:FireServer(pending)
		table.clear(pending)
	end
end

local REVEAL_RADIUS = 34
local caveLayers: { [number]: Frame } = {}
local caveCells: { [number]: { [number]: Frame } } = {}
local revealed: { [number]: { [number]: boolean } } = {}

local function cellKey(row: number, col: number): number
	return row * 100 + col
end

local function buildCaveLayer(level: Cave.LevelDefinition): Frame
	local existing = caveLayers[level.index]
	if existing then
		return existing
	end

	local layer = Instance.new("Frame")
	layer.Name = `Cave_{level.index}`
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = UI.color.glassDark
	layer.BorderSizePixel = 0
	layer.ClipsDescendants = true
	layer.Visible = false
	layer.ZIndex = 3
	layer.Parent = localView
	UI.corner(layer, UI.radius.chip)

	local cells: { [number]: Frame } = {}
	local size = math.floor(LOCAL_SIZE / Cave.GRID)

	for row = 1, Cave.GRID do
		for col = 1, Cave.GRID do
			local char = Cave.charAt(level, row, col)
			if not Cave.OPEN[char] then
				continue
			end

			local cell = Instance.new("Frame")
			cell.Name = `{row}_{col}`
			cell.AnchorPoint = Vector2.new(0.5, 0.5)
			cell.Position = UDim2.fromScale((col - 0.5) / Cave.GRID, 1 - (row - 0.5) / Cave.GRID)
			cell.Size = UDim2.fromOffset(size, size)
			cell.BorderSizePixel = 0
			cell.BackgroundTransparency = 1
			cell.ZIndex = 4
			cell.Parent = layer

			if char == Cave.BOSS then
				cell.BackgroundColor3 = UI.color.tobatsu
			elseif char == Cave.GLOWCAP or char == Cave.MOONCAP then
				cell.BackgroundColor3 = UI.color.leaf
			elseif char == Cave.DOWN or char == Cave.LANDING or char == Cave.SURFACE then
				cell.BackgroundColor3 = UI.color.gold
			elseif char == Cave.ENTRANCE then
				cell.BackgroundColor3 = UI.color.sky
			else
				cell.BackgroundColor3 = UI.color.inkFaint
			end

			cells[cellKey(row, col)] = cell
		end
	end

	caveLayers[level.index] = layer
	caveCells[level.index] = cells
	revealed[level.index] = revealed[level.index] or {}
	return layer
end

local function caveCoords(level: Cave.LevelDefinition, position: Vector3): (number?, number?)
	local cell = Sections.byCoord(level.coord)
	if not cell then
		return nil, nil
	end
	local col = (position.X - cell.minX - Cave.MARGIN) / Cave.CELL + 0.5
	local row = (cell.maxZ - Cave.MARGIN - position.Z) / Cave.CELL + 0.5
	return row, col
end

local function showCave(level: Cave.LevelDefinition, position: Vector3): boolean
	local row, col = caveCoords(level, position)
	if not row or not col then
		return false
	end

	for _, layer in areaLayers do
		layer.Visible = false
	end
	for index, layer in caveLayers do
		layer.Visible = index == level.index
	end
	buildCaveLayer(level).Visible = true

	local seen = revealed[level.index]
	local reach = REVEAL_RADIUS / Cave.CELL
	for key, cell in caveCells[level.index] do
		if not seen[key] then
			local cellRow = math.floor(key / 100)
			local cellCol = key % 100
			local distance = math.sqrt((cellRow - row) ^ 2 + (cellCol - col) ^ 2)
			if distance <= reach then
				seen[key] = true
			end
		end
		cell.BackgroundTransparency = if seen[key] then 0.15 else 1
	end

	playerMarker.Position = UDim2.fromScale(
		math.clamp((col - 0.5) / Cave.GRID, 0, 1),
		math.clamp(1 - (row - 0.5) / Cave.GRID, 0, 1)
	)
	localTitle.Text = string.upper(level.name)
	return true
end

local function hideCave()
	for _, layer in caveLayers do
		layer.Visible = false
	end
end

local function buildStrip()
	local bounds = Layout.BOUNDS_SIZE

	for _, area in Areas.ALL do
		local half = Layout.halfSize(area)
		local left = (area.origin.X - half - Layout.BOUNDS_MIN.X) / bounds.X
		local width = (half * 2) / bounds.X
		local cell = Instance.new("Frame")
		cell.Name = area.key
		cell.Position = UDim2.fromScale(left, 0)
		cell.Size = UDim2.new(width, -2, 1, 0)
		cell.BackgroundColor3 = area.palette.ground
		cell.BackgroundTransparency = 0.6
		cell.BorderSizePixel = 0
		cell.ZIndex = 4
		cell.Parent = strip
		UI.corner(cell, 4)

		UI.label(cell, "Id", {
			text = tostring(area.id),
			font = UI.font.bold,
			size = 11,
			color = UI.color.inkSoft,
			align = Enum.TextXAlignment.Center,
			extent = UDim2.fromScale(1, 1),
			zIndex = 5,
		})

		stripCells[area.id] = cell
	end

	stripMarker = Instance.new("Frame")
	stripMarker.Name = "You"
	stripMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	stripMarker.Position = UDim2.fromScale(0, 0.5)
	stripMarker.Size = UDim2.fromOffset(4, STRIP_HEIGHT - 6)
	stripMarker.BackgroundColor3 = UI.color.leafDeep
	stripMarker.BorderSizePixel = 0
	stripMarker.ZIndex = 7
	stripMarker.Parent = strip
	UI.corner(stripMarker, 2)
end

local function refresh()
	local character = Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local position = rootPart.Position
	local area = Layout.areaAt(position)
	buildLocalView(area)

	local caveLevel = Cave.levelAt(position)
	if caveLevel and showCave(caveLevel, position) then
		local worldFractionBelow = Layout.toMapFraction(position)
		stripMarker.Position = UDim2.fromScale(worldFractionBelow.X, 0.5)
		return
	end

	hideCave()
	local surfaceLayer = areaLayers[area.id]
	if surfaceLayer then
		surfaceLayer.Visible = true
	end
	localTitle.Text = string.upper(if Layout.isHomePosition(area, position) then "Home" else area.name)

	local offset = position - area.origin
	discoverAround(area, offset.X, offset.Z)

	local fraction = toFraction(area, offset.X, offset.Z)
	playerMarker.Position = UDim2.fromScale(math.clamp(fraction.X, 0, 1), math.clamp(fraction.Y, 0, 1))

	local worldFraction = Layout.toMapFraction(position)
	stripMarker.Position = UDim2.fromScale(worldFraction.X, 0.5)

	local snapshot = StateController.getSnapshot()
	for regionId, cell in stripCells do
		local unlocked = not snapshot or snapshot.unlockedRegions[tostring(regionId)] == true
		local here = regionId == area.id
		cell.BackgroundTransparency = if here then 0.15 elseif unlocked then 0.5 else 0.85
	end
end

local ACTION_NAME = "ToggleMinimap"
local isOpen = false

function Minimap.setOpen(open: boolean)
	isOpen = open
	if root then
		root.Visible = open
	end
	for _, listener in changedListeners do
		task.spawn(listener, open)
	end
end

function Minimap.isOpen(): boolean
	return isOpen
end

function Minimap.onChanged(callback: (boolean) -> ()): () -> ()
	table.insert(changedListeners, callback)
	return function()
		local index = table.find(changedListeners, callback)
		if index then
			table.remove(changedListeners, index)
		end
	end
end

function Minimap.setCompact(compact: boolean)
	root.Position = if compact then UDim2.new(1, -8, 0, 8) else UDim2.new(1, -18, 0, 18)
	rootScale.Scale = if compact then 0.72 else 1
end

function Minimap.toggle()
	Minimap.setOpen(not isOpen)
end

function Minimap.build(parent: Instance): Frame
	root = UI.card(parent, "Minimap")
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -18, 0, 18)
	root.Size = UDim2.fromOffset(LOCAL_SIZE + 24, LOCAL_SIZE + STRIP_HEIGHT + 58)
	root.Visible = isOpen
	UI.padding(root, 12)
	UI.shadow(root)
	rootScale = Instance.new("UIScale")
	rootScale.Parent = root

	ContextActionService:BindAction(ACTION_NAME, function(_name, state)
		if state == Enum.UserInputState.Begin then
			Minimap.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)

	localTitle = UI.label(root, "AreaName", {
		text = "",
		font = UI.font.bold,
		size = 11,
		color = UI.color.inkFaint,
		extent = UDim2.new(1, 0, 0, 14),
	})

	localView = Instance.new("Frame")
	localView.Name = "Local"
	localView.Position = UDim2.fromOffset(0, 20)
	localView.Size = UDim2.fromOffset(LOCAL_SIZE, LOCAL_SIZE)
	localView.BackgroundTransparency = 1
	localView.ZIndex = 3
	localView.Parent = root

	playerMarker = patch(localView, {
		name = "You",
		at = Vector2.new(0.5, 0.5),
		width = 9,
		height = 9,
		color = UI.color.ink,
		zIndex = 9,
		radius = 999,
	})
	UI.stroke(playerMarker, UI.color.paper, 1.5)

	strip = Instance.new("Frame")
	strip.Name = "World"
	strip.Position = UDim2.fromOffset(0, LOCAL_SIZE + 30)
	strip.Size = UDim2.new(1, 0, 0, STRIP_HEIGHT)
	strip.BackgroundColor3 = UI.color.paperDeep
	strip.BorderSizePixel = 0
	strip.ZIndex = 3
	strip.Parent = root
	UI.corner(strip, UI.radius.chip)

	UI.label(root, "StripCaption", {
		text = "the whole way along",
		font = UI.font.light,
		size = 10,
		color = UI.color.inkFaint,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.new(1, 0, 0, 12),
		position = UDim2.fromOffset(0, LOCAL_SIZE + STRIP_HEIGHT + 32),
	})

	buildStrip()

	reportRemote = Remotes.event("Discovery", "Report")

	StateController.onChanged(function(snapshot)
		local saved = snapshot and snapshot.discovered
		if type(saved) ~= "table" then
			return
		end
		for key in saved do
			if not discovered[key] then
				discovered[key] = true
				local tile = fogCells[key]
				if tile then
					tile.BackgroundTransparency = 1
				end
			end
		end
	end)

	RunService.RenderStepped:Connect(function(delta)
		accumulator += delta
		if accumulator < REFRESH_INTERVAL then
			return
		end
		accumulator = 0
		local ok, err = pcall(refresh)
		if not ok then
			warn(`[Minimap] refresh failed: {err}`)
		end
	end)

	return root
end

return Minimap

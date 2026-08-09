local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Cave = require(Shared.Modules.Config.Cave)
local Layout = require(Shared.Modules.Config.Layout)
local Sections = require(Shared.Modules.Config.Sections)
local UI = require(Shared.UI)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local Minimap = {}
local LOCAL_SIZE = 186
local STRIP_HEIGHT = 34
local REFRESH_INTERVAL = 0.25
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

local function toLocalFraction(area: Areas.AreaDefinition, offsetX: number, offsetZ: number): Vector2
	local span = area.terrain.islandSize
	return Vector2.new(0.5 + offsetX / span, 0.5 + offsetZ / span)
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

	local road = Instance.new("Frame")
	road.Name = "Road"
	road.AnchorPoint = Vector2.new(0.5, 0.5)
	road.Position = UDim2.fromScale(0.5, 0.5)
	road.Size = UDim2.new(1, 0, 0, 5)
	road.BackgroundColor3 = UI.color.paperDeep
	road.BackgroundTransparency = 0.25
	road.BorderSizePixel = 0
	road.ZIndex = 4
	road.Parent = layer

	local plaza = Instance.new("Frame")
	plaza.Name = "Plaza"
	plaza.AnchorPoint = Vector2.new(0.5, 0.5)
	plaza.Position = UDim2.fromScale(0.5, 0.5)
	local plazaSize = math.max(10, Layout.plazaDiameter(area) / area.terrain.islandSize * LOCAL_SIZE)
	plaza.Size = UDim2.fromOffset(plazaSize, plazaSize)
	plaza.BackgroundColor3 = UI.color.paper
	plaza.BorderSizePixel = 0
	plaza.ZIndex = 6
	plaza.Parent = layer
	UI.corner(plaza, 999)

	if area.id == Areas.STARTING_AREA then
		UI.glyph(layer, "home", {
			color = UI.color.leafDeep,
			extent = UDim2.fromOffset(15, 15),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			zIndex = 7,
		})
	end

	localTitle.Text = string.upper(area.name)
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
	local fraction = toLocalFraction(area, offset.X, offset.Z)
	playerMarker.Position = UDim2.fromScale(math.clamp(fraction.X, 0, 1), math.clamp(fraction.Y, 0, 1))

	local camera = Workspace.CurrentCamera
	if camera then
		local look = camera.CFrame.LookVector
		playerMarker.Rotation = math.deg(math.atan2(look.Z, look.X))
	end

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

	playerMarker = UI.glyph(localView, "arrow", {
		color = UI.color.ink,
		extent = UDim2.fromOffset(15, 15),
		anchor = Vector2.new(0.5, 0.5),
		zIndex = 9,
	})

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

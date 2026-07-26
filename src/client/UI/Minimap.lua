--[[
	The minimap: a local view of the area you are in, and a strip showing where
	that area sits in the world.

	Drawn ENTIRELY from Config/Layout. Not one line of this reads Workspace, and
	that is a requirement rather than a preference: the world runs with
	StreamingEnabled, so at any moment most of it does not exist on the client.
	A minimap built by scanning for parts would show the player standing in a
	void with three pads in it.

	Because Layout is the same module the server built the world from, the map is
	correct by construction — there is no second description of where anything is
	that could drift.

	Two views, because they answer different questions:
	  - the LOCAL view answers "which way is the Craft district" and is what you
	    look at while playing;
	  - the WORLD strip answers "how far along am I", and at 27,000 studs across
	    with six areas in a line, a strip is honestly what the world looks like.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Skills = require(Shared.Modules.Config.Skills)
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

--------------------------------------------------------------------------------
-- Local view
--------------------------------------------------------------------------------

-- Area-local offset (in studs, from the area origin) -> 0..1 across the view.
local function toLocalFraction(area: Areas.AreaDefinition, offsetX: number, offsetZ: number): Vector2
	local span = area.terrain.islandSize
	return Vector2.new(0.5 + offsetX / span, 0.5 + offsetZ / span)
end

--[[
	Rebuilds the local view for one area.

	Cached on `builtArea`: this is a few dozen instances and it only changes when
	the player crosses a border, so rebuilding it on the refresh tick would be
	pure waste.
]]
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

	-- The road between land bridges, drawn first so everything sits on top.
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

	-- Districts: one rotated bar per skill, at its real bearing.
	for _, district in Layout.districts(area) do
		if #district.worksites == 0 then
			continue
		end

		local skill = Skills.get(district.skillId)
		local colour = (skill and skill.color) or UI.color.leaf or Color3.fromRGB(126, 190, 104)
		local offset = district.plateCFrame.Position - area.origin
		local fraction = toLocalFraction(area, offset.X, offset.Z)

		local bar = Instance.new("Frame")
		bar.Name = district.skillId
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(fraction.X, fraction.Y)
		-- Long axis is WIDTH, so Rotation can be the world bearing unchanged:
		-- a Frame rotated by R sends its local +X to (cos R, sin R) in screen
		-- space, and screen +Y is world +Z on this map.
		bar.Size = UDim2.fromOffset(math.max(6, district.plateSize.Z / area.terrain.islandSize * LOCAL_SIZE), 7)
		bar.Rotation = district.angle
		bar.BackgroundColor3 = colour
		bar.BorderSizePixel = 0
		bar.ZIndex = 5
		bar.Parent = layer
		UI.corner(bar, 3)

		-- The tier-1 pad end gets a dot, so a district reads as having a near
		-- end and a far end rather than as a floating dash.
		local head = Instance.new("Frame")
		head.Name = "Head"
		head.AnchorPoint = Vector2.new(0.5, 0.5)
		local headOffset = district.direction * district.innerRadius
		local headFraction = toLocalFraction(area, headOffset.X, headOffset.Z)
		head.Position = UDim2.fromScale(headFraction.X, headFraction.Y)
		head.Size = UDim2.fromOffset(7, 7)
		head.BackgroundColor3 = colour
		head.BorderSizePixel = 0
		head.ZIndex = 6
		head.Parent = layer
		UI.corner(head, 999)
	end

	-- The plaza, and — in Town — the cottage on top of it.
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

--------------------------------------------------------------------------------
-- World strip
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Live state
--------------------------------------------------------------------------------

local function refresh()
	local character = Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local position = rootPart.Position
	local area = Layout.areaAt(position)
	buildLocalView(area)

	local offset = position - area.origin
	local fraction = toLocalFraction(area, offset.X, offset.Z)
	playerMarker.Position = UDim2.fromScale(math.clamp(fraction.X, 0, 1), math.clamp(fraction.Y, 0, 1))

	-- Heading, so the map answers "which way am I facing" as well as "where am
	-- I". Taken from the camera rather than the character: the camera is what
	-- the player is actually looking along.
	local camera = Workspace.CurrentCamera
	if camera then
		local look = camera.CFrame.LookVector
		playerMarker.Rotation = math.deg(math.atan2(look.Z, look.X))
	end

	local worldFraction = Layout.toMapFraction(position)
	stripMarker.Position = UDim2.fromScale(worldFraction.X, 0.5)

	local snapshot = StateController.snapshot
	for regionId, cell in stripCells do
		local unlocked = not snapshot or snapshot.unlockedRegions[tostring(regionId)] == true
		local here = regionId == area.id
		cell.BackgroundTransparency = if here then 0.15 elseif unlocked then 0.5 else 0.85
	end
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

--[[
	Hidden by default; `M` shows it.

	It is a big opaque panel in the corner of a first-person-ish view, and most
	of the time the player is not navigating — they are stood on a pad clicking.
	Permanent was the wrong default for something consulted occasionally, so it
	is now summoned rather than endured.
]]
local ACTION_NAME = "ToggleMinimap"
local isOpen = false

function Minimap.setOpen(open: boolean)
	isOpen = open
	if root then
		root.Visible = open
	end
end

function Minimap.toggle()
	Minimap.setOpen(not isOpen)
end

function Minimap.isOpen(): boolean
	return isOpen
end

function Minimap.build(parent: Instance): Frame
	root = UI.card(parent, "Minimap")
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -18, 0, 18)
	root.Size = UDim2.fromOffset(LOCAL_SIZE + 24, LOCAL_SIZE + STRIP_HEIGHT + 58)
	root.Visible = isOpen
	UI.padding(root, 12)
	UI.shadow(root)

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

function Minimap.setVisible(visible: boolean)
	if root then
		root.Visible = visible
	end
end

return Minimap

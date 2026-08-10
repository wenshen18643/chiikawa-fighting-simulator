local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Farming = require(Shared.Modules.Config.Farming)
local Sections = require(Shared.Modules.Config.Sections)
local BoardService = {}
local FOLDER = "Board"
local LIGHT = Color3.fromRGB(248, 244, 236)
local DARK = Color3.fromRGB(116, 146, 128)
local TRANSPARENCY = 0.55
local LABEL_LIFT = 26
local LABEL_WIDTH = 84
local LABEL_HEIGHT = 34
local LABEL_DISTANCE = 620
local BOARD_HEIGHT = Constants.WORLD.PLATFORM_TOP + 0.3

local function root(): Folder
	local existing = Workspace:FindFirstChild(FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER
	created.Parent = Workspace
	return created
end

local function label(cell: Sections.Cell, parent: Model)
	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(cell.cx, BOARD_HEIGHT + LABEL_LIFT, cell.cz)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(LABEL_WIDTH, LABEL_HEIGHT)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = LABEL_DISTANCE
	gui.Parent = anchor

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.BackgroundColor3 = Color3.fromRGB(28, 32, 30)
	plate.BackgroundTransparency = 0.35
	plate.BorderSizePixel = 0
	plate.Size = UDim2.fromScale(1, 1)
	plate.Parent = gui

	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 6)
	rounded.Parent = plate

	local coord = Instance.new("TextLabel")
	coord.Name = "Coord"
	coord.BackgroundTransparency = 1
	coord.Position = UDim2.fromScale(0, 0.06)
	coord.Size = UDim2.fromScale(1, 0.52)
	coord.Font = Enum.Font.GothamBold
	coord.TextScaled = true
	coord.TextColor3 = Color3.fromRGB(255, 255, 255)
	coord.TextStrokeTransparency = 0.35
	coord.Text = cell.coord
	coord.Parent = plate

	local theme = Instance.new("TextLabel")
	theme.Name = "Theme"
	theme.BackgroundTransparency = 1
	theme.Position = UDim2.fromScale(0.06, 0.58)
	theme.Size = UDim2.fromScale(0.88, 0.34)
	theme.Font = Enum.Font.Gotham
	theme.TextScaled = true
	theme.TextColor3 = Color3.fromRGB(206, 214, 208)
	theme.TextStrokeTransparency = 0.6
	theme.Text = cell.theme
	theme.Parent = plate

	anchor.Parent = parent
end

local function tile(cell: Sections.Cell, parent: Folder)
	local model = Instance.new("Model")
	model.Name = cell.coord

	local slab = Instance.new("Part")
	slab.Name = "Tile"
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.CastShadow = false
	slab.Material = Enum.Material.SmoothPlastic
	slab.Transparency = TRANSPARENCY
	slab.Color = if (cell.i + cell.j) % 2 == 0 then DARK else LIGHT
	slab.Size = Vector3.new(Sections.SIZE, 0.4, Sections.SIZE)
	slab.CFrame = CFrame.new(cell.cx, BOARD_HEIGHT, cell.cz)
	slab.Parent = model

	label(cell, model)

	model.PrimaryPart = slab
	model.Parent = parent
end

function BoardService.build()
	local parent = root()
	parent:ClearAllChildren()
	for _, cell in Sections.cells() do
		if Farming.isFootprintCell(cell.coord) then
			continue
		end
		tile(cell, parent)
	end
	return parent
end

function BoardService.init()
	if RunService:IsStudio() then
		BoardService.build()
	end
end

return BoardService

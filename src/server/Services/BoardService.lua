local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Farming = require(Shared.Modules.Config.Farming)
local Areas = require(Shared.Areas)
local Sections = require(Shared.Modules.Config.Sections)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local BoardService = {}
local FOLDER = "Board"
local LIGHT = Color3.fromRGB(248, 244, 236)
local DARK = Color3.fromRGB(116, 146, 128)
local TRANSPARENCY = 0.55
local LABEL_LIFT = 26

BoardService.height = Constants.WORLD.PLATFORM_TOP + 0.3

local function area(): Areas.AreaDefinition
	return Areas.BY_ID[Areas.STARTING_AREA]
end

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
	anchor.CFrame = CFrame.new(cell.cx, BoardService.height + LABEL_LIFT, cell.cz)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 64)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 1400
	gui.Parent = anchor

	local coord = Instance.new("TextLabel")
	coord.BackgroundTransparency = 1
	coord.Size = UDim2.fromScale(1, 0.62)
	coord.Font = Enum.Font.GothamBold
	coord.TextScaled = true
	coord.TextColor3 = Color3.fromRGB(255, 255, 255)
	coord.TextStrokeTransparency = 0.2
	coord.Text = cell.coord
	coord.Parent = gui

	local theme = Instance.new("TextLabel")
	theme.BackgroundTransparency = 1
	theme.Position = UDim2.fromScale(0, 0.62)
	theme.Size = UDim2.fromScale(1, 0.38)
	theme.Font = Enum.Font.Gotham
	theme.TextScaled = true
	theme.TextColor3 = Color3.fromRGB(226, 226, 226)
	theme.TextStrokeTransparency = 0.4
	theme.Text = cell.theme
	theme.Parent = gui

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
	slab.CFrame = CFrame.new(cell.cx, BoardService.height, cell.cz)
	slab.Parent = model

	label(cell, model)

	model.PrimaryPart = slab
	model.Parent = parent
end

function BoardService.build()
	local parent = root()
	parent:ClearAllChildren()
	for _, cell in Sections.cells() do
		if cell.coord == Farming.CELL_COORD then
			continue
		end
		tile(cell, parent)
	end
	return parent
end

function BoardService.get(coord: string): Model?
	local parent = Workspace:FindFirstChild(FOLDER)
	if not parent then
		return nil
	end
	local model = parent:FindFirstChild(tostring(coord):upper())
	return if model and model:IsA("Model") then model else nil
end

function BoardService.remove(coord: string): boolean
	local model = BoardService.get(coord)
	if not model then
		return false
	end
	model:Destroy()
	return true
end

function BoardService.setVisible(visible: boolean)
	local parent = Workspace:FindFirstChild(FOLDER)
	if not parent then
		return
	end
	for _, model in parent:GetChildren() do
		local slab = model:FindFirstChild("Tile")
		if slab and slab:IsA("BasePart") then
			slab.Transparency = if visible then TRANSPARENCY else 1
		end
		local anchor = model:FindFirstChild("Label")
		local gui = anchor and anchor:FindFirstChildWhichIsA("BillboardGui")
		if gui then
			gui.Enabled = visible
		end
	end
end

function BoardService.clear(coord: string): boolean
	local cell = Sections.byCoord(coord)
	if not cell then
		warn(`[BoardService] no such cell "{coord}"`)
		return false
	end
	TerrainBuilder.clearCell(area(), cell)
	return true
end

function BoardService.rebuild(coord: string): boolean
	local cell = Sections.byCoord(coord)
	if not cell then
		warn(`[BoardService] no such cell "{coord}"`)
		return false
	end
	TerrainBuilder.clearCell(area(), cell)
	TerrainBuilder.buildCell(area(), cell, nil)
	return true
end

function BoardService.init()
	if RunService:IsStudio() then
		BoardService.build()
	end
end

return BoardService

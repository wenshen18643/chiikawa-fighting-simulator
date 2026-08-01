--!strict

--[[
	Builds the Peach Study Library as one relocatable model. Layout owns the
	configured world CFrame; this module owns only geometry relative to it.

	The returned cushion roots are presentation-neutral interaction points.
	LibraryService decides what their prompts do, so this builder cannot award
	progress or create client-server gameplay state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Layout = require(Shared.Modules.Config.Layout)

local LibraryBuilder = {}

export type BuildResult = {
	model: Model,
	stationRoots: { BasePart },
	anchorPosition: Vector3,
}

type PartOptions = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
	canQuery: boolean?,
	castShadow: boolean?,
}

local SIZE = Layout.LIBRARY_SIZE
local FLOOR_HEIGHT = 1.2
local WALL_HEIGHT = 20
local WALL_THICKNESS = 1.5

local WHITE = Color3.fromRGB(255, 251, 246)
local PAPER = Color3.fromRGB(250, 243, 234)
local PEACH = Color3.fromRGB(246, 178, 158)
local PEACH_LIGHT = Color3.fromRGB(252, 214, 197)
local PEACH_DARK = Color3.fromRGB(220, 132, 118)
local TATAMI = Color3.fromRGB(222, 210, 164)
local TATAMI_EDGE = Color3.fromRGB(157, 132, 88)
local WOOD = Color3.fromRGB(153, 108, 76)
local WOOD_DARK = Color3.fromRGB(100, 69, 55)
local GLASS = Color3.fromRGB(217, 239, 242)
local WARM = Color3.fromRGB(255, 225, 177)

local BOOK_COLORS = {
	Color3.fromRGB(225, 111, 116),
	Color3.fromRGB(106, 157, 211),
	Color3.fromRGB(229, 179, 88),
	Color3.fromRGB(126, 179, 119),
	Color3.fromRGB(180, 128, 185),
	Color3.fromRGB(236, 151, 112),
}

local function makePart(parent: Instance, options: PartOptions): Part
	local item = Instance.new("Part")
	item.Name = options.name
	item.Size = options.size
	item.CFrame = options.cframe
	item.Color = options.color
	item.Material = options.material or Enum.Material.SmoothPlastic
	item.Shape = options.shape or Enum.PartType.Block
	item.Transparency = options.transparency or 0
	item.Anchored = true
	item.CanCollide = options.canCollide ~= false
	item.CanQuery = if options.canQuery ~= nil then options.canQuery else item.CanCollide
	item.CanTouch = false
	item.CastShadow = if options.castShadow ~= nil then options.castShadow else true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function localPart(parent: Instance, frame: CFrame, options: PartOptions): Part
	options.cframe = frame * options.cframe
	return makePart(parent, options)
end

local function groundYAt(position: Vector3): number
	local hit = Workspace:Raycast(position + Vector3.new(0, 100, 0), Vector3.new(0, -240, 0))
	return if hit then hit.Position.Y else Constants.WORLD.PLATFORM_TOP
end

local function buildWindow(parent: Instance, frame: CFrame, side: number)
	local x = side * (SIZE.X / 2 - WALL_THICKNESS / 2)
	local wallY = FLOOR_HEIGHT + WALL_HEIGHT / 2

	localPart(parent, frame, {
		name = "SideWallFront",
		size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, 18),
		cframe = CFrame.new(x, wallY, -21),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	localPart(parent, frame, {
		name = "SideWallBack",
		size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, 18),
		cframe = CFrame.new(x, wallY, 21),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	localPart(parent, frame, {
		name = "WindowLowerWall",
		size = Vector3.new(WALL_THICKNESS, 5, 24),
		cframe = CFrame.new(x, FLOOR_HEIGHT + 2.5, 0),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	localPart(parent, frame, {
		name = "WindowUpperWall",
		size = Vector3.new(WALL_THICKNESS, 5, 24),
		cframe = CFrame.new(x, FLOOR_HEIGHT + WALL_HEIGHT - 2.5, 0),
		color = WHITE,
		material = Enum.Material.Plaster,
	})

	local glassX = side * (SIZE.X / 2 + 0.02)
	localPart(parent, frame, {
		name = "WindowGlass",
		size = Vector3.new(0.2, 10, 24),
		cframe = CFrame.new(glassX, FLOOR_HEIGHT + 10, 0),
		color = GLASS,
		material = Enum.Material.Glass,
		transparency = 0.35,
		canCollide = false,
		canQuery = false,
		castShadow = false,
	})
	for _, z in { -12, 0, 12 } do
		localPart(parent, frame, {
			name = "WindowMullion",
			size = Vector3.new(0.5, 10.5, 0.45),
			cframe = CFrame.new(glassX, FLOOR_HEIGHT + 10, z),
			color = PEACH,
			canCollide = false,
			canQuery = false,
		})
	end
	localPart(parent, frame, {
		name = "WindowRail",
		size = Vector3.new(0.5, 0.45, 24),
		cframe = CFrame.new(glassX, FLOOR_HEIGHT + 10, 0),
		color = PEACH,
		canCollide = false,
		canQuery = false,
	})
end

local function buildShell(parent: Instance, frame: CFrame): BasePart
	local foundation = localPart(parent, frame, {
		name = "Foundation",
		size = Vector3.new(SIZE.X, FLOOR_HEIGHT, SIZE.Z),
		cframe = CFrame.new(0, FLOOR_HEIGHT / 2, 0),
		color = PEACH,
		material = Enum.Material.SmoothPlastic,
	})
	localPart(parent, frame, {
		name = "LibraryFloor",
		size = Vector3.new(SIZE.X - 3, 0.35, SIZE.Z - 3),
		cframe = CFrame.new(0, FLOOR_HEIGHT + 0.175, 0),
		color = PAPER,
		material = Enum.Material.WoodPlanks,
	})
	localPart(parent, frame, {
		name = "TatamiInset",
		size = Vector3.new(43, 0.12, 29),
		cframe = CFrame.new(0, FLOOR_HEIGHT + 0.42, -1),
		color = TATAMI,
		material = Enum.Material.Fabric,
		canCollide = false,
		canQuery = false,
	})
	for _, x in { -21.5, 21.5 } do
		localPart(parent, frame, {
			name = "TatamiEdge",
			size = Vector3.new(0.3, 0.14, 29),
			cframe = CFrame.new(x, FLOOR_HEIGHT + 0.49, -1),
			color = TATAMI_EDGE,
			material = Enum.Material.Fabric,
			canCollide = false,
			canQuery = false,
		})
	end

	localPart(parent, frame, {
		name = "BackWall",
		size = Vector3.new(SIZE.X, WALL_HEIGHT, WALL_THICKNESS),
		cframe = CFrame.new(0, FLOOR_HEIGHT + WALL_HEIGHT / 2, SIZE.Z / 2 - WALL_THICKNESS / 2),
		color = WHITE,
		material = Enum.Material.Plaster,
	})
	buildWindow(parent, frame, -1)
	buildWindow(parent, frame, 1)

	for _, side in { -1, 1 } do
		localPart(parent, frame, {
			name = "FrontColumn",
			size = Vector3.new(3, WALL_HEIGHT + 2, 3),
			cframe = CFrame.new(side * (SIZE.X / 2 - 2.5), FLOOR_HEIGHT + (WALL_HEIGHT + 2) / 2, -SIZE.Z / 2 + 1.5),
			color = PEACH,
			material = Enum.Material.Wood,
		})
	end
	localPart(parent, frame, {
		name = "FrontHeader",
		size = Vector3.new(SIZE.X - 4, 3, 2.5),
		cframe = CFrame.new(0, FLOOR_HEIGHT + WALL_HEIGHT - 0.5, -SIZE.Z / 2 + 1.25),
		color = WHITE,
		material = Enum.Material.Wood,
	})

	local roofAngle = math.rad(11)
	for _, side in { -1, 1 } do
		localPart(parent, frame, {
			name = "PeachRoof",
			size = Vector3.new(SIZE.X / 2 + 4, 1.2, SIZE.Z + 5),
			cframe = CFrame.new(side * (SIZE.X / 4), FLOOR_HEIGHT + WALL_HEIGHT + 3.6, 0)
				* CFrame.Angles(0, 0, -side * roofAngle),
			color = PEACH,
			material = Enum.Material.Slate,
		})
	end
	for _, z in { -SIZE.Z / 2 - 2.2, SIZE.Z / 2 + 2.2 } do
		for _, side in { -1, 1 } do
			localPart(parent, frame, {
				name = "WhiteFascia",
				size = Vector3.new(SIZE.X / 2 + 4, 0.8, 1),
				cframe = CFrame.new(side * (SIZE.X / 4), FLOOR_HEIGHT + WALL_HEIGHT + 3.6, z)
					* CFrame.Angles(0, 0, -side * roofAngle),
				color = WHITE,
				material = Enum.Material.Wood,
				canCollide = false,
				canQuery = false,
			})
		end
	end

	return foundation
end

local function addBooks(parent: Instance, shelfFrame: CFrame, width: number, shelfIndex: number)
	local left = -width / 2 + 1.2
	local right = width / 2 - 1.2
	for row = 1, 3 do
		local x = left
		local book = 1
		while x < right do
			local sequence = shelfIndex * 23 + row * 11 + book
			local bookWidth = 0.65 + (sequence % 4) * 0.16
			local bookHeight = 2.6 + (sequence % 5) * 0.22
			if x + bookWidth > right then
				break
			end
			makePart(parent, {
				name = "Book",
				size = Vector3.new(bookWidth, bookHeight, 1.55),
				cframe = shelfFrame
					* CFrame.new(x + bookWidth / 2, 1.35 + (row - 1) * 4.5 + bookHeight / 2, -1.35)
					* CFrame.Angles(0, 0, math.rad((sequence % 3 - 1) * 2)),
				color = BOOK_COLORS[sequence % #BOOK_COLORS + 1],
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				canQuery = false,
				castShadow = false,
			})
			x += bookWidth + 0.16
			book += 1
		end
	end
end

local function buildShelf(parent: Instance, frame: CFrame, at: CFrame, width: number, index: number)
	local shelfFrame = frame * at
	makePart(parent, {
		name = "ShelfBack",
		size = Vector3.new(width, 15.5, 0.6),
		cframe = shelfFrame * CFrame.new(0, 8.2, 0.9),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
	})
	for _, x in { -width / 2, width / 2 } do
		makePart(parent, {
			name = "ShelfSide",
			size = Vector3.new(0.7, 16.5, 3.5),
			cframe = shelfFrame * CFrame.new(x, 8.25, 0),
			color = WOOD,
			material = Enum.Material.Wood,
		})
	end
	for row = 0, 3 do
		makePart(parent, {
			name = "ShelfBoard",
			size = Vector3.new(width + 0.8, 0.55, 3.8),
			cframe = shelfFrame * CFrame.new(0, 0.55 + row * 4.5, 0),
			color = WOOD,
			material = Enum.Material.Wood,
		})
	end
	addBooks(parent, shelfFrame, width, index)
end

local function buildShelves(parent: Instance, frame: CFrame)
	for index, x in { -24, 0, 24 } do
		buildShelf(parent, frame, CFrame.new(x, FLOOR_HEIGHT + 0.5, SIZE.Z / 2 - 3), 20, index)
	end
	for index, z in { -16, 9 } do
		buildShelf(
			parent,
			frame,
			CFrame.new(-SIZE.X / 2 + 3, FLOOR_HEIGHT + 0.5, z) * CFrame.Angles(0, math.rad(-90), 0),
			18,
			index + 3
		)
		buildShelf(
			parent,
			frame,
			CFrame.new(SIZE.X / 2 - 3, FLOOR_HEIGHT + 0.5, z) * CFrame.Angles(0, math.rad(90), 0),
			18,
			index + 5
		)
	end
end

local function buildTable(parent: Instance, frame: CFrame): { BasePart }
	local tableCentre = Vector3.new(0, 0, -1)
	localPart(parent, frame, {
		name = "TableTop",
		size = Vector3.new(24, 0.8, 10),
		cframe = CFrame.new(tableCentre + Vector3.new(0, FLOOR_HEIGHT + 4.2, 0)),
		color = WHITE,
		material = Enum.Material.Wood,
	})
	localPart(parent, frame, {
		name = "TablePeachInset",
		size = Vector3.new(22.5, 0.16, 8.5),
		cframe = CFrame.new(tableCentre + Vector3.new(0, FLOOR_HEIGHT + 4.68, 0)),
		color = PEACH_LIGHT,
		canCollide = false,
		canQuery = false,
	})
	for _, x in { -9.5, 9.5 } do
		for _, z in { -3.2, 3.2 } do
			localPart(parent, frame, {
				name = "TableLeg",
				size = Vector3.new(1, 3.9, 1),
				cframe = CFrame.new(tableCentre + Vector3.new(x, FLOOR_HEIGHT + 2, z)),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
			})
		end
	end

	for index, x in { -6.5, 3.5 } do
		localPart(parent, frame, {
			name = "TableBook",
			size = Vector3.new(4.5, 0.32, 3.3),
			cframe = CFrame.new(tableCentre + Vector3.new(x, FLOOR_HEIGHT + 4.96 + index * 0.03, 0.4))
				* CFrame.Angles(0, math.rad(if index == 1 then -8 else 7), 0),
			color = if index == 1 then PEACH_DARK else Color3.fromRGB(115, 166, 208),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
	})
	end
	localPart(parent, frame, {
		name = "PencilCup",
		size = Vector3.new(1.2, 1.4, 1.2),
		cframe = CFrame.new(tableCentre + Vector3.new(8, FLOOR_HEIGHT + 5.35, -1.5)),
		color = WHITE,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		canQuery = false,
	})

	local stationRoots = {} :: { BasePart }
	local cushionOffsets = {
		Vector3.new(-7, 0, -10),
		Vector3.new(7, 0, -10),
		Vector3.new(-7, 0, 10),
		Vector3.new(7, 0, 10),
		Vector3.new(-17, 0, 0),
		Vector3.new(17, 0, 0),
	}
	for index, offset in cushionOffsets do
		local rotation = if index <= 2
			then 0
			elseif index <= 4 then math.pi
			elseif index == 5 then -math.pi / 2
			else math.pi / 2
		local cushionFrame = frame
			* CFrame.new(tableCentre + offset + Vector3.new(0, FLOOR_HEIGHT + 0.55, 0))
			* CFrame.Angles(0, rotation, 0)
		localPart(parent, cushionFrame, {
			name = "CushionWhitePiping",
			size = Vector3.new(5.6, 0.28, 5.6),
			cframe = CFrame.new(0, -0.18, 0),
			color = WHITE,
			material = Enum.Material.Fabric,
			canCollide = false,
			canQuery = false,
		})
		local root = localPart(parent, cushionFrame, {
			name = `CushionPromptRoot_{index}`,
			size = Vector3.new(5.1, 0.55, 5.1),
			cframe = CFrame.new(),
			color = if index % 2 == 0 then PEACH_LIGHT else PEACH,
			material = Enum.Material.Fabric,
			canCollide = false,
			canQuery = true,
		})
		table.insert(stationRoots, root)
	end

	return stationRoots
end

local function buildLighting(parent: Instance, frame: CFrame)
	for index, offset in {
		Vector3.new(-18, FLOOR_HEIGHT + 16.5, -11),
		Vector3.new(18, FLOOR_HEIGHT + 16.5, -11),
		Vector3.new(-18, FLOOR_HEIGHT + 16.5, 12),
		Vector3.new(18, FLOOR_HEIGHT + 16.5, 12),
	} do
		local lamp = localPart(parent, frame, {
			name = `WarmLamp_{index}`,
			size = Vector3.new(2.2, 2.2, 2.2),
			shape = Enum.PartType.Ball,
			cframe = CFrame.new(offset),
			color = WARM,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			castShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Color = WARM
		light.Brightness = 1.2
		light.Range = 23
		light.Shadows = false
		light.Parent = lamp
	end
end

local function buildSign(parent: Instance, frame: CFrame)
	local sign = localPart(parent, frame, {
		name = "LibrarySign",
		size = Vector3.new(31, 5.5, 0.8),
		cframe = CFrame.new(0, FLOOR_HEIGHT + WALL_HEIGHT - 0.5, -SIZE.Z / 2 - 0.2),
		color = PEACH,
		material = Enum.Material.Wood,
		canCollide = false,
		canQuery = false,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignFace"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0.2
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "Peach Study Library"
	label.TextColor3 = Color3.fromRGB(89, 60, 55)
	label.TextScaled = true
	label.TextStrokeColor3 = WHITE
	label.TextStrokeTransparency = 0.55
	label.Parent = surface
end

local function buildApproach(parent: Instance, frame: CFrame)
	for index = 1, 8 do
		localPart(parent, frame, {
			name = "ApproachStone",
			size = Vector3.new(12, 0.35, 4),
			cframe = CFrame.new(0, 0.18, -(SIZE.Z / 2 + 3 + (index - 1) * 4.5)),
			color = if index % 2 == 0 then WHITE else PEACH_LIGHT,
			material = Enum.Material.Slate,
			canCollide = false,
			canQuery = false,
		})
	end
end

function LibraryBuilder.build(parent: Instance, configuredFrame: CFrame): BuildResult
	local groundY = groundYAt(configuredFrame.Position)
	local frame = CFrame.new(configuredFrame.Position.X, groundY, configuredFrame.Position.Z) * configuredFrame.Rotation

	local library = Instance.new("Model")
	library.Name = "PeachStudyLibrary"
	library:SetAttribute("Cell", Layout.LIBRARY_CELL)

	local foundation = buildShell(library, frame)
	buildShelves(library, frame)
	local stationRoots = buildTable(library, frame)
	buildLighting(library, frame)
	buildSign(library, frame)
	buildApproach(library, frame)

	library.PrimaryPart = foundation
	library.Parent = parent

	return {
		model = library,
		stationRoots = stationRoots,
		anchorPosition = frame:PointToWorldSpace(Vector3.new(0, FLOOR_HEIGHT, -1)),
	}
end

return LibraryBuilder

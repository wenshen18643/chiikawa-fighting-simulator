--[[
	The cottage you spawn in, and the volume in which nothing can touch you.

	See docs/GAME.md §2 and §9.6, and Config/SafeZone.lua for the shape of the
	building. This file turns that table into parts and owns what the volume
	MEANS.

	Two responsibilities that look unrelated and are not:

	  1. It is a home. Three levels — a kitchen you walk into, a loft you sleep
	     in, a roof deck with a view down the whole landmass — assembled from
	     parts so it lives in version control and needs no uploaded assets, the
	     same way NpcService assembles the cast.

	  2. It is THE SAFE ZONE, and the only place in the codebase that is allowed
	     to define what safety means. There is no damage in the game yet, so this
	     is deliberately built as a seam rather than as a reaction: when Slice 5
	     lands, every damage path calls SafeZoneService.isProtected first, and
	     the answer is already correct.

	Protection is three overlapping mechanisms, because each one leaks alone:
	  - A ForceField makes Humanoid:TakeDamage() a no-op. That covers anything
	    written the ordinary way.
	  - A health guard restores anything that writes Humanoid.Health directly,
	    which a ForceField does not stop.
	  - isProtected() is the predicate future systems check before they resolve
	    at all, so the other two never have to fire.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Remotes = require(Shared.Modules.Remotes)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local UI = require(Shared.UI)

local AssetService = require(script.Parent.AssetService)
local WorldService = require(script.Parent.WorldService)

local SafeZoneService = {}

local CHECK_INTERVAL = 0.2

local palette = SafeZone.palette
local houseFolder: Folder
local volumeCentre: Vector3
local volumeHalf: Vector3

local inside: { [Player]: boolean } = {}
local healthGuards: { [Player]: RBXScriptConnection } = {}
local changedRemote: RemoteEvent?

--------------------------------------------------------------------------------
-- Part helpers
--------------------------------------------------------------------------------

local function piece(config: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = config.name or "Piece"
	p.Anchored = true
	p.CanCollide = config.collide ~= false
	p.CanQuery = config.query ~= false
	p.Size = config.size
	p.Shape = config.shape or Enum.PartType.Block
	p.Color = config.color or palette.plaster
	p.Material = config.material or Enum.Material.SmoothPlastic
	p.Transparency = config.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = config.cframe
	p.Parent = config.parent or houseFolder
	return p
end

--------------------------------------------------------------------------------
-- Shell
--------------------------------------------------------------------------------

--[[
	A wall face with at most one rectangular opening, built as the up-to-four
	solid segments left around it.

	Doing it this way rather than as a solid wall with a decorative window pasted
	on is what makes the loft window a view instead of a picture — you can see
	the districts through it, which is the whole point of putting the player's
	bed above the town.
]]
-- selene: allow(unused_variable)
local function wallFace(
	toWorld: (number, number, number) -> CFrame,
	config: {
		name: string,
		width: number,
		height: number,
		thickness: number,
		-- Centre of the wall in cottage space.
		x: number,
		y: number,
		z: number,
		-- true when the wall runs along Z (the -X / +X sides).
		sideways: boolean,
		opening: { x: number, y: number, width: number, height: number }?,
		color: Color3?,
	}
)
	local opening = config.opening
	local halfW, halfH = config.width / 2, config.height / 2

	--[[
		Segments in the wall's own 2D space: `u` runs along the wall, `v` is up.
		Emitted as (centre_u, centre_v, size_u, size_v).
	]]
	local segments: { { number } } = {}

	if not opening then
		table.insert(segments, { 0, 0, config.width, config.height })
	else
		local oLeft, oRight = opening.x - opening.width / 2, opening.x + opening.width / 2
		local oBottom, oTop = opening.y - opening.height / 2, opening.y + opening.height / 2

		local belowHeight = oBottom + halfH
		if belowHeight > 0.05 then
			table.insert(segments, { 0, -halfH + belowHeight / 2, config.width, belowHeight })
		end

		local aboveHeight = halfH - oTop
		if aboveHeight > 0.05 then
			table.insert(segments, { 0, oTop + aboveHeight / 2, config.width, aboveHeight })
		end

		local leftWidth = oLeft + halfW
		if leftWidth > 0.05 then
			table.insert(segments, { -halfW + leftWidth / 2, opening.y, leftWidth, opening.height })
		end

		local rightWidth = halfW - oRight
		if rightWidth > 0.05 then
			table.insert(segments, { oRight + rightWidth / 2, opening.y, rightWidth, opening.height })
		end
	end

	for index, segment in segments do
		local u, v, sizeU, sizeV = segment[1], segment[2], segment[3], segment[4]
		local size = if config.sideways
			then Vector3.new(config.thickness, sizeV, sizeU)
			else Vector3.new(sizeU, sizeV, config.thickness)
		local offsetU = if config.sideways then Vector3.new(0, 0, u) else Vector3.new(u, 0, 0)

		piece({
			name = `{config.name}_{index}`,
			size = size,
			color = config.color or palette.plaster,
			material = Enum.Material.Sand,
			cframe = toWorld(config.x + offsetU.X, config.y + v, config.z + offsetU.Z),
		})
	end
end

--[[
	A floor slab with a rectangular hole for the stairwell, built as the four
	strips around it. Same idea as wallFace, in plan rather than elevation.
]]
-- selene: allow(unused_variable)
local function slabWithHole(
	toWorld: (number, number, number) -> CFrame,
	y: number,
	hole: { x: number, z: number, width: number, depth: number }?
)
	local width, depth = SafeZone.WIDTH, SafeZone.DEPTH
	local thickness = SafeZone.FLOOR_SLAB

	local strips: { { number } } = {}
	if not hole then
		strips = { { 0, 0, width, depth } }
	else
		local zNear = hole.z - hole.depth / 2 + depth / 2 -- distance from -Z edge
		local zFar = depth / 2 - (hole.z + hole.depth / 2)
		if zNear > 0.05 then
			table.insert(strips, { 0, -depth / 2 + zNear / 2, width, zNear })
		end
		if zFar > 0.05 then
			table.insert(strips, { 0, depth / 2 - zFar / 2, width, zFar })
		end

		local xLeft = hole.x - hole.width / 2 + width / 2
		local xRight = width / 2 - (hole.x + hole.width / 2)
		if xLeft > 0.05 then
			table.insert(strips, { -width / 2 + xLeft / 2, hole.z, xLeft, hole.depth })
		end
		if xRight > 0.05 then
			table.insert(strips, { width / 2 - xRight / 2, hole.z, xRight, hole.depth })
		end
	end

	for index, strip in strips do
		piece({
			name = `Floor_{math.floor(y)}_{index}`,
			size = Vector3.new(strip[3], thickness, strip[4]),
			color = palette.floor,
			material = Enum.Material.WoodPlanks,
			cframe = toWorld(strip[1], y - thickness / 2, strip[2]),
		})
	end
end

-- A run of steps climbing one storey. Alternates direction per floor so the
-- staircase zig-zags up the back wall instead of running the same way twice.
-- selene: allow(unused_variable)
local function buildStairs(toWorld: (number, number, number) -> CFrame, fromY: number, rise: number, direction: number)
	local steps = math.max(1, math.ceil(rise / SafeZone.STEP_RISE))
	local stepRise = rise / steps
	local run = steps * SafeZone.STEP_RUN
	local stairZ = -SafeZone.DEPTH / 2 + SafeZone.WALL + SafeZone.STEP_WIDTH / 2

	for index = 1, steps do
		local height = stepRise * index
		piece({
			name = `Step_{index}`,
			size = Vector3.new(SafeZone.STEP_RUN, height, SafeZone.STEP_WIDTH),
			color = palette.timber,
			material = Enum.Material.Wood,
			cframe = toWorld(direction * (-run / 2 + (index - 0.5) * SafeZone.STEP_RUN), fromY + height / 2, stairZ),
		})
	end

	return {
		x = 0,
		z = stairZ,
		width = run + 3,
		depth = SafeZone.STEP_WIDTH + 3,
	}
end

--------------------------------------------------------------------------------
-- Furnishing
--------------------------------------------------------------------------------

local furnishers: { [string]: (any, (number, number, number) -> CFrame, number) -> () } = {}

function furnishers.hearth(row, toWorld, y)
	piece({
		name = "Hearth",
		size = Vector3.new(6, 4, 4),
		color = palette.hearth,
		material = Enum.Material.Slate,
		cframe = toWorld(row.x, y + 2.0, row.z),
	})
	local fire = piece({
		name = "HearthFire",
		size = Vector3.new(3.5, 0.6, 2),
		color = Color3.fromRGB(250, 190, 120),
		material = Enum.Material.Neon,
		transparency = 0.5,
		collide = false,
		cframe = toWorld(row.x, y + 1.2, row.z + 1),
	})

	local flame = Instance.new("Fire")
	flame.Size = 3
	flame.Heat = 2
	flame.Color = Color3.fromRGB(252, 206, 140)
	flame.SecondaryColor = Color3.fromRGB(228, 140, 96)
	flame.Parent = fire

	local light = Instance.new("PointLight")
	light.Brightness = 0.15
	light.Range = 8
	light.Color = Color3.fromRGB(255, 208, 150)
	light.Parent = fire

	-- Small neat chimney piece
	piece({
		name = "Chimney",
		size = Vector3.new(4, SafeZone.FLOOR_HEIGHT - 6, 3),
		color = palette.plasterShade,
		material = Enum.Material.Brick,
		cframe = toWorld(row.x, y + 4 + (SafeZone.FLOOR_HEIGHT - 6) / 2, row.z - 0.5),
	})
end

function furnishers.table(row, toWorld, y)
	local radius = row.radius or 6
	piece({
		name = "TableTop",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, radius * 2, radius * 2),
		color = palette.timber,
		material = Enum.Material.Wood,
		cframe = toWorld(row.x, y + 5, row.z) * CFrame.Angles(0, 0, math.rad(90)),
	})
	piece({
		name = "TableLeg",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5, 2.2, 2.2),
		color = palette.timberDark,
		material = Enum.Material.Wood,
		cframe = toWorld(row.x, y + 2.5, row.z) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

function furnishers.stool(row, toWorld, y)
	piece({
		name = "Stool",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.7, 4.4, 4.4),
		color = palette.timber,
		material = Enum.Material.Wood,
		cframe = toWorld(row.x, y + 3, row.z) * CFrame.Angles(0, 0, math.rad(90)),
	})
	piece({
		name = "StoolLeg",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3, 1.4, 1.4),
		color = palette.timberDark,
		material = Enum.Material.Wood,
		cframe = toWorld(row.x, y + 1.5, row.z) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

function furnishers.futon(row, toWorld, y)
	piece({
		name = "Futon",
		size = Vector3.new(11, 1.6, 16),
		color = palette.fabric,
		material = Enum.Material.Fabric,
		cframe = toWorld(row.x, y + 0.8, row.z),
	})
	piece({
		name = "Pillow",
		size = Vector3.new(7, 1.8, 4),
		color = Color3.fromRGB(252, 246, 238),
		material = Enum.Material.Fabric,
		collide = false,
		cframe = toWorld(row.x, y + 2.4, row.z - 5.5),
	})
end

function furnishers.shelf(row, toWorld, y)
	local width = row.width or 10
	for index = 1, 3 do
		piece({
			name = `Shelf_{index}`,
			size = Vector3.new(width, 0.6, 4),
			color = palette.timber,
			material = Enum.Material.Wood,
			collide = false,
			cframe = toWorld(row.x, y + 3 + (index - 1) * 3.4, row.z),
		})
	end
	for _, side in { -1, 1 } do
		piece({
			name = "ShelfSide",
			size = Vector3.new(0.7, 10.6, 4),
			color = palette.timberDark,
			material = Enum.Material.Wood,
			collide = false,
			cframe = toWorld(row.x + side * width / 2, y + 6, row.z),
		})
	end
end

function furnishers.rug(row, toWorld, y)
	local radius = row.radius or 10
	piece({
		name = "Rug",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, radius * 2, radius * 2),
		color = palette.leaf,
		material = Enum.Material.Fabric,
		collide = false,
		cframe = toWorld(row.x, y + 0.1, row.z) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

function furnishers.lamp(row, toWorld, y)
	local bulb = piece({
		name = "Lantern",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.4, 2.8, 2.4),
		color = palette.lamp,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		cframe = toWorld(row.x, y + SafeZone.FLOOR_HEIGHT - 3.5, row.z),
	})
	piece({
		name = "LanternCord",
		size = Vector3.new(0.3, 3, 0.3),
		color = palette.timberDark,
		collide = false,
		cframe = toWorld(row.x, y + SafeZone.FLOOR_HEIGHT - 0.5, row.z),
	})

	local light = Instance.new("PointLight")
	light.Brightness = 0.1
	light.Range = 8
	light.Color = Color3.fromRGB(255, 220, 180)
	light.Parent = bulb
end

function furnishers.plant(row, toWorld, y)
	piece({
		name = "Pot",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(4, 4.4, 4.4),
		color = Color3.fromRGB(198, 146, 120),
		cframe = toWorld(row.x, y + 2, row.z) * CFrame.Angles(0, 0, math.rad(90)),
	})
	piece({
		name = "Leaves",
		shape = Enum.PartType.Ball,
		size = Vector3.new(7, 8, 7),
		color = palette.leaf,
		material = Enum.Material.Grass,
		collide = false,
		cframe = toWorld(row.x, y + 7, row.z),
	})
end

function furnishers.crate(row, toWorld, y)
	local scale = row.scale or 1
	piece({
		name = "Crate",
		size = Vector3.new(5 * scale, 5 * scale, 5 * scale),
		color = palette.timber,
		material = Enum.Material.WoodPlanks,
		cframe = toWorld(row.x, y + 2.5 * scale, row.z),
	})
end

--[[
	The wall §6's certificates will hang on. Empty for now and labelled as such —
	an obviously-reserved space reads as a promise, where a blank wall reads as
	an unfinished room.
]]
function furnishers.certificateBoard(row, toWorld, y)
	local board = piece({
		name = "CertificateBoard",
		size = Vector3.new(0.4, 4, 8),
		color = palette.timber,
		material = Enum.Material.Wood,
		collide = false,
		cframe = toWorld(row.x, y + 6, row.z),
	})

	UI.sign(board, {
		name = "BoardSign",
		title = "Certificates",
		subtitle = "nothing to hang here yet",
		offset = Vector3.new(-1, 0, 0),
		extent = UDim2.fromScale(8, 3),
		maxDistance = 40,
	})
end

function furnishers.railing(_row, toWorld, y)
	local halfW, halfD = SafeZone.WIDTH / 2, SafeZone.DEPTH / 2
	local height = 5

	local sides = {
		{ size = Vector3.new(SafeZone.WIDTH, height, 1), x = 0, z = -halfD },
		{ size = Vector3.new(SafeZone.WIDTH, height, 1), x = 0, z = halfD },
		{ size = Vector3.new(1, height, SafeZone.DEPTH), x = -halfW, z = 0 },
		{ size = Vector3.new(1, height, SafeZone.DEPTH), x = halfW, z = 0 },
	}

	for index, side in sides do
		piece({
			name = `Railing_{index}`,
			size = side.size,
			color = palette.timber,
			material = Enum.Material.Wood,
			cframe = toWorld(side.x, y + height / 2, side.z),
		})
	end
end

--------------------------------------------------------------------------------
-- Roof
--------------------------------------------------------------------------------

--[[
	A cupola on the roof deck rather than a roof over the whole house: the deck
	is the reward for climbing, so it cannot be under anything. The dome is a
	half-buried ball, which is the cheapest shape that reads as round.
]]
-- selene: allow(unused_variable)
local function buildRoof(toWorld: (number, number, number) -> CFrame, deckY: number)
	local diameter = 22

	piece({
		name = "CupolaDrum",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(9, diameter, diameter),
		color = palette.plaster,
		material = Enum.Material.Sand,
		cframe = toWorld(0, deckY + 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	piece({
		name = "CupolaDome",
		shape = Enum.PartType.Ball,
		size = Vector3.new(diameter + 2, diameter + 2, diameter + 2),
		color = palette.roof,
		material = Enum.Material.Slate,
		cframe = toWorld(0, deckY + 9, 0),
	})
	piece({
		name = "CupolaFinial",
		shape = Enum.PartType.Ball,
		size = Vector3.new(3.4, 3.4, 3.4),
		color = palette.roofDeep,
		collide = false,
		cframe = toWorld(0, deckY + 21, 0),
	})

	-- Eaves: a thin overhang all the way round, so the roofline has a shadow.
	piece({
		name = "Eaves",
		size = Vector3.new(SafeZone.WIDTH + 6, 1.2, SafeZone.DEPTH + 6),
		color = palette.roofDeep,
		material = Enum.Material.Slate,
		collide = false,
		cframe = toWorld(0, deckY - 1.4, 0),
	})
end

--------------------------------------------------------------------------------
-- Garden
--------------------------------------------------------------------------------

local function buildGarden(toWorld: (number, number, number) -> CFrame, rng: Random)
	-- The garden is built during boot, before a background download can finish.
	-- Wait a moment for it rather than always losing that race — see
	-- AssetService.waitFor.
	AssetService.waitFor("naturePack", 4)

	local garden = SafeZone.garden
	local halfX = SafeZone.VOLUME.size.X / 2 - garden.fenceInset
	local frontZ = SafeZone.VOLUME.centreOffset.Z + SafeZone.VOLUME.size.Z / 2 - garden.fenceInset
	local backZ = SafeZone.VOLUME.centreOffset.Z - SafeZone.VOLUME.size.Z / 2 + garden.fenceInset

	-- The path out of the front door: the line the player is meant to walk, and
	-- the thing that makes "step outside" a direction rather than a guess.
	piece({
		name = "Path",
		size = Vector3.new(garden.pathWidth, 0.4, garden.pathLength),
		color = Color3.fromRGB(226, 214, 192),
		material = Enum.Material.Cobblestone,
		collide = false,
		cframe = toWorld(0, 0.2, SafeZone.DEPTH / 2 + garden.pathLength / 2),
	})

	--[[
		A picket fence marking the safe volume. Legibility is the point: the
		boundary is a real rule, so it has to be something the player can see
		rather than a line they discover by being hurt on the far side of it.
		The front is left open where the path crosses it.
	]]
	local function fenceRun(fromX: number, toX: number, z: number, skipGate: boolean)
		local span = toX - fromX
		local count = math.max(1, math.floor(math.abs(span) / garden.postSpacing))
		for index = 0, count do
			local x = fromX + span * (index / count)
			if skipGate and math.abs(x) < garden.pathWidth / 2 + 2 then
				continue
			end
			piece({
				name = "FencePost",
				size = Vector3.new(1, garden.fenceHeight, 1),
				color = palette.timber,
				material = Enum.Material.Wood,
				collide = false,
				cframe = toWorld(x, garden.fenceHeight / 2, z),
			})
		end
	end

	fenceRun(-halfX, halfX, frontZ, true)
	fenceRun(-halfX, halfX, backZ, false)

	local sideCount = math.max(1, math.floor((frontZ - backZ) / garden.postSpacing))
	for _, side in { -1, 1 } do
		for index = 0, sideCount do
			local z = backZ + (frontZ - backZ) * (index / sideCount)
			piece({
				name = "FencePost",
				size = Vector3.new(1, garden.fenceHeight, 1),
				color = palette.timber,
				material = Enum.Material.Wood,
				collide = false,
				cframe = toWorld(side * halfX, garden.fenceHeight / 2, z),
			})
		end
	end

	--[[
		Ground that is clear to plant on: not on the path, not inside the house,
		not on the doorstep a player lands on when they travel to Town.
	]]
	local function isClear(x: number, z: number): boolean
		if math.abs(x) < garden.pathWidth / 2 + 3 then
			return false
		end
		if math.abs(x) < SafeZone.WIDTH / 2 + 2 and math.abs(z) < SafeZone.DEPTH / 2 + 2 then
			return false
		end
		local doorstep = SafeZone.DOORSTEP_OFFSET
		if math.abs(x - doorstep.X) < 8 and math.abs(z - doorstep.Z) < 8 then
			return false
		end
		return true
	end

	--[[
		Plant one thing, preferring a model out of the nature pack and falling
		back to a ball of foliage.

		`match` picks the kind by name. The pack is public and does load, but its
		child names are only known at runtime, so matching is a loose substring
		with the procedural bush behind it -- the garden is the first thing every
		player sees and must never depend on a download.
	]]
	local function plant(x: number, z: number, match: string, targetHeight: number?): boolean
		local model = AssetService.clonePackItem("naturePack", rng, match)
		if model then
			local extents = model:GetExtentsSize()
			if extents.Y > 0.01 and extents.Y < 60 then
				if targetHeight then
					model:ScaleTo(model:GetScale() * (targetHeight / extents.Y))
					extents = model:GetExtentsSize()
				end
				model:PivotTo(
					toWorld(x, extents.Y / 2, z) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
				)
				model.Parent = houseFolder
				return true
			end
			model:Destroy()
		end

		local size = targetHeight or rng:NextNumber(3, 6)
		piece({
			name = "GardenBush",
			shape = Enum.PartType.Ball,
			size = Vector3.new(size, size * 0.8, size),
			color = palette.leaf,
			material = Enum.Material.Grass,
			collide = false,
			cframe = toWorld(x, size * 0.3, z),
		})
		return false
	end

	--[[
		Two trees flanking the gate, so the way out is framed rather than a gap
		in a fence line. Placed rather than scattered: this is the shot every
		player sees on their first frame outdoors.
	]]
	for _, side in { -1, 1 } do
		plant(side * (garden.pathWidth / 2 + 9), frontZ - 7, "tree", 22)
	end

	-- Flower beds hugging both sides of the path, which is what makes the path
	-- read as tended rather than as a strip of different-coloured ground.
	local bedZStart = SafeZone.DEPTH / 2 + 3
	local bedZEnd = SafeZone.DEPTH / 2 + garden.pathLength - 2
	for _, side in { -1, 1 } do
		local steps = 6
		for index = 0, steps do
			local z = bedZStart + (bedZEnd - bedZStart) * (index / steps)
			local x = side * (garden.pathWidth / 2 + 2.5)
			plant(x, z, "flower", rng:NextNumber(2.2, 3.4))
		end
	end

	-- Lanterns down the path. §2: the cottage is the one place that is always
	-- welcoming, and light is the cheapest way to say so.
	for _, side in { -1, 1 } do
		for _, z in { SafeZone.DEPTH / 2 + 8, SafeZone.DEPTH / 2 + 24 } do
			local x = side * (garden.pathWidth / 2 + 5)
			piece({
				name = "GardenLanternPost",
				size = Vector3.new(0.8, 7, 0.8),
				color = palette.timberDark,
				material = Enum.Material.Wood,
				collide = false,
				cframe = toWorld(x, 3.5, z),
			})
			local head = piece({
				name = "GardenLantern",
				shape = Enum.PartType.Ball,
				size = Vector3.new(2.4, 2.4, 2.4),
				color = Color3.fromRGB(255, 226, 150),
				material = Enum.Material.Neon,
				collide = false,
				cframe = toWorld(x, 7.6, z),
			})
			local glow = Instance.new("PointLight")
			glow.Brightness = 1.5
			glow.Range = 24
			glow.Color = Color3.fromRGB(255, 220, 160)
			glow.Parent = head
		end
	end

	-- The rest of the plot: a mix of bushes and grass tufts, path kept clear.
	for _ = 1, garden.plantCount do
		local x = rng:NextNumber(-halfX + 4, halfX - 4)
		local z = rng:NextNumber(backZ + 4, frontZ - 4)
		if not isClear(x, z) then
			continue
		end
		local kind = if rng:NextNumber() > 0.45 then "bush" else "grass"
		plant(x, z, kind, rng:NextNumber(3, 6))
	end
end

--------------------------------------------------------------------------------
-- Assembly
--------------------------------------------------------------------------------

local function buildCottage(origin: Vector3, rng: Random)
	local function toWorld(x: number, y: number, z: number): CFrame
		return CFrame.new(origin + Vector3.new(x, y, z))
	end

	local enclosedFloors = SafeZone.FLOORS - 1 -- the top level is an open deck
	local storey = SafeZone.FLOOR_HEIGHT + SafeZone.FLOOR_SLAB
	local halfW, halfD = SafeZone.WIDTH / 2, SafeZone.DEPTH / 2

	-- Ground slab, solid: nothing needs a hole down into the plaza.
	slabWithHole(toWorld, SafeZone.FLOOR_SLAB, nil)

	local holes: { any } = {}
	for floor = 0, enclosedFloors - 1 do
		local base = floor * storey
		local walkY = base + SafeZone.FLOOR_SLAB

		-- Stairs up to the next level, alternating direction each storey.
		holes[floor + 1] = buildStairs(toWorld, walkY, storey, if floor % 2 == 0 then 1 else -1)

		local isGround = floor == 0
		local wallCentreY = base + storey / 2

		-- Front (+Z): the door downstairs, a wide window upstairs.
		wallFace(toWorld, {
			name = `WallFront_{floor}`,
			width = SafeZone.WIDTH,
			height = storey,
			thickness = SafeZone.WALL,
			x = 0,
			y = wallCentreY,
			z = halfD,
			sideways = false,
			opening = if isGround
				then {
					x = 0,
					y = walkY - wallCentreY + SafeZone.DOOR_HEIGHT / 2,
					width = SafeZone.DOOR_WIDTH,
					height = SafeZone.DOOR_HEIGHT,
				}
				else { x = 0, y = 1, width = 18, height = 9 },
		})

		-- Back (-Z): solid, where the stairs run up inside.
		wallFace(toWorld, {
			name = `WallBack_{floor}`,
			width = SafeZone.WIDTH,
			height = storey,
			thickness = SafeZone.WALL,
			x = 0,
			y = wallCentreY,
			z = -halfD,
			sideways = false,
			opening = nil,
		})

		-- Sides: a round-ish window each, on both storeys.
		for _, side in { -1, 1 } do
			wallFace(toWorld, {
				name = `WallSide_{floor}_{side}`,
				width = SafeZone.DEPTH,
				height = storey,
				thickness = SafeZone.WALL,
				x = side * halfW,
				y = wallCentreY,
				z = 0,
				sideways = true,
				opening = {
					x = if isGround then 8 else 0,
					y = 1,
					width = SafeZone.WINDOW_RADIUS * 2,
					height = SafeZone.WINDOW_RADIUS * 2,
				},
			})
		end
	end

	-- Upper floors, each with the stairwell from the storey below punched out.
	for floor = 1, enclosedFloors do
		slabWithHole(toWorld, floor * storey + SafeZone.FLOOR_SLAB, holes[floor])
	end

	local deckY = enclosedFloors * storey + SafeZone.FLOOR_SLAB

	--------------------------------------------------------------------------
	-- Glazing
	--------------------------------------------------------------------------

	-- Loft window: a disc of glass in the opening, with a ring in front of it.
	piece({
		name = "LoftGlass",
		size = Vector3.new(18, 9, 0.4),
		color = palette.glass,
		material = Enum.Material.Glass,
		transparency = 0.55,
		collide = false,
		cframe = toWorld(0, storey + storey / 2 + 1, halfD),
	})
	for _, side in { -1, 1 } do
		piece({
			name = "LoftMullion",
			size = Vector3.new(0.8, 9, 1),
			color = palette.timberDark,
			material = Enum.Material.Wood,
			collide = false,
			cframe = toWorld(side * 4.5, storey + storey / 2 + 1, halfD),
		})
	end

	for floor = 0, enclosedFloors - 1 do
		local base = floor * storey
		for _, side in { -1, 1 } do
			piece({
				name = "SideGlass",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.4, SafeZone.WINDOW_RADIUS * 2, SafeZone.WINDOW_RADIUS * 2),
				color = palette.glass,
				material = Enum.Material.Glass,
				transparency = 0.5,
				collide = false,
				cframe = toWorld(side * halfW, base + storey / 2 + 1, if floor == 0 then 8 else 0),
			})
		end
	end

	-- Door frame and a door leaf propped open. Not a working door: a closing one
	-- would eventually shut somebody out of their own safe zone.
	piece({
		name = "DoorFrame",
		size = Vector3.new(SafeZone.DOOR_WIDTH + 2.4, SafeZone.DOOR_HEIGHT + 1.6, 1),
		color = palette.timberDark,
		material = Enum.Material.Wood,
		collide = false,
		cframe = toWorld(0, SafeZone.FLOOR_SLAB + SafeZone.DOOR_HEIGHT / 2, halfD + 0.3),
	})
	piece({
		name = "DoorLeaf",
		size = Vector3.new(0.6, SafeZone.DOOR_HEIGHT, SafeZone.DOOR_WIDTH * 0.9),
		color = palette.timber,
		material = Enum.Material.Wood,
		collide = false,
		cframe = toWorld(
			-SafeZone.DOOR_WIDTH / 2 - 0.5,
			SafeZone.FLOOR_SLAB + SafeZone.DOOR_HEIGHT / 2,
			halfD + SafeZone.DOOR_WIDTH * 0.45
		),
	})

	buildRoof(toWorld, deckY)

	--------------------------------------------------------------------------
	-- Furniture
	--------------------------------------------------------------------------

	for _, row in SafeZone.furniture do
		local furnish = furnishers[row.kind]
		if not furnish then
			warn(`[SafeZoneService] no furnisher for "{row.kind}"`)
			continue
		end
		local ok, err = pcall(furnish, row, toWorld, row.floor * storey + SafeZone.FLOOR_SLAB)
		if not ok then
			warn(`[SafeZoneService] furnishing "{row.kind}" failed: {err}`)
		end
	end

	buildGarden(toWorld, rng)

	-- A nameplate over the door, so the building says what it is.
	local plate = piece({
		name = "HomeSign",
		size = Vector3.new(14, 3, 0.6),
		color = palette.timberDark,
		material = Enum.Material.Wood,
		collide = false,
		cframe = toWorld(0, SafeZone.FLOOR_SLAB + SafeZone.DOOR_HEIGHT + 3.5, halfD + 0.4),
	})
	UI.sign(plate, {
		name = "HomeSignLabel",
		title = "Home",
		subtitle = "nothing can reach you here",
		offset = Vector3.new(0, 3, 0),
		extent = UDim2.fromScale(16, 5),
		maxDistance = 220,
	})
end

--------------------------------------------------------------------------------
-- Protection
--------------------------------------------------------------------------------

function SafeZoneService.containsPosition(position: Vector3): boolean
	local delta = position - volumeCentre
	return math.abs(delta.X) <= volumeHalf.X and math.abs(delta.Y) <= volumeHalf.Y and math.abs(delta.Z) <= volumeHalf.Z
end

--[[
	THE predicate. Any system that is about to reduce a player's health, stagger
	them, or otherwise act on them against their will asks this first.

	It is deliberately a plain query rather than an event: a caller cannot forget
	to unsubscribe, and it is correct the instant it is called rather than as of
	the last tick.
]]
function SafeZoneService.isProtected(player: Player): boolean
	return inside[player] == true
end

local function setForceField(character: Model, enabled: boolean)
	local existing = character:FindFirstChildOfClass("ForceField")
	if enabled then
		if not existing then
			local field = Instance.new("ForceField")
			-- The sparkle bubble would sit over the whole cottage interior and
			-- read as a hazard warning, which is the opposite of the intent.
			field.Visible = false
			field.Parent = character
		end
	elseif existing then
		existing:Destroy()
	end
end

--[[
	A ForceField stops Humanoid:TakeDamage. It does NOT stop a direct write to
	Humanoid.Health, which is how a lot of Roblox code actually deals damage. So
	while a player is inside, any drop in health is put straight back.
]]
local function setHealthGuard(player: Player, humanoid: Humanoid?, enabled: boolean)
	local existing = healthGuards[player]
	if existing then
		existing:Disconnect()
		healthGuards[player] = nil
	end
	if not enabled or not humanoid then
		return
	end

	healthGuards[player] = humanoid.HealthChanged:Connect(function(health)
		if health < humanoid.MaxHealth and SafeZoneService.isProtected(player) then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

local function setInside(player: Player, isInside: boolean)
	if inside[player] == isInside then
		return
	end
	inside[player] = isInside

	local character = player.Character
	if character then
		setForceField(character, isInside)
		setHealthGuard(player, character:FindFirstChildOfClass("Humanoid"), isInside)
	end

	player:SetAttribute("InSafeZone", isInside)
	if changedRemote then
		changedRemote:FireClient(player, isInside)
	end
end

local function track()
	local accumulator = 0

	RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0

		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			setInside(player, SafeZoneService.containsPosition(root.Position))
		end
	end)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function SafeZoneService.getSpawnCFrame(): CFrame
	local town = Areas.BY_ID[Areas.STARTING_AREA]
	return CFrame.new(town.origin + Vector3.new(0, Constants.WORLD.PLATFORM_TOP, 0) + SafeZone.SPAWN_OFFSET)
end

-- Where fast travel to Town lands you: outside your own front door, facing the
-- districts, rather than inside the house looking at a wall.
function SafeZoneService.getDoorstepCFrame(): CFrame
	local town = Areas.BY_ID[Areas.STARTING_AREA]
	local position = town.origin + Vector3.new(0, Constants.WORLD.PLATFORM_TOP, 0) + SafeZone.DOORSTEP_OFFSET
	return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
end

function SafeZoneService.init()
	changedRemote = Remotes.event("SafeZone", "Changed")

	local existing = Workspace:FindFirstChild("SafeZone")
	if existing then
		existing:Destroy()
	end

	houseFolder = Instance.new("Folder")
	houseFolder.Name = "SafeZone"
	houseFolder.Parent = Workspace

	local town = Areas.BY_ID[Areas.STARTING_AREA]
	local origin = town.origin + Vector3.new(0, Constants.WORLD.PLATFORM_TOP, 0)

	volumeCentre = origin + SafeZone.VOLUME.centreOffset
	volumeHalf = SafeZone.VOLUME.size / 2

	buildCottage(origin, Random.new(20260726))

	--[[
		The spawn. This replaces the bare SpawnLocation WorldService used to drop
		on the plaza: the first thing a player sees is the inside of their own
		house, and the first thing they do is walk out of it.
	]]
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HomeSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = SafeZoneService.getSpawnCFrame()
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = houseFolder

	-- Arriving in Town by fast travel puts you on the doorstep, not indoors.
	WorldService.setSpawnCFrame(Areas.STARTING_AREA, SafeZoneService.getDoorstepCFrame())

	Players.PlayerRemoving:Connect(function(player)
		local guard = healthGuards[player]
		if guard then
			guard:Disconnect()
		end
		healthGuards[player] = nil
		inside[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			-- Force a re-evaluation: the flag survives the respawn, the
			-- ForceField and the health guard do not.
			inside[player] = nil
			task.defer(function()
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					setInside(player, SafeZoneService.containsPosition(root.Position))
				end
			end)
		end)
	end)

	track()
end

return SafeZoneService

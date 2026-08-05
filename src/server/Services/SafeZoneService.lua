local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Assets = require(Shared.Modules.Config.Assets)
local Remotes = require(Shared.Modules.Remotes)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local UI = require(Shared.UI)
local AssetService = require(script.Parent.AssetService)
local WeedService = require(script.Parent.WeedService)
local WorldService = require(script.Parent.WorldService)
local SafeZoneService = {}
local CHECK_INTERVAL = 0.2
local palette = SafeZone.palette
local dome = SafeZone.DOME
local houseFolder: Folder
local origin: Vector3
local volumeCentre: Vector3
local volumeHalf: Vector3
local inside: { [Player]: boolean } = {}
local healthGuards: { [Player]: RBXScriptConnection } = {}
local changedRemote: RemoteEvent?

local function toWorld(x: number, y: number, z: number): CFrame
	return CFrame.new(origin + Vector3.new(x, y, z))
end

local function piece(config: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Name = config.name or "Piece"
	part.Anchored = true
	part.CanCollide = config.collide ~= false
	part.CanQuery = config.query ~= false
	part.CanTouch = false
	part.Size = config.size
	part.Shape = config.shape or Enum.PartType.Block
	part.Color = config.color or palette.shell
	part.Material = config.material or Enum.Material.SmoothPlastic
	part.Transparency = config.transparency or 0
	part.CastShadow = config.castShadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = config.cframe
	part.Parent = config.parent or houseFolder
	return part
end

local function disc(config: { [string]: any }): Part
	config.shape = Enum.PartType.Cylinder
	config.size = Vector3.new(config.thickness, config.diameter, config.diameter)
	config.cframe = config.cframe * CFrame.Angles(0, 0, math.rad(90))
	return piece(config)
end

local function parameterAt(y: number): number
	return math.asin(math.clamp(y / dome.height, 0, 1)) / (math.pi / 2)
end

local function leanAt(t: number): number
	local step = 0.004
	local r0, y0 = SafeZone.profile(math.max(t - step, 0))
	local r1, y1 = SafeZone.profile(math.min(t + step, 1))
	return math.atan2(r0 - r1, math.max(y1 - y0, 1e-5))
end

local function surfaceFrame(azimuth: number, y: number): CFrame
	local t = parameterAt(y)
	local radius = select(1, SafeZone.profile(t))
	return CFrame.new(origin)
		* CFrame.Angles(0, azimuth, 0)
		* CFrame.new(0, y, radius)
		* CFrame.Angles(-leanAt(t), 0, 0)
end

local function azimuthDelta(a: number, b: number): number
	return (a - b + 540) % 360 - 180
end

local function openingAt(azimuth: number, yLow: number, yHigh: number)
	local midY = (yLow + yHigh) / 2

	for _, opening in SafeZone.OPENINGS do
		local delta = azimuthDelta(azimuth, opening.azimuth)

		if opening.kind == "round" then
			local centreY = (opening.bottom + opening.top) / 2
			local halfY = (opening.top - opening.bottom) / 2
			local u = delta / opening.halfAngle
			local v = (midY - centreY) / halfY
			if u * u + v * v <= 1 then
				return opening
			end
		elseif midY >= opening.bottom and midY <= opening.top and math.abs(delta) <= opening.halfAngle then
			return opening
		end
	end
	return nil
end

local function buildShell()
	for ring = 0, dome.rings - 1 do
		local t0, t1 = ring / dome.rings, (ring + 1) / dome.rings
		local r0, y0 = SafeZone.profile(t0)
		local r1, y1 = SafeZone.profile(t1)
		local midRadius = (r0 + r1) / 2
		local midHeight = (y0 + y1) / 2
		local span = math.sqrt((r1 - r0) ^ 2 + (y1 - y0) ^ 2)
		local lean = math.atan2(r0 - r1, math.max(y1 - y0, 1e-5))
		local count = math.max(8, math.ceil(2 * math.pi * midRadius / dome.segmentArc))
		local width = (2 * math.pi * midRadius / count) * dome.overlap
		local phase = if ring % 2 == 1 then 0.5 else 0

		for index = 0, count - 1 do
			local turn = (index + phase) / count
			if openingAt(turn * 360, y0, y1) then
				continue
			end

			piece({
				name = `Shell_{ring}_{index}`,
				size = Vector3.new(width, span * dome.overlap, dome.wall),
				color = if ring % 2 == 0 then palette.shell else palette.shellShade,
				material = Enum.Material.SmoothPlastic,
				cframe = CFrame.new(origin)
					* CFrame.Angles(0, turn * math.pi * 2, 0)
					* CFrame.new(0, midHeight, midRadius)
					* CFrame.Angles(-lean, 0, 0),
			})
		end
	end
end

local function horizontalSlack(y: number): number
	local radius = select(1, SafeZone.profile(parameterAt(y)))
	local count = math.max(8, math.ceil(2 * math.pi * radius / dome.segmentArc))
	return math.pi * radius / count
end

local function verticalSlack(): number
	return dome.height / dome.rings / 2
end

local function glazeRound(opening: { [string]: any })
	local centreY = (opening.bottom + opening.top) / 2
	local azimuth = math.rad(opening.azimuth)
	local frame = surfaceFrame(azimuth, centreY)
	local radius = select(1, SafeZone.profile(parameterAt(centreY)))
	local halfWidth = radius * math.sin(math.rad(opening.halfAngle)) + horizontalSlack(centreY)
	local halfHeight = (opening.top - opening.bottom) / 2 + verticalSlack()

	disc({
		name = `{opening.name}Glass`,
		thickness = 0.4,
		diameter = math.max(halfWidth, halfHeight) * 2.1,
		color = palette.glass,
		material = Enum.Material.Glass,
		transparency = 0.55,
		collide = false,
		castShadow = false,
		cframe = frame * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(-90)),
	})

	local blocks = 30
	for index = 0, blocks - 1 do
		local angle = (index / blocks) * math.pi * 2
		local u, v = math.cos(angle) * halfWidth, math.sin(angle) * halfHeight
		local tangent = math.atan2(halfHeight * math.cos(angle), -halfWidth * math.sin(angle))
		local arc = 2 * math.pi * math.max(halfWidth, halfHeight) / blocks

		piece({
			name = `{opening.name}Rim_{index}`,
			size = Vector3.new(arc * 1.6, 1.6, dome.wall + 1.6),
			color = palette.trim,
			collide = false,
			cframe = frame * CFrame.new(u, v, 0) * CFrame.Angles(0, 0, tangent),
		})
	end
end

local function frameDoor(opening: { [string]: any })
	local steps = 18
	local rise = (opening.top - opening.bottom) / steps

	for _, side in { -1, 1 } do
		local azimuth = math.rad(opening.azimuth + side * opening.halfAngle)
		for index = 0, steps - 1 do
			local y = opening.bottom + rise * index + rise / 2
			piece({
				name = `DoorJamb_{side}_{index}`,
				size = Vector3.new(horizontalSlack(y) * 2.2, rise * 1.35, dome.wall + 1.6),
				color = palette.trim,
				collide = false,
				cframe = surfaceFrame(azimuth, y),
			})
		end
	end

	local headY = opening.top + verticalSlack() * 0.6
	local headSpan = opening.halfAngle + math.deg(horizontalSlack(headY) / dome.radius)

	for index = 0, steps do
		local azimuth = math.rad(opening.azimuth - headSpan + (headSpan * 2) * (index / steps))
		local radius = select(1, SafeZone.profile(parameterAt(headY)))
		local arc = 2 * radius * math.sin(math.rad(headSpan)) / steps

		piece({
			name = `DoorHead_{index}`,
			size = Vector3.new(arc * 1.7, verticalSlack() * 2.4, dome.wall + 1.6),
			color = palette.trim,
			collide = false,
			cframe = surfaceFrame(azimuth, headY),
		})
	end

	piece({
		name = "Threshold",
		size = Vector3.new(18, 0.6, 6),
		color = palette.stone,
		material = Enum.Material.Concrete,
		cframe = toWorld(0, SafeZone.FLOOR_Y - 0.3, dome.radius - 1),
	})
end

local DOOR_OPEN_ANGLE = math.rad(100)
local DOOR_TRIGGER_RANGE = 12
local DOOR_SWING_SPEED = 2.8

local function buildStrawberryDoor(opening: { [string]: any })
	local model = AssetService.clone("strawberryDoor")
	if not model then
		warn("[SafeZoneService] strawberryDoor asset unavailable - the doorway stays bare")
		return
	end
	model.Name = "StrawberryDoor"

	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("Camera")
			or descendant:IsA("Folder")
			or descendant:IsA("StringValue")
			or descendant:IsA("NumberValue")
		then
			descendant:Destroy()
		end
	end

	local sill = SafeZone.FLOOR_Y
	local head = opening.top - verticalSlack() * 0.6
	local doorHeight = head - sill
	local _, extents = model:GetBoundingBox()
	local axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	local spans = { extents.X, extents.Y, extents.Z }
	local tallest, thinnest = 1, 1
	for index = 2, 3 do
		if spans[index] > spans[tallest] then
			tallest = index
		end
		if spans[index] < spans[thinnest] then
			thinnest = index
		end
	end

	local up = axes[tallest]
	local through = axes[thinnest]
	local across = up:Cross(through)
	local scale = doorHeight / spans[tallest]
	model:ScaleTo(scale)
	local doorWidth = math.abs(across:Dot(extents)) * scale
	local upright = CFrame.fromMatrix(Vector3.zero, across, up, through):Inverse()

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	local centreY = sill + doorHeight / 2
	local frame = surfaceFrame(math.rad(opening.azimuth), centreY)
	model:PivotTo(frame * upright)
	local boxCFrame = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (frame.Position - boxCFrame.Position))

	local hinge = frame * CFrame.new(doorWidth / 2, 0, 0)
	local rel = frame:Inverse() * model:GetPivot()
	local threshold = surfaceFrame(math.rad(opening.azimuth), sill)

	model.Parent = houseFolder

	local angle = 0
	local side = -1
	RunService.Heartbeat:Connect(function(delta)
		local nearest: number? = nil
		local nearestSide = side
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local offset = threshold:PointToObjectSpace(root.Position)
				local distance = offset.Magnitude
				if distance <= DOOR_TRIGGER_RANGE and (nearest == nil or distance < nearest) then
					nearest = distance
					nearestSide = if offset.Z >= 0 then -1 else 1
				end
			end
		end

		if nearest and math.abs(angle) < 0.02 then
			side = nearestSide
		end

		local target = if nearest then DOOR_OPEN_ANGLE * side else 0
		local step = math.clamp(target - angle, -DOOR_SWING_SPEED * delta, DOOR_SWING_SPEED * delta)
		if step ~= 0 then
			angle += step
			model:PivotTo(hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse() * frame * rel)
		end
	end)
end

local function buildFloor()
	disc({
		name = "Plinth",
		thickness = 1.6,
		diameter = (dome.radius + 2.2) * 2,
		color = palette.stone,
		material = Enum.Material.Concrete,
		cframe = toWorld(0, 0.2, 0),
	})

	disc({
		name = "Floor",
		thickness = 1.5,
		diameter = (dome.radius - dome.wall + 1) * 2,
		color = palette.floor,
		material = Enum.Material.WoodPlanks,
		cframe = toWorld(0, SafeZone.FLOOR_Y - 0.75, 0),
	})

	disc({
		name = "Rug",
		thickness = 0.2,
		diameter = SafeZone.RUG.diameter,
		color = palette.mint,
		material = Enum.Material.Fabric,
		collide = false,
		castShadow = false,
		cframe = toWorld(0, SafeZone.FLOOR_Y + 0.1, SafeZone.RUG.z),
	})
end

local function buildLoft(): number
	local loft = SafeZone.LOFT
	local radius = SafeZone.interiorRadiusAt(loft.y) - loft.inset
	local deckY = loft.y

	for index = 0, loft.strips - 1 do
		local x0 = -radius + 2 * radius * (index / loft.strips)
		local x1 = -radius + 2 * radius * ((index + 1) / loft.strips)
		local outer = math.max(math.abs(x0), math.abs(x1))
		local back = -math.sqrt(math.max(radius * radius - outer * outer, 0))
		local depth = loft.frontZ - back

		if depth < 1 then
			continue
		end

		piece({
			name = `LoftDeck_{index}`,
			size = Vector3.new(x1 - x0, loft.slab, depth),
			color = palette.floor,
			material = Enum.Material.WoodPlanks,
			cframe = toWorld((x0 + x1) / 2, deckY - loft.slab / 2, back + depth / 2),
		})
	end

	local railHalf = math.sqrt(math.max(radius * radius - (math.abs(loft.frontZ) + 1) ^ 2, 0))

	piece({
		name = "LoftRail",
		size = Vector3.new(railHalf * 2, 0.7, 0.7),
		color = palette.timber,
		material = Enum.Material.Wood,
		cframe = toWorld(0, deckY + loft.railHeight, loft.frontZ),
	})

	local posts = 9
	for index = 0, posts do
		piece({
			name = `LoftPost_{index}`,
			size = Vector3.new(0.5, loft.railHeight, 0.5),
			color = palette.timber,
			material = Enum.Material.Wood,
			collide = false,
			cframe = toWorld(-railHalf + (railHalf * 2) * (index / posts), deckY + loft.railHeight / 2, loft.frontZ),
		})
	end

	return deckY
end

local function buildStair(deckY: number)
	local stair = SafeZone.STAIR

	for index = 1, stair.steps do
		local fraction = index / stair.steps
		local azimuth = math.rad(stair.fromAzimuth + stair.sweep * fraction)
		local top = deckY * fraction

		piece({
			name = `Step_{index}`,
			size = Vector3.new(stair.length, 1.7, stair.width),
			color = palette.timber,
			material = Enum.Material.Wood,
			cframe = CFrame.new(origin)
				* CFrame.Angles(0, azimuth, 0)
				* CFrame.new(0, top - 0.85 + SafeZone.FLOOR_Y, stair.radius),
		})
	end
end

local function buildChimney()
	local frame = surfaceFrame(math.rad(150), dome.height * 0.82)

	local stack = piece({
		name = "Chimney",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(7, 4.6, 4.6),
		color = palette.shellShade,
		cframe = frame * CFrame.new(0, 0, 2.4) * CFrame.Angles(0, math.rad(90), 0),
	})
	piece({
		name = "ChimneyCap",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.2, 6, 6),
		color = palette.trim,
		collide = false,
		cframe = frame * CFrame.new(0, 0, 6) * CFrame.Angles(0, math.rad(90), 0),
	})

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(252, 250, 246))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5),
		NumberSequenceKeypoint.new(1, 9),
	})
	smoke.Rate = 5
	smoke.Lifetime = NumberRange.new(3.5, 5)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.SpreadAngle = Vector2.new(9, 9)
	smoke.Acceleration = Vector3.new(1.5, 2.5, 0)
	smoke.LightEmission = 0.35
	smoke.Parent = stack
end

local function buildCertificateBoard()
	local frame = surfaceFrame(math.rad(-140), 9)

	local board = piece({
		name = "CertificateBoard",
		size = Vector3.new(16, 9, 0.6),
		color = palette.timber,
		material = Enum.Material.Wood,
		collide = false,
		cframe = frame * CFrame.new(0, 0, -0.4),
	})

	UI.sign(board, {
		name = "BoardSign",
		title = "Certificates",
		subtitle = "nothing to hang here yet",
		offset = Vector3.new(0, 7, 0),
		extent = UDim2.fromScale(9, 3.5),
		maxDistance = 60,
	})
end

local function buildFuton(deckY: number)
	local loft = SafeZone.LOFT
	local deckRadius = SafeZone.interiorRadiusAt(loft.y) - loft.inset
	local width, depth = 12, 15
	local x = -7
	local usable = deckRadius - 1.5
	local back = -math.sqrt(math.max(usable * usable - (math.abs(x) + width / 2) ^ 2, 0))
	local z = math.min(back + depth / 2, loft.frontZ - depth / 2)

	piece({
		name = "Futon",
		size = Vector3.new(width, 1.4, depth),
		color = palette.fabric,
		material = Enum.Material.Fabric,
		cframe = toWorld(x, deckY + 0.7, z),
	})
	piece({
		name = "Duvet",
		size = Vector3.new(width + 0.6, 1.8, depth * 0.6),
		color = palette.linen,
		material = Enum.Material.Fabric,
		collide = false,
		cframe = toWorld(x, deckY + 1.9, z + depth * 0.2),
	})
	piece({
		name = "Pillow",
		size = Vector3.new(width * 0.62, 2, 4.2),
		color = palette.linen,
		material = Enum.Material.Fabric,
		collide = false,
		cframe = toWorld(x, deckY + 2.2, z - depth / 2 + 2.6),
	})
end

local function buildLamps(deckY: number)
	for index, spot in SafeZone.LAMPS do
		local y = if spot.on == "loft" then deckY + spot.y else spot.y
		local bulb = piece({
			name = `Lantern_{index}`,
			shape = Enum.PartType.Ball,
			size = Vector3.new(spot.size, spot.size, spot.size),
			color = palette.honey,
			material = Enum.Material.Neon,
			collide = false,
			castShadow = false,
			cframe = toWorld(spot.x, y, spot.z),
		})
		piece({
			name = `LanternCord_{index}`,
			size = Vector3.new(0.2, 6, 0.2),
			color = palette.timberDark,
			collide = false,
			castShadow = false,
			cframe = toWorld(spot.x, y + 4.8, spot.z),
		})

		local light = Instance.new("PointLight")
		light.Brightness = spot.brightness
		light.Range = spot.range
		light.Color = Color3.fromRGB(255, 226, 186)
		light.Shadows = false
		light.Parent = bulb
	end
end

local function worldHeight(cframe: CFrame, size: Vector3): number
	return math.abs(cframe.XVector.Y) * size.X
		+ math.abs(cframe.YVector.Y) * size.Y
		+ math.abs(cframe.ZVector.Y) * size.Z
end

local function place(row: SafeZone.Placement, baseY: number): Model?
	local model = AssetService.clone(row.asset)
	if not model then
		return nil
	end

	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	if largest > 0.01 then
		model:ScaleTo(model:GetScale() * (row.fit / largest))
		extents *= row.fit / largest
	end

	local target = toWorld(row.x, 0, row.z)
		* CFrame.Angles(0, math.rad(row.yaw or 0), 0)
		* CFrame.Angles(math.rad(row.pitch or 0), 0, math.rad(row.roll or 0))
	model:PivotTo(target)

	local landedCFrame, landedSize = model:GetBoundingBox()
	local height = worldHeight(landedCFrame, landedSize)
	local sink = row.sink or 0
	if row.asset == "grassPatch" then
		sink = height / 2
	end
	local wanted = origin + Vector3.new(row.x, baseY + (row.y or 0) + height / 2 - sink, row.z)
	model:PivotTo(model:GetPivot() + (wanted - landedCFrame.Position))

	if row.name then
		model.Name = row.name
	end

	model:SetAttribute("PlotSize", extents)
	model:SetAttribute("PlotCentre", wanted)
	model:SetAttribute("PlotYaw", row.yaw or 0)

	model.Parent = houseFolder
	return model
end

local function drape(cloth: Model, table_: Model, groundY: number)
	local sheet: BasePart? = nil
	local best = 0
	for _, descendant in cloth:GetDescendants() do
		if descendant:IsA("BasePart") then
			local area = descendant.Size.X * descendant.Size.Z
			if area > best then
				sheet, best = descendant, area
			end
		end
	end
	if not sheet then
		return
	end

	local clothCFrame, clothSize = cloth:GetBoundingBox()
	local tableCFrame, tableSize = table_:GetBoundingBox()
	local hemTop = clothCFrame.Position.Y - worldHeight(clothCFrame, clothSize) / 2
	local hemBottom = math.max(groundY + 0.1, tableCFrame.Position.Y - worldHeight(tableCFrame, tableSize) / 2 + 0.1)
	local drop = hemTop - hemBottom
	if drop <= 0.2 then
		return
	end

	local look = clothCFrame.LookVector
	local frame = CFrame.new(clothCFrame.Position.X, hemBottom + drop / 2, clothCFrame.Position.Z)
		* CFrame.Angles(0, math.atan2(look.X, look.Z), 0)

	local thickness = math.max(sheet.Size.Y, 0.16)

	local sides = {
		{ size = Vector3.new(clothSize.X, drop, thickness), offset = Vector3.new(0, 0, clothSize.Z / 2) },
		{ size = Vector3.new(clothSize.X, drop, thickness), offset = Vector3.new(0, 0, -clothSize.Z / 2) },
		{ size = Vector3.new(thickness, drop, clothSize.Z), offset = Vector3.new(clothSize.X / 2, 0, 0) },
		{ size = Vector3.new(thickness, drop, clothSize.Z), offset = Vector3.new(-clothSize.X / 2, 0, 0) },
	}

	for index, side in sides do
		local panel = Instance.new("Part")
		panel.Name = `ClothSkirt{index}`
		panel.Size = side.size
		panel.CFrame = frame * CFrame.new(side.offset)
		panel.Color = sheet.Color
		panel.Material = sheet.Material
		panel.Anchored = true
		panel.CanCollide = false
		panel.CanQuery = false
		panel.CanTouch = false
		panel.TopSurface = Enum.SurfaceType.Smooth
		panel.BottomSurface = Enum.SurfaceType.Smooth
		panel.Parent = cloth
	end
end

export type Footprint = { x: number, z: number, halfX: number, halfZ: number }

local function footprintOf(row: SafeZone.Placement, model: Model): Footprint
	local _, size = model:GetBoundingBox()
	local yaw = math.rad(row.yaw or 0)
	local cos, sin = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
	return {
		x = row.x,
		z = row.z,
		halfX = (size.X * cos + size.Z * sin) / 2,
		halfZ = (size.X * sin + size.Z * cos) / 2,
	}
end

local function placeAll(rows: { SafeZone.Placement }, groundY: number, deckY: number): { Footprint }
	local named: { [string]: Model } = {}
	local footprints: { Footprint } = {}

	for _, row in rows do
		local baseY = if row.on == "loft" then deckY else groundY
		local ok, result = pcall(place, row, baseY)
		if not ok then
			warn(`[SafeZoneService] placing "{row.asset}" failed: {result}`)
		elseif result == nil then
			warn(`[SafeZoneService] asset "{row.asset}" did not load; nothing placed`)
		else
			if row.name then
				named[row.name] = result
			end
			if row.drapeOver then
				local over = named[row.drapeOver]
				if over then
					drape(result, over, baseY + origin.Y)
				else
					warn(`[SafeZoneService] "{row.asset}" drapes over "{row.drapeOver}", which is not placed yet`)
				end
			end
			local spec = Assets.get(row.asset)
			if spec and spec.collide ~= false and not spec.canopy then
				table.insert(footprints, footprintOf(row, result))
			end
		end
	end

	return footprints
end

local function buildFence()
	local garden = SafeZone.garden
	local halfX = SafeZone.VOLUME.size.X / 2 - garden.fenceInset
	local frontZ = SafeZone.VOLUME.centreOffset.Z + SafeZone.VOLUME.size.Z / 2 - garden.fenceInset
	local backZ = SafeZone.VOLUME.centreOffset.Z - SafeZone.VOLUME.size.Z / 2 + garden.fenceInset

	local function post(x: number, z: number)
		piece({
			name = "FencePost",
			size = Vector3.new(1.1, garden.fenceHeight, 1.1),
			color = palette.linen,
			cframe = toWorld(x, garden.fenceHeight / 2, z),
		})
		piece({
			name = "FenceCap",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.5, 1.5, 1.5),
			color = palette.trim,
			collide = false,
			castShadow = false,
			cframe = toWorld(x, garden.fenceHeight, z),
		})
	end

	local function geometry(run: { [string]: any })
		local from = Vector2.new(run.fromX, run.fromZ)
		local span = Vector2.new(run.toX, run.toZ) - from
		local length = span.Magnitude
		local direction = span.Unit
		return from, direction, length, (Vector2.new(run.gateX, run.gateZ) - from):Dot(direction)
	end

	local function rails(run: { [string]: any })
		local from, direction, length, gateAt = geometry(run)
		local yaw = math.atan2(direction.X, direction.Y)

		local halves = {
			{ start = 0, finish = gateAt - garden.gateGap },
			{ start = gateAt + garden.gateGap, finish = length },
		}

		for _, height in { garden.fenceHeight * 0.35, garden.fenceHeight * 0.72 } do
			for _, half in halves do
				local run_ = half.finish - half.start
				if run_ > 0.5 then
					local centre = from + direction * (half.start + run_ / 2)
					piece({
						name = "FenceRail",
						size = Vector3.new(0.5, 0.5, run_),
						color = palette.linen,
						castShadow = false,
						cframe = toWorld(centre.X, height, centre.Y) * CFrame.Angles(0, yaw, 0),
					})
				end
			end
		end
	end

	local runs = {
		{ fromX = -halfX, fromZ = frontZ, toX = halfX, toZ = frontZ, gateX = 0, gateZ = frontZ },
		{ fromX = -halfX, fromZ = backZ, toX = halfX, toZ = backZ, gateX = 0, gateZ = backZ },
		{ fromX = -halfX, fromZ = backZ, toX = -halfX, toZ = frontZ, gateX = -halfX, gateZ = 90 },
		{ fromX = halfX, fromZ = backZ, toX = halfX, toZ = frontZ, gateX = halfX, gateZ = 90 },
	}

	for _, run in runs do
		local from, direction, length, gateAt = geometry(run)
		local count = math.max(1, math.floor(length / garden.postSpacing))

		for index = 0, count do
			local at = from + direction * (length * index / count)
			if math.abs(length * index / count - gateAt) >= garden.gateGap then
				post(at.X, at.Y)
			end
		end

		for _, edge in { gateAt - garden.gateGap, gateAt + garden.gateGap } do
			if edge > 0.5 and edge < length - 0.5 then
				local at = from + direction * edge
				post(at.X, at.Y)
			end
		end

		rails(run)
	end
end

local function isClear(x: number, z: number): boolean
	return Vector2.new(x, z).Magnitude >= dome.radius + 2
end

local function scatterGrass(rng: Random, occupied: { Footprint })
	local garden = SafeZone.garden

	local function isFree(x: number, z: number): boolean
		for _, spot in occupied do
			if math.abs(x - spot.x) < spot.halfX and math.abs(z - spot.z) < spot.halfZ then
				return false
			end
		end
		return true
	end

	local halfX = SafeZone.VOLUME.size.X / 2 - garden.fenceInset - 5
	local frontZ = SafeZone.VOLUME.centreOffset.Z + SafeZone.VOLUME.size.Z / 2 - garden.fenceInset - 5
	local backZ = SafeZone.VOLUME.centreOffset.Z - SafeZone.VOLUME.size.Z / 2 + garden.fenceInset + 5
	local spacing = garden.grassSpacing
	local columns = math.floor((halfX * 2) / spacing)
	local rows = math.floor((frontZ - backZ) / spacing)

	for column = 0, columns do
		for row = 0, rows do
			local x = -halfX + column * spacing + rng:NextNumber(-garden.grassJitter, garden.grassJitter)
			local z = backZ + row * spacing + rng:NextNumber(-garden.grassJitter, garden.grassJitter)
			if not isClear(x, z) or not isFree(x, z) then
				continue
			end

			local clump = place({
				asset = "grassPatch",
				x = x,
				z = z,
				fit = rng:NextNumber(garden.grassFit[1], garden.grassFit[2]),
				yaw = rng:NextNumber(0, 360),
				sink = 0.6,
			}, 0)

			if not clump then
				return
			end

			WeedService.registerPatch(clump, function(child)
				return child:IsA("Model")
			end)
		end
	end
end

function SafeZoneService.containsPosition(position: Vector3): boolean
	if not volumeCentre then
		return false
	end
	local delta = position - volumeCentre
	return math.abs(delta.X) <= volumeHalf.X and math.abs(delta.Y) <= volumeHalf.Y and math.abs(delta.Z) <= volumeHalf.Z
end

function SafeZoneService.isProtected(player: Player): boolean
	return inside[player] == true
end

local function setForceField(character: Model, enabled: boolean)
	local existing = character:FindFirstChildOfClass("ForceField")
	if enabled then
		if not existing then
			local field = Instance.new("ForceField")
			field.Visible = false
			field.Parent = character
		end
	elseif existing then
		existing:Destroy()
	end
end

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

local function build(rng: Random)
	buildShell()
	buildFloor()

	for _, opening in SafeZone.OPENINGS do
		if opening.kind == "round" then
			glazeRound(opening)
		else
			frameDoor(opening)
			buildStrawberryDoor(opening)
		end
	end

	local deckY = buildLoft()
	buildStair(deckY)
	buildChimney()
	buildCertificateBoard()
	buildFuton(deckY)
	buildLamps(deckY)

	buildFence()

	placeAll(SafeZone.interior, SafeZone.FLOOR_Y, deckY)
	local outdoors = placeAll(SafeZone.exterior, SafeZone.FLOOR_Y, deckY)
	scatterGrass(rng, outdoors)

	local plate = piece({
		name = "HomeSign",
		size = Vector3.new(17, 3.4, 0.6),
		color = palette.timberDark,
		material = Enum.Material.Wood,
		collide = false,
		cframe = surfaceFrame(0, SafeZone.OPENINGS[1].top + 3.4) * CFrame.new(0, 0, 0.6),
	})
	UI.sign(plate, {
		name = "HomeSignLabel",
		title = "Home",
		subtitle = "won in the yogurt draw · nothing can reach you here",
		offset = Vector3.new(0, 4, 0),
		extent = UDim2.fromScale(20, 5),
		maxDistance = 240,
	})
end

function SafeZoneService.getSpawnCFrame(): CFrame
	local town = Areas.BY_ID[Areas.STARTING_AREA]
	local position = town.origin + Vector3.new(0, Constants.WORLD.PLATFORM_TOP, 0) + SafeZone.SPAWN_OFFSET
	return CFrame.lookAt(position, position + SafeZone.SPAWN_LOOK)
end

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
	origin = town.origin + Vector3.new(0, Constants.WORLD.PLATFORM_TOP, 0)

	volumeCentre = origin + SafeZone.VOLUME.centreOffset
	volumeHalf = SafeZone.VOLUME.size / 2

	build(Random.new(20260727))

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

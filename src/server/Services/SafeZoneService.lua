--[[
	The dome you spawn in, and the volume in which nothing can touch you.

	See docs/GAME.md §2 and §9.6, and Config/SafeZone.lua for the shape of the
	building. This file turns that table into parts and owns what the volume
	MEANS.

	Two responsibilities that look unrelated and are not:

	  1. It is a home. One white round room, a loft you sleep in, and a garden
	     with a job booth at the end of it, assembled from parts and from the
	     models under assets/Models/ so it lives in version control and needs no
	     uploaded ids, the same way NpcService assembles the cast.

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

	--------------------------------------------------------------------------
	BUILDING A CURVE OUT OF PARTS
	--------------------------------------------------------------------------

	There is no flat face on this building, which changes how everything below
	is written. Two ideas carry the whole file:

	  `surfaceFrame(azimuth, y)` returns a CFrame sitting ON the shell with +Z
	  pointing out of it, +Y running up the slope and +X tangential. Anything
	  that belongs on the wall -- glass, window rims, the door surround -- is
	  positioned in that frame and never in world space.

	  `buildShell` walks the profile in rings and lays each ring as tilted
	  blocks. Tilting each block to the local slope is the load-bearing detail:
	  untilted rings stair-step, and a stair-stepped dome reads as a ziggurat.
]]

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
local Skeleton = require(Shared.Modules.Anim.Skeleton)
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

--------------------------------------------------------------------------------
-- Geometry helpers
--------------------------------------------------------------------------------

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

-- A flat disc lying in the XZ plane. Cylinder's axis is its X axis, so every
-- disc in this file needs the same roll and it is worth having once.
local function disc(config: { [string]: any }): Part
	config.shape = Enum.PartType.Cylinder
	config.size = Vector3.new(config.thickness, config.diameter, config.diameter)
	config.cframe = config.cframe * CFrame.Angles(0, 0, math.rad(90))
	return piece(config)
end

-- Sweep parameter t (0 at the ground, 1 at the crown) for a given height.
local function parameterAt(y: number): number
	return math.asin(math.clamp(y / dome.height, 0, 1)) / (math.pi / 2)
end

--[[
	How far the shell leans in at sweep parameter t, in radians from vertical.

	Measured from the profile by finite difference rather than differentiated by
	hand, so changing `bulge` in the config cannot silently desynchronise the
	tilt from the shape it is supposed to be following.
]]
local function leanAt(t: number): number
	local step = 0.004
	local r0, y0 = SafeZone.profile(math.max(t - step, 0))
	local r1, y1 = SafeZone.profile(math.min(t + step, 1))
	return math.atan2(r0 - r1, math.max(y1 - y0, 1e-5))
end

--[[
	A frame sitting on the shell: +Z out of the surface, +Y up its slope, +X
	tangential. Everything mounted on the wall is placed relative to this.
]]
local function surfaceFrame(azimuth: number, y: number): CFrame
	local t = parameterAt(y)
	local radius = select(1, SafeZone.profile(t))
	return CFrame.new(origin)
		* CFrame.Angles(0, azimuth, 0)
		* CFrame.new(0, y, radius)
		* CFrame.Angles(-leanAt(t), 0, 0)
end

-- Signed difference between two azimuths in degrees, wrapped to [-180, 180].
local function azimuthDelta(a: number, b: number): number
	return (a - b + 540) % 360 - 180
end

--------------------------------------------------------------------------------
-- The shell
--------------------------------------------------------------------------------

--[[
	Which opening, if any, swallows the ring segment centred at `azimuth`
	spanning `yLow .. yHigh`.

	Round openings test against an ELLIPSE rather than the arc's bounding box.
	That is the difference between a round window and a square hole with a round
	frame leaning against it -- the rim drawn later would hide the corners at
	eye level and expose them from every other angle.

	Both branches test the ring's MIDPOINT, not its span. Overlap was tried on
	the door first and is wrong: a ring is 3.5 studs tall, so "any part of this
	ring is below the door head" opens the ring ABOVE the head as well and
	leaves a slot over the arch that the door surround does not reach.
]]
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

		-- Segment count follows the ring's circumference, so the crown is not
		-- paying for the same 30 blocks the base needed.
		local count = math.max(8, math.ceil(2 * math.pi * midRadius / dome.segmentArc))
		local width = (2 * math.pi * midRadius / count) * dome.overlap

		--[[
			Alternate rings are nudged half a segment round. The seams then form
			a running bond instead of stacking into continuous vertical lines up
			the side of the building, which is what makes a segmented dome look
			segmented.
		]]
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

--------------------------------------------------------------------------------
-- Openings
--------------------------------------------------------------------------------

--[[
	How far the real edge of a hole can sit from the arc that asked for it.

	An opening is cut by dropping whole segments, so its boundary lands on
	whichever segment edge is nearest -- up to half a segment away, which at the
	base of this dome is three and a half studs. Trim sized to the NOMINAL arc
	therefore floats in the middle of the hole on one ring and sits inside solid
	shell on the next.

	Every surround below is widened by these instead. It is the difference
	between a window and a window with daylight leaking round one side of it.
]]
local function horizontalSlack(y: number): number
	local radius = select(1, SafeZone.profile(parameterAt(y)))
	local count = math.max(8, math.ceil(2 * math.pi * radius / dome.segmentArc))
	return math.pi * radius / count
end

local function verticalSlack(): number
	return dome.height / dome.rings / 2
end

--[[
	A rim of small blocks following an ellipse drawn ON the shell, plus the glass
	behind it.

	Offsets are taken in the window's own surface frame rather than recomputed
	per block. Over ten studs of a thirty-two stud dome the flat-patch error is
	well under the rim's own thickness, and the alternative -- a fresh
	surfaceFrame per block -- makes the rim wobble where the two disagree.
]]
local function glazeRound(opening: { [string]: any })
	local centreY = (opening.bottom + opening.top) / 2
	local azimuth = math.rad(opening.azimuth)
	local frame = surfaceFrame(azimuth, centreY)

	local radius = select(1, SafeZone.profile(parameterAt(centreY)))
	local halfWidth = radius * math.sin(math.rad(opening.halfAngle)) + horizontalSlack(centreY)
	local halfHeight = (opening.top - opening.bottom) / 2 + verticalSlack()

	-- Sized to the rim, not to the opening: the pane has to reach whatever the
	-- rim is covering, or the gap between the two is a hole in the wall.
	disc({
		name = `{opening.name}Glass`,
		thickness = 0.4,
		diameter = math.max(halfWidth, halfHeight) * 2.1,
		color = palette.glass,
		material = Enum.Material.Glass,
		transparency = 0.55,
		collide = false,
		castShadow = false,
		-- Rotated so the disc's axis lies along the surface normal.
		cframe = frame * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(-90)),
	})

	local blocks = 30
	for index = 0, blocks - 1 do
		local angle = (index / blocks) * math.pi * 2
		local u, v = math.cos(angle) * halfWidth, math.sin(angle) * halfHeight
		-- Tangent to the ellipse, so consecutive blocks meet flush.
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

--[[
	The door surround: two jambs up the sides and an arc across the head.

	The head is sampled along the shell rather than drawn as a straight lintel,
	because the shell is already leaning back by seventeen studs up and a
	straight lintel would float off it at the middle.
]]
local function frameDoor(opening: { [string]: any })
	local steps = 18
	local rise = (opening.top - opening.bottom) / steps

	--[[
		Jambs are as wide as the quantisation can wander and are centred ON the
		nominal edge, so whichever side of it a given ring's real edge fell,
		the jamb is already covering it.
	]]
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

	--[[
		The head is sampled along the shell rather than drawn as a straight
		lintel: seventeen studs up the wall is already leaning back by twenty
		degrees, and a straight lintel would leave the middle of the arch
		floating off the surface.

		It runs past the jambs at both ends and is deep enough to swallow a
		ring's worth of vertical wander, so the three trim runs meet as corners
		rather than as a T with daylight in it.
	]]
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

	-- Threshold, so the doorway has a lip instead of ending at the grass.
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

--[[
	The leaf is sized off the aperture frameDoor actually leaves, not off the
	nominal arc in Config/SafeZone. Those are not the same number: the jambs are
	`horizontalSlack * 2.2` wide and centred ON the nominal edge, so half of each
	one juts back into the hole, and the head blocks hang `verticalSlack * 1.2`
	below their own centre. A leaf sized to the config arc came out covering
	about half of what the player sees.

	Height wins over width. The leaf's authored aspect (5.51 wide to 9.83 tall)
	is narrower than the aperture's, so filling the width would leave a gap
	under the arch, whereas filling the height overlaps each jamb by under a
	stud -- which is where a door sits against its stop anyway.
]]
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

	--[[
		Which way round the leaf is, taken from its proportions instead of
		assumed.

		This is what hung it edge-on. The exporter left a ninety degree yaw on
		the model's WorldPivot, so in the leaf's OWN space the five-and-a-half
		stud width is X and the one-and-a-half stud thickness is Z -- the mirror
		of what the world-space file looks like, and the mirror of what the old
		`CFrame.Angles(0, -90, 0)` here corrected for. The two cancelled the
		wrong way: the width ended up pointing out of the wall and the thickness
		spanning the doorway, which is a full-height three-stud plank standing in
		the middle of the arch.

		A door is taller than it is wide and wider than it is thick, and that
		ordering survives any rotation an exporter cares to leave behind, so the
		axes are read off the bounding box rather than named. GetBoundingBox, not
		GetExtentsSize: its size is documented to be in the pivot's own frame,
		which is the frame the answer has to be expressed in.
	]]
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

	-- Turns the leaf's own axes onto the surface frame's: width along its X,
	-- height up its Y, thickness out through its Z.
	local upright = CFrame.fromMatrix(Vector3.zero, across, up, through):Inverse()

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	--[[
		Hung in the doorway's own frame rather than on a vertical axis: the shell
		leans back about nine degrees at this height, and a leaf standing plumb in
		a leaning wall meets the head trim at one edge and floats off it at the
		other. Swinging about the frame's Y keeps it in the wall's plane the whole
		way round.
	]]
	local centreY = sill + doorHeight / 2
	local frame = surfaceFrame(math.rad(opening.azimuth), centreY)
	model:PivotTo(frame * upright)
	local boxCFrame = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (frame.Position - boxCFrame.Position))

	--[[
		Hinge and swing are both stated in the DOORWAY's frame, not the leaf's.
		`upright` is whatever it takes to turn this particular export the right
		way up, and hanging the swing off that would put the hinge wherever the
		exporter's pivot happened to point. The doorway's frame is fixed: X runs
		along the wall, Y up its slope, Z out through it.
	]]
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

--------------------------------------------------------------------------------
-- Interior structure
--------------------------------------------------------------------------------

local function buildFloor()
	-- The plinth reads as a base course and, more usefully, hides the ragged
	-- bottom edge where the first ring of segments meets the ground.
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

	-- A round rug under the table, which is what stops the floor reading as a
	-- disc of planks with furniture standing on it.
	disc({
		name = "Rug",
		thickness = 0.2,
		diameter = 30,
		color = palette.mint,
		material = Enum.Material.Fabric,
		collide = false,
		castShadow = false,
		cframe = toWorld(0, SafeZone.FLOOR_Y + 0.1, -3),
	})
end

--[[
	The loft deck: a half-disc across the back of the room, built as strips.

	Each strip's depth is measured at whichever of its edges is further from the
	centre, so every strip lands inside the circle. Taking the midpoint instead
	pokes the corners of each strip through the wall.
]]
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

	-- Railing along the open edge. Half-width is taken where the deck is still
	-- at least a stud deep, so the rail stops with the floor rather than
	-- running on past it into the wall.
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

--[[
	A stair that spirals up the inside of the shell.

	Straight flights were tried first and a straight flight in a round room
	either cuts across the middle of the only floor you have, or runs into the
	curve and has to stop early. Following the wall costs nothing and leaves the
	floor clear.

	Treads are thicker than their own rise so consecutive steps overlap into a
	continuous ribbon rather than fifteen floating slabs.
]]
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

--------------------------------------------------------------------------------
-- Fixtures
--------------------------------------------------------------------------------

local function buildChimney()
	-- Set back from the crown so it breaks the silhouette rather than sitting
	-- on top of it like a handle.
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

--[[
	The wall §6's certificates will hang on. Empty for now and labelled as such
	-- an obviously-reserved space reads as a promise, where a blank wall reads
	as an unfinished room.

	On the shell rather than free-standing, since there is no flat wall to lean
	it against.
]]
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

--[[
	The bed.

	Sized and placed against the deck's own radius rather than by eye. The deck
	is a half-disc, so its far corners are much closer to the middle than its
	waist is -- a bed that fits alongside the stair at x = -7 hangs its back
	corner into the wall if it is pushed two studs further out. Measured here so
	changing LOFT.inset or the dome's bulge moves the bed instead of burying it.
]]
local function buildFuton(deckY: number)
	local loft = SafeZone.LOFT
	local deckRadius = SafeZone.interiorRadiusAt(loft.y) - loft.inset

	local width, depth = 12, 15
	local x = -7
	--[[
		Furthest the bed's centre can sit back with both far corners still on
		deck. The margin is not slop: the deck is strips, and each strip's depth
		is taken at its outer edge, so the real floor is a notch inside the
		circle this is measured against.
	]]
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

--[[
	Lighting, hung rather than baked.

	Two lamps and a fire's worth of warm light, all low-brightness: the shell is
	near-white and takes very little to blow out. The point is that the inside
	is warmer than the daylight outside it, not that it is bright.
]]
local function buildLamps(deckY: number)
	local spots = {
		{ x = 0, y = dome.height * 0.62, z = 0, range = 34, brightness = 1.1 },
		{ x = -9, y = deckY + 9, z = -12, range = 20, brightness = 0.7 },
	}

	for index, spot in spots do
		local bulb = piece({
			name = `Lantern_{index}`,
			shape = Enum.PartType.Ball,
			size = Vector3.new(3.6, 3.6, 3.6),
			color = palette.honey,
			material = Enum.Material.Neon,
			collide = false,
			castShadow = false,
			cframe = toWorld(spot.x, spot.y, spot.z),
		})
		piece({
			name = `LanternCord_{index}`,
			size = Vector3.new(0.2, 6, 0.2),
			color = palette.timberDark,
			collide = false,
			castShadow = false,
			cframe = toWorld(spot.x, spot.y + 4.8, spot.z),
		})

		local light = Instance.new("PointLight")
		light.Brightness = spot.brightness
		light.Range = spot.range
		light.Color = Color3.fromRGB(255, 226, 186)
		light.Shadows = false
		light.Parent = bulb
	end
end

--------------------------------------------------------------------------------
-- Placing models
--------------------------------------------------------------------------------

--[[
	Put a loaded model down at a target SIZE rather than a target scale.

	Two things here are worth not rediscovering:

	  Sizing is driven by the model's largest dimension. These came from a dozen
	  toolbox authors working at a dozen scales, and "make it thirteen studs"
	  is the only instruction that means the same thing to all of them.

	  Placement is done twice. A Model's pivot is wherever its author left it,
	  which is frequently not the centre of its geometry, so pivoting to the
	  target and stopping puts the model somewhere near where you asked. The
	  second pass measures where the bounding box actually landed and corrects
	  by the difference, which is exact regardless of the pivot.

	  The height is measured AFTER the rotation, and measured against the WORLD
	  up axis rather than read off the box. Yaw alone cannot change a model's
	  vertical extent so this never mattered before, but `pitch` and `roll` can:
	  a can tipped 35 degrees forward is shorter than the can standing up, and
	  sizing it upright buries the spout in the lawn.

	  Both GetBoundingBox and GetExtentsSize are oriented to the model's PIVOT,
	  not to the world -- so once the model is tilted, `size.Y` is its own height
	  and not the height of the hole it needs in the ground. `worldHeight` below
	  projects the box's three axes onto world up, which is that height.
]]
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

	--[[
		Where this ended up, in the model's OWN frame, recorded for anything that
		has to be positioned against it.

		`extents` is measured before the model is ever rotated, so it is the
		authored-orientation size -- which is the only frame in which "the long
		axis of the counter" means anything. Reading it back off the placed model
		does not work: GetExtentsSize is oriented to the pivot, and a prop yawed
		twenty degrees reports a box that is a blend of its own two axes.

		This exists because Yoroi-san's position used to be a second set of
		hand-written coordinates that had to agree with the booth's, and did not:
		the booth moved and resized twice while the attendant stayed where it
		was, standing inside the counter.
	]]
	model:SetAttribute("PlotSize", extents)
	model:SetAttribute("PlotCentre", wanted)
	model:SetAttribute("PlotYaw", row.yaw or 0)

	model.Parent = houseFolder
	return model
end

--[[
	Give a flat cloth the shape of the table under it.

	TableCloth is a 12.6 x 0.24 x 12.7 sheet with a scalloped frill around its
	rim and no drape whatsoever, so laid on a table it is a lid: the frill hangs
	in mid-air off every edge with nothing joining it to the furniture. Nothing
	in the model can be posed into a skirt either -- the frill pieces are all at
	the same height as the sheet.

	So the skirt is built. Four panels drop from the cloth's own rim to just
	above the floor, taking their colour and material from the sheet, sized to
	the CLOTH rather than to the table so the hem lines up with the frill that is
	already there. The panels overlap at the corners rather than mitring.
]]
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

	-- The cloth's own yaw, kept upright: panels hang plumb whatever the sheet is
	-- turned to, which they would not if they inherited its full rotation.
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

--[[
	Footprints of what has already been placed, in plot coordinates.

	Only used by the lawn. Scattering 22 clumps at random almost never landed one
	inside a shop; covering the plot on a grid lands several, and a clump of grass
	standing up through a shop floor is worse than a bare patch.

	SOLID THINGS ONLY -- the ones Config/Assets marks `collide`, which is the
	shops, the booth and the picnic table. A sakura is 54 studs of canopy over a
	trunk you can walk up to, and reserving its bounding box would clear a
	54-stud circle of lawn to protect a tree that grass is supposed to grow
	under.
]]
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
			--[[
				Solid AND not a canopy. `collide` used to be opt-in and doubled
				as "is this a building", which stopped working the moment it
				became the default: reserving lawn under everything solid clears
				a 54-stud circle for each sakura, which is most of the garden.
			]]
			local spec = Assets.get(row.asset)
			if spec and spec.collide ~= false and not spec.canopy then
				table.insert(footprints, footprintOf(row, result))
			end
		end
	end

	return footprints
end

--------------------------------------------------------------------------------
-- Yoroi-san
--------------------------------------------------------------------------------

--[[
	R6 joint names, keyed by the limb the joint drives.

	The rig is renamed from this rather than trusting the names it shipped with.
	See rigYoroi: one of its two `Snap`s is called "Neck" and connects nothing,
	while the one that actually holds the head on is called "Snap". Deriving the
	name from the child part is the only version of this that cannot be lied to.
]]
local YOROI_JOINTS = {
	Head = "Neck",
	["Left Arm"] = "Left Shoulder",
	["Right Arm"] = "Right Shoulder",
	["Left Leg"] = "Left Hip",
	["Right Leg"] = "Right Hip",
}

--[[
	Make the job-booth attendant animatable.

	The model is a legacy R6 rig: the right six parts with the right names, held
	together by `Motor` and `Snap`. Those are the pre-Motor6D joint classes and
	nothing in Roblox's animation stack -- or in Anim/Machine -- will touch
	them, which is why this arrives as a statue and not as a character.

	Converting the classes is the easy half. The rig underneath them is wrong in
	three separate ways, and all three are silent:

	  BOTH SHOULDERS ARE BACKWARDS. `Right Shoulder` has Part0 = Right Arm and
	  Part1 = Torso. A Motor6D moves its Part1, so driving that joint swings the
	  BODY around a stationary arm. Every joint is therefore re-pointed away
	  from the Torso, swapping C0 and C1 with it so the rest pose is unchanged.

	  THE NECK IS A DECOY. There are two Snaps: one named "Neck" with Part0 and
	  Part1 both null, and one named "Snap" that actually holds the head on.
	  Joints are dropped if either part is missing and renamed afterwards from
	  YOROI_JOINTS, so the profile binds to the joint that exists rather than to
	  the one with the right name.

	  THERE IS NO ROOT. No HumanoidRootPart means no joint for a root track to
	  drive, and the whole body would be rigid while its limbs moved. An
	  invisible root joined to the Torso gives Machine the one joint it needs to
	  breathe.

	Order matters. ScaleTo runs FIRST, because it rewrites Motor6D offsets to
	match and any joint built afterwards would be measured against parts that
	have already moved.

	Note `ClassName` and not `IsA` on the conversion. Motor6D inherits from
	Motor, so `IsA("Motor")` is true of the very objects being created and the
	loop would eat its own output.
]]
local function rigYoroi(model: Model, height: number): BasePart?
	local extents = model:GetExtentsSize()
	if extents.Y > 0.01 then
		model:ScaleTo(model:GetScale() * (height / extents.Y))
	end

	local torso = model:FindFirstChild("Torso", true)
	if not (torso and torso:IsA("BasePart")) then
		warn("[SafeZoneService] yoroiKnight has no Torso; leaving it unrigged")
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant.ClassName ~= "Motor" and descendant.ClassName ~= "Snap" then
			continue
		end

		local legacy = descendant :: any
		local part0, part1 = legacy.Part0, legacy.Part1
		local c0, c1 = legacy.C0, legacy.C1
		legacy:Destroy()

		if not (part0 and part1) then
			continue
		end

		-- Point the joint away from the Torso, so Part1 is always the limb.
		if part1 == torso then
			part0, part1 = part1, part0
			c0, c1 = c1, c0
		end

		local named = YOROI_JOINTS[part1.Name]
		if not named then
			continue
		end

		local motor = Instance.new("Motor6D")
		motor.Name = named
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = c0
		motor.C1 = c1
		motor.Parent = part0
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = torso.Size
	root.CFrame = torso.CFrame
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.Parent = model

	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = root
	rootJoint.Part1 = torso
	rootJoint.C0 = CFrame.new()
	rootJoint.C1 = CFrame.new()
	rootJoint.Parent = root

	--[[
		Anything the rig left loose -- the two shoulder plates -- is welded to
		the torso so it travels with the animation instead of hanging in the air
		where the model was authored.

		Everything except the root is unanchored. An anchored part ignores its
		joints, so a rig anchored part-by-part animates nothing; anchoring only
		the root holds the whole assembly in place through the joints while
		leaving Motor6D.Transform free to move it.
	]]
	local jointed: { [BasePart]: boolean } = { [root] = true, [torso] = true }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			if descendant.Part1 then
				jointed[descendant.Part1] = true
			end
		end
	end

	--[[
		Solid, like everything else on the plot.

		Safe because of the anchoring above: joints propagate anchoring through
		an assembly, so limbs joined to an anchored root cannot be shoved
		anywhere by a player walking into them. Collision here only means Yoroi
		occupies its own space instead of being a hologram of a bailiff.

		The root is the exception. It is an invisible box sitting exactly on the
		torso, so leaving it solid would give the torso two collision hulls.
	]]
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local isRoot = descendant == root
			descendant.Anchored = isRoot
			descendant.CanCollide = not isRoot
			descendant.CanQuery = not isRoot
			descendant.CanTouch = false
			if not jointed[descendant] then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = torso
				weld.Part1 = descendant
				weld.Parent = torso
			end
		end
	end

	model.PrimaryPart = root
	model:SetAttribute(Skeleton.PROFILE_ATTRIBUTE, "yoroi")
	return root
end

--[[
	Where the attendant stands, derived from the booth that is already placed.

	The booth is the thing that moves. It has been resized twice and re-yawed
	twice, and both times Yoroi-san stayed at the coordinates written next to it
	-- which is how it ended up standing inside its own counter. So this reads
	the booth's recorded frame and measures off it, and the config now says
	"just past the end of the counter" in units of the booth rather than in
	studs of the world.

	Standing at the END of the counter and not behind it is forced by the model.
	ShopStall's back board sits at local X -1.60 and its counter spans -1.50 to
	+1.50, so there is no gap to stand in -- and the board runs the full height
	of the stall, so anything behind it is hidden completely. The open end is the
	only place an attendant is both out of the geometry and visible.
]]
local function boothStation(): (CFrame?, number?)
	local booth = houseFolder:FindFirstChild(SafeZone.YOROI.booth)
	if not (booth and booth:IsA("Model")) then
		return nil, nil
	end

	local centre = booth:GetAttribute("PlotCentre")
	local size = booth:GetAttribute("PlotSize")
	local yaw = booth:GetAttribute("PlotYaw")
	if typeof(centre) ~= "Vector3" or typeof(size) ~= "Vector3" or type(yaw) ~= "number" then
		return nil, nil
	end

	local spot = SafeZone.YOROI
	local frame = CFrame.new(centre) * CFrame.Angles(0, math.rad(yaw), 0)
	local station = frame * CFrame.new(spot.outFromCounter * size.X / 2, 0, spot.alongCounter * size.Z / 2)

	--[[
		Facing, derived rather than typed.

		The booth serves along its own +X, which is the bearing yaw + 90. The rig
		faces its own -X -- every part in it carries a 90 degree yaw, and "Right
		Arm" sits at -Z where a standard R6 rig puts it at +X -- so a rig at yaw
		phi faces the bearing phi - 90. Setting those equal gives phi = yaw + 180,
		and `facingOffset` is that 180 with a name on it.
	]]
	return CFrame.new(station.Position), yaw + spot.facingOffset
end

local function buildYoroi(groundY: number)
	local model = AssetService.clone("yoroiKnight")
	if not model then
		warn("[SafeZoneService] yoroiKnight did not load; the job booth is unstaffed")
		return
	end

	local spot = SafeZone.YOROI
	model.Name = "YoroiSan"

	local root = rigYoroi(model, spot.height)
	if not root then
		model:Destroy()
		return
	end

	local station, facing = boothStation()
	if not (station and facing) then
		warn("[SafeZoneService] job booth is not placed; standing Yoroi-san at its fallback spot")
		station, facing = toWorld(spot.x, 0, spot.z), spot.yaw
	end

	-- Feet on the ground: the rig's own extents are measured after scaling, and
	-- the root sits at the torso, which is not the bottom of the model.
	model:PivotTo(CFrame.new(station.Position) * CFrame.Angles(0, math.rad(facing), 0))
	local box, size = model:GetBoundingBox()
	local lift = (origin.Y + groundY + size.Y / 2) - box.Position.Y
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))

	--[[
		Parented last, and only once it is rigged and standing.

		SafeZoneAnimController binds on ChildAdded and reads the profile
		attribute to decide whether a model is animatable. Parenting first would
		make that a race against the rig it is waiting for.
	]]
	model.Parent = houseFolder

	UI.sign(root, {
		name = "BoothSign",
		title = "Weeding — apply here",
		subtitle = "certification raises the rate",
		offset = Vector3.new(0, 9, 0),
		extent = UDim2.fromScale(16, 4.5),
		maxDistance = 140,
	})
end

--------------------------------------------------------------------------------
-- Garden
--------------------------------------------------------------------------------

local function buildPath()
	local garden = SafeZone.garden
	local length = garden.pathTo - garden.pathFrom
	local centre = (garden.pathFrom + garden.pathTo) / 2

	piece({
		name = "Path",
		size = Vector3.new(garden.pathWidth, 0.4, length),
		color = palette.stone,
		material = Enum.Material.Cobblestone,
		collide = false,
		castShadow = false,
		cframe = toWorld(0, SafeZone.FLOOR_Y - 0.4, centre),
	})

	-- Edging. The strip alone reads as a texture change in the ground; two
	-- lines of trim either side is what makes it read as a made path.
	for _, side in { -1, 1 } do
		piece({
			name = "PathEdge",
			size = Vector3.new(1.2, 0.6, length),
			color = palette.trim,
			collide = false,
			castShadow = false,
			cframe = toWorld(side * (garden.pathWidth / 2 + 0.6), SafeZone.FLOOR_Y - 0.35, centre),
		})
	end
end

--[[
	A picket fence marking the safe volume.

	Legibility is the point: the boundary is a real rule, so it has to be
	something the player can see rather than a line they discover by being hurt
	on the far side of it. The front is left open where the path crosses it.

	Round caps, not points. A pointed picket is a fence; a round-topped one is
	the same fence drawn by somebody being nice about it, and that is the whole
	register this plot is supposed to be in.
]]
local function buildFence()
	local garden = SafeZone.garden
	local halfX = SafeZone.VOLUME.size.X / 2 - garden.fenceInset
	local frontZ = SafeZone.VOLUME.centreOffset.Z + SafeZone.VOLUME.size.Z / 2 - garden.fenceInset
	local backZ = SafeZone.VOLUME.centreOffset.Z - SafeZone.VOLUME.size.Z / 2 + garden.fenceInset

	local function post(x: number, z: number)
		if math.abs(x) < garden.gateGap and math.abs(z - frontZ) < 0.01 then
			return
		end
		piece({
			name = "FencePost",
			size = Vector3.new(1.1, garden.fenceHeight, 1.1),
			color = palette.linen,
			collide = false,
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

	local function rails(fromX: number, fromZ: number, toX: number, toZ: number, gate: boolean)
		local length = (Vector2.new(toX, toZ) - Vector2.new(fromX, fromZ)).Magnitude
		local yaw = math.atan2(toX - fromX, toZ - fromZ)
		for _, height in { garden.fenceHeight * 0.35, garden.fenceHeight * 0.72 } do
			if gate then
				-- Two runs either side of the opening the path passes through.
				local span = (length / 2) - garden.gateGap
				for _, side in { -1, 1 } do
					piece({
						name = "FenceRail",
						size = Vector3.new(0.5, 0.5, span),
						color = palette.linen,
						collide = false,
						castShadow = false,
						cframe = toWorld((fromX + toX) / 2, height, (fromZ + toZ) / 2)
							* CFrame.Angles(0, yaw, 0)
							* CFrame.new(0, 0, side * (garden.gateGap + span / 2)),
					})
				end
			else
				piece({
					name = "FenceRail",
					size = Vector3.new(0.5, 0.5, length),
					color = palette.linen,
					collide = false,
					castShadow = false,
					cframe = toWorld((fromX + toX) / 2, height, (fromZ + toZ) / 2) * CFrame.Angles(0, yaw, 0),
				})
			end
		end
	end

	local runs = {
		{ fromX = -halfX, fromZ = frontZ, toX = halfX, toZ = frontZ, gate = true },
		{ fromX = -halfX, fromZ = backZ, toX = halfX, toZ = backZ, gate = false },
		{ fromX = -halfX, fromZ = backZ, toX = -halfX, toZ = frontZ, gate = false },
		{ fromX = halfX, fromZ = backZ, toX = halfX, toZ = frontZ, gate = false },
	}

	for _, run in runs do
		local length = (Vector2.new(run.toX, run.toZ) - Vector2.new(run.fromX, run.fromZ)).Magnitude
		local count = math.max(1, math.floor(length / garden.postSpacing))
		for index = 0, count do
			local alpha = index / count
			post(run.fromX + (run.toX - run.fromX) * alpha, run.fromZ + (run.toZ - run.fromZ) * alpha)
		end
		rails(run.fromX, run.fromZ, run.toX, run.toZ, run.gate)
	end
end

local function buildPathLanterns()
	local garden = SafeZone.garden
	local count = math.floor((garden.pathTo - garden.pathFrom) / garden.lanternSpacing)

	for index = 1, count do
		local z = garden.pathFrom + garden.lanternSpacing * index
		for _, side in { -1, 1 } do
			local x = side * (garden.pathWidth / 2 + 4.5)

			piece({
				name = "LanternPost",
				size = Vector3.new(0.7, 9, 0.7),
				color = palette.timberDark,
				material = Enum.Material.Wood,
				collide = false,
				cframe = toWorld(x, 4.5, z),
			})

			local head = place({ asset = "lantern", x = x, z = z, fit = 6, y = 8.4 }, 0)
			local anchor = head and head.PrimaryPart or (head and head:FindFirstChildWhichIsA("BasePart", true))
			if anchor then
				local glow = Instance.new("PointLight")
				glow.Brightness = 1.6
				glow.Range = 26
				glow.Color = Color3.fromRGB(255, 214, 158)
				glow.Shadows = false
				glow.Parent = anchor
			end
		end
	end
end

--[[
	Ground that is clear to plant on: not on the paving, and not inside the house.

	The paving is the path strip plus its 1.2-stud edging either side, so it ends
	at 8.2 from the centre line and grass may start just past that. This used to
	keep back pathWidth/2 + 6 -- a 26-stud-wide bald strip down the middle of the
	garden for a 14-stud path -- and to leave a 20-stud square of bare ground on
	the doorstep, which is paving too and does not need a lawn exclusion of its
	own.
]]
local function isClear(x: number, z: number): boolean
	local garden = SafeZone.garden
	local paved = garden.pathWidth / 2 + 1.2 + garden.grassPathMargin
	if math.abs(x) < paved and z > garden.pathFrom - garden.grassPathMargin and z < garden.pathTo then
		return false
	end
	return Vector2.new(x, z).Magnitude >= dome.radius + 2
end

--[[
	Lawn, by jittered grid.

	One clump per cell, displaced by up to `grassJitter`, sized to overlap its
	neighbours. Cells whose centre is on the paving or under the house are
	skipped, so the grass runs right up to the kerb and stops.
]]
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
			-- The sparkle bubble would sit over the whole interior and read as a
			-- hazard warning, which is the opposite of the intent.
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
-- Assembly
--------------------------------------------------------------------------------

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

	buildPath()
	buildFence()
	buildPathLanterns()

	placeAll(SafeZone.interior, SafeZone.FLOOR_Y, deckY)
	local outdoors = placeAll(SafeZone.exterior, SafeZone.FLOOR_Y, deckY)
	scatterGrass(rng, outdoors)
	buildYoroi(SafeZone.FLOOR_Y)

	--[[
		The nameplate over the door.

		§the house was won in a lottery run by a yogurt conglomerate, which is
		the only fact about this building the source material actually states.
		It goes on the sign because a plaque explaining how you came to own the
		place is exactly what somebody who won a house would put up.
	]]
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

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Spawning at the back of the room facing the door means the first frame of the
-- game is the room, the doorway, and the garden framed through it.
function SafeZoneService.getSpawnCFrame(): CFrame
	local town = Areas.BY_ID[Areas.STARTING_AREA]
	local position = town.origin + Vector3.new(0, Constants.WORLD.PLATFORM_TOP, 0) + SafeZone.SPAWN_OFFSET
	return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
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
	origin = town.origin + Vector3.new(0, Constants.WORLD.PLATFORM_TOP, 0)

	volumeCentre = origin + SafeZone.VOLUME.centreOffset
	volumeHalf = SafeZone.VOLUME.size / 2

	build(Random.new(20260727))

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

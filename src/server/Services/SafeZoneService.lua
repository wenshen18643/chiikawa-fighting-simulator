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
local Remotes = require(Shared.Modules.Remotes)
local SafeZone = require(Shared.Modules.Config.SafeZone)
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local UI = require(Shared.UI)

local AssetService = require(script.Parent.AssetService)
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

	--[[
		A door leaf propped open against the outside of the shell. Not a working
		door: a closing one would eventually shut somebody out of their own safe
		zone, and the whole point of the building is that it cannot.
	]]
	local leaf = surfaceFrame(math.rad(opening.azimuth - opening.halfAngle), opening.bottom + 7)
	piece({
		name = "DoorLeaf",
		size = Vector3.new(0.5, 14, 12),
		color = palette.timber,
		material = Enum.Material.Wood,
		collide = false,
		cframe = leaf * CFrame.new(-1, 0, 2.5) * CFrame.Angles(0, math.rad(74), 0),
	})

	-- Threshold, so the doorway has a lip instead of ending at the grass.
	piece({
		name = "Threshold",
		size = Vector3.new(18, 0.6, 6),
		color = palette.stone,
		material = Enum.Material.Concrete,
		cframe = toWorld(0, SafeZone.FLOOR_Y - 0.3, dome.radius - 1),
	})
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
]]
local function place(row: SafeZone.Placement, baseY: number): Model?
	local model = AssetService.clone(row.asset)
	if not model then
		return nil
	end

	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	if largest > 0.01 then
		model:ScaleTo(model:GetScale() * (row.fit / largest))
		extents = model:GetExtentsSize()
	end

	local target = toWorld(row.x, 0, row.z) * CFrame.Angles(0, math.rad(row.yaw or 0), 0)
	model:PivotTo(target)

	local wanted = origin
		+ Vector3.new(row.x, baseY + (row.y or 0) + extents.Y / 2 - (row.sink or 0), row.z)
	local landed = select(1, model:GetBoundingBox()).Position
	model:PivotTo(model:GetPivot() + (wanted - landed))

	if row.name then
		model.Name = row.name
	end
	model.Parent = houseFolder
	return model
end

local function placeAll(rows: { SafeZone.Placement }, groundY: number, deckY: number)
	for _, row in rows do
		local baseY = if row.on == "loft" then deckY else groundY
		local ok, result = pcall(place, row, baseY)
		if not ok then
			warn(`[SafeZoneService] placing "{row.asset}" failed: {result}`)
		elseif result == nil then
			warn(`[SafeZoneService] asset "{row.asset}" did not load; nothing placed`)
		end
	end
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

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanQuery = false
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

	-- Feet on the ground: the rig's own extents are measured after scaling, and
	-- the root sits at the torso, which is not the bottom of the model.
	model:PivotTo(toWorld(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0))
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
	Ground that is clear to plant on: not on the path, not inside the house, and
	not on the doorstep a player lands on when they travel to Town.
]]
local function isClear(x: number, z: number): boolean
	local garden = SafeZone.garden
	if math.abs(x) < garden.pathWidth / 2 + 6 and z > garden.pathFrom - 6 and z < garden.pathTo + 6 then
		return false
	end
	if Vector2.new(x, z).Magnitude < dome.radius + 8 then
		return false
	end
	local doorstep = SafeZone.DOORSTEP_OFFSET
	return not (math.abs(x - doorstep.X) < 10 and math.abs(z - doorstep.Z) < 10)
end

local function scatterGrass(rng: Random)
	local garden = SafeZone.garden
	local halfX = SafeZone.VOLUME.size.X / 2 - garden.fenceInset - 5
	local frontZ = SafeZone.VOLUME.centreOffset.Z + SafeZone.VOLUME.size.Z / 2 - garden.fenceInset - 5
	local backZ = SafeZone.VOLUME.centreOffset.Z - SafeZone.VOLUME.size.Z / 2 + garden.fenceInset + 5

	local placed = 0
	local attempts = 0
	while placed < garden.grassCount and attempts < garden.grassCount * 8 do
		attempts += 1
		local x = rng:NextNumber(-halfX, halfX)
		local z = rng:NextNumber(backZ, frontZ)
		if not isClear(x, z) then
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
		placed += 1
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
	placeAll(SafeZone.exterior, SafeZone.FLOOR_Y, deckY)
	scatterGrass(rng)
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

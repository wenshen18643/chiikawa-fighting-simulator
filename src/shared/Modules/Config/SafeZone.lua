--[[
	The home dome, as data. See docs/GAME.md §9.6 and §2.

	SPEC NOTE: §9.6 puts the player's home in Slice 6. It arrives early, because
	it is the first thing anyone ever sees and because the safe volume has to
	exist before combat does -- not after.

	--------------------------------------------------------------------------
	WHY A DOME AND NOT A COTTAGE
	--------------------------------------------------------------------------

	The previous version of this file described a three-storey box with a
	domed cupola sitting on top of it, and it read as a box with a hat. The
	reference is not a house with a dome on it -- it IS a dome: one white
	round-shouldered shell, one room, a round door and round windows.

	So the shell here is not a set of walls. It is a surface of revolution,
	sampled into rings of tilted blocks (SafeZoneService.buildShell). That is
	the only way to get a curve out of parts, and it is why openings are
	described below as ARCS rather than as rectangles -- there is no flat face
	on this building for a rectangle to sit on.

	Coordinates are relative to the dome's centre, which sits on the Town plaza:
	  +Z is out through the front door, +Y is up, +X is right as you leave.
	Azimuth is measured in degrees from +Z, positive toward +X.
]]

local SafeZone = {}

--------------------------------------------------------------------------------
-- The shell
--------------------------------------------------------------------------------

--[[
	The dome profile, swept from the ground (t=0) to the crown (t=1):

	    y(t) = height * sin(t * pi/2)
	    r(t) = radius * cos(t * pi/2) ^ bulge

	`bulge` below 1 pushes the shoulder outward, which is the whole difference
	between an igloo and the reference silhouette. At 1.0 this is a plain
	half-ellipsoid and the walls fall away from the player's head immediately;
	at 0.86 the wall stays near-vertical for the first eight studs and then
	turns over, so the interior has usable floor all the way to its edge.
]]
SafeZone.DOME = {
	radius = 32,
	height = 37,
	wall = 2.2,
	-- Sampling. `rings` is vertical resolution; `segmentArc` is the target
	-- horizontal chord in studs, so rings near the crown get fewer, larger
	-- blocks instead of the same count crushed into a smaller circle.
	rings = 16,
	segmentArc = 7.0,
	bulge = 0.86,
	-- Blocks are grown slightly past their share of the ring so neighbours
	-- overlap. Without it the shell is a colander at every seam.
	overlap = 1.14,
}

SafeZone.FLOOR_Y = 0.75

--[[
	Openings, as arcs.

	A segment is omitted when its centre falls inside `azimuth ± halfAngle` AND
	its vertical span overlaps `bottom .. top`. Because the shell leans inward
	as it climbs, an opening with straight sides in this table comes out as an
	arch in the world -- the door narrows toward its head on its own, with no
	arch geometry authored anywhere.
]]
SafeZone.OPENINGS = {
	{ name = "Door", azimuth = 0, halfAngle = 14, bottom = 0, top = 17.5, kind = "door" },
	{ name = "WindowE", azimuth = 76, halfAngle = 10, bottom = 7.5, top = 16.5, kind = "round" },
	{ name = "WindowW", azimuth = -76, halfAngle = 10, bottom = 7.5, top = 16.5, kind = "round" },
	{ name = "WindowN", azimuth = 180, halfAngle = 10, bottom = 7.5, top = 16.5, kind = "round" },
	-- The loft's window. Above the door, so from outside the building reads as
	-- having an upstairs, and from inside it is the view the bed faces.
	{ name = "LoftWindow", azimuth = 0, halfAngle = 12, bottom = 21.5, top = 29, kind = "round" },
}

--------------------------------------------------------------------------------
-- The loft
--------------------------------------------------------------------------------

--[[
	A half-deck across the back of the room, reached by a stair that spirals up
	the inside of the shell.

	§2 rule 6 -- the reward for climbing your own house is that it was worth
	climbing -- survives the move from a three-storey box: you sleep above your
	own front door, looking out of the window over the garden.
]]
SafeZone.LOFT = {
	y = 18.5,
	slab = 0.8,
	-- Front edge of the deck. Everything behind this (-Z) is floor.
	frontZ = -4,
	inset = 2.6, -- from the interior wall at the loft's height
	strips = 20, -- how finely the curved back edge is sampled
	railHeight = 4.2,
}

SafeZone.STAIR = {
	steps = 15,
	fromAzimuth = 128,
	sweep = 132, -- degrees travelled while climbing
	radius = 23.5,
	width = 7.5,
	length = 6.4,
}

--------------------------------------------------------------------------------
-- Palette
--------------------------------------------------------------------------------

--[[
	Warm off-white, one soft pink, one mint, one honey. Nothing saturated.

	The old palette's terracotta roof was the loudest thing on the plot and it
	was competing with the sakura for the eye; the shell is now the quietest
	surface in the scene and the pink trim is the only strong hue on the
	building, which is what makes the flowers and the food read.
]]
SafeZone.palette = {
	shell = Color3.fromRGB(250, 247, 242),
	shellShade = Color3.fromRGB(236, 229, 220),
	trim = Color3.fromRGB(244, 186, 190),
	trimDeep = Color3.fromRGB(224, 152, 158),
	mint = Color3.fromRGB(186, 224, 212),
	honey = Color3.fromRGB(252, 226, 166),
	timber = Color3.fromRGB(198, 154, 116),
	timberDark = Color3.fromRGB(156, 116, 84),
	floor = Color3.fromRGB(232, 208, 176),
	glass = Color3.fromRGB(206, 232, 240),
	fabric = Color3.fromRGB(248, 214, 214),
	linen = Color3.fromRGB(253, 250, 246),
	leaf = Color3.fromRGB(146, 200, 122),
	stone = Color3.fromRGB(232, 224, 210),
}

--------------------------------------------------------------------------------
-- The safe volume
--------------------------------------------------------------------------------

--[[
	The protected box: the dome, its garden, the path, and the market frontage
	at the far end.

	Deliberately much larger than the building. A safe zone whose edge is the
	front wall means the moment you open the door you are exposed, which turns
	your own doorstep into the most dangerous tile in the game. The far edge is
	past the shops, so the errand you walk out to do is also safe.

	Town's island is 2600 studs and its first district pad sits at radius 200
	(Constants.WORLD.DISTRICT_INNER_RADIUS), so the far corner here at ~150 is
	inside the plaza with room to spare.
]]
SafeZone.VOLUME = {
	size = Vector3.new(184, 132, 212),
	centreOffset = Vector3.new(0, 52, 40),
}

-- Where a player is put down: at the back of the room, facing their own door.
SafeZone.SPAWN_OFFSET = Vector3.new(0, 3.5, -17)
-- Where travelling to Town lands you: on the doorstep, facing out at the world.
SafeZone.DOORSTEP_OFFSET = Vector3.new(0, 3.5, 42)

--------------------------------------------------------------------------------
-- Dressing
--------------------------------------------------------------------------------

--[[
	One row per placed model. `asset` is a key in Config/Assets.

	`fit` is the target size in studs of the model's LARGEST dimension, and it
	is the only sizing control -- there is no per-model scale anywhere. These
	came from a dozen different toolbox authors at a dozen different scales, so
	"make it this big" is the only instruction that means the same thing twice.

	`y` lifts the model's base above the surface it stands on; omitted means it
	sits on the ground. `yaw` is degrees. `sink` buries it, for things that
	should look planted rather than placed.

	`pitch` and `roll` tip the model in its own yawed frame, and exist for two
	jobs: standing up a model whose author left it lying on its side (the yogurt
	tub's bowl points its open face at -Z, not up), and tipping something that is
	meant to be in use (the watering can pours or it is a watering can nobody is
	using). They are applied after `yaw`, and the model is re-measured afterwards
	so a tilted thing still lands on the ground rather than through it.
]]
export type Placement = {
	asset: string,
	x: number,
	z: number,
	fit: number,
	y: number?,
	yaw: number?,
	pitch: number?,
	roll: number?,
	sink: number?,
	name: string?,
	-- "loft" measures `y` from the loft deck instead of the ground floor.
	on: string?,
	-- Names an already-placed model this one should be draped over; see
	-- SafeZoneService.drape.
	drapeOver: string?,
}

--[[
	FOOD IS OVERSIZED ON PURPOSE.

	A Roblox character is about 5 studs tall and the companion rigs normalise to
	roughly 4. Every `fit` below beats both. The gag in the source material is
	that a portion of food is an event -- a bowl two characters have to stand
	either side of -- and scaling it against the table instead of against the
	character loses the entire joke and just gives you a table with lunch on it.

	Kept as a named table rather than inline numbers because it is the one set
	of values here that is a deliberate joke and not a measurement, and it
	should be obvious that changing it downward breaks something on purpose.
]]
SafeZone.FOOD = {
	ramen = 13,
	dangoPlatter = 15,
	dango = 10,
	onigiri = 9,
	pancakes = 10,
	yogurtBerry = 8,
	yogurtVanilla = 8,
}

-- Inside the dome. Ground floor unless `y` says otherwise.
--[[
	Surface heights, derived rather than guessed.

	`fit` scales a model by its largest dimension, so every usable surface in here
	is a fixed fraction of that model's `fit` and can be worked out exactly:

	  LowTable    top is 2.59 of 9.44  -> 0.274 * fit -> 3.57 at fit 13
	  TableCloth  adds 0.24 of 14.01   -> 0.017 * fit -> 0.25 at fit 14.5
	  PicnicTable top is 3.79 of 14.78 -> 0.256 * fit -> 3.08 at fit 12

	These were previously eyeballed, and every one of them was low: the crockery
	sat 0.9 studs inside the table it was standing on and the cloth was buried in
	the tabletop with only its frill showing, which is the floating hem in the
	screenshot.
]]
SafeZone.SURFACE = {
	lowTable = 3.57,
	cloth = 3.82,
	picnicTable = 3.08,
}

SafeZone.interior = {
	{ asset = "lowTable", x = 0, z = -3, fit = 13, name = "LowTable" },
	{ asset = "tableCloth", x = 0, z = -3, fit = 14.5, y = SafeZone.SURFACE.lowTable, drapeOver = "LowTable" },
	{ asset = "floorCushion", x = -9, z = -3, fit = 5, yaw = 90 },
	{ asset = "floorCushion", x = 9, z = -3, fit = 5, yaw = -90 },
	{ asset = "floorCushion", x = 0, z = -12, fit = 5, yaw = 180 },

	-- On the table, in descending order of absurdity.
	{ asset = "ramen", x = 0, z = -3, fit = SafeZone.FOOD.ramen, y = SafeZone.SURFACE.cloth },
	{ asset = "teaPot", x = -5.5, z = 2.5, fit = 4.5, y = SafeZone.SURFACE.cloth },
	{ asset = "teaCup", x = 4.5, z = 3, fit = 2.4, y = SafeZone.SURFACE.cloth },
	{ asset = "teaCup", x = 6, z = 1.5, fit = 2.4, y = SafeZone.SURFACE.cloth },

	--[[
		On the floor, because they do not fit on the table.

		Both of these used to stand inside the staircase. STAIR sweeps azimuth
		128 to 260 at radius 23.5 with a width of 7.5, so it owns everything
		between radius 19.75 and 27.25 in that arc -- and the dango platter sat at
		azimuth 129.5 radius 22.0, the onigiri at azimuth 232.6 radius 21.4, which
		is to say both of them were in the stairs. They are now on the east and
		west of the room, in the arc the stair does not cross.
	]]
	{ asset = "dangoPlatter", x = 17, z = 10, fit = SafeZone.FOOD.dangoPlatter },
	{ asset = "onigiri", x = -16, z = 14, fit = SafeZone.FOOD.onigiri },
	{ asset = "kettle", x = -20, z = 3, fit = 5 },
} :: { Placement }

-- The garden, the path, and the market frontage at the gate.
SafeZone.exterior = {
	-- Two sakura framing the gate. Placed rather than scattered: this is the
	-- shot every player sees on their first frame outdoors.
	{ asset = "sakuraTree", x = -42, z = 62, fit = 54, yaw = 25 },
	{ asset = "sakuraTree", x = 42, z = 62, fit = 50, yaw = -40 },
	--[[
		The third sakura, behind the house. Moved out from (-20, -46): at 44 studs
		across, its canopy reached to 22.6 studs of the plot centre and the dome's
		shell is at 32, so the branches were growing through the roof.
	]]
	{ asset = "sakuraTree", x = -26, z = -54, fit = 44, yaw = 150 },

	-- The gate itself.
	{ asset = "lanternTall", x = -13, z = 99, fit = 22 },
	{ asset = "lanternTall", x = 13, z = 99, fit = 22 },
	{ asset = "mailBox", x = 19, z = 95, fit = 7, yaw = -20 },

	-- Household clutter down the west side. A home reads as lived in from the
	-- things left outside it, not from the things arranged inside it.
	{ asset = "laundryLine", x = -48, z = 8, fit = 30, yaw = 8 },

	--[[
		The watering can, and the thing it waters.

		Its spout points along the model's own -Z and sits near the top, so a can
		standing upright in an empty patch of lawn is a can nobody is using. Yawed
		to 180 the spout points up the garden, pitched forward it pours, and the
		two clumps below are what it pours onto.
	]]
	{ asset = "wateringCan", x = 24, z = 36, fit = 5, yaw = 180, pitch = -35 },
	{ asset = "grassPatch", x = 24, z = 42, fit = 9, sink = 0.6 },
	{ asset = "grassPatch", x = 28.5, z = 44, fit = 7, yaw = 40, sink = 0.6 },

	--[[
		The picnic table, and lunch. This is the set piece the path walks you
		past on the way out.

		Sized down from 26. `fit` is the largest dimension, and this model's is
		its 14.78-stud length, so 26 put a table 12.5 studs TALL next to a 5-stud
		character -- the tabletop alone was above their head. At 12 the top lands
		at 3.08, which is a table a Chiikawa can reach.

		Moved off the sakura at (42, 62) as well; at the old size and position the
		trunk came up through the middle of it.
	]]
	{ asset = "picnicTable", x = 52, z = 56, fit = 12, yaw = -22 },
	{ asset = "dango", x = 52, z = 56, fit = SafeZone.FOOD.dango, y = SafeZone.SURFACE.picnicTable, yaw = -22 },

	--[[
		The rest of lunch, on the grass, because SafeZone.FOOD means a stack of
		pancakes is 10 studs across and the tabletop is 5.6. Same joke as the
		interior floor, and the reason these are out here at all is that they were
		on the loft: breakfast nobody was ever going to see, up a spiral stair.
	]]
	{ asset = "yogurtVanilla", x = 42, z = 51, fit = SafeZone.FOOD.yogurtVanilla, pitch = 90 },
	{ asset = "pancakes", x = 66, z = 50, fit = SafeZone.FOOD.pancakes, yaw = 15 },
	{ asset = "yogurtBerry", x = 46, z = 68, fit = SafeZone.FOOD.yogurtBerry, yaw = -30 },

	-- Market frontage at the far end of the path. Both were about as big as the
	-- house; the dome is 37 tall and shopBlue was 32.
	{ asset = "shopBlue", x = -40, z = 100, fit = 20, yaw = 34 },
	{ asset = "shopRed", x = 40, z = 100, fit = 18, yaw = -34 },

	--[[
		The job booth. Yoroi-san hand out weeding and subjugation work from a
		desk, so the booth is the reason the plot has a gate at all -- you leave
		the house to take a job. `yoroiKnight` is rigged and animated behind it;
		see SafeZoneService.rigYoroi.

		The stall's back board sits at lower local X than its counter, so the
		model serves toward its own +X, and at yaw 118 it was serving the fence.
		Yawed to -20 the counter faces the path and angles up toward the gate.

		`fit` was 18 on a model whose largest dimension is its 9.2-stud height, so
		the booth was 18 studs tall and 6 wide -- a chimney with a counter.
	]]
	{ asset = "shopStall", x = -18, z = 76, fit = 12, yaw = -20, name = "JobBooth" },
	-- Sat clear of the attendant, which moved when the booth did.
	{ asset = "yoroiBeast", x = -29, z = 92, fit = 7, yaw = -140 },
} :: { Placement }

--[[
	Where the rigged Yoroi-san stands, and which way it faces.

	The rig is built facing its own -X: every part in the model carries a 90
	degree yaw, its arms and legs separate along Z, and its shoulder plates sit
	at lower X than its torso. Everything else on this plot is authored facing
	+Z, so the number here is 90 degrees out from what it looks like it says --
	which is why Yoroi-san was standing beside its own counter looking off across
	the garden. 160 turns it to face the same way the booth serves.

	Position is derived from the booth rather than set near it: two studs behind
	the counter's back face along the booth's own backward axis. It used to be
	5.8 studs from the booth's CENTRE, which on an 18-stud booth is inside it.
]]
SafeZone.YOROI = {
	booth = "JobBooth",
	--[[
		Position, in units of the booth's own half-extents rather than in studs.

		`alongCounter` runs down the booth's long axis; past 1.0 is past the end
		of it. `outFromCounter` runs across the serving side. Written this way so
		resizing or re-yawing the booth carries the attendant with it -- the
		previous version was a second pair of world coordinates that had to agree
		with the booth's and did not.
	]]
	--[[
		1.7, not 1.25. Both are "past the end of the counter", but the attendant
		is 5.7 studs deep and stands turned 180 to the booth, so its own box
		reaches back toward the stall -- at 1.25 the two still overlapped by 1.3
		studs, which is now something you can walk into rather than something
		that merely looks wrong. This leaves 1.4 studs of daylight.
	]]
	alongCounter = 1.7,
	outFromCounter = 0.35,
	--[[
		Turned to face the way the booth serves. 180 rather than 0 because the rig
		faces its own -X while the booth serves its own +X; see boothStation.
	]]
	facingOffset = 180,
	height = 8.5, -- deliberately taller than the player: they are the authority

	-- Used only if the booth failed to load and there is nothing to measure off.
	x = -18,
	z = 84,
	yaw = 160,
}

--------------------------------------------------------------------------------
-- Garden
--------------------------------------------------------------------------------

SafeZone.garden = {
	pathWidth = 14,
	pathFrom = 33,
	pathTo = 100,
	fenceInset = 8,
	fenceHeight = 5.5,
	postSpacing = 7.5,
	gateGap = 11, -- half-width of the opening the path passes through

	--[[
		Scatter. `grassPatch` is a 10-stud clump of blades.

		A jittered grid, not 22 random points. Random scatter at that count left
		most of the plot as bare ground with a few tufts on it, and raising the
		count alone does not fix it -- uniform random clumps and leaves holes. The
		grid guarantees coverage, the jitter takes the grid back out of it.

		`spacing` is the cell; clumps are sized to overlap their neighbours so the
		lawn is continuous. The model is 105 parts, so this is the one number here
		that costs real frame time: 16 studs over this plot is around 90 clumps
		once the path and the house are cut out of it.
	]]
	grassSpacing = 16,
	grassJitter = 5,
	grassFit = { 14, 20 },
	-- Clearance from the paving's outer edge. The path is 14 wide with a 1.2
	-- edging either side, so the pavement ends at 8.2 and grass starts just past.
	grassPathMargin = 1.5,
	lanternSpacing = 22, -- down both sides of the path
}

function SafeZone.profile(t: number): (number, number)
	local dome = SafeZone.DOME
	local angle = t * math.pi / 2
	return dome.radius * math.cos(angle) ^ dome.bulge, dome.height * math.sin(angle)
end

-- Interior radius at a given height, or 0 above the crown. Used to keep
-- furniture and the loft off the wall as it turns over.
function SafeZone.interiorRadiusAt(y: number): number
	local dome = SafeZone.DOME
	if y >= dome.height then
		return 0
	end
	local t = math.asin(math.clamp(y / dome.height, 0, 1)) / (math.pi / 2)
	local radius = select(1, SafeZone.profile(t))
	return math.max(radius - dome.wall, 0)
end

return SafeZone

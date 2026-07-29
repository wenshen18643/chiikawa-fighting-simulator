--[[
	Tunable constants. See docs/GAME.md.

	Every number here is a starting value to tune, not a balanced one. §18 lists
	the pacing targets these need to be fitted to (notably: Season 1 reachable in
	2-4 hours).

	PLACEMENT MATH DOES NOT LIVE HERE. This file holds scalars; anything that
	turns a scalar into a world position lives in Config/Layout.lua, which both
	realms call so the client's map cannot drift from the server's world.
]]

local Constants = {}

Constants.WORK = {
	-- §4: base gain before multipliers. All growth is multiplicative.
	BASE_GAIN = 1,

	--[[
		§13: server-side rate limit on work actions. Excess is dropped, never
		credited. The "No Limit"-style gamepass RAISES this cap, it does not
		remove it (§14 sells time, not an exploit surface).

		Raised from 8 when work became click-per-action. A person clicking hard
		peaks around 12-14/sec, and a cap below that silently eats real inputs —
		which is exactly the "my click did nothing" feeling the change is meant
		to remove. Autoclickers still hit the ceiling; that is its job.
	]]
	MAX_ACTIONS_PER_SECOND = 14,
	MAX_ACTIONS_PER_SECOND_GAMEPASS = 26,
	-- 0 = not published yet. Fill in the real asset id when the pass exists.
	NO_LIMIT_GAMEPASS_ID = 0,
	-- Burst allowance so a laggy client is not punished for a bunched send.
	ACTION_BURST = 8,

	--[[
		§4: AFK ticks at this fraction of the active rate. Idling is endorsed,
		not punished.

		THE knob for how much clicking is worth. At 0.5 a clicking player earns
		roughly 2x a player standing still, which is a deliberate call: the
		click earns its keep through feedback (FeedbackController) rather than
		through rate. Lower this if clicking should feel more decisive.
	]]
	AFK_RATE_FRACTION = 0.5,
	AFK_TICK_INTERVAL = 1,

	-- §13: how far outside a worksite part a player may be and still be
	-- credited, to absorb normal client-server position drift.
	POSITION_TOLERANCE = 8,

	-- Client-side guard against one physical click registering twice. Well
	-- under the human ceiling, so it never eats a real input.
	CLICK_DEBOUNCE = 0.05,

	--[[
		§5 TRAINING OFF A PAD.

		A worksite pad used to be a GATE: clicking anywhere else was refused
		outright, so a player who wanted to top up a neglected skill had to walk
		to the right district first and could not build a character freely.

		A pad is now a MULTIPLIER instead. Off a pad you still train — at this
		multiplier, with certifications, season, comfort and boosts all still
		applied — and a pad is worth x2 at tier 1 rising to x5000 at tier 7. The
		incentive to stand in a district is between two and five thousand times
		your open-ground rate, which never needed a wall to enforce.

		Raise this if open ground should stay competitive later in a run; the
		whole of that decision is this one number.
	]]
	OFF_PAD_MULTIPLIER = 1,
}

--[[
	The first certification slice: studying prepares the player for the canon
	Kusatori Grade 5 exam. Page flips are their own server-validated action;
	ordinary Work clicks and passive pad ticks never grant Exam Prep.
]]
Constants.STUDY = {
	SUBJECT = "kusatori",
	PAGE_BASE_GAIN = 2,
	DECK_MULTIPLIER = 2,
	FACT_CHANCE = 0.1,
	PREVIEW_DURATION = 1.5,
	CORRECT_PROGRESS = 0.2,
	LEARNING_PROGRESS = 0.08,
	FOCUS_BUFF_CHANCE = 0.15,
	FOCUS_BUFF_DURATION = 30,
	FOCUS_BUFF_MULTIPLIER = 2,
	EXAM_QUESTIONS = 5,
	EXAM_PASSING_ANSWERS = 4,
	REVIEW_AFTER_FAILURE = 2,
	PAGE_DEBOUNCE = 0.35,
}

--[[
	Foraging. Plucking an ingredient node is click-gated by kusatori
	(Config/Ingredients.lua): at the node's gateExponent it opens at minClicks,
	and each exponent you are short adds CLICKS_PER_EXPONENT_BEHIND clicks.
]]
Constants.FORAGE = {
	CLICKS_PER_EXPONENT_BEHIND = 3, -- under the gate, each missing kusatori exponent adds this many clicks
	-- Reach of one Work click, the same rule weeds use. Slightly longer than
	-- the weed radius because a sausage tree is a wide thing to stand next to.
	PULL_RADIUS = 14,
	CLUMP_SPREAD = 8, -- studs between the nodes inside one clump
	DIRT_PATCH_SIZE = 4.5, -- the dug soil left under a ground crop
}

--[[
	Cooking. Stirring a dish is click-gated by resilience: every resilience
	exponent shaves CLICKS_PER_RESILIENCE_EXPONENT clicks off baseClicks, down
	to MIN_CLICKS_FRACTION of the base. Each click invested also trains
	resilience, which is how the retired pads' skill is earned now.
]]
Constants.COOKING = {
	STATION_OFFSET_ANGLE = 270, -- degrees on the plaza, away from the safe-zone dome side
	STATION_OFFSET_RADIUS = 0.72, -- fraction of plaza radius
	STATION_RADIUS = 18, -- how close you must stand to cook
	MIN_CLICKS_FRACTION = 0.25, -- resilience can cut clicks to this fraction of base
	CLICKS_PER_RESILIENCE_EXPONENT = 1,
	MAX_CLICKS_PER_SECOND = 8,
	XP_PER_CLICK = 1, -- resilience gain per click invested, times gainPerAction
}

Constants.MOVEMENT = {
	--[[
		The world is ~27,000 studs across (Config/Layout.lua). Walking it at the
		Roblox default of 16 is not a design, it is a punishment.

		SPEC DEVIATION: §10 says sprint drains stamina. It does not. Stamina is
		the work-rate limiter, so charging travel to it means crossing your own
		world taxes your income — which reads as the game fining you for looking
		around. Sprint is free.
	]]
	WALK_SPEED = 16,
	SPRINT_SPEED = 30,
	-- Eased rather than snapped, so the change of pace is felt.
	SPEED_LERP = 0.18,
	JUMP_POWER = 52,

	--[[
		MOVEMENT TRAINS GRIT (§4).

		§4 defines Grit as endurance — "enduring a long shift, working while
		tired" — and it governs max stamina and regen. Running across a 27,000
		stud world is exactly that, so travel pays into it. Crossing the world
		on foot stops being dead time.

		Sized well under active clicking on purpose: one unit per 40 studs at
		sprint speed is ~0.75 units/sec against ~6/sec for a player clicking,
		and a Grit pad multiplies on top of that. Travel is a trickle, not a
		strategy.

		Free of stamina, for the same reason sprinting is (see above).
	]]
	STUDS_PER_GRIT_UNIT = 40,
	JUMP_GRIT_UNITS = 2,
	-- Stops a player bunny-hopping on the spot from out-earning a runner.
	JUMP_COOLDOWN = 0.6,

	TRAINING_TICK = 0.25,
	--[[
		Character position is replicated FROM the client, so it can be lied
		about. Any tick reporting movement faster than sprinting could plausibly
		produce is discarded rather than paid: that covers both exploits and the
		legitimate case of fast travel teleporting you 20,000 studs.
	]]
	MAX_PLAUSIBLE_SPEED_FACTOR = 1.6,
}

Constants.STAMINA = {
	BASE_MAX = 100,
	-- §4: Grit raises max stamina. Scales off log10 so an unbounded BigNum
	-- drives a bounded, readable bar.
	MAX_PER_GRIT_LOG = 25,

	-- Sized against MAX_ACTIONS_PER_SECOND: at the 14/sec cap this drains 14/sec
	-- against 6/sec regen, so a full bar buys ~12s of flat-out clicking before a
	-- 5s sit-down. Sustained realistic clicking (~6/sec) never runs dry at all,
	-- which is the intent: stamina catches autoclickers, not players.
	COST_PER_ACTION = 1.0,
	REGEN_PER_SECOND = 6,
	REGEN_PER_GRIT_LOG = 1.5,

	-- §2 rule 3 / §10: running out is a nap, not a punishment. The character
	-- sits down, keeps earning at the AFK rate, and gets up again.
	REST_DURATION = 5,
}

Constants.CURRENCY = {
	YEN = "yen",
	STAMPS = "stamps",

	-- §8: Yen is the volume currency. Passive wage pays per minute, credited in
	-- smaller slices so the HUD number moves.
	BASE_YEN_PER_MINUTE = 60,
	WAGE_TICK_INTERVAL = 5,

	-- §8: weeding also pays directly per pull, so active work beats idling on
	-- money as well as on skill.
	WEEDING_YEN_PER_GAIN = 0.25,

	STARTING_YEN = 0,
	STARTING_STAMPS = 0,
}

Constants.SEASON = {
	-- §9.7: each completed season multiplies all future skill gain by 10x.
	MULTIPLIER_BASE = 10,
}

Constants.HOME = {
	-- §9.6: furniture grants Comfort, a passive multiplier. Slice 6.
	BASE_COMFORT = 1,
}

Constants.DATA = {
	STORE_NAME = "PlayerProfiles_v1",
	KEY_PREFIX = "Player_",
	AUTOSAVE_INTERVAL = 60,
	LOAD_RETRIES = 4,
	RETRY_BACKOFF = 2,
	-- Bump when PlayerProfile changes shape; DataService.migrate handles the gap.
	SCHEMA_VERSION = 2,
}

Constants.REPLICATION = {
	-- Snapshot push rate. Skills are six small {m,e} pairs, so this is cheap.
	SNAPSHOT_INTERVAL = 0.4,
}

--[[
	Vertical layout. Everything built into the world derives from these two
	numbers rather than picking its own offset.

	Smooth terrain does NOT render a flat face at the fill boundary — marching
	cubes rounds the surface, so it can sit a stud or two above the nominal top.
	An earlier version filled terrain to y = 0 and put 1-stud pads at y = 0.6,
	which the rounded surface simply swallowed: the pads and the NPCs' legs were
	underneath the ground.

	So the terrain now stops well below the build level, and every platform is
	thick enough to be embedded in it AND clearly proud of it.
]]
Constants.WORLD = {
	TERRAIN_TOP = -2, -- terrain is filled up to here
	PLATFORM_TOP = 1, -- plazas and worksite pads all present this surface
	PLATFORM_THICKNESS = 4, -- deep enough to bury the bottom edge in terrain

	WORKSITE_SIZE = Vector3.new(56, 4, 56),
	WORKSITE_BORDER = 6, -- darker frame around each pad, for legibility

	--[[
		District ring. Each area fans its six skill districts around a central
		plaza; within a district the pads run OUTWARD in tier order, so walking
		deeper into a district is literally progressing up the ladder.

		Turned into positions by Config/Layout.lua.

		Both distances are BASE + a fraction of the area's size, not a pure
		fraction. A pure fraction put the Ruins' tier-1 pad 1,800 studs from the
		plaza — a two-minute walk to do the easiest thing in the game. Base
		keeps tier 1 just outside your front door in every area; the fraction
		makes the climb to tier 7 a real journey in the big ones.
	]]
	DISTRICT_INNER_RADIUS = 200, -- plaza centre to the tier-1 pad
	DISTRICT_RADIUS_FRACTION = 0.04, -- of islandSize, added to the above
	DISTRICT_PAD_SPACING = 96, -- between consecutive tiers
	DISTRICT_SPACING_FRACTION = 0.03, -- of islandSize, added to the above
	DISTRICT_PLATE_MARGIN = 34,
	DISTRICT_ARCH_SETBACK = 92, -- how far in front of the tier-1 pad the arch sits

	PLAZA_DIAMETER_FRACTION = 0.10, -- of islandSize
	PLAZA_MIN_DIAMETER = 170,

	-- How far above PLATFORM_TOP an NPC's feet rest.
	NPC_FOOT_CLEARANCE = 0.2,

	--[[
		Terrain. The world is one landmass ~27,000 studs long, so terrain is a
		SHELL, not a solid block: depth 8 rather than the old 16 roughly halves
		the voxel count across ~114 million square studs of ground, and nothing
		ever sees the inside of it.
	]]
	ISLAND_DEPTH = 8,
	SHORE_FALLOFF = 90, -- terrain skirt outside the walkable area

	--[[
		Terrain:FillBlock is bounded by the number of voxels one call may touch,
		and a 6,000-stud area is far past it. TerrainBuilder tiles every fill at
		this edge length (1024 studs = 256 x 256 cells per layer) and spends a
		frame budget between tiles so world generation never blocks the server.
	]]
	TERRAIN_TILE = 1024,

	-- Isthmus between neighbouring areas: the land bridge you physically walk
	-- across, and where the area gate stands.
	BRIDGE_GAP = 400,
	BRIDGE_WIDTH = 300,

	-- §2 rule 2 (nothing is lost): the OUTER perimeter of the whole landmass is
	-- fenced, and anything that gets past it is caught and put back rather than
	-- killed. There are no walls between areas any more — those are gates.
	WALL_HEIGHT = 140,
	WALL_THICKNESS = 12,
	HEDGE_HEIGHT = 6,
	VOID_Y = -60,

	-- Gate arch across an isthmus. Solid only for players who have not unlocked
	-- the area beyond, via a per-region collision group.
	GATE_HEIGHT = 46,
	GATE_PILLAR = 12,
}

--[[
	Streaming. The world is far too large to replicate whole, so Workspace runs
	with StreamingEnabled (set in default.project.json) and the client cannot
	assume any distant Instance exists.

	This is why Config/Layout.lua is a pure function of config rather than a
	scan of Workspace: the minimap and the guide arrow have to be right about
	places that are not loaded.
]]
Constants.STREAMING = {
	MIN_RADIUS = 256,
	TARGET_RADIUS = 1024,
}

return Constants

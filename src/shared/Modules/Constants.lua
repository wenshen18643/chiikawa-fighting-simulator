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

		FIVE CLICKS PER SECOND: fast enough to feel like clicking, still far
		short of an autoclicker. Inputs above 5/sec are eaten, and the client
		debounce below matches it so an over-rate click is never even sent.
	]]
	MAX_ACTIONS_PER_SECOND = 5,
	MAX_ACTIONS_PER_SECOND_GAMEPASS = 26,
	-- 0 = not published yet. Fill in the real asset id when the pass exists.
	NO_LIMIT_GAMEPASS_ID = 0,
	-- No burst: a bucket deeper than the rate would let a held-back client
	-- dump several actions at once, which is the thing the cap exists to stop.
	ACTION_BURST = 1,

	-- Client-side mirror of MAX_ACTIONS_PER_SECOND, with a small margin so a
	-- click that is legal locally is never dropped by the server bucket over
	-- network jitter. An over-rate click is refused here and never sent, so
	-- the player sees no feedback for it rather than a burst that earns nothing.
	CLICK_DEBOUNCE = 0.21,
}

--[[
	The book. Page flips are their own server-validated action; ordinary Work
	clicks never grant Exam Prep.

	PAGE_BASE_GAIN is deliberately one, not two. Exam Prep's certification order
	is the ceiling on every other skill's, so the stat that gates the game must
	not also be the fastest one to raise: at two, a page every PAGE_DEBOUNCE
	beats five clicks a second.
]]
Constants.STUDY = {
	PAGE_BASE_GAIN = 1,
	FACT_CHANCE = 0.1,
	PREVIEW_DURATION = 1.5,
	CORRECT_PROGRESS = 0.2,
	LEARNING_PROGRESS = 0.08,
	FOCUS_BUFF_CHANCE = 0.15,
	FOCUS_BUFF_DURATION = 30,
	FOCUS_BUFF_MULTIPLIER = 2,
	PAGE_DEBOUNCE = 0.35,
}

-- Sitting an exam at the Exam Hall desk. Only Kusatori is quizzed; the rest are
-- decided by the stat value, the Exam Prep cap, and Exam Prep's item cost.
Constants.EXAM = {
	QUESTIONS = 5,
	PASSING_ANSWERS = 4,
	REVIEW_AFTER_FAILURE = 2,
	QUIZ_SKILL = "kusatori",
	PROMPT_DISTANCE = 14,
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
	STATION_RADIUS = 18, -- how close you must stand to cook
	MIN_CLICKS_FRACTION = 0.25, -- resilience can cut clicks to this fraction of base
	CLICKS_PER_RESILIENCE_EXPONENT = 1,
	MAX_CLICKS_PER_SECOND = 1,
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

	-- INERT AT THE CURRENT CAP. This was sized against a 14/sec action rate,
	-- where a full bar bought ~12s of flat-out clicking. At MAX_ACTIONS_PER_SECOND
	-- = 1 the drain is 1/sec against 6/sec regen, so the bar never falls: stamina
	-- no longer gates anything. Raise COST_PER_ACTION (or cut REGEN_PER_SECOND)
	-- if stamina should still be a real cost at one click per second.
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
	FARM_MAILBOX_STORE_NAME = "FarmCredits_v1",
	KEY_PREFIX = "Player_",
	AUTOSAVE_INTERVAL = 60,
	LOAD_RETRIES = 4,
	RETRY_BACKOFF = 2,
	-- Bump when PlayerProfile changes shape; DataService.migrate handles the gap.
	SCHEMA_VERSION = 4,
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
	PLATFORM_TOP = 1, -- plazas all present this surface
	PLATFORM_THICKNESS = 4, -- deep enough to bury the bottom edge in terrain

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

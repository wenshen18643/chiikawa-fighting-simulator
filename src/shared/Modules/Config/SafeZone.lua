--[[
	The cottage you spawn in, as data. See docs/GAME.md §9.6 and §2.

	SPEC NOTE: §9.6 puts the player's home in Slice 6. It arrives here instead,
	because it is the first thing anyone ever sees and because the safe volume
	has to exist before combat does — not after. Furniture, Comfort and home
	visits are still Slice 6; this is the building and the protection.

	§0 NOTE: an original round-shouldered cottage in the same tonal register as
	the reference material — cream plaster, a domed roof, round windows. No
	character designs, no proper nouns. That is the Path B homage §0 recommends,
	and it is the only thing this file has to say about it.

	Everything is described as plain numbers and colours here so the shape of the
	house can be changed without touching the builder, exactly like Worksites and
	Npcs. SafeZoneService turns it into parts.

	Coordinates are relative to the cottage origin, which sits on the Town plaza:
	  +Z is toward the front door, +Y is up, +X is to the right as you leave.
]]

local SafeZone = {}

--------------------------------------------------------------------------------
-- Shell
--------------------------------------------------------------------------------

SafeZone.WIDTH = 46 -- along X
SafeZone.DEPTH = 42 -- along Z
SafeZone.WALL = 1.5
SafeZone.FLOOR_HEIGHT = 14 -- generous: a Roblox character is 5 studs tall and
-- a low ceiling makes an interior feel like a crawlspace
SafeZone.FLOOR_SLAB = 1.5
SafeZone.FLOORS = 3

-- Door and window openings, measured on the front (+Z) wall.
SafeZone.DOOR_WIDTH = 10
SafeZone.DOOR_HEIGHT = 11
SafeZone.WINDOW_RADIUS = 4.2

--[[
	Stairs. Each floor is climbed by a run of steps against the -X wall. A
	Roblox humanoid steps over anything up to its HipHeight (about 2 studs), so
	1.75 is comfortably walkable in both directions without a ramp.
]]
SafeZone.STEP_RISE = 1.75
SafeZone.STEP_RUN = 3.2
SafeZone.STEP_WIDTH = 9

--------------------------------------------------------------------------------
-- Palette
--------------------------------------------------------------------------------

SafeZone.palette = {
	plaster = Color3.fromRGB(246, 238, 224),
	plasterShade = Color3.fromRGB(232, 220, 202),
	roof = Color3.fromRGB(206, 126, 104),
	roofDeep = Color3.fromRGB(178, 100, 84),
	timber = Color3.fromRGB(150, 116, 84),
	timberDark = Color3.fromRGB(118, 88, 64),
	floor = Color3.fromRGB(214, 186, 152),
	glass = Color3.fromRGB(198, 226, 238),
	hearth = Color3.fromRGB(96, 88, 82),
	fabric = Color3.fromRGB(238, 196, 186),
	leaf = Color3.fromRGB(126, 190, 104),
	lamp = Color3.fromRGB(255, 226, 168),
}

--------------------------------------------------------------------------------
-- The safe volume
--------------------------------------------------------------------------------

--[[
	The protected box: the cottage plus its front garden, extending above the
	roof so nothing can reach in over the top.

	Deliberately larger than the building. A safe zone whose edge is the front
	wall means the moment you open the door you are exposed, which turns your own
	doorstep into the most dangerous tile in the game.
]]
SafeZone.VOLUME = {
	size = Vector3.new(124, 108, 116),
	-- Pushed toward +Z so the garden in front of the door is inside it.
	centreOffset = Vector3.new(0, 44, 18),
}

-- Where a player is put down: just inside the front door, facing into the room.
SafeZone.SPAWN_OFFSET = Vector3.new(0, 3, 13)
-- Where travelling to Town lands you: on the doorstep, facing out at the world.
SafeZone.DOORSTEP_OFFSET = Vector3.new(0, 3, 40)

--------------------------------------------------------------------------------
-- Furnishing
--------------------------------------------------------------------------------

--[[
	One row per object. `floor` is 0-based from the ground. `kind` is dispatched
	in SafeZoneService.furnish; adding a chair is a row here, never a new script.

	Kinds: slab, post, table, stool, futon, shelf, rug, hearth, lamp, plant,
	crate, certificateBoard, railing.
]]
SafeZone.furniture = {
	-- Ground floor: the kitchen and the table you eat at.
	{ kind = "hearth", floor = 0, x = -15, z = -14 },
	{ kind = "table", floor = 0, x = 8, z = -6, radius = 6 },
	{ kind = "stool", floor = 0, x = 1, z = -6 },
	{ kind = "stool", floor = 0, x = 15, z = -6 },
	{ kind = "stool", floor = 0, x = 8, z = -13 },
	{ kind = "shelf", floor = 0, x = 20, z = -15, width = 10 },
	{ kind = "crate", floor = 0, x = 18, z = 6 },
	{ kind = "crate", floor = 0, x = 18, z = 10, scale = 0.7 },
	{ kind = "rug", floor = 0, x = 0, z = 8, radius = 11 },
	{ kind = "plant", floor = 0, x = -19, z = 12 },
	{ kind = "lamp", floor = 0, x = 0, z = -1 },

	-- Loft: where you sleep, and where §6's certificates will hang.
	{ kind = "futon", floor = 1, x = -12, z = 8 },
	{ kind = "lamp", floor = 1, x = -12, z = -2 },
	{ kind = "certificateBoard", floor = 1, x = 21, z = 0, width = 26 },
	{ kind = "shelf", floor = 1, x = 4, z = -16, width = 14 },
	{ kind = "rug", floor = 1, x = -6, z = 4, radius = 8 },
	{ kind = "plant", floor = 1, x = 16, z = 14 },

	-- Attic deck: nothing but a railing and the view. §2 rule 6 — the reward
	-- for climbing your own house is that it was worth climbing.
	{ kind = "railing", floor = 2 },
	{ kind = "lamp", floor = 2, x = 0, z = 0 },
}

--------------------------------------------------------------------------------
-- Garden
--------------------------------------------------------------------------------

SafeZone.garden = {
	pathWidth = 12,
	pathLength = 34,
	fenceInset = 6, -- from the edge of the safe volume
	fenceHeight = 5,
	postSpacing = 9,
	plantCount = 14,
}

function SafeZone.totalHeight(): number
	return SafeZone.FLOORS * (SafeZone.FLOOR_HEIGHT + SafeZone.FLOOR_SLAB)
end

function SafeZone.floorY(index: number): number
	-- Top surface of the slab the given floor stands on. Floor 0's slab is the
	-- ground slab, so its walking surface is one slab up from the base.
	return index * (SafeZone.FLOOR_HEIGHT + SafeZone.FLOOR_SLAB) + SafeZone.FLOOR_SLAB
end

return SafeZone

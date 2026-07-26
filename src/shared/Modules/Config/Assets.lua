--[[
	Uploaded model ids for world decor. Transcribed from docs/ASSETS.md, which
	stays the human-facing list; this is the one the game reads.

	--------------------------------------------------------------------------
	WHY THESE ARE OPTIONAL
	--------------------------------------------------------------------------

	Everything here has a procedural fallback in Areas/Area.lua. An id that is
	0, or that fails to load, costs nothing but the nicer model: the world still
	builds, in the same places, out of parts. That is deliberate — this project
	greyboxes from Config and a missing upload must never be the difference
	between a world and a hole in the ground.

	A blank id is therefore a valid state, not a bug. AssetService lists them at
	startup so they are discoverable rather than mysterious.

	--------------------------------------------------------------------------
	WHAT LOADS AND WHAT DOES NOT
	--------------------------------------------------------------------------

	InsertService:LoadAsset only succeeds for assets that are free/public OR
	owned by the account that owns the place. A private model belonging to
	somebody else fails no matter what the id says, and it fails at runtime on a
	live server rather than at build time — which is why every load is pcall'd
	and every failure is a warning plus a fallback, never an error.

	`kind` tells AssetService what it is holding:
		"model"  a single thing. Cloned as-is.
		"pack"   a container of many things. Cloned one random child at a time,
		         chosen by name at runtime, because nobody here knows what is
		         inside a given pack and guessing child names is the same
		         mistake as guessing ids.
]]

local Assets = {}

export type AssetSpec = {
	id: number,
	kind: string,
	-- Multiplied onto the model after load. Uploaded models arrive at whatever
	-- scale their author chose, which is rarely this world's scale.
	scale: number?,
	-- Decor is non-colliding by default; set true for things worth bumping into.
	collide: boolean?,
}

Assets.MODELS = {
	-- Still blank in docs/ASSETS.md. These fall back to their procedural
	-- versions; wiring is in place, so filling an id in here is the only step.
	tree = { id = 0, kind = "model", scale = 1 },
	grass = { id = 0, kind = "model", scale = 1 },
	stone = { id = 0, kind = "model", scale = 1 },

	log = { id = 9731248486, kind = "model", scale = 1 },
	bush = { id = 11337757315, kind = "model", scale = 1 },
	house = { id = 136868946197723, kind = "model", scale = 1, collide = true },
	terrain = { id = 97974769788038, kind = "model", scale = 1 },
	naturePack = { id = 71032774784968, kind = "pack", scale = 1 },
} :: { [string]: AssetSpec }

function Assets.get(key: string): AssetSpec?
	return Assets.MODELS[key]
end

-- Keys with an id worth attempting a load for.
function Assets.configured(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if spec.id and spec.id > 0 then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

-- Keys still waiting on an id, for the startup report.
function Assets.blank(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if not spec.id or spec.id <= 0 then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

return Assets

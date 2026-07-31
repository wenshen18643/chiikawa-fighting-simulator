--[[
	Who is available to follow you around, and where each one comes from.

	--------------------------------------------------------------------------
	TWO SOURCES, ONE ROSTER
	--------------------------------------------------------------------------

	`kind = "mascot"` reuses an NPC's own `build` out of Config/Npcs, so the
	friend walking behind you is the character you met in town rather than a
	lookalike -- one definition, two placements. These always work: they are
	parts, and parts cannot fail to download.

	`kind = "asset"` is an uploaded model from Config/Assets. It is the nicer
	option and the fragile one: a free model can be taken down, moderated, or
	turned private by its author, at which point `AssetService.clone` starts
	returning nil. Anything listed this way must therefore be droppable from the
	menu at runtime without leaving a hole -- CompanionService filters the
	roster it sends to the client by what actually loaded.

	--------------------------------------------------------------------------
	IDS ARE SAVED ON THE PROFILE
	--------------------------------------------------------------------------

	`id` is written to `profile.companions.selected` and read back on the next
	join, so renaming one silently resets whoever had it chosen. Add and
	deprecate; do not rename.
]]

local Companions = {}

export type CompanionSpec = {
	id: string,
	name: string,
	blurb: string,
	kind: "mascot" | "asset" | "built",
	-- kind == "mascot": whose silhouette to build, by Config/Npcs id.
	npcId: string?,
	-- kind == "asset": which Config/Assets entry to clone.
	assetKey: string?,
	--[[
		kind == "asset", and only when that entry is a `pack`: a
		case-insensitive substring of the child to pick out of it. Nothing
		matches -> any child, so a wrong guess degrades to a random one.
	]]
	assetMatch: string?,
	--[[
		Art correction on top of the automatic fit, for `kind = "asset"` only.

		AssetService normalises every upload to the same HEIGHT, which is the
		only measure that survives not knowing how a model was authored. It is
		not the same as looking the same size: a round character and a flat one
		at equal height differ by their depth, and the round one reads as much
		bigger because it carries the volume to match.

		So this is a taste value, not a computed one. 1 (or absent) means take
		the automatic fit.
	]]
	scale: number?,
	skill: string?,
	--[[
		kind == "built": a creature assembled from primitives by MobRig, named
		by its Config/Mobs id. The third source, and the only one that is
		neither an upload nor a member of the cast -- a Sporeling is not a
		mascot and never had a model to download.
	]]
	mobId: string?,
	--[[
		Earned rather than offered. A locked companion is filtered out of the
		roster until profile.companions.owned holds its id, which is the only
		thing in this file the server has to check twice.
	]]
	locked: boolean?,
}

-- The "walk alone" sentinel, offered as the last row of the menu.
Companions.NONE = "none"

Companions.LIST = {
	{
		id = "chiikawa",
		name = "Chiikawa",
		blurb = "Small, worried, and right behind you.",
		kind = "asset",
		--[[
			No `assetMatch`: this one is served from assets/Models/Chiikawa.rbxmx
			rather than fetched, and it is exactly one character. It used to be a
			bundle of plushies behind one id, where the pack path had to guess
			which child was actually Chiikawa -- a coin flip that is now simply
			not a question being asked.
		]]
		assetKey = "chiikawa",
		skill = "resilience",
	},
	{
		id = "hachiware",
		name = "Hachiware",
		blurb = "Blue-eared and unbothered.",
		kind = "asset",
		assetKey = "hachiware",
		--[[
			Height-fitted this one comes out 3.45 x 4.00 x 3.54 against
			Chiikawa's 3.05 x 4.00 x 1.95: the same height carrying twice the
			volume, because it is round where Chiikawa is flat. That is what
			made it read as the big one.

			0.86 rather than the 0.79 that would equalise volume outright.
			Matching volume also takes the on-screen silhouette down to 0.71 of
			Chiikawa's, which overshoots into looking SMALLER; 0.86 cuts the
			bulk (2.05 -> 1.31) while keeping height and silhouette close.
		]]
		scale = 0.86,
		skill = "examprep",
	},
	{
		id = "usagi",
		name = "Usagi",
		blurb = "Says one thing, loudly, forever.",
		kind = "asset",
		assetKey = "usagi",
		skill = "tobatsu",
	},
	--[[
		The one you carry out of the cave. Built from the same MobRig recipe as
		the ones that puffed spores at you on level one, at a size that reads as
		"the little one", so the friend behind you is visibly the thing you were
		fighting an hour ago.
	]]
	{
		id = "sporeling",
		name = "Sporeling",
		blurb = "It followed you up. It has not explained why.",
		kind = "built",
		mobId = "cave_sporeling",
		locked = true,
		skill = "tobatsu",
	},
} :: { CompanionSpec }

--[[
	What an unavailable choice falls back to. A player who has never opened
	the menu gets Companions.NONE instead -- see selectionFor.

	MUST BE SOMETHING THAT CANNOT FAIL TO LOAD. It is the end of the fallback
	chain: if the default itself is unavailable, a player gets no companion and
	a warning instead of a friend.

	This used to say "MUST be `kind = "mascot"`", because a mascot is built out
	of parts by Config/Npcs and so cannot be moderated away, whereas an upload
	can go private overnight. That reasoning still holds for uploads -- it just
	no longer picks out mascots specifically. `chiikawa` is served from
	assets/Models/Chiikawa.rbxmx, committed to this repo, so it makes no web
	call and has no uploader who can withdraw it. It is as unfailable as a
	mascot was, and it is the character the game is named after.

	If this is ever pointed at `hachiware` or `usagi`, restore the old rule:
	those two are still fetched by id and can vanish.
]]
Companions.DEFAULT = "chiikawa"

function Companions.get(id: string): CompanionSpec?
	for _, spec in Companions.LIST do
		if spec.id == id then
			return spec
		end
	end
	return nil
end

return Companions

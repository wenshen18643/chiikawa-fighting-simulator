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
	kind: "mascot" | "asset",
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
}

--[[
	The "no companion" sentinel.

	NO LONGER OFFERED IN THE MENU -- it was removed from LIST, so `Companions.get`
	does not resolve it and `CompanionService.select` will reject it. The
	constant stays because CompanionService still reads it in `spawn` and
	`select` as the "walk alone" state, and because a save written before the
	roster was trimmed can still hold it (`selectionFor` falls through to
	DEFAULT in that case, so those players quietly gain a companion).

	Deleting the constant means deleting that handling too. Left in place so
	re-offering the option is a one-line change to LIST rather than a rewrite.
]]
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
	},
	{
		id = "usagi",
		name = "Usagi",
		blurb = "Says one thing, loudly, forever.",
		kind = "asset",
		assetKey = "usagi",
	},
} :: { CompanionSpec }

--[[
	What a player who has never opened the menu gets, and what an unavailable
	choice falls back to.

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

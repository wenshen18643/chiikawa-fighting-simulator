local Companions = {}

export type CompanionSpec = {
	id: string,
	name: string,
	blurb: string,
	kind: "mascot" | "asset" | "built",
	npcId: string?,
	assetKey: string?,

	scale: number?,
	skill: string?,
	mobId: string?,
	locked: boolean?,
}

Companions.NONE = "none"

Companions.LIST = {
	{
		id = "chiikawa",
		name = "Chiikawa",
		blurb = "Small, worried, and right behind you.",
		kind = "asset",
		assetKey = "chiikawa",
		skill = "resilience",
	},
	{
		id = "hachiware",
		name = "Hachiware",
		blurb = "Blue-eared and unbothered.",
		kind = "asset",
		assetKey = "hachiware",

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

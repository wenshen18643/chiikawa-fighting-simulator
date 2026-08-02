local FACTS = {
	"Chiikawa is gentle, sweet, and kind.",
	"Chiikawa is shy and sometimes cries when feeling nervous.",
	"Hachiware and Usagi are Chiikawa's closest friends.",
	"Hachiware has a big heart and a cheerful can-do attitude.",
	"Hachiware tries to find the bright side of a difficult moment.",
	"Hachiware helps Chiikawa feel safe when things get scary.",
	"Hachiware has cat-like ears, but may not actually be a cat.",
	"Usagi is the most energetic member of the familiar trio.",
	"Usagi's signature calls include “Yaha!” and “Ura!”.",
	"The Japanese word usagi means rabbit.",
	"Even with bunny-like ears, Usagi's exact identity is a mystery.",
	"No one knows where Usagi lives.",
	"Momonga is known for wide eyes and a large fluffy tail.",
	"Momonga can fly.",
	"Momonga often uses cuteness to try to get their way.",
	"Rakko is the top-ranked leader among the monster hunters.",
	"Rakko is highly skilled with a sword.",
	"Rakko helps Chiikawa and friends improve their hunting skills.",
	"Rakko has a soft spot for sweet treats.",
	"Kurimanju is often seen enjoying a snack with a favourite drink.",
	"Quiet Kurimanju kindly shares food with friends.",
	"Shisa's design is inspired by guardians from the Ryukyu Islands.",
	"Shisa passed the difficult super part-time worker qualification.",
	"Shisa assists the chef at the ramen shop Rou.",
	"Furuhonya is a kind bookworm who trades secondhand books.",
	"Furuhonya and Momonga are friends.",
	"Furuhonya's crab-shaped headband was a gift from Momonga.",
	"Pochette no Yoroi-san loves cute things and makes handmade pajamas.",
	"Roudou no Yoroi-san is responsible for handing out work assignments.",
	"Ramen no Yoroi-san owns Rou, where Shisa works as an assistant.",
}

local ChiikawaFacts = {}

ChiikawaFacts.COUNT = #FACTS
assert(ChiikawaFacts.COUNT == 30, "ChiikawaFacts must contain exactly 30 facts")

function ChiikawaFacts.get(factId: number?): string?
	if type(factId) ~= "number" or factId % 1 ~= 0 then
		return nil
	end
	return FACTS[factId]
end

function ChiikawaFacts.pickId(rng: Random, previousId: number?): number
	if previousId and previousId >= 1 and previousId <= ChiikawaFacts.COUNT then
		local factId = rng:NextInteger(1, ChiikawaFacts.COUNT - 1)
		return if factId >= previousId then factId + 1 else factId
	end
	return rng:NextInteger(1, ChiikawaFacts.COUNT)
end

return ChiikawaFacts

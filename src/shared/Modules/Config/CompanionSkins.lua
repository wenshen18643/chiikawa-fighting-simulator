--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinLooks = require(Shared.Modules.Config.SkinLooks)
local CompanionSkins = {}

export type RarityId = "common" | "uncommon" | "rare" | "epic" | "legendary"
export type DrawId = "standard" | "premium"

export type RarityDefinition = {
	id: RarityId,
	name: string,
	order: number,
	color: Color3,
	resaleYen: number,
	multiplier: number,
}

export type DrawDefinition = {
	id: DrawId,
	name: string,
	cost: number,
	weights: { [string]: number },
}

export type CharacterDefinition = {
	id: string,
	name: string,
	skills: { string },
}

export type SkinDefinition = {
	id: string,
	name: string,
	characterId: string,
	rarity: RarityId,
	showcase: boolean?,
	assetKey: string?,
	scale: number?,
}

export type ProfileState = {
	copies: { [string]: number },
	equipped: { [string]: string },
	rarePlusMisses: number,
	legendaryMisses: number,
}

CompanionSkins.CAPACITY = 60
CompanionSkins.RARE_PLUS_PITY = 10
CompanionSkins.LEGENDARY_PITY = 100
CompanionSkins.ALLOWED_BATCHES = { [1] = true, [10] = true }

local RARITY_ORDER: { RarityId } = {
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
}
CompanionSkins.RARITY_ORDER = RARITY_ORDER

CompanionSkins.RARITIES = {
	common = {
		id = "common",
		name = "Common",
		order = 1,
		color = Color3.fromRGB(178, 158, 152),
		resaleYen = 100,
		multiplier = 1.05,
	},
	uncommon = {
		id = "uncommon",
		name = "Uncommon",
		order = 2,
		color = Color3.fromRGB(158, 210, 138),
		resaleYen = 250,
		multiplier = 1.10,
	},
	rare = {
		id = "rare",
		name = "Rare",
		order = 3,
		color = Color3.fromRGB(150, 202, 244),
		resaleYen = 600,
		multiplier = 1.18,
	},
	epic = {
		id = "epic",
		name = "Epic",
		order = 4,
		color = Color3.fromRGB(198, 182, 238),
		resaleYen = 1500,
		multiplier = 1.28,
	},
	legendary = {
		id = "legendary",
		name = "Legendary",
		order = 5,
		color = Color3.fromRGB(248, 202, 106),
		resaleYen = 5000,
		multiplier = 1.40,
	},
} :: { [string]: RarityDefinition }

CompanionSkins.DRAWS = {
	standard = {
		id = "standard",
		name = "Standard Draw",
		cost = 1000,
		weights = { common = 60, uncommon = 25, rare = 10, epic = 4, legendary = 1 },
	},
	premium = {
		id = "premium",
		name = "Premium Draw",
		cost = 2500,
		weights = { common = 55, uncommon = 25, rare = 10, epic = 5, legendary = 5 },
	},
} :: { [string]: DrawDefinition }

CompanionSkins.CHARACTER_ORDER = { "chiikawa", "hachiware", "usagi" }
CompanionSkins.CHARACTERS = {
	chiikawa = {
		id = "chiikawa",
		name = "Chiikawa",
		skills = { "resilience", "kusatori" },
	},
	hachiware = {
		id = "hachiware",
		name = "Hachiware",
		skills = { "examprep", "resilience" },
	},
	usagi = {
		id = "usagi",
		name = "Usagi",
		skills = { "tobatsu", "kusatori" },
	},
} :: { [string]: CharacterDefinition }

local skins = {} :: { SkinDefinition }
for _, entry in SkinLooks.ENTRIES do
	if not CompanionSkins.CHARACTERS[entry.characterId] then
		continue
	end
	if not CompanionSkins.RARITIES[entry.rarity] then
		continue
	end
	table.insert(skins, {
		id = entry.id,
		name = entry.name,
		characterId = entry.characterId,
		rarity = (entry.rarity :: any) :: RarityId,
		showcase = entry.showcase,
		assetKey = nil,
		scale = nil,
	})
end
CompanionSkins.SKINS = skins

local byId = {} :: { [string]: SkinDefinition }
local byRarity = {} :: { [string]: { SkinDefinition } }
local dropPool = {} :: { [string]: { SkinDefinition } }
for _, rarityId in RARITY_ORDER do
	byRarity[rarityId] = {}
	dropPool[rarityId] = {}
end
for _, skin in skins do
	byId[skin.id] = skin
	table.insert(byRarity[skin.rarity], skin)
	if not skin.showcase then
		table.insert(dropPool[skin.rarity], skin)
	end
end
for _, rarityId in RARITY_ORDER do
	if #dropPool[rarityId] == 0 then
		dropPool[rarityId] = byRarity[rarityId]
	end
end

CompanionSkins.BY_RARITY = byRarity

function CompanionSkins.poolSize(rarityId: string, includeShowcase: boolean?): number
	local pool = if includeShowcase then byRarity[rarityId] else dropPool[rarityId]
	return if pool then #pool else 0
end

function CompanionSkins.forCharacter(characterId: string): { SkinDefinition }
	local out = {}
	for _, skin in skins do
		if skin.characterId == characterId then
			table.insert(out, skin)
		end
	end
	return out
end

local function finiteInteger(value: unknown, maximum: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, maximum)
end

function CompanionSkins.get(id: string): SkinDefinition?
	return byId[id]
end

function CompanionSkins.getDraw(id: string): DrawDefinition?
	return CompanionSkins.DRAWS[id :: DrawId]
end

function CompanionSkins.getRarity(id: string): RarityDefinition?
	return CompanionSkins.RARITIES[id :: RarityId]
end

function CompanionSkins.getState(profile: any): ProfileState?
	local state = profile.companionSkins
	return if type(state) == "table" then state :: ProfileState else nil
end

function CompanionSkins.totalCopies(state: ProfileState): number
	local total = 0
	for _, count in state.copies do
		total += count
	end
	return total
end

function CompanionSkins.isEquipped(state: ProfileState, skinId: string): boolean
	for _, equippedId in state.equipped do
		if equippedId == skinId then
			return true
		end
	end
	return false
end

function CompanionSkins.equippedSkin(profile: any, characterId: string): SkinDefinition?
	local state = CompanionSkins.getState(profile)
	if not state then
		return nil
	end
	local skinId = state.equipped[characterId]
	local skin = if skinId then byId[skinId] else nil
	if skin and skin.characterId == characterId and (state.copies[skin.id] or 0) > 0 then
		return skin
	end
	return nil
end

function CompanionSkins.bestOwnedRarity(profile: any, characterId: string): RarityDefinition?
	local state = CompanionSkins.getState(profile)
	if not state then
		return nil
	end

	local best: RarityDefinition? = nil
	for skinId, count in state.copies do
		local skin = if count > 0 then byId[skinId] else nil
		if skin and skin.characterId == characterId then
			local rarity = CompanionSkins.RARITIES[skin.rarity]
			if not best or rarity.order > best.order then
				best = rarity
			end
		end
	end
	return best
end

function CompanionSkins.activeMultiplier(profile: any, skillId: string): number
	local companions = profile.companions
	local selected = if type(companions) == "table" then companions.selected else nil
	if type(selected) ~= "string" then
		return 1
	end

	local character = CompanionSkins.CHARACTERS[selected]
	if not character then
		return 1
	end

	local affectsSkill = false
	for _, configuredSkill in character.skills do
		if configuredSkill == skillId then
			affectsSkill = true
			break
		end
	end
	if not affectsSkill then
		return 1
	end

	local rarity = CompanionSkins.bestOwnedRarity(profile, selected)
	return if rarity then rarity.multiplier else 1
end

function CompanionSkins.rollRarity(draw: DrawDefinition, minimumOrder: number, rng: Random): RarityId
	local total = 0
	for _, rarityId in RARITY_ORDER do
		local rarity = CompanionSkins.RARITIES[rarityId]
		if rarity.order >= minimumOrder then
			total += draw.weights[rarityId]
		end
	end

	local roll = rng:NextNumber() * total
	for _, rarityId in RARITY_ORDER do
		local rarity = CompanionSkins.RARITIES[rarityId]
		if rarity.order >= minimumOrder then
			roll -= draw.weights[rarityId]
			if roll <= 0 then
				return (rarityId :: any) :: RarityId
			end
		end
	end
	return "legendary"
end

function CompanionSkins.rollSkin(rarityId: string, rng: Random): SkinDefinition
	local pool = dropPool[rarityId]
	return pool[rng:NextInteger(1, #pool)]
end

function CompanionSkins.reconcileProfile(profile: any): ProfileState
	local raw = profile.companionSkins
	if type(raw) ~= "table" then
		raw = {}
	end

	local copies = {} :: { [string]: number }
	local rawCopies = raw.copies
	if type(rawCopies) == "table" then
		for skinId, value in rawCopies do
			if type(skinId) == "string" and byId[skinId] then
				local count = finiteInteger(value, CompanionSkins.CAPACITY)
				if count > 0 then
					copies[skinId] = count
				end
			end
		end
	end

	local equipped = {} :: { [string]: string }
	local rawEquipped = raw.equipped
	if type(rawEquipped) == "table" then
		for characterId, skinId in rawEquipped do
			if type(characterId) == "string" and type(skinId) == "string" then
				local skin = byId[skinId]
				if skin and skin.characterId == characterId and (copies[skinId] or 0) > 0 then
					equipped[characterId] = skinId
				end
			end
		end
	end

	local state: ProfileState = {
		copies = copies,
		equipped = equipped,
		rarePlusMisses = finiteInteger(raw.rarePlusMisses, CompanionSkins.RARE_PLUS_PITY - 1),
		legendaryMisses = finiteInteger(raw.legendaryMisses, CompanionSkins.LEGENDARY_PITY - 1),
	}

	local excess = CompanionSkins.totalCopies(state) - CompanionSkins.CAPACITY
	if excess > 0 then
		for _, rarityId in RARITY_ORDER do
			for _, skin in byRarity[rarityId] do
				local count = state.copies[skin.id] or 0
				local reserved = if CompanionSkins.isEquipped(state, skin.id) then 1 else 0
				local removable = math.min(math.max(count - reserved, 0), excess)
				if removable > 0 then
					local remaining = count - removable
					if remaining > 0 then
						state.copies[skin.id] = remaining
					else
						state.copies[skin.id] = nil
					end
					excess -= removable
				end
				if excess <= 0 then
					break
				end
			end
			if excess <= 0 then
				break
			end
		end
	end

	profile.companionSkins = state
	return state
end

return CompanionSkins

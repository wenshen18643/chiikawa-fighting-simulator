--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local WeaponLooks = require(Shared.Modules.Config.WeaponLooks)
local WeaponSkins = {}

export type RarityId = CompanionSkins.RarityId
export type DrawId = CompanionSkins.DrawId
export type RarityDefinition = CompanionSkins.RarityDefinition
export type DrawDefinition = CompanionSkins.DrawDefinition

export type WeaponDefinition = {
	id: string,
	name: string,
}

export type OriginDefinition = {
	id: string,
	name: string,
}

export type SkinDefinition = {
	id: string,
	name: string,
	weaponId: string,
	rarity: RarityId,
	origin: string,
	blurb: string,
	showcase: boolean?,
}

export type OwnedView = {
	copies: { [string]: number },
	equipped: { [string]: string },
}

export type ProfileState = {
	copies: { [string]: number },
	equipped: { [string]: string },
	rarePlusMisses: number,
	legendaryMisses: number,
}

WeaponSkins.CAPACITY = CompanionSkins.CAPACITY
WeaponSkins.RARE_PLUS_PITY = CompanionSkins.RARE_PLUS_PITY
WeaponSkins.LEGENDARY_PITY = CompanionSkins.LEGENDARY_PITY
WeaponSkins.ALLOWED_BATCHES = CompanionSkins.ALLOWED_BATCHES
WeaponSkins.RARITY_ORDER = CompanionSkins.RARITY_ORDER
WeaponSkins.RARITIES = CompanionSkins.RARITIES
WeaponSkins.DRAWS = CompanionSkins.DRAWS

WeaponSkins.SLOT = "weapon"
WeaponSkins.DEFAULT_SKIN_ID = WeaponLooks.DEFAULT_ID

WeaponSkins.ORIGIN_ORDER = { "canon", "cool", "cute" }
WeaponSkins.ORIGINS = {
	canon = { id = "canon", name = "From the show" },
	cool = { id = "cool", name = "Original · cool" },
	cute = { id = "cute", name = "Original · cute" },
} :: { [string]: OriginDefinition }

WeaponSkins.WEAPONS = {
	sasumata = { id = "sasumata", name = "Sasumata" },
	club = { id = "club", name = "Club" },
	staff = { id = "staff", name = "Discharge Rod" },
	sword = { id = "sword", name = "Sword" },
	binyoyo = { id = "binyoyo", name = "Binyoyo" },
	mallet = { id = "mallet", name = "Mallet" },
	morningstar = { id = "morningstar", name = "Morningstar" },
	axe = { id = "axe", name = "Axe" },
	wand = { id = "wand", name = "Wand" },
} :: { [string]: WeaponDefinition }

local skins = {} :: { SkinDefinition }
for _, entry in WeaponLooks.ENTRIES do
	if not WeaponSkins.WEAPONS[entry.weaponId] then
		continue
	end
	if not WeaponSkins.RARITIES[entry.rarity] then
		continue
	end
	table.insert(skins, {
		id = entry.id,
		name = entry.name,
		weaponId = entry.weaponId,
		rarity = (entry.rarity :: any) :: RarityId,
		origin = entry.origin,
		blurb = entry.blurb,
		showcase = entry.showcase,
	})
end
WeaponSkins.SKINS = skins

local byId = {} :: { [string]: SkinDefinition }
local byRarity = {} :: { [string]: { SkinDefinition } }
local dropPool = {} :: { [string]: { SkinDefinition } }
for _, rarityId in WeaponSkins.RARITY_ORDER do
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
for _, rarityId in WeaponSkins.RARITY_ORDER do
	if #dropPool[rarityId] == 0 then
		dropPool[rarityId] = byRarity[rarityId]
	end
end

WeaponSkins.BY_RARITY = byRarity

function WeaponSkins.poolSize(rarityId: string, includeShowcase: boolean?): number
	local pool = if includeShowcase then byRarity[rarityId] else dropPool[rarityId]
	return if pool then #pool else 0
end

local function finiteInteger(value: unknown, maximum: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, maximum)
end

function WeaponSkins.get(id: string): SkinDefinition?
	return byId[id]
end

function WeaponSkins.getWeapon(id: string): WeaponDefinition?
	return WeaponSkins.WEAPONS[id]
end

function WeaponSkins.getOrigin(id: string): OriginDefinition?
	return WeaponSkins.ORIGINS[id]
end

function WeaponSkins.getDraw(id: string): DrawDefinition?
	return WeaponSkins.DRAWS[id :: DrawId]
end

function WeaponSkins.getRarity(id: string): RarityDefinition?
	return WeaponSkins.RARITIES[id :: RarityId]
end

function WeaponSkins.getState(profile: any): ProfileState?
	local state = profile.weaponSkins
	return if type(state) == "table" then state :: ProfileState else nil
end

function WeaponSkins.totalCopies(state: ProfileState): number
	local total = 0
	for _, count in state.copies do
		total += count
	end
	return total
end

function WeaponSkins.isEquipped(state: OwnedView, skinId: string): boolean
	return state.equipped[WeaponSkins.SLOT] == skinId
end

function WeaponSkins.reservedCopies(state: OwnedView, skinId: string): number
	if skinId == WeaponSkins.DEFAULT_SKIN_ID or WeaponSkins.isEquipped(state, skinId) then
		return 1
	end
	return 0
end

function WeaponSkins.sellableCopies(state: OwnedView, skinId: string): number
	local owned = state.copies[skinId] or 0
	return math.max(owned - WeaponSkins.reservedCopies(state, skinId), 0)
end

function WeaponSkins.equippedSkin(profile: any): SkinDefinition?
	local state = WeaponSkins.getState(profile)
	if not state then
		return nil
	end
	local skinId = state.equipped[WeaponSkins.SLOT]
	local skin = if skinId then byId[skinId] else nil
	if skin and (state.copies[skin.id] or 0) > 0 then
		return skin
	end
	return nil
end

function WeaponSkins.rollRarity(draw: DrawDefinition, minimumOrder: number, rng: Random): RarityId
	return CompanionSkins.rollRarity(draw, minimumOrder, rng)
end

function WeaponSkins.rollSkin(rarityId: string, rng: Random): SkinDefinition
	local pool = dropPool[rarityId]
	return pool[rng:NextInteger(1, #pool)]
end

function WeaponSkins.reconcileProfile(profile: any): ProfileState
	local raw = profile.weaponSkins
	if type(raw) ~= "table" then
		raw = {}
	end

	local copies = {} :: { [string]: number }
	local rawCopies = raw.copies
	if type(rawCopies) == "table" then
		for skinId, value in rawCopies do
			if type(skinId) == "string" and byId[skinId] then
				local count = finiteInteger(value, WeaponSkins.CAPACITY)
				if count > 0 then
					copies[skinId] = count
				end
			end
		end
	end

	local default = WeaponSkins.DEFAULT_SKIN_ID
	copies[default] = math.max(copies[default] or 0, 1)

	local equipped = {} :: { [string]: string }
	local rawEquipped = raw.equipped
	if type(rawEquipped) == "table" then
		local candidate = rawEquipped[WeaponSkins.SLOT]
		if type(candidate) ~= "string" then
			candidate = rawEquipped.sasumata
		end
		if type(candidate) == "string" and byId[candidate] and (copies[candidate] or 0) > 0 then
			equipped[WeaponSkins.SLOT] = candidate
		end
	end
	if not equipped[WeaponSkins.SLOT] then
		equipped[WeaponSkins.SLOT] = default
	end

	local state: ProfileState = {
		copies = copies,
		equipped = equipped,
		rarePlusMisses = finiteInteger(raw.rarePlusMisses, WeaponSkins.RARE_PLUS_PITY - 1),
		legendaryMisses = finiteInteger(raw.legendaryMisses, WeaponSkins.LEGENDARY_PITY - 1),
	}

	local excess = WeaponSkins.totalCopies(state) - WeaponSkins.CAPACITY
	if excess > 0 then
		for _, rarityId in WeaponSkins.RARITY_ORDER do
			for _, skin in byRarity[rarityId] do
				local count = state.copies[skin.id] or 0
				local removable = math.min(WeaponSkins.sellableCopies(state, skin.id), excess)
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

	profile.weaponSkins = state
	return state
end

return WeaponSkins

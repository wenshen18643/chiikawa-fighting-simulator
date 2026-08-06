--!strict

local CompanionSkins = require(script.Parent.CompanionSkins)
local WeaponSkins = {}

export type RarityId = CompanionSkins.RarityId
export type DrawId = CompanionSkins.DrawId
export type RarityDefinition = CompanionSkins.RarityDefinition
export type DrawDefinition = CompanionSkins.DrawDefinition

export type WeaponDefinition = {
	id: string,
	name: string,
	baseName: string,
}

export type SkinDefinition = {
	id: string,
	name: string,
	weaponId: string,
	rarity: RarityId,
	primary: Color3,
	secondary: Color3,
	accent: Color3,
	material: Enum.Material,
	accentMaterial: Enum.Material,
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

WeaponSkins.WEAPON_ORDER = { "sasumata" }
WeaponSkins.WEAPONS = {
	sasumata = {
		id = "sasumata",
		name = "Sasumata",
		baseName = "Classic Pink",
	},
} :: { [string]: WeaponDefinition }

WeaponSkins.SKINS = {
	{
		id = "sasumata_common_01",
		name = "Strawberry Patrol",
		weaponId = "sasumata",
		rarity = "common",
		primary = Color3.fromRGB(243, 167, 193),
		secondary = Color3.fromRGB(226, 124, 158),
		accent = Color3.fromRGB(252, 247, 240),
		material = Enum.Material.SmoothPlastic,
		accentMaterial = Enum.Material.SmoothPlastic,
	},
	{
		id = "sasumata_uncommon_01",
		name = "Melon Defender",
		weaponId = "sasumata",
		rarity = "uncommon",
		primary = Color3.fromRGB(137, 216, 167),
		secondary = Color3.fromRGB(66, 151, 105),
		accent = Color3.fromRGB(235, 255, 224),
		material = Enum.Material.SmoothPlastic,
		accentMaterial = Enum.Material.Neon,
	},
	{
		id = "sasumata_rare_01",
		name = "Tidal Guardian",
		weaponId = "sasumata",
		rarity = "rare",
		primary = Color3.fromRGB(104, 192, 244),
		secondary = Color3.fromRGB(44, 105, 184),
		accent = Color3.fromRGB(224, 247, 255),
		material = Enum.Material.Metal,
		accentMaterial = Enum.Material.Neon,
	},
	{
		id = "sasumata_epic_01",
		name = "Wisteria Moon",
		weaponId = "sasumata",
		rarity = "epic",
		primary = Color3.fromRGB(182, 139, 235),
		secondary = Color3.fromRGB(103, 67, 168),
		accent = Color3.fromRGB(245, 225, 255),
		material = Enum.Material.Metal,
		accentMaterial = Enum.Material.Neon,
	},
	{
		id = "sasumata_legendary_01",
		name = "Rakko's Golden Fang",
		weaponId = "sasumata",
		rarity = "legendary",
		primary = Color3.fromRGB(247, 199, 74),
		secondary = Color3.fromRGB(207, 86, 56),
		accent = Color3.fromRGB(255, 247, 192),
		material = Enum.Material.Metal,
		accentMaterial = Enum.Material.Neon,
	},
} :: { SkinDefinition }

local byId = {} :: { [string]: SkinDefinition }
local byRarity = {} :: { [string]: { SkinDefinition } }
for _, rarityId in WeaponSkins.RARITY_ORDER do
	byRarity[rarityId] = {}
end
for _, skin in WeaponSkins.SKINS do
	byId[skin.id] = skin
	table.insert(byRarity[skin.rarity], skin)
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

function WeaponSkins.isEquipped(state: ProfileState, skinId: string): boolean
	for _, equippedId in state.equipped do
		if equippedId == skinId then
			return true
		end
	end
	return false
end

function WeaponSkins.equippedSkin(profile: any, weaponId: string): SkinDefinition?
	local state = WeaponSkins.getState(profile)
	if not state then
		return nil
	end
	local skinId = state.equipped[weaponId]
	local skin = if skinId then byId[skinId] else nil
	if skin and skin.weaponId == weaponId and (state.copies[skin.id] or 0) > 0 then
		return skin
	end
	return nil
end

function WeaponSkins.rollRarity(draw: DrawDefinition, minimumOrder: number, rng: Random): RarityId
	return CompanionSkins.rollRarity(draw, minimumOrder, rng)
end

function WeaponSkins.rollSkin(rarityId: string, rng: Random): SkinDefinition
	local pool = byRarity[rarityId]
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

	local equipped = {} :: { [string]: string }
	local rawEquipped = raw.equipped
	if type(rawEquipped) == "table" then
		for weaponId, skinId in rawEquipped do
			if type(weaponId) == "string" and type(skinId) == "string" then
				local skin = byId[skinId]
				if skin and skin.weaponId == weaponId and (copies[skinId] or 0) > 0 then
					equipped[weaponId] = skinId
				end
			end
		end
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
				local reserved = if WeaponSkins.isEquipped(state, skin.id) then 1 else 0
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

	profile.weaponSkins = state
	return state
end

return WeaponSkins

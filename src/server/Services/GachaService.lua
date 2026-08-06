--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local GachaMachine = require(script.Parent.GachaMachine)
local CompanionService = require(script.Parent.CompanionService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local ReplicationService = require(script.Parent.ReplicationService)

type ProfileState = CompanionSkins.ProfileState
type SkinDefinition = CompanionSkins.SkinDefinition

local GachaService = {}

local function copyStringNumberMap(source: { [string]: number }): { [string]: number }
	return table.clone(source)
end

local function copyStringMap(source: { [string]: string }): { [string]: string }
	return table.clone(source)
end

local function bestByCharacter(profile: any): { [string]: string }
	local result = {}
	for _, characterId in CompanionSkins.CHARACTER_ORDER do
		local rarity = CompanionSkins.bestOwnedRarity(profile, characterId)
		if rarity then
			result[characterId] = rarity.id
		end
	end
	return result
end

local function buildState(profile: any, state: ProfileState): { [string]: any }
	local companions = profile.companions
	return {
		yen = profile.currencies.yen,
		unlimitedYen = CurrencyService.isUnlimited("yen"),
		capacity = CompanionSkins.CAPACITY,
		used = CompanionSkins.totalCopies(state),
		copies = copyStringNumberMap(state.copies),
		equipped = copyStringMap(state.equipped),
		rarePlusMisses = state.rarePlusMisses,
		legendaryMisses = state.legendaryMisses,
		bestByCharacter = bestByCharacter(profile),
		selectedCharacter = if type(companions) == "table" then companions.selected else nil,
	}
end

local function parseEquip(request: unknown): any
	if type(request) ~= "table" then
		return nil
	end
	local payload = request :: { [string]: unknown }
	local characterId = payload.characterId
	local skinId = payload.skinId
	if
		type(characterId) ~= "string"
		or not CompanionSkins.CHARACTERS[characterId]
		or (skinId ~= nil and type(skinId) ~= "string")
	then
		return nil
	end
	return { characterId = characterId, skinId = skinId }
end

local function equip(_profile: any, state: ProfileState, request: any): (boolean, string?)
	local characterId = request.characterId
	local skinId = request.skinId
	if skinId then
		local skin = CompanionSkins.get(skinId)
		if not skin or skin.characterId ~= characterId or (state.copies[skinId] or 0) <= 0 then
			return false, "You do not own that skin for this companion."
		end
		state.equipped[characterId] = skinId
	else
		state.equipped[characterId] = nil
	end
	return true, nil
end

local function afterEquip(player: Player, profile: any, _state: ProfileState)
	local companions = profile.companions
	if type(companions) == "table" and type(companions.selected) == "string" then
		CompanionService.refreshAppearance(player)
	end
end

local function sellableCopies(state: ProfileState, item: GachaMachine.ItemDefinition): number
	local skin = (item :: any) :: SkinDefinition
	local owned = state.copies[skin.id] or 0
	local reserved = if state.equipped[skin.characterId] == skin.id then 1 else 0
	return math.max(owned - reserved, 0)
end

function GachaService.init()
	local domain: GachaMachine.DomainConfig = {
		id = "CompanionGacha",
		remoteCategory = "Gacha",
		npcName = "GachaGuy",
		npcDisplayName = "Gacha Guy",
		promptName = "GachaPrompt",
		promptAction = "Draw skins",
		signTitle = "Companion Skins",
		signSubtitle = "draw · equip · trade back",
		itemNoun = "skin",
		capacity = CompanionSkins.CAPACITY,
		rarePlusPity = CompanionSkins.RARE_PLUS_PITY,
		legendaryPity = CompanionSkins.LEGENDARY_PITY,
		allowedBatches = CompanionSkins.ALLOWED_BATCHES,

		getState = function(profile)
			return CompanionSkins.getState(profile)
		end,

		buildState = function(profile, state)
			return buildState(profile, state :: ProfileState)
		end,

		totalCopies = function(state)
			return CompanionSkins.totalCopies(state :: ProfileState)
		end,

		getDraw = function(id)
			return CompanionSkins.getDraw(id) :: any
		end,

		getItem = function(id)
			return CompanionSkins.get(id) :: any
		end,

		getRarity = function(id)
			return CompanionSkins.getRarity(id) :: any
		end,

		rollRarity = function(draw, minimumOrder, rng)
			return CompanionSkins.rollRarity(draw, minimumOrder, rng)
		end,

		rollItem = function(rarityId, rng)
			return CompanionSkins.rollSkin(rarityId, rng) :: any
		end,
		parseEquip = parseEquip,

		equip = function(profile, state, request)
			return equip(profile, state :: ProfileState, request)
		end,

		afterEquip = function(player, profile, state)
			afterEquip(player, profile, state :: ProfileState)
		end,

		sellableCopies = function(state, item)
			return sellableCopies(state :: ProfileState, item)
		end,
	}

	local newMachine = GachaMachine.new(domain, {
		CurrencyService = CurrencyService,
		DataService = DataService,
		NotifyService = NotifyService,
		ReplicationService = ReplicationService,
	})
	newMachine:Init()
end

return GachaService

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponSkins = require(Shared.Modules.Config.WeaponSkins)
local GachaMachine = require(script.Parent.GachaMachine)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local ReplicationService = require(script.Parent.ReplicationService)

type ProfileState = WeaponSkins.ProfileState
type SkinDefinition = WeaponSkins.SkinDefinition

local WeaponGachaService = {}
local WEAPON_ID = "sasumata"
local ATTRIBUTE = "WeaponSkinId"
local playerConnections: { [Player]: RBXScriptConnection } = {}

local function copyStringNumberMap(source: { [string]: number }): { [string]: number }
	return table.clone(source)
end

local function copyStringMap(source: { [string]: string }): { [string]: string }
	return table.clone(source)
end

local function buildState(profile: any, state: ProfileState): { [string]: any }
	return {
		yen = profile.currencies.yen,
		unlimitedYen = CurrencyService.isUnlimited("yen"),
		capacity = WeaponSkins.CAPACITY,
		used = WeaponSkins.totalCopies(state),
		copies = copyStringNumberMap(state.copies),
		equipped = copyStringMap(state.equipped),
		rarePlusMisses = state.rarePlusMisses,
		legendaryMisses = state.legendaryMisses,
	}
end

local function applyAppearance(player: Player, profile: any?)
	local character = player.Character
	if not character then
		return
	end
	local loadedProfile = profile or DataService.get(player)
	local skin = loadedProfile and WeaponSkins.equippedSkin(loadedProfile, WEAPON_ID)
	character:SetAttribute(ATTRIBUTE, if skin then skin.id else nil)
end

local function bindPlayer(player: Player)
	if playerConnections[player] then
		return
	end
	playerConnections[player] = player.CharacterAdded:Connect(function()
		task.defer(applyAppearance, player, nil)
	end)
	if player.Character then
		task.defer(applyAppearance, player, nil)
	end
end

local function parseEquip(request: unknown): any
	if type(request) ~= "table" then
		return nil
	end
	local payload = request :: { [string]: unknown }
	local weaponId = payload.weaponId
	local skinId = payload.skinId
	if
		type(weaponId) ~= "string"
		or not WeaponSkins.WEAPONS[weaponId]
		or (skinId ~= nil and type(skinId) ~= "string")
	then
		return nil
	end
	return { weaponId = weaponId, skinId = skinId }
end

local function equip(_profile: any, state: ProfileState, request: any): (boolean, string?)
	local weaponId = request.weaponId
	local skinId = request.skinId
	if skinId then
		local skin = WeaponSkins.get(skinId)
		if not skin or skin.weaponId ~= weaponId or (state.copies[skinId] or 0) <= 0 then
			return false, "You do not own that skin for this weapon."
		end
		state.equipped[weaponId] = skinId
	else
		state.equipped[weaponId] = nil
	end
	return true, nil
end

local function sellableCopies(state: ProfileState, item: GachaMachine.ItemDefinition): number
	local skin = (item :: any) :: SkinDefinition
	local owned = state.copies[skin.id] or 0
	local reserved = if state.equipped[skin.weaponId] == skin.id then 1 else 0
	return math.max(owned - reserved, 0)
end

function WeaponGachaService.init()
	local domain: GachaMachine.DomainConfig = {
		id = "WeaponGacha",
		remoteCategory = "WeaponGacha",
		npcName = "WeaponsGachaGuy",
		npcDisplayName = "Weapons Gacha Guy",
		promptName = "WeaponGachaPrompt",
		promptAction = "Draw weapon skins",
		signTitle = "Weapon Skins",
		signSubtitle = "draw · equip · trade back",
		itemNoun = "weapon skin",
		capacity = WeaponSkins.CAPACITY,
		rarePlusPity = WeaponSkins.RARE_PLUS_PITY,
		legendaryPity = WeaponSkins.LEGENDARY_PITY,
		allowedBatches = WeaponSkins.ALLOWED_BATCHES,

		getState = function(profile)
			return WeaponSkins.getState(profile)
		end,

		buildState = function(profile, state)
			return buildState(profile, state :: ProfileState)
		end,

		totalCopies = function(state)
			return WeaponSkins.totalCopies(state :: ProfileState)
		end,

		getDraw = function(id)
			return WeaponSkins.getDraw(id) :: any
		end,

		getItem = function(id)
			return WeaponSkins.get(id) :: any
		end,

		getRarity = function(id)
			return WeaponSkins.getRarity(id) :: any
		end,

		rollRarity = function(draw, minimumOrder, rng)
			return WeaponSkins.rollRarity(draw, minimumOrder, rng)
		end,

		rollItem = function(rarityId, rng)
			return WeaponSkins.rollSkin(rarityId, rng) :: any
		end,
		parseEquip = parseEquip,

		equip = function(profile, state, request)
			return equip(profile, state :: ProfileState, request)
		end,

		afterEquip = function(player, profile, _state)
			applyAppearance(player, profile)
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

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local connection = playerConnections[player]
		if connection then
			connection:Disconnect()
			playerConnections[player] = nil
		end
	end)
	DataService.onLoaded(function(player, profile)
		bindPlayer(player)
		applyAppearance(player, profile)
	end)
end

return WeaponGachaService

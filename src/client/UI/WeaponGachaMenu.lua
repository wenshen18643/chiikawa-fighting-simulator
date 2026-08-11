--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponSkins = require(Shared.Modules.Config.WeaponSkins)
local GachaMenuCore = require(script.Parent.GachaMenuCore)
local WeaponPreview = require(script.Parent.WeaponPreview)

return GachaMenuCore.new({
	catalog = WeaponSkins,
	preview = WeaponPreview,
	isWeapon = true,
	menuId = "weapon-gacha",
	flowInputLock = "weapon-gacha-flow",
	screenName = "WeaponGachaMenu",
	displayOrder = 12,
	remoteCategory = "WeaponGacha",
	npcName = "WeaponsGachaGuy",
	promptName = "WeaponGachaPrompt",
})

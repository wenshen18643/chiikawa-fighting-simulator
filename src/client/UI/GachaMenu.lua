--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local GachaMenuCore = require(script.Parent.GachaMenuCore)
local SkinPreview = require(script.Parent.SkinPreview)

return GachaMenuCore.new({
	catalog = CompanionSkins,
	preview = SkinPreview,
	isWeapon = false,
	menuId = "gacha",
	flowInputLock = "gacha-flow",
	screenName = "GachaMenu",
	displayOrder = 11,
	remoteCategory = "Gacha",
	npcName = "GachaGuy",
	promptName = "GachaPrompt",
})

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cave = require(Shared.Modules.Config.Cave)
local CaveController = {}
local LEVEL_ATTRIBUTE = "CaveLevel"
local LANTERN_ATTRIBUTE = "HasLantern"
local FADE = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local surface = Cave.SURFACE_LIGHT
local currentLevel = -1
local connections: { RBXScriptConnection } = {}

local function applyLevel(index: number, hasLantern: boolean)
	if index == currentLevel then
		return
	end
	currentLevel = index

	local target = surface
	local level = Cave.get(index)
	if level then
		local light = level.light
		local lift = if hasLantern then 0.55 else 0
		target = {
			ambient = light.ambient:Lerp(Color3.fromRGB(150, 146, 160), lift),
			outdoorAmbient = light.outdoorAmbient:Lerp(Color3.fromRGB(120, 118, 132), lift),
			brightness = light.brightness + lift,
			fogEnd = light.fogEnd + lift * 120,
			fogColor = light.fogColor,
		}
	end

	TweenService:Create(Lighting, FADE, {
		Ambient = target.ambient,
		OutdoorAmbient = target.outdoorAmbient,
		Brightness = target.brightness,
		FogEnd = target.fogEnd,
		FogColor = target.fogColor,
	}):Play()
end

local function readCharacter(character: Model)
	local level = character:GetAttribute(LEVEL_ATTRIBUTE)
	local lantern = character:GetAttribute(LANTERN_ATTRIBUTE) == true
	applyLevel(if type(level) == "number" then level else 0, lantern)
end

local function bind(character: Model)
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}

	for _, attribute in { LEVEL_ATTRIBUTE, LANTERN_ATTRIBUTE } do
		table.insert(
			connections,
			character:GetAttributeChangedSignal(attribute):Connect(function()
				currentLevel = -1
				readCharacter(character)
			end)
		)
	end

	currentLevel = -1
	readCharacter(character)
end

function CaveController.init()
	local player = Players.LocalPlayer
	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)

	player.CharacterRemoving:Connect(function()
		applyLevel(0, false)
	end)
end

function CaveController.level(): number
	return math.max(currentLevel, 0)
end

return CaveController

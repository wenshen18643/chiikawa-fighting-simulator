--[[
	Underground lighting, and the cave map layer.

	--------------------------------------------------------------------------
	ONE ATTRIBUTE DRIVES BOTH
	--------------------------------------------------------------------------

	CaveService keeps `CaveLevel` current on the character: 0 above ground, 1-3
	below. Attributes replicate on change, so this costs nothing while a player
	is walking around town and fires exactly once when they cross a floor.

	Lighting is a SWAP, not a per-frame effect. Each level's numbers come out of
	Config/Cave and are tweened onto Lighting when the level changes; there is
	no render loop here and nothing to switch off.

	The darkness on the bottom floor is real, and the lantern is what answers
	it. Without one, level three is lit only by what grows there.
]]

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

local surface: {
	ambient: Color3,
	outdoorAmbient: Color3,
	brightness: number,
	fogEnd: number,
	fogColor: Color3,
}

local currentLevel = -1
local connections: { RBXScriptConnection } = {}

--[[
	Captured once, at boot, before anything underground has touched Lighting.

	Read back rather than hardcoded: the surface look is somebody else's to
	tune, and a cave that restores its own guess at daylight would quietly undo
	every change they make.
]]
local function captureSurface()
	surface = {
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
		brightness = Lighting.Brightness,
		fogEnd = Lighting.FogEnd,
		fogColor = Lighting.FogColor,
	}
end

--[[
	The lantern does not brighten the world; it brightens what the PLAYER can
	see, and the light itself is a real PointLight the server welds on. What
	this does is lift the floor of the ambient so the lantern has something to
	fall off into, rather than a black wall a foot from the flame.
]]
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

	-- Both matter: crossing a floor changes which numbers apply, and earning the
	-- lantern changes them without the player moving at all.
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
	captureSurface()

	local player = Players.LocalPlayer
	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)

	--[[
		Dying underground puts the player back in town, and a character that
		never got its attribute set would otherwise keep the cave's fog on the
		surface until they walked back in.
	]]
	player.CharacterRemoving:Connect(function()
		applyLevel(0, false)
	end)
end

function CaveController.level(): number
	return math.max(currentLevel, 0)
end

return CaveController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Companions = require(Shared.Modules.Config.Companions)
local Remotes = require(Shared.Modules.Remotes)

local CompanionShelfController = {}

local COMPANION_ID_ATTRIBUTE = "CompanionId"
local STAND_TIMEOUT = 60

local plushies: Instance? = nil
local taken: string? = nil
local authored: { [Instance]: number } = {}

local function veil(instance: Instance, away: boolean)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = if away then 1 else 0
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		if authored[instance] == nil then
			authored[instance] = instance.Transparency
		end
		instance.Transparency = if away then 1 else authored[instance]
	end
end

local function apply()
	local shelf = plushies
	if not shelf then
		return
	end

	for _, plushie in shelf:GetChildren() do
		local away = taken ~= nil and plushie:GetAttribute(COMPANION_ID_ATTRIBUTE) == taken
		veil(plushie, away)
		for _, descendant in plushie:GetDescendants() do
			veil(descendant, away)
		end
	end
end

function CompanionShelfController.init()
	Remotes.event("Companion", "Shelf").OnClientEvent:Connect(function(id)
		taken = if type(id) == "string" and id ~= Companions.NONE then id else nil
		apply()
	end)

	task.spawn(function()
		local companions = Workspace:WaitForChild("Companions", STAND_TIMEOUT)
		local stand = companions and companions:WaitForChild("FriendStand", STAND_TIMEOUT)
		local shelf = stand and stand:WaitForChild("Plushies", STAND_TIMEOUT)
		if not shelf then
			warn("[CompanionShelf] the friend stand never appeared - the shelf will not empty")
			return
		end

		plushies = shelf
		apply()
		shelf.ChildAdded:Connect(apply)
		shelf.DescendantAdded:Connect(apply)
	end)
end

return CompanionShelfController

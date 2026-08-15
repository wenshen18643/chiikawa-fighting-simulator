--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Remotes = require(Shared.Modules.Remotes)
local LibraryBuilder = require(script.Parent.LibraryBuilder)
local WorldService = require(script.Parent.WorldService)
local StudioFirst = require(script.Parent.Parent.StudioFirst)
local LibraryService = {}
local PROMPT_DISTANCE = 10
local CLOSE_DISTANCE = 32

local function bindPrompt(prompt: ProximityPrompt, anchorPosition: Vector3, openRemote: RemoteEvent)
	prompt.Name = "LibraryPrompt"
	prompt.ActionText = "Study"
	prompt.ObjectText = "Peach Study Library"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false

	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player, {
			anchorPosition = anchorPosition,
			closeDistance = CLOSE_DISTANCE,
		})
	end)
end

local function attachPrompt(root: BasePart, anchorPosition: Vector3, openRemote: RemoteEvent)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Parent = root
	bindPrompt(prompt, anchorPosition, openRemote)
end

function LibraryService.init()
	local area = Areas.get(Areas.STARTING_AREA)
	local regionFolder = WorldService.getRegionFolder(Areas.STARTING_AREA)
	if not area or not regionFolder then
		warn("[LibraryService] starting region is unavailable; Peach Study Library was not built")
		return
	end

	local openRemote = Remotes.event("Library", "Open")
	local existing = regionFolder:FindFirstChild("PeachStudyLibrary")
	if existing and StudioFirst.shouldPreserve(existing) then
		local anchorPosition = if existing:IsA("Model")
			then existing:GetPivot().Position
			else Layout.libraryCFrame(area).Position
		local bound = 0
		for _, descendant in existing:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and descendant.Name == "LibraryPrompt" then
				bindPrompt(descendant, anchorPosition, openRemote)
				bound += 1
			end
		end
		if bound > 0 then
			return
		end
	end

	local built = LibraryBuilder.build(regionFolder, Layout.libraryCFrame(area))
	for _, root in built.stationRoots do
		attachPrompt(root, built.anchorPosition, openRemote)
	end
end

return LibraryService

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)
local Remotes = require(Shared.Modules.Remotes)
local LibraryBuilder = require(script.Parent.LibraryBuilder)
local WorldService = require(script.Parent.WorldService)
local LibraryService = {}
local PROMPT_DISTANCE = 10
local CLOSE_DISTANCE = 32

local function attachPrompt(root: BasePart, anchorPosition: Vector3, openRemote: RemoteEvent)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LibraryPrompt"
	prompt.ActionText = "Study"
	prompt.ObjectText = "Peach Study Library"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player, {
			anchorPosition = anchorPosition,
			closeDistance = CLOSE_DISTANCE,
		})
	end)
end

function LibraryService.init()
	local area = Areas.get(Areas.STARTING_AREA)
	local regionFolder = WorldService.getRegionFolder(Areas.STARTING_AREA)
	if not area or not regionFolder then
		warn("[LibraryService] starting region is unavailable; Peach Study Library was not built")
		return
	end

	local built = LibraryBuilder.build(regionFolder, Layout.libraryCFrame(area))
	local openRemote = Remotes.event("Library", "Open")
	for _, root in built.stationRoots do
		attachPrompt(root, built.anchorPosition, openRemote)
	end
end

return LibraryService

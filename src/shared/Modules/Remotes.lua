local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_TREE = {
	Work = {
		Perform = "RemoteEvent",
		Feedback = "RemoteEvent",
		SelectSkill = "RemoteEvent",
	},
	State = {
		Snapshot = "RemoteEvent",
	},
	Region = {
		RequestTravel = "RemoteEvent",
		Entered = "RemoteEvent",
	},
	SafeZone = {
		Changed = "RemoteEvent",
	},
	Notify = {
		Message = "RemoteEvent",
	},
	Companion = {
		Open = "RemoteEvent",
		Select = "RemoteEvent",
		Act = "RemoteEvent",
		Shelf = "RemoteEvent",
	},
	Study = {
		Page = "RemoteEvent",
		Answer = "RemoteEvent",
		Close = "RemoteEvent",
		Event = "RemoteEvent",
	},
	Exam = {
		Open = "RemoteEvent",
		Sit = "RemoteEvent",
		Answer = "RemoteEvent",
		Close = "RemoteEvent",
		Event = "RemoteEvent",
	},
	Forage = { Event = "RemoteEvent" },
	Cook = {
		Open = "RemoteEvent",
		Select = "RemoteEvent",
		Click = "RemoteEvent",
		Event = "RemoteEvent",
	},
	Library = {
		Open = "RemoteEvent",
	},
	Feast = { Event = "RemoteEvent" },
	Inventory = { Eat = "RemoteEvent", UseSeasoning = "RemoteEvent" },
	Farm = {
		Rent = "RemoteEvent",
		Bid = "RemoteEvent",
		Plant = "RemoteEvent",
		Harvest = "RemoteEvent",
		Open = "RemoteEvent",
		State = "RemoteEvent",
	},
	Guide = {
		Acknowledge = "RemoteEvent",
	},

	Shop = {
		Open = "RemoteEvent",
		Buy = "RemoteEvent",
		Event = "RemoteEvent",
	},
	Order = {
		Open = "RemoteEvent",
		Accept = "RemoteEvent",
		TurnIn = "RemoteEvent",
		Event = "RemoteEvent",
	},
}

local Remotes = {}

local function buildFolder(parent: Instance, name: string, definition: { [string]: any })
	local folder = parent:FindFirstChild(name) or Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	for key, value in definition do
		if type(value) == "table" then
			buildFolder(folder, key, value)
		else
			local existing = folder:FindFirstChild(key)
			if not existing then
				existing = Instance.new(value)
				existing.Name = key
				existing.Parent = folder
			end
		end
	end

	return folder
end

function Remotes.init()
	buildFolder(ReplicatedStorage, "Remotes", REMOTE_TREE)
end

function Remotes.get(): Folder
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(category: string, name: string): RemoteEvent
	local folder = Remotes.get():WaitForChild(category)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes

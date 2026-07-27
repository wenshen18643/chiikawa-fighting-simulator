--[[
	Builds/fetches the ReplicatedStorage.Remotes folder tree.
	Server calls Remotes.init() once at startup; client just calls Remotes.get().

	Remote surface, per docs/GAME.md §13:
	  - Work.Perform        client -> server INTENT only. No numbers travel up.
	  - Work.SelectSkill    client -> server, which skill to train off a pad.
	  - Work.Feedback       server -> client, per-credited-action, for VFX.
	  - State.Snapshot      server -> client, the authoritative display state.
	  - Region.RequestTravel client -> server, server validates the gate.
	  - Region.Entered      server -> client, drives the area title card.
	  - SafeZone.Changed    server -> client, crossing your own front gate.
	  - Notify.Message      server -> client, cozy toast copy (§2 rule 3).
	  - Companion.Open      server -> client, the friend-stand roster.
	  - Companion.Select    client -> server, which friend follows them.

	There is deliberately no currency remote the client can write to.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_TREE = {
	Work = {
		Perform = "RemoteEvent",
		Feedback = "RemoteEvent",
		-- Which skill free-form training raises. Sent when the player picks one,
		-- NOT with each click: the server holds it on the profile so a click
		-- still carries no arguments and has nothing to lie about.
		SelectSkill = "RemoteEvent",
	},
	State = {
		Snapshot = "RemoteEvent",
	},
	Region = {
		RequestTravel = "RemoteEvent",
		-- Fired when the player walks (or travels) into a different area, so the
		-- client can title-card it. The world is continuous now, so this is the
		-- only signal that a boundary was crossed.
		Entered = "RemoteEvent",
	},
	SafeZone = {
		Changed = "RemoteEvent",
	},
	Notify = {
		Message = "RemoteEvent",
	},
	Companion = {
		-- server -> client, when the player triggers the friend stand: the
		-- roster to show and which entry is currently theirs. Sent rather than
		-- read from a shared config, because which uploaded companions are
		-- actually available is a runtime fact only the server knows.
		Open = "RemoteEvent",
		-- client -> server, an id from that roster. Validated server-side; the
		-- client cannot name a companion that was not offered to it.
		Select = "RemoteEvent",
		Act = "RemoteEvent",
	},
	Guide = {
		-- Client tells the server the player has read the intro, so it stops
		-- being offered. One remote beats a client-side flag that forgets.
		Acknowledge = "RemoteEvent",
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

-- Remotes.event("Work", "Perform") reads better at call sites than a chain of
-- WaitForChild, and fails loudly if the tree and this module drift apart.
function Remotes.event(category: string, name: string): RemoteEvent
	local folder = Remotes.get():WaitForChild(category)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes

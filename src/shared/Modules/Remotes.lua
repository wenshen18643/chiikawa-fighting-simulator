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
	  - Study.Page          client -> server, one completed study-page intent.
	  - Study.Answer        client -> server, an option from the issued question.
	  - Study.SitExam       client -> server, request to begin the Grade 5 exam.
	  - Study.Close         client -> server, abandon the current book session.
	  - Study.Event         server -> client, study/exam presentation payloads.
	  - Forage.Event        server -> client, pluck progress/success for VFX.
	  - Feast.Event         server -> client, shared bite progress on giant food.
	  - Cook.Open           server -> client, open the kitchen UI.
	  - Cook.Select         client -> server, chosen recipe id, validated server-side.
	  - Cook.Click          client -> server, one stir click, intent only.
	  - Cook.Event          server -> client, cook session lifecycle payloads.
	  - Inventory.Eat       client -> server, dish id to consume, validated.

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
		Shelf = "RemoteEvent",
	},
	Study = {
		-- One page-complete intent after an Exam Prep work gesture. The server
		-- independently verifies that the player is actually studying.
		Page = "RemoteEvent",
		-- The id of the plant button chosen for the currently issued question.
		Answer = "RemoteEvent",
		-- Requests the exam once the authoritative readiness requirements are met.
		SitExam = "RemoteEvent",
		-- Cancels any pending recall prompt or in-progress exam when the book closes.
		Close = "RemoteEvent",
		-- Preview, question, feedback and result payloads from server to client.
		Event = "RemoteEvent",
	},
	-- Plucking itself uses server ProximityPrompts, so there is deliberately no
	-- Forage.Pluck remote; this only carries the presentation back down.
	Forage = { Event = "RemoteEvent" }, -- server -> client: pluck progress/success for VFX
	Cook = {
		Open = "RemoteEvent", -- server -> client: open the kitchen UI (station proximity prompt)
		Select = "RemoteEvent", -- client -> server: chosen recipe id, validated server-side
		Click = "RemoteEvent", -- client -> server: one stir click, arg-less intent
		Event = "RemoteEvent", -- server -> client: cook session lifecycle (started/progress/done/cancelled)
	},
	-- server -> client: shared bite progress on a giant food. Eating is the Work
	-- click, so there is deliberately no client -> server remote here.
	Feast = { Event = "RemoteEvent" },
	-- client -> server: an item id to consume, validated
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
		-- Client tells the server the player has read the intro, so it stops
		-- being offered. One remote beats a client-side flag that forgets.
		Acknowledge = "RemoteEvent",
	},
	--[[
		Yoroi-san's work orders.

		Accept and TurnIn carry an ORDER ID and nothing else. Progress is never
		sent up: the server counts kills, pulls and depth itself from the events
		it already owns, so there is no number here for a client to inflate.
	]]
	Order = {
		Open = "RemoteEvent", -- server -> client: the board, on walking up to the booth
		Accept = "RemoteEvent", -- client -> server: an id from the board it was shown
		TurnIn = "RemoteEvent", -- client -> server: claim a finished order
		Event = "RemoteEvent", -- server -> client: progress, completion, board refresh
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

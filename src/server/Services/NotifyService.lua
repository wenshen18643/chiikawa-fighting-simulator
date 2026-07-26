--[[
	Server -> client toast messages.

	Every message that reaches a player passes through here, which is the
	practical way to hold docs/GAME.md §2 rule 3: failure is soft. There is no
	"error" or "denied" kind on purpose — the harshest tone available is
	"locked", which says what is not open yet rather than what the player did
	wrong.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)

local NotifyService = {
	-- Resolved in init(). Nil until then, so send() is safe to call during boot.
	remote = nil :: RemoteEvent?,
}

export type MessageKind = "info" | "unlock" | "locked" | "travel" | "reward"

function NotifyService.send(player: Player, message: string, kind: MessageKind?)
	if not NotifyService.remote then
		return
	end
	NotifyService.remote:FireClient(player, message, kind or "info")
end

function NotifyService.init()
	NotifyService.remote = Remotes.event("Notify", "Message")
end

return NotifyService

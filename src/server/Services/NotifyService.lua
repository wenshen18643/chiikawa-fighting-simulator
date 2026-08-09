local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)

local NotifyService = {
	remote = nil :: RemoteEvent?,
}

export type MessageKind = "info" | "unlock" | "locked" | "travel" | "reward"

function NotifyService.send(player: Player, message: string, kind: MessageKind?, channel: string?)
	if not NotifyService.remote then
		return
	end
	NotifyService.remote:FireClient(player, message, kind or "info", channel)
end

function NotifyService.init()
	NotifyService.remote = Remotes.event("Notify", "Message")
end

return NotifyService

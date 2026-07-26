--!nocheck
--[[
	PASTE INTO STUDIO'S COMMAND BAR (View -> Command Bar). Edit mode, no Play.

	Builds the HUD into StarterGui as real, selectable GuiObjects so it can be
	edited by hand in the Explorer and Properties panels.

	Why this works when a LocalScript does not: the Command Bar executes Luau in
	the Edit-mode DataModel. There is no LocalPlayer and no server, which is
	exactly the case HUD.init(container) was refactored to handle — so this
	reuses that path rather than needing a plugin or a Play session.

	Studio renders StarterGui ScreenGuis in the Edit-mode viewport, so the HUD
	appears at viewport size (well above the 760px COMPACT_WIDTH breakpoint,
	i.e. the full layout rather than the phone one).

	This is a SCRATCHPAD. src/client/UI/*.lua stays the source of truth — edits
	made to these instances do not flow back. Re-running this discards them, so
	dump anything worth keeping with dump-ui.lua first.

	Not in the Rojo tree on purpose: it is a copy-paste snippet, not game code,
	and should never ship in the place file.
]]

local MOUNT_NAME = "HUD_Edit"

local HUD = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.HUD)

-- Idempotent: re-running is the normal way to pick up code changes.
local existing = game.StarterGui:FindFirstChild(MOUNT_NAME)
if existing then
	existing:Destroy()
end

local screen = Instance.new("ScreenGui")
screen.Name = MOUNT_NAME
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = game.StarterGui

-- Given a container, HUD.init parents a full-size Frame inside it and seeds
-- every panel from PREVIEW_SNAPSHOT instead of waiting on a server snapshot.
HUD.init(screen)

--[[
	Both of these are built but deliberately hidden, and they read as missing
	rather than as closed. Flip Visible in Properties to work on them:
	  StarterGui/HUD_Edit/HUD/Minimap   -- owned by the M toggle
	  StarterGui/HUD_Edit/Atlas         -- a modal, opens on N
	The character bust stays empty: no LocalPlayer to clone.
]]
print(`[mount-ui] {MOUNT_NAME} built in StarterGui. Minimap and Atlas are Visible=false.`)

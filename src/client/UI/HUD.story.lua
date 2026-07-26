--[[
	UI Labs story for the HUD (https://ui-labs.luau.page).

	Mounts the whole HUD — identity card, skill bar, minimap, work core, atlas
	modal — inside Studio's Edit mode, no Play required. There is no
	LocalPlayer and no server here, so HUD.init() takes the UI Labs target
	instead of PlayerGui and seeds itself from PREVIEW_SNAPSHOT instead of a
	real State.Snapshot remote — see the `container` parameter on HUD.init().

	Rojo's live sync hot-reloads this, and everything it requires, on save.
]]

local HUD = require(script.Parent.HUD)

local function story(target: Frame)
	return HUD.init(target) or function() end
end

return story

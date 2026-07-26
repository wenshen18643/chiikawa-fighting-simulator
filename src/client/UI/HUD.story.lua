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

--[[
	A defined stage behind the HUD.

	The HUD's own root frame is transparent, because in the real game it sits
	over a 3D world. In a plugin widget that transparency is a liability: an
	empty preview pane and a pane that IS rendering a HUD look identical, so a
	mount failure and a too-narrow pane are indistinguishable. This gives the
	pane visible bounds and puts the cream cards on something to read against.
]]
local STAGE = Color3.fromRGB(68, 74, 82)

--[[
	The HUD sheds its side panels below 760px (COMPACT_WIDTH in HUD.lua) and
	the work core, skill bar and minimap are positioned for a wide screen. A
	docked UI Labs pane is very often narrower than that, and when it is, the
	layout you are reviewing is not the layout players get. So the pane states
	its own width rather than letting you draw conclusions from the wrong one.
]]
local function buildReadout(parent: Frame)
	local label = Instance.new("TextLabel")
	label.Name = "PaneSize"
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -8, 1, -8)
	label.Size = UDim2.fromOffset(210, 18)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.ZIndex = 2000
	label.Parent = parent

	local function refresh()
		local size = parent.AbsoluteSize
		local compact = size.X < 760
		label.Text = `{math.floor(size.X)} x {math.floor(size.Y)}  {if compact then "COMPACT" else "full"} `
		label.TextColor3 = if compact then Color3.fromRGB(240, 190, 90) else Color3.fromRGB(150, 200, 150)
	end

	refresh()
	return label, parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
end

local function story(target: Frame)
	local stage = Instance.new("Frame")
	stage.Name = "PreviewStage"
	stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundColor3 = STAGE
	stage.BorderSizePixel = 0
	stage.ZIndex = 0 -- Behind the HUD, which leaves its own root at the default.
	stage.Parent = target

	local readout, readoutConnection = buildReadout(target)

	-- nil in preview would mean HUD.init took its live-client branch, which it
	-- cannot have done here; it returns a teardown when given a container.
	local teardown = HUD.init(target)

	return function()
		if teardown then
			teardown()
		end
		readoutConnection:Disconnect()
		readout:Destroy()
		stage:Destroy()
	end
end

return story

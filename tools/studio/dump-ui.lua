--!nocheck
--[[
	PASTE INTO STUDIO'S COMMAND BAR after hand-editing StarterGui/HUD_Edit.

	Prints the edits you made, and nothing else, as Luau-shaped values ready to
	be ported into src/client/UI/*.lua.

	How it isolates them: it mounts a second, pristine HUD from the CURRENT code
	next to yours, walks both trees in parallel, and reports only properties
	that differ. So the output is your hand edits rather than a dump of the whole
	HUD — no diffing 200 unchanged lines by eye.

	The baseline is parented to StarterGui (not left orphaned) on purpose:
	applyResponsiveLayout() reads AbsoluteSize, which is 0 outside the render
	tree and would flip it to the compact layout, reporting every responsive
	size as a false edit. It is destroyed again before this returns.

	Output goes to the Output window, which Studio mirrors to
	%LOCALAPPDATA%\Roblox\logs\ — so Claude can read the result back with
	`grep UIDUMP` and do the porting without anything being retyped.
]]

local MOUNT_NAME = "HUD_Edit"
local BASELINE_NAME = "HUD_Edit__baseline"

--------------------------------------------------------------------------------
-- Formatting: emit the shortest constructor that is still faithful, so ported
-- values read like the hand-written ones already in the source.
--------------------------------------------------------------------------------

local function udim2(value: UDim2): string
	local sx, ox, sy, oy = value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset
	if sx == 0 and sy == 0 then
		return `UDim2.fromOffset({ox}, {oy})`
	elseif ox == 0 and oy == 0 then
		return `UDim2.fromScale({sx}, {sy})`
	end
	return `UDim2.new({sx}, {ox}, {sy}, {oy})`
end

local function udim(value: UDim): string
	if value.Scale == 0 then
		return `UDim.new(0, {value.Offset})`
	end
	return `UDim.new({value.Scale}, {value.Offset})`
end

local function color(value: Color3): string
	return `Color3.fromRGB({math.round(value.R * 255)}, {math.round(value.G * 255)}, {math.round(value.B * 255)})`
end

local function format(value: any): string
	local kind = typeof(value)
	if kind == "UDim2" then
		return udim2(value)
	elseif kind == "UDim" then
		return udim(value)
	elseif kind == "Color3" then
		return color(value)
	elseif kind == "Vector2" then
		return `Vector2.new({value.X}, {value.Y})`
	elseif kind == "EnumItem" then
		return tostring(value)
	elseif kind == "string" then
		return `"{value}"`
	elseif kind == "number" then
		-- Trim float noise from dragging: 0.30000001192 reads as an edit nobody made.
		return tostring(math.abs(value - math.round(value)) < 1e-4 and math.round(value) or value)
	end
	return tostring(value)
end

--------------------------------------------------------------------------------
-- Which properties are worth reporting. Layout and visual only: reporting
-- everything would bury the two numbers that actually moved.
--------------------------------------------------------------------------------

local COMMON = { "Position", "Size", "AnchorPoint", "ZIndex", "Visible", "Rotation" }

local BY_CLASS = {
	Frame = { "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel" },
	TextLabel = {
		"Text",
		"TextSize",
		"TextColor3",
		"TextTransparency",
		"FontFace",
		"TextXAlignment",
		"TextYAlignment",
		"TextWrapped",
		"BackgroundColor3",
		"BackgroundTransparency",
	},
	TextButton = {
		"Text",
		"TextSize",
		"TextColor3",
		"BackgroundColor3",
		"BackgroundTransparency",
	},
	ImageLabel = { "Image", "ImageColor3", "ImageTransparency", "BackgroundTransparency" },
	ViewportFrame = { "BackgroundColor3", "BackgroundTransparency" },
	UICorner = { "CornerRadius" },
	UIStroke = { "Thickness", "Color", "Transparency" },
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UIListLayout = { "Padding", "HorizontalAlignment", "VerticalAlignment", "SortOrder" },
	UIGradient = { "Rotation" },
}

local function propertiesFor(instance: Instance): { string }
	local list = {}
	if instance:IsA("GuiObject") then
		for _, name in COMMON do
			table.insert(list, name)
		end
	end
	for _, name in BY_CLASS[instance.ClassName] or {} do
		table.insert(list, name)
	end
	return list
end

--------------------------------------------------------------------------------
-- Walk
--------------------------------------------------------------------------------

--[[
	Path keyed by name AND occurrence, because sibling names are not guaranteed
	unique (the side rail's hint frames, the toast cards). Without the index a
	second sibling would silently compare against the first.
]]
local function indexTree(root: Instance): { [string]: Instance }
	local map = {}

	local function walk(instance: Instance, prefix: string)
		local seen = {}
		for _, child in instance:GetChildren() do
			local key = child.Name
			seen[key] = (seen[key] or 0) + 1
			local suffix = if seen[key] > 1 then `#{seen[key]}` else ""
			local path = `{prefix}/{child.Name}{suffix}`
			map[path] = child
			walk(child, path)
		end
	end

	walk(root, "")
	return map
end

local edited = game.StarterGui:FindFirstChild(MOUNT_NAME)
if not edited then
	warn(`[UIDUMP] No StarterGui/{MOUNT_NAME} found. Run mount-ui.lua first.`)
	return
end

local stale = game.StarterGui:FindFirstChild(BASELINE_NAME)
if stale then
	stale:Destroy()
end

local HUD = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.HUD)
local baseline = Instance.new("ScreenGui")
baseline.Name = BASELINE_NAME
baseline.ResetOnSpawn = false
baseline.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
baseline.Enabled = false -- Built for comparison, not for looking at.
baseline.Parent = game.StarterGui

--[[
	Keep the teardown. HUD.init also subscribes to StateController and to
	UserInputService.LastInputTypeChanged, and those live on objects that
	outlast this script — destroying the ScreenGui alone would leak a fresh set
	of connections on every dump, which in a design loop means dozens.
]]
local teardownBaseline = HUD.init(baseline)

local mine = indexTree(edited)
local pristine = indexTree(baseline)

local changes, added = 0, 0

-- Sorted so repeated dumps diff cleanly against each other.
local paths = {}
for path in mine do
	table.insert(paths, path)
end
table.sort(paths)

print("[UIDUMP] ---- begin ----")

for _, path in paths do
	local instance = mine[path]
	local original = pristine[path]

	if not original then
		print(`[UIDUMP] ADDED {path} :: {instance.ClassName}`)
		added += 1
	else
		for _, property in propertiesFor(instance) do
			local ok, current = pcall(function()
				return (instance :: any)[property]
			end)
			local okBase, before = pcall(function()
				return (original :: any)[property]
			end)

			if ok and okBase and current ~= before then
				print(`[UIDUMP] {path} . {property}  {format(before)}  ->  {format(current)}`)
				changes += 1
			end
		end
	end
end

for path, instance in pristine do
	if not mine[path] then
		print(`[UIDUMP] REMOVED {path} :: {instance.ClassName}`)
	end
end

if teardownBaseline then
	teardownBaseline()
end
baseline:Destroy()

--[[
	HUD.lua keeps `screen`, `identityCard` and friends at module scope, so the
	init above repointed them at the baseline that has just been destroyed. The
	instances under HUD_Edit are unaffected — they are real objects in the tree
	and stay fully editable — but re-run mount-ui.lua before expecting anything
	that drives the HUD from code to touch them again.
]]
print(`[UIDUMP] ---- end: {changes} changed, {added} added ----`)

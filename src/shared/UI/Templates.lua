--[[
	The bridge between Studio-authored layout and code-owned styling.

	--------------------------------------------------------------------------
	WHY THIS EXISTS
	--------------------------------------------------------------------------

	Laying out a card in Studio's viewport is faster than typing `Instance.new`
	forty times, and some things (a fiddly decorative composition, an exact
	nine-slice, anything you want to SEE while you nudge it) are genuinely
	better designed by eye. So layout is authored in Studio and committed as
	`assets/UI/*.model.json`.

	But a saved template bakes in literal values. If every colour in every
	template is a raw Color3, then the next retune — the kind `Theme.lua`
	documents, where the whole interface moved from cream-and-brown to dark
	arcade and NOTHING needed a per-call-site override — becomes a manual edit
	of every template file. That property is worth keeping.

	The split this module enforces:

	    Studio owns    STRUCTURE  — what exists, where it sits, how big, layout
	    Theme owns     APPEARANCE — colour, font, text size, radius, stroke, pad

	You express the second half in Studio as ATTRIBUTES rather than as baked
	property values, and `Templates.mount` resolves them against `Theme` at
	runtime. Retuning the theme still moves every template at once.

	--------------------------------------------------------------------------
	AUTHORING IN STUDIO
	--------------------------------------------------------------------------

	Build the thing, then in Properties -> Attributes add any of:

	    ThemeColor   string   Theme.color key  -> painted onto the class's
	                                              natural colour property
	    ThemeFont    string   Theme.font key   -> TextLabel/TextButton.Font
	    ThemeText    string   Theme.text key   -> .TextSize
	    ThemeRadius  string   Theme.radius key -> adds a UICorner
	    ThemeStroke  string   Theme.stroke key -> adds a UIStroke in Theme line
	    ThemePad     string   Theme.space key  -> adds a UIPadding on all sides

	Leave the baked property at whatever looked right while you were designing;
	the attribute wins at mount time. That way the template still previews
	sensibly in Studio AND stays tokenised at runtime.

	Unknown keys are a hard error, not a silent skip: a typo'd `ThemeColor` that
	quietly does nothing is exactly the kind of drift this module exists to stop.

	--------------------------------------------------------------------------
	USING IT
	--------------------------------------------------------------------------

		local UI = require(ReplicatedStorage.Shared.UI)

		local card = UI.template("ShopItemCard", {
			parent = container,
			bind = { Title = itemName, Price = `¥ {price}` },
		})

	Shared, not client-only, for the same reason the rest of `Shared/UI` is:
	the server builds world-space signs from the same templates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Primitives = require(script.Parent.Primitives)
local Theme = require(script.Parent.Theme)

local Templates = {}

--[[
	Which property a `ThemeColor` should paint, per class.

	A TextLabel almost always wants its TEXT tinted, not its background — the
	background of a label is usually meant to stay transparent. Getting this
	wrong produces a wall of solid rectangles, so it is a lookup rather than a
	guess.
]]
local COLOR_TARGET: { [string]: string } = {
	TextLabel = "TextColor3",
	TextButton = "TextColor3",
	TextBox = "TextColor3",
	ImageLabel = "ImageColor3",
	ImageButton = "ImageColor3",
	UIStroke = "Color",
}

local DEFAULT_COLOR_TARGET = "BackgroundColor3"

--[[
	Resolve one attribute against one Theme table, erroring loudly on a miss.

	`where` is the instance's full name, so the error names the offending object
	rather than making you grep the templates for the bad key.
]]
local function resolve(scope: { [string]: any }, scopeName: string, key: string, where: string): any
	local value = scope[key]
	if value == nil then
		local known = {}
		for name in scope do
			table.insert(known, name)
		end
		table.sort(known)
		error(`[Templates] {where}: no Theme.{scopeName} key "{key}". Known: {table.concat(known, ", ")}`, 0)
	end
	return value
end

--[[
	Apply the Theme attributes on a single instance.

	Ordering matters in one place: ThemeStroke is applied after ThemeColor so a
	stroke added here always takes the line colour rather than inheriting
	whatever ThemeColor just painted.
]]
local function applyTokens(instance: Instance)
	local where = instance:GetFullName()

	local colorKey = instance:GetAttribute("ThemeColor")
	if colorKey ~= nil then
		local target = COLOR_TARGET[instance.ClassName] or DEFAULT_COLOR_TARGET;
		(instance :: any)[target] = resolve(Theme.color, "color", colorKey, where)
	end

	local fontKey = instance:GetAttribute("ThemeFont")
	if fontKey ~= nil then
		(instance :: any).Font = resolve(Theme.font, "font", fontKey, where)
	end

	local textKey = instance:GetAttribute("ThemeText")
	if textKey ~= nil then
		(instance :: any).TextSize = resolve(Theme.text, "text", textKey, where)
	end

	local radiusKey = instance:GetAttribute("ThemeRadius")
	if radiusKey ~= nil then
		Primitives.corner(instance, resolve(Theme.radius, "radius", radiusKey, where))
	end

	local strokeKey = instance:GetAttribute("ThemeStroke")
	if strokeKey ~= nil then
		Primitives.stroke(instance, Theme.color.line, resolve(Theme.stroke, "stroke", strokeKey, where))
	end

	local padKey = instance:GetAttribute("ThemePad")
	if padKey ~= nil then
		Primitives.padding(instance, resolve(Theme.space, "space", padKey, where))
	end
end

--[[
	The template folder, resolved lazily.

	Not cached at require time: on the server this module may load before Rojo
	has finished populating ReplicatedStorage, and a nil captured then would
	persist for the session.
]]
local function templateRoot(): Instance
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		error("[Templates] ReplicatedStorage.Assets is missing - is assets/ mapped in default.project.json?", 0)
	end

	local ui = assets:FindFirstChild("UI")
	if not ui then
		error("[Templates] ReplicatedStorage.Assets.UI is missing - add a template under assets/UI/.", 0)
	end

	return ui
end

export type MountConfig = {
	parent: Instance?,
	-- Descendant name -> text. Applied after tokens so a bound string is never
	-- overwritten by styling.
	bind: { [string]: string }?,
	name: string?,
}

--[[
	Clone a template, tokenise it, optionally bind text into it, and parent it.

	Returns the clone. Everything past this point is ordinary Luau: wire up
	events, drive it with Motion, hold onto children by name. This module has no
	opinion about behaviour — that is the "Lua for everything else" half.
]]
function Templates.mount(templateName: string, config: MountConfig?): Instance
	local settings = config or {}

	local source = templateRoot():FindFirstChild(templateName)
	if not source then
		error(`[Templates] no template named "{templateName}" under assets/UI/`, 0)
	end

	local clone = source:Clone()

	applyTokens(clone)
	for _, descendant in clone:GetDescendants() do
		applyTokens(descendant)
	end

	if settings.bind then
		for childName, text in settings.bind do
			local target = clone:FindFirstChild(childName, true)
			if not target then
				error(`[Templates] template "{templateName}" has no descendant "{childName}" to bind`, 0)
			end
			(target :: any).Text = text
		end
	end

	if settings.name then
		clone.Name = settings.name
	end

	-- Parent last: a template that is tokenised and bound before it enters the
	-- DataModel never renders in its half-styled intermediate state.
	if settings.parent then
		clone.Parent = settings.parent
	end

	return clone
end

--[[
	Whether a template exists. For call sites that want to fall back to building
	a panel from Components rather than hard-failing on a missing asset.
]]
function Templates.exists(templateName: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	return ui ~= nil and ui:FindFirstChild(templateName) ~= nil
end

return Templates

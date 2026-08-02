local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Primitives = require(script.Parent.Primitives)
local Theme = require(script.Parent.Theme)
local Templates = {}

local COLOR_TARGET: { [string]: string } = {
	TextLabel = "TextColor3",
	TextButton = "TextColor3",
	TextBox = "TextColor3",
	ImageLabel = "ImageColor3",
	ImageButton = "ImageColor3",
	UIStroke = "Color",
}

local DEFAULT_COLOR_TARGET = "BackgroundColor3"

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
	bind: { [string]: string }?,
	name: string?,
}

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

	if settings.parent then
		clone.Parent = settings.parent
	end

	return clone
end

function Templates.exists(templateName: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	return ui ~= nil and ui:FindFirstChild(templateName) ~= nil
end

return Templates

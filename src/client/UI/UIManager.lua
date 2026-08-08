--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local WorkController = require(script.Parent.Parent.Controllers.WorkController)
local InputMode = require(script.Parent.InputMode)
local UIManager = {}

export type ModalKind = "ordinary" | "critical"
export type ModalConfig = {
	setVisible: (open: boolean, instant: boolean) -> (),
	focus: (() -> GuiObject?)?,
	back: (() -> boolean)?,
	dismissible: boolean?,
	kind: ModalKind?,
}
export type OverlayConfig = {
	close: () -> (),
	focus: (() -> GuiObject?)?,
}

local BACK_ACTION = "UIManagerBack"
local INPUT_LOCK = "ui-manager"
local OVERLAY_LOCK = "ui-overlay"
local BACK_PRIORITY = Enum.ContextActionPriority.High.Value + 50
local initialized = false
local entries: { [string]: ModalConfig } = {}
local activeId: string? = nil
local previousSelection: GuiObject? = nil
local blockers: { [string]: string | boolean } = {}
local overlayId: string? = nil
local overlayConfig: OverlayConfig? = nil
local surfaceListeners: { () -> () } = {}

local function notifySurfaceChanged()
	for _, listener in surfaceListeners do
		task.spawn(listener)
	end
end

local function validSelection(candidate: GuiObject?): boolean
	if candidate == nil or not candidate:IsDescendantOf(game) or not candidate.Visible then
		return false
	end
	local ancestor = candidate.Parent
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("LayerCollector") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end

local function focusEntry(config: ModalConfig)
	if InputMode.current() ~= "gamepad" or not config.focus then
		return
	end
	task.defer(function()
		local target = config.focus and config.focus()
		if validSelection(target) then
			GuiService.SelectedObject = target
		end
	end)
end

local function restoreFocus()
	if validSelection(previousSelection) then
		GuiService.SelectedObject = previousSelection
	else
		GuiService.SelectedObject = nil
	end
	previousSelection = nil
end

local function blockedFor(id: string): boolean
	for _, allowed in blockers do
		if allowed ~= id then
			return true
		end
	end
	return false
end

local function closeOverlayInternal()
	local config = overlayConfig
	overlayId = nil
	overlayConfig = nil
	WorkController.setInputLocked(OVERLAY_LOCK, false)
	if config then
		config.close()
	end
	notifySurfaceChanged()
end

local function closeInternal(id: string, instant: boolean, shouldRestore: boolean)
	if activeId ~= id then
		return
	end
	local config = entries[id]
	activeId = nil
	WorkController.setInputLocked(INPUT_LOCK, false)
	if config then
		config.setVisible(false, instant)
	end
	if shouldRestore then
		restoreFocus()
	end
	notifySurfaceChanged()
end

function UIManager.init()
	if initialized then
		return
	end
	initialized = true
	InputMode.init()
	InputMode.onChanged(function(kind)
		if kind ~= "gamepad" then
			GuiService.SelectedObject = nil
			return
		end
		if overlayConfig and overlayConfig.focus then
			local target = overlayConfig.focus()
			if validSelection(target) then
				GuiService.SelectedObject = target
			end
			return
		end
		local config = activeId and entries[activeId]
		if config then
			focusEntry(config)
		end
	end)
	ContextActionService:BindActionAtPriority(BACK_ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		if overlayId then
			closeOverlayInternal()
			return Enum.ContextActionResult.Sink
		end
		local id = activeId
		local config = id and entries[id]
		if not id or not config then
			return Enum.ContextActionResult.Pass
		end
		if config.back and config.back() then
			return Enum.ContextActionResult.Sink
		end
		if config.dismissible ~= false then
			UIManager.close(id)
		end
		return Enum.ContextActionResult.Sink
	end, false, BACK_PRIORITY, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape)
end

function UIManager.register(id: string, config: ModalConfig): () -> ()
	UIManager.init()
	assert(entries[id] == nil, `[UIManager] duplicate modal id "{id}"`)
	entries[id] = config
	return function()
		if activeId == id then
			closeInternal(id, true, true)
		end
		entries[id] = nil
	end
end

function UIManager.open(id: string): boolean
	UIManager.init()
	local config = entries[id]
	if not config then
		warn(`[UIManager] cannot open unregistered modal "{id}"`)
		return false
	end
	if activeId == id then
		return true
	end
	if blockedFor(id) then
		return false
	end
	if activeId then
		local activeConfig = entries[activeId]
		local activeKind = if activeConfig then activeConfig.kind or "ordinary" else "ordinary"
		if activeKind == "critical" then
			return false
		end
		closeInternal(activeId, true, false)
	end
	if overlayId then
		closeOverlayInternal()
	end
	previousSelection = GuiService.SelectedObject
	activeId = id
	WorkController.setInputLocked(INPUT_LOCK, true)
	config.setVisible(true, false)
	focusEntry(config)
	notifySurfaceChanged()
	return true
end

function UIManager.close(id: string, instant: boolean?)
	closeInternal(id, instant == true, true)
end

function UIManager.isOpen(id: string): boolean
	return activeId == id
end

function UIManager.beginBlock(owner: string, allowedModalId: string?)
	blockers[owner] = allowedModalId or false
	WorkController.setInputLocked(`ui-block:{owner}`, true)
	if activeId and activeId ~= allowedModalId then
		local config = entries[activeId]
		if config and (config.kind or "ordinary") == "ordinary" then
			closeInternal(activeId, true, true)
		end
	end
	if overlayId then
		closeOverlayInternal()
	end
end

function UIManager.endBlock(owner: string)
	blockers[owner] = nil
	WorkController.setInputLocked(`ui-block:{owner}`, false)
end

function UIManager.showOverlay(id: string, config: OverlayConfig): boolean
	if activeId then
		return false
	end
	if overlayId and overlayId ~= id then
		closeOverlayInternal()
	end
	overlayId = id
	overlayConfig = config
	WorkController.setInputLocked(OVERLAY_LOCK, true)
	if InputMode.current() == "gamepad" and config.focus then
		task.defer(function()
			local target = config.focus and config.focus()
			if validSelection(target) then
				GuiService.SelectedObject = target
			end
		end)
	end
	notifySurfaceChanged()
	return true
end

function UIManager.hideOverlay(id: string)
	if overlayId == id then
		closeOverlayInternal()
	end
end

function UIManager.active(): string?
	return activeId
end

function UIManager.hasSurface(): boolean
	return activeId ~= nil or overlayId ~= nil
end

function UIManager.onChanged(callback: () -> ()): () -> ()
	table.insert(surfaceListeners, callback)
	return function()
		local index = table.find(surfaceListeners, callback)
		if index then
			table.remove(surfaceListeners, index)
		end
	end
end

return UIManager

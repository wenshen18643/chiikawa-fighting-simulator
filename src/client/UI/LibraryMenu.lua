--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)

local WorkController = require(script.Parent.Parent.Controllers.WorkController)

local LibraryMenu = {}

type OpenPayload = {
	anchorPosition: Vector3,
	closeDistance: number,
}

local ACTION_NAME = "CloseLibraryMenu"
local INPUT_LOCK = "library-menu"
local DISTANCE_CHECK_SECONDS = 0.25

local player = Players.LocalPlayer
local screen: ScreenGui?
local panel: Frame?
local closeButton: TextButton?
local setPanelOpen: ((boolean) -> ())?

local isOpen = false
local anchorPosition: Vector3?
local closeDistance = 32
local distanceConnection: RBXScriptConnection?
local characterRemovingConnection: RBXScriptConnection?
local previousSelection: GuiObject?

local function disconnectOpenConnections()
	if distanceConnection then
		distanceConnection:Disconnect()
		distanceConnection = nil
	end
	if characterRemovingConnection then
		characterRemovingConnection:Disconnect()
		characterRemovingConnection = nil
	end
end

local function restoreSelection()
	local currentPanel = panel
	local selected = GuiService.SelectedObject
	if selected and currentPanel and selected:IsDescendantOf(currentPanel) then
		if previousSelection and previousSelection:IsDescendantOf(game) and previousSelection.Visible then
			GuiService.SelectedObject = previousSelection
		else
			GuiService.SelectedObject = nil
		end
	end
	previousSelection = nil
end

local function closeMenu()
	if isOpen and setPanelOpen then
		setPanelOpen(false)
	end
end

local function bindCloseAction()
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_name, state)
			if state == Enum.UserInputState.Begin then
				closeMenu()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
end

local function startDistanceMonitor()
	disconnectOpenConnections()
	local elapsed = 0
	distanceConnection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < DISTANCE_CHECK_SECONDS then
			return
		end
		elapsed = 0

		local anchor = anchorPosition
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not anchor or not root or not root:IsA("BasePart") then
			closeMenu()
			return
		end
		if (root.Position - anchor).Magnitude > closeDistance then
			closeMenu()
		end
	end)
	characterRemovingConnection = player.CharacterRemoving:Connect(function()
		closeMenu()
	end)
end

local function onToggled(open: boolean)
	if isOpen == open then
		return
	end
	isOpen = open
	WorkController.setInputLocked(INPUT_LOCK, open)

	if open then
		previousSelection = GuiService.SelectedObject
		bindCloseAction()
		startDistanceMonitor()
		if UserInputService.GamepadEnabled then
			task.defer(function()
				if isOpen and closeButton then
					GuiService.SelectedObject = closeButton
				end
			end)
		end
		return
	end

	ContextActionService:UnbindAction(ACTION_NAME)
	disconnectOpenConnections()
	restoreSelection()
	anchorPosition = nil
end

local function buildPanel(parent: ScreenGui)
	local scrim, content, toggle = UI.modal(parent, "LibraryMenu", {
		extent = UDim2.fromScale(0.78, 0.68),
		zIndex = 30,
		onToggled = onToggled,
	})
	panel = content
	setPanelOpen = toggle
	scrim.Visible = false
	content.Active = true

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(300, 250)
	sizeConstraint.MaxSize = Vector2.new(720, 480)
	sizeConstraint.Parent = content

	UI.padding(content, UI.space.loose)

	local header = UI.header(content, "Header", {
		title = "Peach Study Library",
		accent = UI.color.rest,
		extent = UDim2.new(1, -76, 0, 48),
		zIndex = content.ZIndex + 2,
	})
	header.Position = UDim2.fromOffset(0, 0)

	local close = UI.button(content, "Close", {
		text = "×",
		font = UI.font.display,
		textSize = 30,
		color = UI.color.paperRaised,
		extent = UDim2.fromOffset(48, 48),
		position = UDim2.new(1, -48, 0, 0),
		zIndex = content.ZIndex + 3,
		onActivated = closeMenu,
	})
	close.AnchorPoint = Vector2.zero
	closeButton = close

	local divider = UI.divider(content, UI.color.blush)
	divider.Position = UDim2.fromOffset(0, 58)
	divider.Size = UDim2.new(1, 0, 0, 3)
	divider.ZIndex = content.ZIndex + 2

	local emptyContent = UI.card(content, "MinigameContent", {
		color = UI.color.paperRaised,
		gradient = false,
		strokeColor = UI.color.blush,
		strokeWidth = 3,
		zIndex = content.ZIndex + 1,
	})
	emptyContent.Position = UDim2.fromOffset(0, 76)
	emptyContent.Size = UDim2.new(1, 0, 1, -76)
	emptyContent.Active = true

	local inner = Instance.new("Frame")
	inner.Name = "EmptyContent"
	inner.BackgroundColor3 = UI.color.paper
	inner.BackgroundTransparency = 0.45
	inner.BorderSizePixel = 0
	inner.Position = UDim2.fromOffset(12, 12)
	inner.Size = UDim2.new(1, -24, 1, -24)
	inner.ZIndex = emptyContent.ZIndex + 1
	inner.Parent = emptyContent
	UI.corner(inner, UI.radius.tile)
	UI.stroke(inner, UI.lighten(UI.color.rest, 0.45), 2)
end

local function parseOpenPayload(payload: any): OpenPayload?
	if type(payload) ~= "table" then
		return nil
	end
	if typeof(payload.anchorPosition) ~= "Vector3" then
		return nil
	end
	if type(payload.closeDistance) ~= "number" or payload.closeDistance ~= payload.closeDistance then
		return nil
	end
	return {
		anchorPosition = payload.anchorPosition,
		closeDistance = math.clamp(payload.closeDistance, 12, 100),
	}
end

local function openFromServer(payload: any)
	local parsed = parseOpenPayload(payload)
	if not parsed or not setPanelOpen then
		return
	end
	anchorPosition = parsed.anchorPosition
	closeDistance = parsed.closeDistance

	if isOpen then
		startDistanceMonitor()
		return
	end
	setPanelOpen(true)
end

function LibraryMenu.setOpen(open: boolean)
	if not setPanelOpen then
		return
	end
	if not open then
		closeMenu()
	end
end

function LibraryMenu.init()
	if screen then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "LibraryMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screen = gui

	buildPanel(gui)
	Remotes.event("Library", "Open").OnClientEvent:Connect(openFromServer)
end

return LibraryMenu

--[[
	How far along the tree you are pulling is.

	A forage node takes several clicks and the tree gives no sign of it, so a
	big sausage and a small one look identical mid-pull. This puts the count
	over the node being worked, in world space rather than on the HUD: the
	answer to "is this one nearly out" belongs on the tree, not in a corner.

	One reusable billboard follows whichever node the server last credited, so
	switching trees moves the counter instead of stacking a second one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local UI = require(Shared.UI)

local ForageProgressController = {}

local LIFETIME = 1.6 -- seconds of no progress before it fades out
local FADE = 0.35
local LIFT = 3.2 -- studs above the node centre

local anchor: Part
local billboard: BillboardGui
local card: Frame
local counter: TextLabel
local title: TextLabel
local fill: Frame
local hideAt = 0
local visible = false

local function build()
	anchor = Instance.new("Part")
	anchor.Name = "ForageProgressAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = Workspace

	billboard = Instance.new("BillboardGui")
	billboard.Name = "ForageProgress"
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromOffset(170, 62)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 160
	billboard.Enabled = false
	billboard.Parent = anchor

	card = UI.card(billboard, "Card", { radius = UI.radius.chip })
	card.Size = UDim2.fromScale(1, 1)

	title = UI.label(card, "Name", {
		text = "",
		font = UI.font.bold,
		size = UI.text.small,
		color = UI.color.inkSoft,
		align = Enum.TextXAlignment.Left,
		position = UDim2.fromOffset(12, 8),
		extent = UDim2.new(1, -24, 0, 16),
	})

	counter = UI.label(card, "Counter", {
		text = "",
		font = UI.font.display,
		size = UI.text.title,
		color = UI.color.ink,
		align = Enum.TextXAlignment.Right,
		position = UDim2.fromOffset(12, 6),
		extent = UDim2.new(1, -24, 0, 20),
	})

	local track
	track, fill = UI.bar(card, "Track", UI.color.kusatori)
	track.Position = UDim2.fromOffset(12, 38)
	track.Size = UDim2.new(1, -24, 0, 10)
end

local function setTransparency(alpha: number)
	card.BackgroundTransparency = alpha
	title.TextTransparency = alpha
	counter.TextTransparency = alpha
	for _, descendant in card:GetDescendants() do
		if descendant:IsA("Frame") then
			descendant.BackgroundTransparency = alpha
		elseif descendant:IsA("UIStroke") then
			descendant.Transparency = alpha
		end
	end
end

local function show(ingredientId: string, current: number, needed: number, at: Vector3)
	local definition = Ingredients.get(ingredientId)
	anchor.CFrame = CFrame.new(at + Vector3.new(0, LIFT, 0))

	title.Text = if definition then definition.name else ingredientId
	counter.Text = `{current}/{needed}`
	fill.Size = UDim2.fromScale(math.clamp(current / math.max(needed, 1), 0, 1), 1)
	fill.BackgroundColor3 = if definition and definition.rarity == "legendary"
		then UI.color.examprep
		else UI.color.kusatori

	setTransparency(0)
	billboard.Enabled = true
	visible = true
	hideAt = os.clock() + LIFETIME
end

function ForageProgressController.init()
	build()

	Remotes.event("Forage", "Event").OnClientEvent:Connect(function(kind, ingredientId, a, b, at)
		if kind == "progress" and typeof(at) == "Vector3" then
			show(ingredientId, a, b, at)
		elseif kind == "success" then
			-- The node is gone; the counter would be describing nothing.
			hideAt = math.min(hideAt, os.clock())
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not visible then
			return
		end
		local over = os.clock() - hideAt
		if over < 0 then
			return
		end
		if over >= FADE then
			billboard.Enabled = false
			visible = false
			return
		end
		setTransparency(over / FADE)
	end)
end

return ForageProgressController

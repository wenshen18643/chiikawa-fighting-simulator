local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)

local OrderTracker = {}

local WIDTH = 260
local HEIGHT = 54
local TEMPLATE = "OrderTracker"

local root: Frame
local title: TextLabel
local detail: TextLabel
local fill: Frame

local function setVisible(visible: boolean)
	if root.Visible == visible then
		return
	end
	root.Visible = visible
end

local function show(name: string, summary: string, progress: number, count: number)
	title.Text = name
	detail.Text = `{summary}  {progress}/{count}`
	local ratio = if count > 0 then math.clamp(progress / count, 0, 1) else 0
	fill.Size = UDim2.fromScale(ratio, 1)
	fill.BackgroundColor3 = if ratio >= 1 then UI.color.leaf else UI.color.sky
	setVisible(true)
end

local function build(parent: ScreenGui)
	if UI.hasTemplate(TEMPLATE) then
		local mounted = UI.template(TEMPLATE, { parent = parent })
		local mountedTitle = mounted and mounted:FindFirstChild("Title", true)
		local mountedDetail = mounted and mounted:FindFirstChild("Detail", true)
		local mountedFill = mounted and mounted:FindFirstChild("Fill", true)
		if
			mounted
			and mounted:IsA("Frame")
			and mountedTitle
			and mountedTitle:IsA("TextLabel")
			and mountedDetail
			and mountedDetail:IsA("TextLabel")
			and mountedFill
			and mountedFill:IsA("Frame")
		then
			root, title, detail, fill = mounted, mountedTitle, mountedDetail, mountedFill
			root.Visible = false
			return
		end
		warn(`[OrderTracker] template "{TEMPLATE}" is missing Title, Detail or Fill; using the built strip`)
		if mounted then
			mounted:Destroy()
		end
	end

	root = UI.card(parent, "OrderTracker", {
		color = UI.color.paperDeep,
		radius = UI.radius.chip,
	})
	root.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -UI.space.base, 0, 120)
	root.Visible = false

	title = UI.label(root, "Title", {
		text = "",
		font = UI.font.display,
		size = UI.text.small,
		position = UDim2.fromOffset(UI.space.snug, UI.space.tight),
		extent = UDim2.new(1, -UI.space.snug * 2, 0, 18),
	})

	detail = UI.label(root, "Detail", {
		text = "",
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(UI.space.snug, UI.space.tight + 19),
		extent = UDim2.new(1, -UI.space.snug * 2, 0, 14),
	})

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = UI.color.glassDark
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(UI.space.snug, HEIGHT - 14)
	track.Size = UDim2.new(1, -UI.space.snug * 2, 0, 6)
	track.ZIndex = root.ZIndex + 1
	track.Parent = root
	UI.corner(track, UI.radius.pill)

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UI.color.sky
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = track.ZIndex + 1
	fill.Parent = track
	UI.corner(fill, UI.radius.pill)
end

function OrderTracker.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "OrderTracker"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 4
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	build(screen)

	Remotes.event("Order", "Event").OnClientEvent:Connect(function(kind, payload)
		if type(payload) ~= "table" then
			return
		end

		if kind == "progress" then
			show(payload.name, payload.summary, payload.progress, payload.count)
		elseif kind == "completed" then
			setVisible(false)
		elseif kind == "board" then
			local active = payload.active
			if type(active) ~= "string" then
				setVisible(false)
				return
			end
			for _, entry in payload.orders or {} do
				if entry.id == active then
					show(entry.name, entry.summary, entry.progress, entry.objective.count)
					return
				end
			end
			setVisible(false)
		end
	end)

	Remotes.event("Order", "Open").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.active) ~= "string" then
			setVisible(false)
		end
	end)
end

return OrderTracker

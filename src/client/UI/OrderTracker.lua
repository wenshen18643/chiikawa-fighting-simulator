local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local WorkOrders = require(Shared.Modules.Config.WorkOrders)
local UI = require(Shared.UI)
local OrderTracker = {}

type Row = {
	root: Frame,
	title: TextLabel,
	detail: TextLabel,
	fill: Frame,
}

type Entry = {
	id: string,
	name: string,
	summary: string,
	kind: string?,
	progress: number,
	count: number,
}

local WIDTH = 260
local COMPACT_WIDTH = 220
local HEIGHT = 54
local GAP = UI.space.tight
local TEMPLATE = "OrderTracker"
local holder: Frame
local rows: { [string]: Row } = {}
local order: { string } = {}
local suppressed = false
local compact = false
local margin = 18
local bottomOffset = 328
local anchored: UDim2 = UDim2.new(1, -18, 1, -(328 - HEIGHT))

local function place()
	if not holder then
		return
	end
	anchored = UDim2.new(1, -margin, 1, -(bottomOffset - HEIGHT))
	holder.Position = anchored
	holder.Size = UDim2.fromOffset(if compact then COMPACT_WIDTH else WIDTH, 0)
end

local function refresh()
	local visible = #order > 0 and not suppressed
	if holder.Visible == visible then
		return
	end
	holder.Visible = visible
	if visible then
		holder.Position = anchored + UDim2.fromOffset(26, 0)
		UI.motion.to(holder, UI.motion.settle, { Position = anchored })
	end
end

function OrderTracker.setSuppressed(value: boolean)
	suppressed = value
	if holder then
		refresh()
	end
end

function OrderTracker.setLayout(value: boolean, edge: number, bottom: number)
	compact = value
	margin = edge
	bottomOffset = bottom
	place()
end

local function buildRow(id: string): Row?
	if UI.hasTemplate(TEMPLATE) then
		local mounted = UI.template(TEMPLATE, { parent = holder, name = id })
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
			mounted.Size = UDim2.new(1, 0, mounted.Size.Y.Scale, mounted.Size.Y.Offset)
			return { root = mounted, title = mountedTitle, detail = mountedDetail, fill = mountedFill }
		end
		warn(`[OrderTracker] template "{TEMPLATE}" is missing Title, Detail or Fill; using the built strip`)
		if mounted then
			mounted:Destroy()
		end
	end

	local root = UI.card(holder, id, {
		radius = UI.radius.chip,
	})
	root.Size = UDim2.new(1, 0, 0, HEIGHT)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = UI.color.sky
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromOffset(0, 10)
	accent.Size = UDim2.fromOffset(4, HEIGHT - 20)
	accent.ZIndex = root.ZIndex + 1
	accent.Parent = root
	UI.corner(accent, UI.radius.pill)

	local inset = UI.space.snug + 6
	local title = UI.label(root, "Title", {
		text = "",
		font = UI.font.display,
		size = UI.text.body,
		position = UDim2.fromOffset(inset, UI.space.tight),
		extent = UDim2.new(1, -(inset + UI.space.snug), 0, 19),
	})

	local detail = UI.label(root, "Detail", {
		text = "",
		font = UI.font.body,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(inset, UI.space.tight + 20),
		extent = UDim2.new(1, -(inset + UI.space.snug), 0, 14),
	})

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = UI.color.paperSunken
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(inset, HEIGHT - 14)
	track.Size = UDim2.new(1, -(inset + UI.space.snug), 0, 6)
	track.ZIndex = root.ZIndex + 1
	track.Parent = root
	UI.corner(track, UI.radius.pill)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UI.color.sky
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = track.ZIndex + 1
	fill.Parent = track
	UI.corner(fill, UI.radius.pill)

	return { root = root, title = title, detail = detail, fill = fill }
end

local function rowFor(id: string): Row?
	local existing = rows[id]
	if existing then
		return existing
	end

	local row = buildRow(id)
	if not row then
		return nil
	end
	rows[id] = row
	table.insert(order, id)
	return row
end

local function drop(id: string)
	local row = rows[id]
	if not row then
		return
	end
	row.root:Destroy()
	rows[id] = nil
	local index = table.find(order, id)
	if index then
		table.remove(order, index)
	end
end

local function update(entry: Entry)
	local row = rowFor(entry.id)
	if not row then
		return
	end

	row.title.Text = entry.name
	row.detail.Text = if entry.kind == "train"
		then `{entry.summary}  {entry.progress}%`
		else `{entry.summary}  {WorkOrders.formatCount(entry.progress)}/{WorkOrders.formatCount(entry.count)}`

	local ratio = if entry.count > 0 then math.clamp(entry.progress / entry.count, 0, 1) else 0
	UI.motion.to(row.fill, UI.motion.settle, {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = if ratio >= 1 then UI.color.leaf else UI.color.sky,
	})
end

local function sync(entries: { Entry })
	local seen: { [string]: boolean } = {}
	for index, entry in entries do
		if type(entry) == "table" and type(entry.id) == "string" then
			seen[entry.id] = true
			update(entry)
			local row = rows[entry.id]
			if row then
				row.root.LayoutOrder = index
			end
		end
	end

	for index = #order, 1, -1 do
		local id = order[index]
		if not seen[id] then
			drop(id)
		end
	end
	refresh()
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

	holder = Instance.new("Frame")
	holder.Name = "Stack"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Visible = false
	holder.Parent = screen
	UI.list(holder, GAP)
	place()

	Remotes.event("Order", "Event").OnClientEvent:Connect(function(kind, payload)
		if type(payload) ~= "table" then
			return
		end

		if kind == "progress" then
			update(payload)
			refresh()
		elseif kind == "completed" then
			drop(payload.id)
			refresh()
		elseif kind == "board" then
			sync(if type(payload.tracked) == "table" then payload.tracked else {})
		end
	end)

	Remotes.event("Order", "Open").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			sync(if type(payload.tracked) == "table" then payload.tracked else {})
		end
	end)
end

return OrderTracker

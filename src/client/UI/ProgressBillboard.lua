local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Shared").UI)

export type Options = {
	lifetime: number?,
	fade: number?,
	lift: number?,
	color: Color3?,
	size: UDim2?,
	maxDistance: number?,
}

local ProgressBillboard = {}
ProgressBillboard.__index = ProgressBillboard

export type Board = typeof(setmetatable(
	{} :: {
		lifetime: number,
		fade: number,
		lift: number,
		color: Color3,
		anchor: Part,
		billboard: BillboardGui,
		card: Frame,
		title: TextLabel,
		counter: TextLabel,
		fill: Frame,
		hideAt: number,
		visible: boolean,
	},
	ProgressBillboard
))

function ProgressBillboard.new(name: string, options: Options?): Board
	local config = options or {}
	local anchor = Instance.new("Part")
	anchor.Name = `{name}Anchor`
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = anchor
	billboard.Size = config.size or UDim2.fromOffset(170, 62)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = config.maxDistance or 160
	billboard.Enabled = false
	billboard.Parent = anchor

	local card = UI.card(billboard, "Card", { radius = UI.radius.chip })
	card.Size = UDim2.fromScale(1, 1)

	local title = UI.label(card, "Name", {
		text = "",
		font = UI.font.bold,
		size = UI.text.small,
		color = UI.color.inkSoft,
		align = Enum.TextXAlignment.Left,
		position = UDim2.fromOffset(12, 8),
		extent = UDim2.new(1, -24, 0, 16),
	})

	local counter = UI.label(card, "Counter", {
		text = "",
		font = UI.font.display,
		size = UI.text.title,
		color = UI.color.ink,
		align = Enum.TextXAlignment.Right,
		position = UDim2.fromOffset(12, 6),
		extent = UDim2.new(1, -24, 0, 20),
	})

	local color = config.color or UI.color.kusatori
	local track, fill = UI.bar(card, "Track", color)
	track.Position = UDim2.fromOffset(12, 38)
	track.Size = UDim2.new(1, -24, 0, 10)

	local board: Board = setmetatable({
		lifetime = config.lifetime or 1.6,
		fade = config.fade or 0.35,
		lift = config.lift or 3.2,
		color = color,
		anchor = anchor,
		billboard = billboard,
		card = card,
		title = title,
		counter = counter,
		fill = fill,
		hideAt = 0,
		visible = false,
	}, ProgressBillboard) :: any

	RunService.RenderStepped:Connect(function()
		board:step()
	end)

	return board
end

function ProgressBillboard.setTransparency(self: Board, alpha: number)
	self.card.BackgroundTransparency = alpha
	self.title.TextTransparency = alpha
	self.counter.TextTransparency = alpha
	for _, descendant in self.card:GetDescendants() do
		if descendant:IsA("Frame") then
			descendant.BackgroundTransparency = alpha
		elseif descendant:IsA("UIStroke") then
			descendant.Transparency = alpha
		end
	end
end

function ProgressBillboard.show(
	self: Board,
	title: string,
	current: number,
	needed: number,
	at: Vector3,
	color: Color3?
)
	self.anchor.CFrame = CFrame.new(at + Vector3.new(0, self.lift, 0))
	self.title.Text = title
	self.counter.Text = `{current}/{needed}`
	self.fill.Size = UDim2.fromScale(math.clamp(current / math.max(needed, 1), 0, 1), 1)
	self.fill.BackgroundColor3 = color or self.color

	self:setTransparency(0)
	self.billboard.Enabled = true
	self.visible = true
	self.hideAt = os.clock() + self.lifetime
end

function ProgressBillboard.dismiss(self: Board)
	self.hideAt = math.min(self.hideAt, os.clock())
end

function ProgressBillboard.step(self: Board)
	if not self.visible then
		return
	end

	local over = os.clock() - self.hideAt
	if over < 0 then
		return
	end
	if over >= self.fade then
		self.billboard.Enabled = false
		self.visible = false
		return
	end
	self:setTransparency(over / self.fade)
end

return ProgressBillboard

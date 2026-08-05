--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Farming = require(ReplicatedStorage:WaitForChild("Shared").Modules.Config.Farming)
local FarmController = {}
local TAG = "FarmPlot"
local TIMER_NAME = "OwnerCropTimer"
local tracked: { [Model]: boolean } = {}

local function clockText(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
end

local function labelIn(model: Model, name: string): TextLabel?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("TextLabel") then found else nil
end

local function destroyCropTimer(model: Model)
	local existing = model:FindFirstChild(TIMER_NAME)
	if existing then
		existing:Destroy()
	end
end

local function makeCropTimer(model: Model): BillboardGui?
	local adornee = model.PrimaryPart or model:FindFirstChild("Base")
	if not adornee or not adornee:IsA("BasePart") then
		return nil
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = TIMER_NAME
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(230, 68)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 110

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(255, 248, 226)
	background.BackgroundTransparency = 0.08
	background.BorderSizePixel = 0
	background.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = background

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(94, 132, 76)
	stroke.Thickness = 2
	stroke.Transparency = 0.12
	stroke.Parent = background

	local label = Instance.new("TextLabel")
	label.Name = "Timer"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(8, 5)
	label.Size = UDim2.new(1, -16, 1, -10)
	label.Font = Enum.Font.FredokaOne
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(68, 95, 54)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = background

	gui.Parent = model
	return gui
end

local function updateCropTimer(model: Model)
	local cropId = model:GetAttribute("CropId")
	local maturesAt = model:GetAttribute("MaturesAt")
	if type(cropId) ~= "string" or type(maturesAt) ~= "number" then
		destroyCropTimer(model)
		return
	end
	local definition = Farming.cropDefinition(cropId)
	if not definition then
		destroyCropTimer(model)
		return
	end

	local found = model:FindFirstChild(TIMER_NAME)
	local gui = if found and found:IsA("BillboardGui") then found else makeCropTimer(model)
	if not gui then
		return
	end

	local label = gui:FindFirstChild("Timer", true)
	if not label or not label:IsA("TextLabel") then
		gui:Destroy()
		return
	end

	local remaining = maturesAt - os.time()
	local cropText = string.format("%s · YIELD %d", string.upper(cropId), definition.harvestYield)
	if remaining <= 0 then
		label.Text = string.format("%s\nREADY TO HARVEST!", cropText)
		label.TextColor3 = Color3.fromRGB(48, 132, 72)
	else
		label.Text = string.format("%s\nREADY IN %s", cropText, clockText(remaining))
		label.TextColor3 = Color3.fromRGB(68, 95, 54)
	end
end

local function update(model: Model)
	if not model.Parent then
		destroyCropTimer(model)
		tracked[model] = nil
		return
	end
	updateCropTimer(model)

	local status = labelIn(model, "Status")
	local auction = labelIn(model, "Auction")
	if not status or not auction then
		return
	end

	local ownerName = model:GetAttribute("OwnerName")
	local leaseEndsAt = model:GetAttribute("LeaseEndsAt")
	local cropId = model:GetAttribute("CropId")
	local visualStage = model:GetAttribute("VisualStage")
	if type(ownerName) == "string" and type(leaseEndsAt) == "number" then
		local cropText = if type(cropId) == "string"
			then string.format(" · %s %s", cropId, if type(visualStage) == "string" then visualStage else "planted")
			else ""
		status.Text = string.format("%s · %s%s", ownerName, clockText(leaseEndsAt - os.time()), cropText)
	else
		status.RichText = true
		status.Text = '<font transparency="0.5">Vacant</font> · Rent Yen 20'
	end

	local bidderName = model:GetAttribute("HighestBidderName")
	local highestBid = model:GetAttribute("HighestBid")
	if type(bidderName) == "string" and type(highestBid) == "number" then
		auction.Text = string.format("Next: %s · Yen %d", bidderName, highestBid)
	elseif type(ownerName) == "string" then
		auction.Text = "Next lease: bidding from Yen 20"
	else
		auction.Text = ""
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	tracked[instance] = true
	update(instance)
end

function FarmController.init()
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("Model") then
			destroyCropTimer(instance)
			tracked[instance] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for model in tracked do
				update(model)
			end
		end
	end)
end

return FarmController

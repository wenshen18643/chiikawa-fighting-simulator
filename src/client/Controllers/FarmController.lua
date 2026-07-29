--!strict

local CollectionService = game:GetService("CollectionService")

local FarmController = {}

local TAG = "FarmPlot"
local tracked: { [Model]: boolean } = {}

local function clockText(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
end

local function labelIn(model: Model, name: string): TextLabel?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("TextLabel") then found else nil
end

local function update(model: Model)
	if not model.Parent then
		tracked[model] = nil
		return
	end

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
		status.Text = "Vacant · Rent Yen 20"
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

--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Farming = require(Shared.Modules.Config.Farming)

type BigNum = BigNumber.BigNum

export type BidState = {
	userId: number,
	name: string,
	amount: number,
}

export type CropState = {
	id: string,
	plantedAt: number,
	xpPerItem: BigNum,
}

export type Snapshot = {
	plotId: number,
	ownerUserId: number?,
	ownerName: string?,
	leaseEndsAt: number?,
	crop: { id: string, plantedAt: number, maturesAt: number }?,
	highestBid: number?,
	highestBidderUserId: number?,
	highestBidderName: string?,
	minimumBid: number,
	serverNow: number,
}

export type Dependencies = {
	clock: () -> number,
	onLeaseExpired: (number, number) -> (),
	renderCrop: (Folder, string, number, CFrame) -> (),
}

local FarmPlot = {}
FarmPlot.__index = FarmPlot

type Fields = {
	_id: number,
	_model: Model,
	_base: BasePart,
	_cropFolder: Folder,
	_cropCFrame: CFrame,
	_dependencies: Dependencies,
	_ownerUserId: number?,
	_ownerName: string?,
	_leaseEndsAt: number?,
	_bid: BidState?,
	_crop: CropState?,
	_leaseGeneration: number,
	_cropGeneration: number,
	_leaseTask: thread?,
	_cropTasks: { thread },
	_destroyed: boolean,
}

export type FarmPlot = typeof(setmetatable({} :: Fields, FarmPlot))

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function makeSign(parent: Instance, baseCFrame: CFrame, plotId: number): BasePart
	local post = makePart(
		parent,
		"SignPost",
		Vector3.new(0.8, 5, 0.8),
		baseCFrame * CFrame.new(0, 3.2, Farming.PLOT_SIZE / 2 - 1.2),
		Color3.fromRGB(136, 100, 72)
	)
	post.Material = Enum.Material.Wood

	local gui = Instance.new("BillboardGui")
	gui.Name = "PlotStatus"
	gui.Size = UDim2.fromOffset(210, 100)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	gui.MaxDistance = 180
	gui.AlwaysOnTop = false
	gui.Parent = post

	local function label(name: string, y: number, height: number, text: string, font: Enum.Font): TextLabel
		local item = Instance.new("TextLabel")
		item.Name = name
		item.BackgroundTransparency = 1
		item.Position = UDim2.fromScale(0, y)
		item.Size = UDim2.fromScale(1, height)
		item.Font = font
		item.Text = text
		item.TextScaled = true
		item.TextColor3 = Color3.fromRGB(255, 255, 255)
		item.TextStrokeTransparency = 0.25
		item.Parent = gui
		return item
	end

	label("Title", 0, 0.34, `Plot {string.format("%02d", plotId)}`, Enum.Font.FredokaOne)
	label("Status", 0.34, 0.34, "Vacant · Rent ¥20", Enum.Font.GothamBold)
	label("Auction", 0.68, 0.32, "", Enum.Font.Gotham)
	return post
end

local function cancelThread(owned: thread?)
	if owned then
		pcall(task.cancel, owned)
	end
end

function FarmPlot.new(
	plotId: number,
	cframe: CFrame,
	parent: Instance,
	dependencies: Dependencies
): FarmPlot
	local model = Instance.new("Model")
	model.Name = `FarmPlot_{string.format("%02d", plotId)}`

	local base = makePart(
		model,
		"Base",
		Vector3.new(Farming.PLOT_SIZE, Farming.PLOT_THICKNESS, Farming.PLOT_SIZE),
		cframe,
		Color3.fromRGB(132, 101, 72)
	)
	base.Material = Enum.Material.Ground
	base.CanCollide = true

	local soil = makePart(
		model,
		"Soil",
		Vector3.new(Farming.PLOT_SIZE - 3, 0.5, Farming.PLOT_SIZE - 3),
		cframe * CFrame.new(0, Farming.PLOT_THICKNESS / 2 + 0.24, 0),
		Color3.fromRGB(102, 72, 51)
	)
	soil.Material = Enum.Material.Ground

	local edge = Farming.PLOT_SIZE / 2 - 0.5
	for _, spec in {
		{ size = Vector3.new(Farming.PLOT_SIZE, 0.8, 0.7), offset = Vector3.new(0, 1.35, -edge) },
		{ size = Vector3.new(Farming.PLOT_SIZE, 0.8, 0.7), offset = Vector3.new(0, 1.35, edge) },
		{ size = Vector3.new(0.7, 0.8, Farming.PLOT_SIZE), offset = Vector3.new(-edge, 1.35, 0) },
		{ size = Vector3.new(0.7, 0.8, Farming.PLOT_SIZE), offset = Vector3.new(edge, 1.35, 0) },
	} do
		local border = makePart(model, "Border", spec.size, cframe * CFrame.new(spec.offset), Color3.fromRGB(176, 132, 86))
		border.Material = Enum.Material.WoodPlanks
		border.CanQuery = false
	end

	makeSign(model, cframe, plotId)

	local cropFolder = Instance.new("Folder")
	cropFolder.Name = "Crop"
	cropFolder.Parent = model

	model.PrimaryPart = base
	model:SetAttribute("PlotId", plotId)
	model:SetAttribute("RentPrice", Farming.RENT_PRICE)
	model:SetAttribute("VisualStage", "empty")
	model.Parent = parent
	CollectionService:AddTag(model, "FarmPlot")

	local self = setmetatable({
		_id = plotId,
		_model = model,
		_base = base,
		_cropFolder = cropFolder,
		_cropCFrame = cframe * CFrame.new(0, Farming.PLOT_THICKNESS / 2 + 0.52, 0),
		_dependencies = dependencies,
		_ownerUserId = nil,
		_ownerName = nil,
		_leaseEndsAt = nil,
		_bid = nil,
		_crop = nil,
		_leaseGeneration = 0,
		_cropGeneration = 0,
		_leaseTask = nil,
		_cropTasks = {},
		_destroyed = false,
	} :: Fields, FarmPlot)

	return self
end

function FarmPlot.getId(self: FarmPlot): number
	return self._id
end

function FarmPlot.getPosition(self: FarmPlot): Vector3
	return self._base.Position
end

function FarmPlot.getOwnerUserId(self: FarmPlot): number?
	return self._ownerUserId
end

function FarmPlot.getLeaseEndsAt(self: FarmPlot): number?
	return self._leaseEndsAt
end

function FarmPlot.isActive(self: FarmPlot, now: number): boolean
	return self._ownerUserId ~= nil and self._leaseEndsAt ~= nil and now < self._leaseEndsAt
end

function FarmPlot.getBid(self: FarmPlot): BidState?
	local bid = self._bid
	return if bid then { userId = bid.userId, name = bid.name, amount = bid.amount } else nil
end

function FarmPlot.getCrop(self: FarmPlot): CropState?
	local crop = self._crop
	return if crop
		then { id = crop.id, plantedAt = crop.plantedAt, xpPerItem = BigNumber.clone(crop.xpPerItem) }
		else nil
end

function FarmPlot.refreshAttributes(self: FarmPlot)
	local bid = self._bid
	local crop = self._crop
	local growthSeconds = if crop then Farming.growthSeconds(crop.id) else nil
	self._model:SetAttribute("OwnerUserId", self._ownerUserId)
	self._model:SetAttribute("OwnerName", self._ownerName)
	self._model:SetAttribute("LeaseEndsAt", self._leaseEndsAt)
	self._model:SetAttribute("HighestBid", if bid then bid.amount else nil)
	self._model:SetAttribute("HighestBidderUserId", if bid then bid.userId else nil)
	self._model:SetAttribute("HighestBidderName", if bid then bid.name else nil)
	self._model:SetAttribute("CropId", if crop then crop.id else nil)
	self._model:SetAttribute("PlantedAt", if crop then crop.plantedAt else nil)
	self._model:SetAttribute("MaturesAt", if crop and growthSeconds then crop.plantedAt + growthSeconds else nil)
end

function FarmPlot.beginLease(self: FarmPlot, userId: number, name: string, endsAt: number)
	self._ownerUserId = userId
	self._ownerName = name
	self._leaseEndsAt = endsAt
	self._bid = nil
	self._leaseGeneration += 1
	local generation = self._leaseGeneration
	cancelThread(self._leaseTask)
	self._leaseTask = task.delay(math.max(0, endsAt - self._dependencies.clock()), function()
		if not self._destroyed and generation == self._leaseGeneration then
			self._dependencies.onLeaseExpired(self._id, generation)
		end
	end)
	self:refreshAttributes()
end

function FarmPlot.vacate(self: FarmPlot)
	self._ownerUserId = nil
	self._ownerName = nil
	self._leaseEndsAt = nil
	self._bid = nil
	self._leaseGeneration += 1
	cancelThread(self._leaseTask)
	self._leaseTask = nil
	self:clearCrop()
	self:refreshAttributes()
end

function FarmPlot.setBid(self: FarmPlot, bid: BidState?)
	self._bid = if bid then { userId = bid.userId, name = bid.name, amount = bid.amount } else nil
	self:refreshAttributes()
end

function FarmPlot.takeBid(self: FarmPlot): BidState?
	local bid = self:getBid()
	self._bid = nil
	self:refreshAttributes()
	return bid
end

function FarmPlot.renderCrop(self: FarmPlot, now: number)
	self._cropFolder:ClearAllChildren()
	local crop = self._crop
	if not crop then
		self._model:SetAttribute("VisualStage", "empty")
		return
	end

	local elapsed = math.max(0, now - crop.plantedAt)
	local growthSeconds = Farming.growthSeconds(crop.id)
	assert(growthSeconds, `Missing farming definition for {crop.id}`)
	local stage = if elapsed >= growthSeconds
		then 3
		elseif elapsed >= growthSeconds / 2 then 2
		else 1
	self._model:SetAttribute("VisualStage", if stage == 3 then "ready" elseif stage == 2 then "growing" else "planted")
	self._dependencies.renderCrop(self._cropFolder, crop.id, stage, self._cropCFrame)
end

function FarmPlot.plant(self: FarmPlot, crop: CropState)
	self:clearCrop()
	self._crop = {
		id = crop.id,
		plantedAt = crop.plantedAt,
		xpPerItem = BigNumber.clone(crop.xpPerItem),
	}
	self._cropGeneration += 1
	local generation = self._cropGeneration
	self:renderCrop(self._dependencies.clock())
	self:refreshAttributes()

	local growthSeconds = Farming.growthSeconds(crop.id)
	assert(growthSeconds, `Missing farming definition for {crop.id}`)
	for _, threshold in { growthSeconds / 2, growthSeconds } do
		local waitFor = crop.plantedAt + threshold - self._dependencies.clock()
		if waitFor > 0 then
			table.insert(self._cropTasks, task.delay(waitFor, function()
				if not self._destroyed and generation == self._cropGeneration then
					self:renderCrop(self._dependencies.clock())
				end
			end))
		end
	end
end

function FarmPlot.clearCrop(self: FarmPlot)
	self._cropGeneration += 1
	for _, owned in self._cropTasks do
		cancelThread(owned)
	end
	table.clear(self._cropTasks)
	self._crop = nil
	self._cropFolder:ClearAllChildren()
	self._model:SetAttribute("VisualStage", "empty")
	self:refreshAttributes()
end

function FarmPlot.takeCrop(self: FarmPlot): CropState?
	local crop = self:getCrop()
	self:clearCrop()
	return crop
end

function FarmPlot.snapshot(self: FarmPlot, now: number): Snapshot
	local bid = self._bid
	local crop = self._crop
	local growthSeconds = if crop then Farming.growthSeconds(crop.id) else nil
	return {
		plotId = self._id,
		ownerUserId = self._ownerUserId,
		ownerName = self._ownerName,
		leaseEndsAt = self._leaseEndsAt,
		crop = if crop
			then {
				id = crop.id,
				plantedAt = crop.plantedAt,
				maturesAt = crop.plantedAt + assert(growthSeconds, `Missing farming definition for {crop.id}`),
			}
			else nil,
		highestBid = if bid then bid.amount else nil,
		highestBidderUserId = if bid then bid.userId else nil,
		highestBidderName = if bid then bid.name else nil,
		minimumBid = Farming.minimumBid(if bid then bid.amount else nil),
		serverNow = now,
	}
end

function FarmPlot.Destroy(self: FarmPlot)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._leaseGeneration += 1
	self._cropGeneration += 1
	cancelThread(self._leaseTask)
	for _, owned in self._cropTasks do
		cancelThread(owned)
	end
	table.clear(self._cropTasks)
	CollectionService:RemoveTag(self._model, "FarmPlot")
	self._model:Destroy()
end

return FarmPlot

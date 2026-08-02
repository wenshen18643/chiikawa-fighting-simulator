local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Constants = require(Shared.Modules.Constants)
local Market = require(Shared.Modules.Config.Market)
local UI = require(Shared.UI)
local YoroiRig = require(Shared.Modules.YoroiRig)
local AssetService = require(script.Parent.AssetService)
local MarketService = {}
local FOLDER_NAME = "Market"
local folder: Folder
local origin: Vector3

local function groundAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }

	local from = origin + Vector3.new(x, 220, z)
	local hit = Workspace:Raycast(from, Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else origin.Y + Constants.WORLD.PLATFORM_TOP
end

local function place(row: Market.Placement): Model?
	local model = AssetService.clone(row.asset)
	if not model then
		warn(`[MarketService] asset "{row.asset}" did not load`)
		return nil
	end

	local x = Market.CENTRE.X + row.x
	local z = Market.CENTRE.Y + row.z
	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	if largest > 0.01 then
		model:ScaleTo(model:GetScale() * (row.fit / largest))
		extents *= row.fit / largest
	end

	model:PivotTo(CFrame.new(origin + Vector3.new(x, 0, z)) * CFrame.Angles(0, math.rad(row.yaw or 0), 0))

	local landed, size = model:GetBoundingBox()
	local wanted = Vector3.new(origin.X + x, groundAt(x, z) + size.Y / 2, origin.Z + z)
	model:PivotTo(model:GetPivot() + (wanted - landed.Position))

	if row.name then
		model.Name = row.name
	end

	model:SetAttribute("PlotSize", extents)
	model:SetAttribute("PlotCentre", wanted)
	model:SetAttribute("PlotYaw", row.yaw or 0)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	model.Parent = folder
	return model
end

local function boothStation(): (Vector3?, number?)
	local booth = folder:FindFirstChild(Market.YOROI.booth)
	if not (booth and booth:IsA("Model")) then
		return nil, nil
	end

	local centre = booth:GetAttribute("PlotCentre")
	local size = booth:GetAttribute("PlotSize")
	local yaw = booth:GetAttribute("PlotYaw")
	if typeof(centre) ~= "Vector3" or typeof(size) ~= "Vector3" or type(yaw) ~= "number" then
		return nil, nil
	end

	local spot = Market.YOROI
	local frame = CFrame.new(centre) * CFrame.Angles(0, math.rad(yaw), 0)
	local station = frame * CFrame.new(spot.outFromCounter * size.X / 2, 0, spot.alongCounter * size.Z / 2)
	return station.Position, yaw + spot.facingOffset
end

local function prompt(parent: BasePart, name: string, objectText: string, actionText: string)
	local made = Instance.new("ProximityPrompt")
	made.Name = name
	made.ObjectText = objectText
	made.ActionText = actionText
	made.HoldDuration = 0
	made.MaxActivationDistance = 14
	made.RequiresLineOfSight = false
	made.Parent = parent
end

local function anchorOf(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function buildCounter()
	local counter = folder:FindFirstChild(Market.UPGRADE_COUNTER)
	if not (counter and counter:IsA("Model")) then
		warn("[MarketService] the upgrade counter did not load; upgrades cannot be bought")
		return
	end

	local anchor = anchorOf(counter)
	if not anchor then
		return
	end

	prompt(anchor, "ShopPrompt", "Upgrades", "Spend yen")
	UI.sign(anchor, {
		name = "UpgradeSign",
		title = "Upgrades",
		subtitle = "training, wages, stamina",
		offset = Vector3.new(0, 10, 0),
		extent = UDim2.fromScale(16, 4.5),
		maxDistance = 140,
	})
end

local function buildYoroi()
	local model = AssetService.clone("yoroiKnight")
	if not model then
		warn("[MarketService] yoroiKnight did not load; the job booth is unstaffed")
		return
	end

	model.Name = "YoroiSan"

	local root = YoroiRig.rig(model, Market.YOROI.height)
	if not root then
		model:Destroy()
		return
	end

	local station, facing = boothStation()
	if not (station and facing) then
		warn("[MarketService] job booth is not placed; the attendant has nothing to stand beside")
		model:Destroy()
		return
	end

	model:PivotTo(CFrame.new(station) * CFrame.Angles(0, math.rad(facing), 0))
	local box, size = model:GetBoundingBox()
	local lift = (groundAt(station.X - origin.X, station.Z - origin.Z) + size.Y / 2) - box.Position.Y
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))

	model.Parent = folder

	UI.sign(root, {
		name = "BoothSign",
		title = "Weeding — apply here",
		subtitle = "certification raises the rate",
		offset = Vector3.new(0, 9, 0),
		extent = UDim2.fromScale(16, 4.5),
		maxDistance = 140,
	})

	prompt(root, "OrderBoardPrompt", "Yoroi-san", "Work orders")
end

function MarketService.init()
	local town = Areas.BY_ID[Areas.STARTING_AREA]
	if not town then
		warn("[MarketService] no starting area; the market has nowhere to stand")
		return
	end
	origin = town.origin

	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	for _, row in Market.stalls do
		place(row)
	end
	place(Market.beast)

	buildCounter()
	buildYoroi()
end

return MarketService

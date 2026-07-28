--[[
	Builds the training districts and answers "which worksite is this player
	standing in, and are they allowed to be credited for it?"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local Areas = require(Shared.Areas)
local Area = require(Shared.Areas.Area)
local Layout = require(Shared.Modules.Config.Layout)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)

local DataService = require(script.Parent.DataService)
local WeedService = require(script.Parent.WeedService)
local WorldService = require(script.Parent.WorldService)

local WorksiteService = {}

local OCCUPANCY_INTERVAL = 0.2

export type Occupancy = { worksiteId: string, regionId: number }

local padsByRegion: { [number]: { [string]: BasePart } } = {}
local occupancy: { [Player]: Occupancy? } = {}
local blocked: { [Player]: Occupancy? } = {}

--------------------------------------------------------------------------------
-- World building
--------------------------------------------------------------------------------

local function makeLabel(parent: BasePart, worksite: Worksites.WorksiteDefinition)
	local skill = Skills.get(worksite.skill)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(16, 5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 320
	gui.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.45)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = worksite.name
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromScale(0, 0.45)
	subtitle.Size = UDim2.fromScale(1, 0.3)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextScaled = true
	subtitle.TextStrokeTransparency = 0.6
	subtitle.TextColor3 = skill and skill.color or Color3.new(1, 1, 1)
	subtitle.Text = `TIER {worksite.tier}  ·  x{worksite.multiplier}`
	subtitle.Parent = gui

	local requirement = Instance.new("TextLabel")
	requirement.Name = "Requirement"
	requirement.Position = UDim2.fromScale(0, 0.75)
	requirement.Size = UDim2.fromScale(1, 0.25)
	requirement.BackgroundTransparency = 1
	requirement.Font = Enum.Font.Gotham
	requirement.TextScaled = true
	requirement.TextStrokeTransparency = 0.7
	requirement.TextColor3 = Color3.fromRGB(238, 232, 224)
	requirement.Text = if BigNumber.isZero(BigNumber.coerce(worksite.requirement))
		then "open to everyone"
		else `needs {BigNumber.toString(BigNumber.coerce(worksite.requirement))}`
	requirement.Parent = gui
end

local function buildWorksite(worksite: Worksites.WorksiteDefinition, cframe: CFrame, folder: Folder, regionId: number)
	local skill = Skills.get(worksite.skill)
	local color = skill and skill.color or Color3.fromRGB(160, 160, 160)
	local size = Constants.WORLD.WORKSITE_SIZE
	local border = Constants.WORLD.WORKSITE_BORDER

	local area = Areas.get(regionId)
	local frame = Instance.new("Part")
	frame.Name = `{worksite.id}_Frame`
	frame.Anchored = true
	frame.CanCollide = true
	frame.Size = Vector3.new(size.X + border, 0.2, size.Z + border)
	frame.CFrame = cframe * CFrame.new(0, -0.1, 0)
	frame.Color = color:Lerp(area.palette.ground, 0.4)
	frame.Material = Enum.Material.Concrete
	frame.TopSurface = Enum.SurfaceType.Smooth
	frame.Parent = folder

	local part = Instance.new("Part")
	part.Name = worksite.id
	part.Anchored = true
	part.CanCollide = true
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.Grass
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("WorksiteId", worksite.id)
	part:SetAttribute("Skill", worksite.skill)
	part:SetAttribute("RegionId", regionId)
	part.Parent = folder

	local post = Instance.new("Part")
	post.Name = `{worksite.id}_Post`
	post.Anchored = true
	post.CanCollide = false
	post.Size = Vector3.new(1.2, 10, 1.2)
	post.CFrame = cframe * CFrame.new(0, 5, -size.Z / 2 + 2)
	post.Color = Color3.fromRGB(150, 118, 90)
	post.Material = Enum.Material.Wood
	post.Parent = folder

	makeLabel(post, worksite)

	--[[
		A partial DecorateContext. These props are built onto a pad rather than
		into an area, so there is no area file and no reserved-ground map — but
		the helpers still expect somewhere to parent to, a palette to read, and
		an rng. Seeded off the worksite id so a given pad looks the same on
		every server, which is the same promise Areas makes.
	]]
	local dummyCtx = {
		origin = cframe.Position,
		area = { palette = { prop = color } },
		parent = folder,
		rng = Random.new(#worksite.id * 7919 + worksite.tier),
	}

	--[[
		Tier is visible on the prop itself.

		§17's ladder is seven tiers deep and, until now, a tier-7 pad looked
		exactly like a tier-1 one. Scaling the prop is the cheapest read on "you
		have got further here" that does not cost a UI element — bigger forks,
		massive weeds, taller waterfalls. Sublinear, and matched to the tool
		scale GestureController puts in the player's hands, so the fork on the
		pad and the fork being swung at it agree.
	]]
	local propScale = 1 + math.clamp(worksite.tier - 1, 0, 6) * 0.14

	local prop: Model? = nil
	if worksite.skill == "examprep" or worksite.skill == "special" or worksite.skill == "craft" then
		prop = Area.helpers.studyDesk(dummyCtx, { x = 0, z = 0, y = 2.4, parent = folder, tier = worksite.tier })
	elseif worksite.skill == "kusatori" or worksite.skill == "agility" or worksite.skill == "weeding" then
		prop = Area.helpers.weedingPatch(dummyCtx, { x = 0, z = 0, y = 1.2, parent = folder, tier = worksite.tier })
	elseif worksite.skill == "tobatsu" or worksite.skill == "strength" or worksite.skill == "subjugation" then
		prop = Area.helpers.sasumataDummy(dummyCtx, { x = 0, z = 0, y = 4.2, parent = folder, tier = worksite.tier })
	elseif worksite.skill == "resilience" or worksite.skill == "durability" or worksite.skill == "grit" then
		prop = Area.helpers.waterfallZone(dummyCtx, { x = 0, z = -12, y = 8.0, parent = folder, tier = worksite.tier })
	end

	--[[
		Scaling happens about the model's pivot, which is its bounding-box
		centre — so a prop that grows also sinks half its new height into the
		ground. Lift it back by the difference to keep its base planted.
	]]
	if prop and propScale ~= 1 then
		local pivotBefore, sizeBefore = prop:GetBoundingBox()
		prop:ScaleTo(propScale)
		local _, sizeAfter = prop:GetBoundingBox()
		prop:PivotTo(pivotBefore + Vector3.new(0, (sizeAfter.Y - sizeBefore.Y) / 2, 0))
	end

	if prop and (worksite.skill == "kusatori" or worksite.skill == "agility" or worksite.skill == "weeding") then
		WeedService.registerPatch(prop, function(child)
			return child.Name:match("^WeedSprout_") ~= nil
		end)
	end

	return part
end

local function buildDistrictArch(_area: Areas.AreaDefinition, district: Layout.District, folder: Folder)
	local skill = Skills.get(district.skillId)
	if not skill or #district.worksites == 0 then
		return
	end

	local width = Constants.WORLD.WORKSITE_SIZE.X + 26
	local height = 30

	for _, side in { -1, 1 } do
		local pillar = Instance.new("Part")
		pillar.Name = "ArchPillar"
		pillar.Anchored = true
		pillar.CanCollide = true
		pillar.Size = Vector3.new(5, height, 5)
		pillar.CFrame = district.archCFrame * CFrame.new(side * width / 2, height / 2 - 1, 0)
		pillar.Color = Color3.fromRGB(226, 218, 204)
		pillar.Material = Enum.Material.Concrete
		pillar.Parent = folder
	end

	local lintel = Instance.new("Part")
	lintel.Name = `{district.skillId}_Arch`
	lintel.Anchored = true
	lintel.CanCollide = true
	lintel.Size = Vector3.new(width + 5, 6, 5)
	lintel.CFrame = district.archCFrame * CFrame.new(0, height - 1, 0)
	lintel.Color = skill.color
	lintel.Material = Enum.Material.SmoothPlastic
	lintel.Parent = folder

	local top = district.worksites[#district.worksites]
	local gui = Instance.new("BillboardGui")
	gui.Name = "ArchBanner"
	gui.Size = UDim2.fromScale(24, 7)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	gui.MaxDistance = 700
	gui.Parent = lintel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.35
	title.Text = string.upper(skill.name)
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromScale(0, 0.6)
	subtitle.Size = UDim2.fromScale(1, 0.4)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextScaled = true
	subtitle.TextStrokeTransparency = 0.6
	subtitle.TextColor3 = Color3.fromRGB(240, 234, 226)
	subtitle.Text = `tiers 1 to {top.tier}  ·  up to x{top.multiplier}`
	subtitle.Parent = gui
end

local function buildRegion(area: Areas.AreaDefinition)
	local folder = WorldService.getRegionFolder(area.id)
	if not folder then
		warn(`[WorksiteService] no world folder for region {area.id} - did WorldService run first?`)
		return
	end

	local pads = Instance.new("Folder")
	pads.Name = "Worksites"
	pads.Parent = folder

	padsByRegion[area.id] = {}

	for _, district in Layout.districts(area) do
		buildDistrictArch(area, district, pads)

		for tierIndex, worksite in district.worksites do
			local cframe = Layout.padCFrame(area, district.skillId, tierIndex)
			padsByRegion[area.id][worksite.id] = buildWorksite(worksite, cframe, pads, area.id)
		end
	end
end

local function buildWorksites()
	for _, area in Areas.ALL do
		buildRegion(area)
	end
end

local function validateAreaGates()
	for _, area in Areas.ALL do
		local gate = BigNumber.coerce(area.gate.skillTotal)
		for _, worksite in Worksites.getInRegion(area.id) do
			if worksite.homeRegion ~= area.id then
				continue
			end
			local requirement = BigNumber.coerce(worksite.requirement)
			if BigNumber.lt(requirement, gate) then
				warn(
					`[WorksiteService] area "{area.key}" gate ({BigNumber.toString(gate)}) is higher than `
						.. `worksite "{worksite.id}" requires ({BigNumber.toString(requirement)}).`
				)
			end
		end
	end
end

local function validateEverySkillIsTrainable()
	for _, area in Areas.ALL do
		for _, skillId in Skills.ORDER do
			-- A retired ladder (resilience) is deliberately empty, not a config bug.
			if #Worksites.getLadder(skillId) == 0 then
				continue
			end
			local available = Worksites.getInRegionForSkill(area.id, skillId)
			local entry = available[1]
			if not entry or not BigNumber.isZero(BigNumber.coerce(entry.requirement)) then
				warn(`[WorksiteService] area "{area.key}" has no zero-requirement {skillId} worksite.`)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Occupancy
--------------------------------------------------------------------------------

function WorksiteService.getSpawnCFrame(regionId: number): CFrame?
	return WorldService.getSpawnCFrame(regionId)
end

function WorksiteService.getOccupied(player: Player): Occupancy?
	return occupancy[player]
end

function WorksiteService.getBlocked(player: Player): Occupancy?
	return blocked[player]
end

function WorksiteService.isInSkillDistrict(player: Player, skillId: string): boolean
	if not Skills.exists(skillId) then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end

	local canonical = Skills.canonicalize(skillId)
	local area = Layout.areaAt(root.Position)
	local profile = DataService.get(player)
	if not profile or not profile.unlockedRegions[tostring(area.id)] then
		return false
	end
	local district = Layout.districtFor(area, canonical)
	local point = district.plateCFrame:PointToObjectSpace(root.Position)
	local half = district.plateSize / 2
	local tolerance = Constants.WORK.POSITION_TOLERANCE

	return math.abs(point.X) <= half.X + tolerance
		and math.abs(point.Z) <= half.Z + tolerance
		and point.Y >= -tolerance
		and point.Y <= half.Y + 12
end

function WorksiteService.explain(profile: any, spot: Occupancy): string?
	local _, reason = WorksiteService.canUse(profile, spot.worksiteId, spot.regionId)
	return reason
end

function WorksiteService.canUse(profile: any, worksiteId: string, regionId: number): (boolean, string?)
	local worksite = Worksites.get(worksiteId)
	if not worksite then
		return false, "That worksite does not exist."
	end
	if worksite.homeRegion > regionId then
		return false, "That worksite is not built here."
	end
	if not profile.unlockedRegions[tostring(regionId)] then
		local region = Areas.get(regionId)
		return false, `{region and region.name or "That area"} is not open to you yet.`
	end
	if not Formulas.meetsWorksiteRequirement(profile, worksiteId) then
		local skill = Skills.get(worksite.skill)
		return false, `You need more {skill and skill.name or worksite.skill} to work here.`
	end
	return true
end

local function resolveOccupancy(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		occupancy[player] = nil
		blocked[player] = nil
		return
	end

	local profile = DataService.get(player)
	if not profile then
		occupancy[player] = nil
		blocked[player] = nil
		return
	end

	local position = root.Position
	local area = Layout.areaAt(position)
	local pads = padsByRegion[area.id]
	if not pads then
		occupancy[player] = nil
		blocked[player] = nil
		return
	end

	local tolerance = Constants.WORK.POSITION_TOLERANCE

	local bestUsable, bestUsableDistance = nil, math.huge
	local bestBlocked, bestBlockedDistance = nil, math.huge

	for worksiteId, pad in pads do
		local point = pad.CFrame:PointToObjectSpace(position)
		local half = pad.Size / 2
		local insideX = math.abs(point.X) <= half.X + tolerance
		local insideZ = math.abs(point.Z) <= half.Z + tolerance
		local insideY = point.Y >= -tolerance and point.Y <= half.Y + 12

		if insideX and insideZ and insideY then
			local flat = Vector3.new(point.X, 0, point.Z).Magnitude
			if WorksiteService.canUse(profile, worksiteId, area.id) then
				if flat < bestUsableDistance then
					bestUsable, bestUsableDistance = worksiteId, flat
				end
			elseif flat < bestBlockedDistance then
				bestBlocked, bestBlockedDistance = worksiteId, flat
			end
		end
	end

	occupancy[player] = if bestUsable then { worksiteId = bestUsable, regionId = area.id } else nil
	blocked[player] = if bestUsable or not bestBlocked then nil else { worksiteId = bestBlocked, regionId = area.id }
end

function WorksiteService.validate(player: Player, profile: any, spot: Occupancy): boolean
	local current = occupancy[player]
	if not current or current.worksiteId ~= spot.worksiteId or current.regionId ~= spot.regionId then
		return false
	end
	return (WorksiteService.canUse(profile, spot.worksiteId, spot.regionId))
end

function WorksiteService.init()
	buildWorksites()
	validateAreaGates()
	validateEverySkillIsTrainable()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator < OCCUPANCY_INTERVAL then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			resolveOccupancy(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		occupancy[player] = nil
		blocked[player] = nil
	end)
end

return WorksiteService

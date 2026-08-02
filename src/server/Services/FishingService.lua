--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Budget = require(Shared.Modules.Budget)
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Fishing = require(Shared.Modules.Config.Fishing)
local UI = require(Shared.UI)
local ForagingService = require(script.Parent.ForagingService)
local HarvestNodes = require(script.Parent.HarvestNodes)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local WorldService = require(script.Parent.WorldService)
local FishingService = {}
local WORLD = Constants.WORLD
local WOOD = Color3.fromRGB(168, 132, 98)
local WOOD_DARK = Color3.fromRGB(126, 94, 68)
local FLOAT_RED = Color3.fromRGB(238, 116, 108)
local folder: Folder
local nodes = HarvestNodes.new({
	tag = "FishingSpot",
	slot = "rod",
	skill = "resilience",
	reach = Fishing.SPOT.radius,
	verb = "Landed",
})

FishingService.ready = false
local readySignal = Instance.new("BindableEvent")

function FishingService.awaitReady()
	if FishingService.ready then
		return
	end
	readySignal.Event:Wait()
end

local function part(config: { [string]: any }): BasePart
	local piece = Instance.new("Part")
	piece.Name = config.name or "Part"
	piece.Anchored = true
	piece.CanCollide = config.collide ~= false
	piece.CanQuery = config.collide ~= false
	piece.CanTouch = false
	piece.Size = config.size
	piece.CFrame = config.cframe
	piece.Color = config.color or WOOD
	piece.Material = config.material or Enum.Material.WoodPlanks
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	if config.shape then
		piece.Shape = config.shape
	end
	piece.Parent = config.parent or folder
	return piece
end

local function carveLake(area: Areas.AreaDefinition, centre: Vector2, step: any)
	local lake = Fishing.LAKE
	local top = WORLD.TERRAIN_TOP
	local islandBottom = top - WORLD.ISLAND_DEPTH / 2 - WORLD.ISLAND_DEPTH
	local waterTop = top - lake.surfaceDrop
	local floorY = math.max(top - lake.depth, islandBottom + lake.bedClearance)
	local basinDepth = top - floorY
	local rings = 6

	for index = 0, rings do
		local alpha = index / rings
		local radius = lake.radius * (1 - alpha * 0.78)
		local cutTop = top + 6
		local cutBottom = top - basinDepth * (0.32 + alpha * 0.68)
		TerrainBuilder.fillCylinder(
			area.origin + Vector3.new(centre.X, (cutTop + cutBottom) / 2, centre.Y),
			cutTop - cutBottom,
			radius,
			Enum.Material.Air,
			step
		)
	end

	TerrainBuilder.fillCylinder(
		area.origin + Vector3.new(centre.X, floorY - lake.bedThickness / 2, centre.Y),
		lake.bedThickness,
		lake.radius + 4,
		Enum.Material.Sand,
		step
	)

	TerrainBuilder.fillCylinder(
		area.origin + Vector3.new(centre.X, (waterTop + floorY) / 2, centre.Y),
		waterTop - floorY,
		lake.radius,
		Enum.Material.Water,
		step
	)
end

local function buildPier(area: Areas.AreaDefinition, base: Vector2, tip: Vector2)
	local pier = Fishing.PIER
	local deckY = area.origin.Y + WORLD.TERRAIN_TOP + pier.deckY
	local span = tip - base
	local length = span.Magnitude
	local yaw = math.atan2(span.X, span.Y)
	local model = Instance.new("Model")
	model.Name = "Pier"
	model.Parent = folder

	local centre = (base + tip) / 2
	local deckFrame = CFrame.new(area.origin + Vector3.new(centre.X, deckY, centre.Y)) * CFrame.Angles(0, yaw, 0)

	part({
		name = "Deck",
		size = Vector3.new(pier.width, 0.8, length + 6),
		cframe = deckFrame,
		color = WOOD,
		parent = model,
	})

	local posts = math.max(2, math.floor(length / pier.postEvery))
	for index = 0, posts do
		local along = (index / posts - 0.5) * length
		for _, side in { -1, 1 } do
			local offset = Vector3.new(side * (pier.width / 2 - 0.8), 0, along)
			local postTop = deckFrame * CFrame.new(offset)
			local height = pier.deckY + Fishing.LAKE.depth * 0.7
			part({
				name = "Post",
				size = Vector3.new(0.9, height, 0.9),
				cframe = CFrame.new(postTop.Position - Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, yaw, 0),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
				parent = model,
			})
			part({
				name = "Rail",
				size = Vector3.new(0.4, pier.railHeight, 0.4),
				cframe = postTop * CFrame.new(0, pier.railHeight / 2, 0),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
				collide = false,
				parent = model,
			})
		end
	end

	for _, side in { -1, 1 } do
		part({
			name = "HandRail",
			size = Vector3.new(0.4, 0.4, length),
			cframe = deckFrame * CFrame.new(side * (pier.width / 2 - 0.8), pier.railHeight, 0),
			color = WOOD,
			material = Enum.Material.Wood,
			collide = false,
			parent = model,
		})
	end

	local lampBase = deckFrame * CFrame.new(0, pier.railHeight + 2.4, length / 2 - 2)
	local lamp = part({
		name = "Lamp",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.2, 2.2, 2.2),
		cframe = lampBase,
		color = Color3.fromRGB(255, 232, 186),
		material = Enum.Material.Neon,
		collide = false,
		parent = model,
	})

	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range = 34
	light.Color = Color3.fromRGB(255, 226, 176)
	light.Parent = lamp

	return model
end

local function buildSpot(area: Areas.AreaDefinition, at: Vector2, index: number): (Model, Vector3)
	local model = Instance.new("Model")
	model.Name = `FishingSpot_{index}`
	model.Parent = folder

	local waterTop = area.origin.Y + WORLD.TERRAIN_TOP - Fishing.LAKE.surfaceDrop
	local centre = area.origin + Vector3.new(at.X, waterTop, at.Y)

	local ripple = part({
		name = "Ripple",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.4, 13, 13),
		cframe = CFrame.new(centre + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(206, 236, 250),
		material = Enum.Material.Neon,
		collide = false,
		parent = model,
	})
	ripple.Transparency = 0.62

	local bobber = part({
		name = "Bobber",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.5, 1.5, 1.5),
		cframe = CFrame.new(centre + Vector3.new(0, 0.7, 0)),
		color = FLOAT_RED,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		parent = model,
	})
	bobber.Transparency = 1

	local anchor = part({
		name = "Anchor",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(centre),
		color = Color3.fromRGB(255, 255, 255),
		collide = false,
		parent = model,
	})
	anchor.Transparency = 1
	model.PrimaryPart = anchor

	local sign = UI.sign(anchor, {
		name = "SpotSign",
		title = "Cast",
		subtitle = "click to fish",
		extent = UDim2.fromScale(9, 3),
		offset = Vector3.new(0, 6, 0),
		maxDistance = 130,
	})
	sign.Name = "SpotSign"

	UI.motion.loop(ripple, 2.4, { Size = Vector3.new(0.4, 17, 17), Transparency = 0.82 })

	return model, centre
end

local function showBobber(node: HarvestNodes.Node, current: number, needed: number)
	local bobber = node.model:FindFirstChild("Bobber")
	if not bobber or not bobber:IsA("BasePart") then
		return
	end

	bobber.Transparency = 0
	local dip = math.min(0.9, current / math.max(needed, 1))
	local home = node.centre + Vector3.new(0, 0.7, 0)
	local drift = Fishing.SPOT.bobberDrift
	local angle = current * 1.7
	bobber.CFrame = CFrame.new(home + Vector3.new(math.cos(angle) * drift, -dip * 0.6, math.sin(angle) * drift))

	local sign = node.model:FindFirstChild("Anchor")
	if sign then
		local label = sign:FindFirstChild("SpotSign")
		local title = label and label:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			title.Text = `Reel {current}/{needed}`
		end
	end
end

local rerollRng = Random.new(os.clock() * 1000)

local function resetSpot(node: HarvestNodes.Node)
	nodes:setIngredient(node, Fishing.roll(rerollRng))

	local bobber = node.model:FindFirstChild("Bobber")
	if bobber and bobber:IsA("BasePart") then
		bobber.Transparency = 1
	end

	local anchor = node.model:FindFirstChild("Anchor")
	local label = anchor and anchor:FindFirstChild("SpotSign")
	local title = label and label:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = "Cast"
	end
end

function FishingService.nearestSpot(position: Vector3): HarvestNodes.Node?
	return nodes:nearest(position, Fishing.SPOT.radius)
end

function FishingService.reel(player: Player, profile: any): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local node = FishingService.nearestSpot(root.Position)
	if not node then
		return false
	end

	return nodes:click(player, profile, node, Fishing.LAND_XP)
end

function FishingService.init()
	local existing = Workspace:FindFirstChild("Lake")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Lake"
	folder.Parent = Workspace

	nodes.onProgress = function(node, _player, current, needed)
		showBobber(node, current, needed)
	end

	nodes.onSpent = function(node)
		resetSpot(node)
	end
	nodes.onReset = resetSpot

	task.spawn(function()
		WorldService.awaitDressed()
		ForagingService.awaitReady()

		local area = Areas.get(Areas.STARTING_AREA)
		local centre = Fishing.centre()
		local base = Fishing.pierBase()
		local tip = Fishing.pierTip()
		if not area or not centre or not base or not tip then
			warn("[FishingService] no lake cell on the board; nothing built")
			FishingService.ready = true
			readySignal:Fire()
			return
		end

		local step = Budget.stepper()
		carveLake(area, centre, step)
		ForagingService.clearArea(area.origin + Vector3.new(centre.X, WORLD.TERRAIN_TOP, centre.Y), Fishing.LAKE.radius)
		buildPier(area, base, tip)

		for index, at in Fishing.spotPositions() do
			local model, worldCentre = buildSpot(area, at, index)
			nodes:add(model, Fishing.roll(Random.new(index * 991)), worldCentre, Fishing.CAST_CLICKS)
		end

		FishingService.ready = true
		readySignal:Fire()
	end)
end

return FishingService

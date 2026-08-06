--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Budget = require(Shared.Modules.Budget)
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Quarry = require(Shared.Modules.Config.Quarry)
local UI = require(Shared.UI)
local CaveService = require(script.Parent.CaveService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local ForagingService = require(script.Parent.ForagingService)
local HarvestNodes = require(script.Parent.HarvestNodes)
local NotifyService = require(script.Parent.NotifyService)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local WorldService = require(script.Parent.WorldService)
local QuarryService = {}
local WORLD = Constants.WORLD
local SLATE = Color3.fromRGB(150, 148, 148)
local TIMBER = Color3.fromRGB(150, 116, 84)

local SEAM_TINT = {
	chalkStone = Color3.fromRGB(238, 232, 220),
	ironOre = Color3.fromRGB(196, 140, 106),
	copperOre = Color3.fromRGB(228, 156, 96),
	quartzOre = Color3.fromRGB(206, 226, 246),
	moonOre = Color3.fromRGB(196, 174, 250),
}

local folder: Folder
local nodes = HarvestNodes.new({
	tag = "OreVein",
	slot = "pickaxe",
	skill = "tobatsu",
	reach = 20,
	verb = "Cut",
})

local function part(config: { [string]: any }): BasePart
	local piece = Instance.new("Part")
	piece.Name = config.name or "Part"
	piece.Anchored = true
	piece.CanCollide = config.collide ~= false
	piece.CanQuery = true
	piece.CanTouch = false
	piece.Size = config.size
	piece.CFrame = config.cframe
	piece.Color = config.color or SLATE
	piece.Material = config.material or Enum.Material.Slate
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	if config.shape then
		piece.Shape = config.shape
	end
	piece.Transparency = config.transparency or 0
	piece.Parent = config.parent or folder
	return piece
end

local function carvePit(area: Areas.AreaDefinition, centre: Vector2, step: any)
	local pit = Quarry.PIT
	local top = WORLD.TERRAIN_TOP

	for index = 1, pit.terraces do
		local radius = Quarry.terraceRadius(index)
		local depth = Quarry.terraceDepth(index)
		local cutTop = top + 8
		local cutBottom = top + depth
		TerrainBuilder.fillCylinder(
			area.origin + Vector3.new(centre.X, (cutTop + cutBottom) / 2, centre.Y),
			cutTop - cutBottom,
			radius,
			Enum.Material.Air,
			step
		)
	end

	local floorTop = top + Quarry.terraceDepth(pit.terraces)
	TerrainBuilder.fillCylinder(
		area.origin + Vector3.new(centre.X, floorTop - 3, centre.Y),
		6,
		pit.floorRadius + 4,
		Enum.Material.Slate,
		step
	)
end

local function buildRamp(area: Areas.AreaDefinition, centre: Vector2)
	local pit = Quarry.PIT
	local model = Instance.new("Model")
	model.Name = "Ramp"
	model.Parent = folder

	local turns = pit.terraces * 4
	for index = 0, turns do
		local alpha = index / turns
		local angle = alpha * math.pi * 1.7 + math.pi * 0.2
		local radius = pit.radius - (pit.radius - pit.floorRadius - 6) * alpha
		local y = area.origin.Y + WORLD.TERRAIN_TOP - pit.stepDown * pit.terraces * alpha + 1

		part({
			name = `Step_{index}`,
			size = Vector3.new(16, 1.4, 16),
			cframe = CFrame.new(
				area.origin.X + centre.X + math.cos(angle) * radius,
				y,
				area.origin.Z + centre.Y + math.sin(angle) * radius
			) * CFrame.Angles(0, -angle, 0),
			color = SLATE,
			material = Enum.Material.Slate,
			parent = model,
		})

		if index % 3 == 0 then
			part({
				name = `Post_{index}`,
				size = Vector3.new(0.7, 5, 0.7),
				cframe = CFrame.new(
					area.origin.X + centre.X + math.cos(angle) * (radius + 6),
					y + 2.5,
					area.origin.Z + centre.Y + math.sin(angle) * (radius + 6)
				),
				color = TIMBER,
				material = Enum.Material.Wood,
				collide = false,
				parent = model,
			})
		end
	end
end

local function buildVein(at: Vector3, seamId: string, index: number): Model
	local model = Instance.new("Model")
	model.Name = `OreVein_{index}`
	model.Parent = folder

	local tint = SEAM_TINT[seamId] or SLATE
	local size = Quarry.VEIN.height

	local matrix = part({
		name = "Matrix",
		shape = Enum.PartType.Ball,
		size = Vector3.new(size * 1.5, size, size * 1.5),
		cframe = CFrame.new(at),
		color = SLATE,
		material = Enum.Material.Slate,
		parent = model,
	})
	model.PrimaryPart = matrix

	local rng = Random.new(index * 5171)
	for crystal = 1, 5 do
		local angle = rng:NextNumber() * math.pi * 2
		local spread = rng:NextNumber(0.3, size * 0.5)
		local length = rng:NextNumber(1.1, 2.3)
		part({
			name = `Crystal_{crystal}`,
			size = Vector3.new(length * 0.6, length * 1.7, length * 0.6),
			cframe = CFrame.new(at + Vector3.new(math.cos(angle) * spread, size * 0.42, math.sin(angle) * spread))
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)),
			color = tint,
			material = Enum.Material.Neon,
			collide = false,
			parent = model,
		})
	end

	local definition = Ingredients.get(seamId)
	UI.sign(matrix, {
		name = "VeinSign",
		title = if definition then definition.name else "Seam",
		subtitle = "swing to cut",
		extent = UDim2.fromScale(9, 3),
		offset = Vector3.new(0, 5.5, 0),
		maxDistance = 110,
	})

	return model
end

local function setVeinVisible(node: HarvestNodes.Node, visible: boolean)
	for _, piece in node.model:GetDescendants() do
		if piece:IsA("BasePart") and piece.Name ~= "Matrix" then
			piece.Transparency = if visible then 0 else 1
		end
	end
	local matrix = node.model:FindFirstChild("Matrix")
	if matrix and matrix:IsA("BasePart") then
		matrix.Transparency = if visible then 0 else 0.55
		matrix.CanCollide = visible
	end
end

local function plantVeins(area: Areas.AreaDefinition, centre: Vector2)
	local rng = Random.new(80211)
	local placed: { Vector2 } = {}

	for index = 1, Quarry.VEIN.count do
		local terrace =
			math.clamp(math.ceil(index / math.max(1, Quarry.VEIN.count / Quarry.PIT.terraces)), 1, Quarry.PIT.terraces)
		local ringOuter = Quarry.terraceRadius(terrace)
		local ringInner = Quarry.terraceRadius(math.min(terrace + 1, Quarry.PIT.terraces))
		local spot: Vector2? = nil
		for _ = 1, 24 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = rng:NextNumber(math.min(ringInner + 4, ringOuter - 2), ringOuter - 2)
			local candidate = Vector2.new(centre.X + math.cos(angle) * radius, centre.Y + math.sin(angle) * radius)
			local clash = false
			for _, other in placed do
				if (other - candidate).Magnitude < Quarry.VEIN.minSpacing then
					clash = true
					break
				end
			end
			if not clash then
				spot = candidate
				break
			end
		end

		if spot then
			table.insert(placed, spot)
			local seamId = Quarry.rollSeam(rng, terrace)
			local y = area.origin.Y + WORLD.TERRAIN_TOP + Quarry.terraceDepth(terrace) + Quarry.VEIN.height * 0.4
			local at = Vector3.new(area.origin.X + spot.X, y, area.origin.Z + spot.Y)
			local model = buildVein(at, seamId, index)
			nodes:add(model, seamId, at, Quarry.VEIN.swings)
		end
	end
end

local function sellOre(player: Player): (number, number)
	local profile = DataService.get(player)
	if not profile then
		return 0, 0
	end

	local ingredients = profile.currencies.ingredients
	local total = 0
	local count = 0
	local sold: { Ingredients.IngredientDefinition } = {}

	for id, held in ingredients do
		local definition = Ingredients.get(id)
		if definition and definition.material and definition.yen and held > 0 then
			total += definition.yen * held
			count += held
			ingredients[id] = 0
			table.insert(sold, definition)
		end
	end

	if total > 0 then
		CurrencyService.award(profile, "yen", BigNumber.fromNumber(total))
	end

	for _, definition in sold do
		HarvestNodes.notifyStockChanged(player, definition, 0)
	end

	return count, total
end

local function buildForeman(area: Areas.AreaDefinition, at: Vector2)
	local model = Instance.new("Model")
	model.Name = "Foreman"
	model.Parent = folder

	local ground = ForagingService.groundAt(area.origin.X + at.X, area.origin.Z + at.Y)
	local base = Vector3.new(area.origin.X + at.X, ground, area.origin.Z + at.Y)

	local desk = part({
		name = "Desk",
		size = Vector3.new(7, 4, 3.4),
		cframe = CFrame.new(base + Vector3.new(0, 2, 0)),
		color = TIMBER,
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	model.PrimaryPart = desk

	part({
		name = "Scale",
		size = Vector3.new(2.4, 0.4, 2.4),
		cframe = CFrame.new(base + Vector3.new(1.6, 4.2, 0)),
		color = Color3.fromRGB(196, 158, 108),
		material = Enum.Material.Metal,
		collide = false,
		parent = model,
	})

	part({
		name = "Crate",
		size = Vector3.new(3, 3, 3),
		cframe = CFrame.new(base + Vector3.new(-5.5, 1.5, 1)) * CFrame.Angles(0, math.rad(18), 0),
		color = TIMBER,
		material = Enum.Material.WoodPlanks,
		parent = model,
	})

	UI.sign(desk, {
		name = "ForemanSign",
		title = "Quarry Office",
		subtitle = "ore bought here",
		extent = UDim2.fromScale(13, 4),
		offset = Vector3.new(0, 6, 0),
		maxDistance = 180,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellOre"
	prompt.ActionText = "Sell ore"
	prompt.ObjectText = "Quarry Office"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = Quarry.FOREMAN.sellRadius
	prompt.RequiresLineOfSight = false
	prompt.Parent = desk

	prompt.Triggered:Connect(function(player)
		local count, total = sellOre(player)
		if count <= 0 then
			NotifyService.send(player, "Nothing in the barrow yet. Go and cut some.", "info")
			return
		end
		NotifyService.send(player, `Sold {count} for {total} Yen.`, "reward")
	end)

	return model
end

function QuarryService.nearestVein(position: Vector3): HarvestNodes.Node?
	return nodes:nearest(position, 20)
end

function QuarryService.swing(player: Player, profile: any): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local node = QuarryService.nearestVein(root.Position)
	if not node then
		return false
	end

	return nodes:click(player, profile, node, Quarry.LAND_XP)
end

function QuarryService.init()
	local existing = Workspace:FindFirstChild("Quarry")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Quarry"
	folder.Parent = Workspace

	local problems = Quarry.check()
	if #problems > 0 then
		for _, problem in problems do
			warn(`[QuarryService] {problem}`)
		end
		return
	end

	nodes.onSpent = function(node)
		setVeinVisible(node, false)
	end

	nodes.onReset = function(node)
		setVeinVisible(node, true)
	end

	task.spawn(function()
		WorldService.awaitDressed()
		ForagingService.awaitReady()
		CaveService.awaitReady()

		local area = Areas.get(Areas.STARTING_AREA)
		local centre = Quarry.centre()
		local foremanAt = Quarry.foremanPosition()
		if not area or not centre or not foremanAt then
			return
		end

		local step = Budget.stepper()
		carvePit(area, centre, step)
		ForagingService.clearArea(
			area.origin + Vector3.new(centre.X, WORLD.TERRAIN_TOP, centre.Y),
			Quarry.PIT.clearRadius
		)
		buildRamp(area, centre)
		plantVeins(area, centre)
		buildForeman(area, foremanAt)
	end)
end

return QuarryService

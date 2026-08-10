local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Farming = require(Shared.Modules.Config.Farming)
local Layout = require(Shared.Modules.Config.Layout)
local Sections = require(Shared.Modules.Config.Sections)

local client = StarterPlayer.StarterPlayerScripts:WaitForChild("Client")
assert(type(require(client.Controllers.FarmController)) == "table", "FarmController did not load")
assert(type(require(client.UI.FarmMenu)) == "table", "FarmMenu did not load")

RunService:Run()

local success, failure = pcall(function()
	local deadline = os.clock() + 75
	local farm
	repeat
		local world = Workspace:FindFirstChild("World")
		local region = world and world:FindFirstChild("Region_1")
		farm = region and region:FindFirstChild("CommunityFarm")
		if farm then
			break
		end
		task.wait(0.25)
	until os.clock() >= deadline

	assert(farm and farm:IsA("Folder"), "CommunityFarm was not built")
	local area = assert(Areas.get(Areas.STARTING_AREA), "starting area is unavailable")
	local farmFrame = Layout.farmCFrame(area)
	assert(
		(farmFrame.Position - Vector3.new(424, Layout.farmSurfaceY(area), 424)).Magnitude < 0.01,
		"farm anchor moved"
	)
	local towardPlaza = Vector3.new(area.origin.X - farmFrame.Position.X, 0, area.origin.Z - farmFrame.Position.Z).Unit
	assert(farmFrame.LookVector:Dot(towardPlaza) > 0.999, "farm does not face the plaza")

	assert(Sections.GRID == 8, "section board is not 8x8")
	for _, coord in Farming.FOOTPRINT_CELLS do
		assert(Sections.byCoord(coord), `farm footprint cell {coord} is missing`)
	end
	for index = 1, Sections.GRID do
		local edgeCoords = {
			Sections.coord(index, 1),
			Sections.coord(index, Sections.GRID),
			Sections.coord(1, index),
			Sections.coord(Sections.GRID, index),
		}
		for _, coord in edgeCoords do
			local cell = assert(Sections.byCoord(coord), `outer cell {coord} is missing`)
			assert(cell.theme == "bare", `outer cell {coord} is not bare`)
		end
	end
	assert(assert(Sections.byCoord("D6")).theme == "bare", "the vacated farm site is not bare")

	local environment = farm:FindFirstChild("FarmEnvironment")
	assert(environment and environment:IsA("Model"), "FarmEnvironment was not built")
	assert(environment:FindFirstChild("MainRamp", true), "main ramp is missing")
	assert(environment:FindFirstChild("SideRamp", true), "side ramp is missing")
	local title = environment:FindFirstChild("Title", true)
	assert(title and title:IsA("TextLabel") and title.Text == "COMMUNITY FARM", "farm title is wrong")
	local generated = environment:GetAttribute("GeneratedPartCount")
	local collidable = environment:GetAttribute("CollidablePartCount")
	assert(type(generated) == "number" and generated > 0, "generated farm part count is missing")
	assert(
		type(collidable) == "number" and collidable > 0 and collidable < generated,
		"farm collision count is invalid"
	)

	local plotModels = {}
	for _, child in farm:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PlotId") then
			table.insert(plotModels, child)
		end
	end
	assert(#plotModels == Farming.PLOT_COUNT, `expected {Farming.PLOT_COUNT} farm plots, got {#plotModels}`)

	table.sort(plotModels, function(a, b)
		return a:GetAttribute("PlotId") < b:GetAttribute("PlotId")
	end)

	for plotId, model in plotModels do
		assert(model:GetAttribute("PlotId") == plotId, `plot ids are not deterministic at {plotId}`)
		local base = model:FindFirstChild("Base")
		assert(base and base:IsA("BasePart"), `Plot {plotId} has no base`)
		assert(base.Size.X == Farming.PLOT_SIZE and base.Size.Z == Farming.PLOT_SIZE, `Plot {plotId} is not square`)
		assert(
			math.abs(base.Position.Y + Farming.PLOT_THICKNESS / 2 - Layout.farmSurfaceY(area)) < 0.01,
			`Plot {plotId} elevation is wrong`
		)
		assert(base.CFrame.LookVector:Dot(farmFrame.LookVector) > 0.999, `Plot {plotId} rotation is wrong`)
		assert(not model:FindFirstChild("ManagePrompt", true), `Plot {plotId} still has a legacy manage prompt`)
		for otherId = plotId + 1, #plotModels do
			local otherBase = plotModels[otherId]:FindFirstChild("Base")
			assert(otherBase and otherBase:IsA("BasePart"), `Plot {otherId} has no base`)
			local delta = farmFrame:VectorToObjectSpace(otherBase.Position - base.Position)
			assert(
				math.abs(delta.X) >= Farming.PLOT_STRIDE or math.abs(delta.Z) >= Farming.PLOT_STRIDE,
				`Plots {plotId} and {otherId} overlap`
			)
		end
	end

	local foreign = {}
	for _, descendant in Workspace:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and not descendant:IsDescendantOf(farm)
			and Layout.isFarmPosition(area, descendant.Position)
		then
			table.insert(foreign, descendant:GetFullName())
		end
	end
	assert(#foreign == 0, `farm footprint contains foreign content: {table.concat(foreign, ", ")}`)
end)

if success then
	print("[FarmingWorldSmoke] PASS: rotated 15-plot terrace, entrances, arch, and reservations")
else
	warn(`[FarmingWorldSmoke] FAIL: {failure}`)
end
RunService:Stop()

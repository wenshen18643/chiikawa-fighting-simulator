local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Farming = require(Shared.Modules.Config.Farming)
local Sections = require(Shared.Modules.Config.Sections)

-- Requiring the client modules here compiles their strict Luau even though a
-- command-line Studio run has no LocalPlayer to boot StarterPlayerScripts.
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
	farm = region and region:FindFirstChild("C5Farm")
	if farm then
		break
	end
	task.wait(0.25)
until os.clock() >= deadline

assert(farm and farm:IsA("Folder"), "C5Farm was not built")

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
	assert(not model:FindFirstChild("ManagePrompt", true), `Plot {plotId} still has a legacy manage prompt`)
	for otherId = plotId + 1, #plotModels do
		local otherBase = plotModels[otherId]:FindFirstChild("Base")
		assert(otherBase and otherBase:IsA("BasePart"), `Plot {otherId} has no base`)
		local delta = otherBase.Position - base.Position
		assert(
			math.abs(delta.X) >= Farming.PLOT_STRIDE or math.abs(delta.Z) >= Farming.PLOT_STRIDE,
			`Plots {plotId} and {otherId} overlap`
		)
	end
end

local cell = Sections.byCoord(Farming.CELL_COORD)
assert(cell, "C5 is missing from section config")
local foreign = {}
for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("BasePart") then
		local position = descendant.Position
		local inside = position.X >= cell.minX
			and position.X <= cell.maxX
			and position.Z >= cell.minZ
			and position.Z <= cell.maxZ
		if inside and not descendant:IsDescendantOf(farm) then
			table.insert(foreign, descendant:GetFullName())
		end
	end
end
assert(#foreign == 0, `C5 contains non-farm content: {table.concat(foreign, ", ")}`)

end)

if success then
	print("[FarmingWorldSmoke] PASS: 15 square plots and no foreign C5 parts")
else
	warn(`[FarmingWorldSmoke] FAIL: {failure}`)
end
RunService:Stop()

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local FarmController = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.FarmController)

RunService:Run()
FarmController.init()

local model = Instance.new("Model")
model.Name = "CropLabelSmokePlot"

local base = Instance.new("Part")
base.Name = "Base"
base.Anchored = true
base.Parent = model
model.PrimaryPart = base
model:SetAttribute("CropId", "carrot")
model:SetAttribute("MaturesAt", os.time() + 120)
model.Parent = workspace
CollectionService:AddTag(model, "FarmPlot")

task.wait(1.2)
local gui = model:FindFirstChild("OwnerCropTimer")
assert(gui and gui:IsA("BillboardGui"), "a planted crop must receive an in-world label")
local label = gui:FindFirstChild("Timer", true)
assert(label and label:IsA("TextLabel"), "the crop label must contain status text")
assert(string.find(label.Text, "CARROT", 1, true), "the crop label must show the crop name")
assert(string.find(label.Text, "YIELD 8", 1, true), "the crop label must show the configured yield")
assert(string.find(label.Text, "READY IN", 1, true), "a growing crop must show its countdown")

model:SetAttribute("MaturesAt", os.time() - 1)
task.wait(1.2)
assert(string.find(label.Text, "READY TO HARVEST!", 1, true), "a mature crop must show its ready state")

model:SetAttribute("CropId", nil)
task.wait(1.2)
assert(not model:FindFirstChild("OwnerCropTimer"), "clearing a crop must remove its in-world label")

CollectionService:RemoveTag(model, "FarmPlot")
model:Destroy()
print("[FarmCropLabelSmoke] PASS")
RunService:Stop()

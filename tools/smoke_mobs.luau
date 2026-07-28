local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mobs = require(Shared.Modules.Config.Mobs)

local EXPECTED = {
	mushroom_frog = {
		modelName = "MushroomFrog",
		population = 6,
		health = 10,
		joints = { "RootJoint", "HatJoint" },
	},
	duck = {
		modelName = "Duck",
		population = 4,
		health = 8,
		joints = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" },
	},
	spider = {
		modelName = "Spider",
		population = 3,
		health = 30,
		joints = { "RootJoint" },
	},
}

local TOTAL_POPULATION = 13

local function populationById(mobs)
	local counts = {}
	for _, model in mobs:GetChildren() do
		local mobId = model:GetAttribute("MobId")
		if type(mobId) == "string" then
			counts[mobId] = (counts[mobId] or 0) + 1
		end
	end
	return counts
end

local function populationReady(mobs)
	if #mobs:GetChildren() ~= TOTAL_POPULATION then
		return false
	end
	local counts = populationById(mobs)
	for mobId, expected in EXPECTED do
		if counts[mobId] ~= expected.population then
			return false
		end
	end
	return true
end

RunService:Run()

local deadline = os.clock() + 20
local mobs
repeat
	mobs = Workspace:FindFirstChild("Mobs")
	if mobs and populationReady(mobs) then
		break
	end
	task.wait(0.25)
until os.clock() >= deadline

assert(mobs, "Workspace.Mobs was not created")
assert(populationReady(mobs), "expected 6 frogs, 4 ducks, and 3 spiders")

for _, model in mobs:GetChildren() do
	assert(model:IsA("Model"), "Mobs contains a non-model child")
	local mobId = model:GetAttribute("MobId")
	local expected = EXPECTED[mobId]
	assert(expected, `unknown mob id {tostring(mobId)}`)
	local definition = Mobs.get(mobId)
	assert(definition, `mob config {mobId} is missing`)
	assert(model.Name == `{expected.modelName}_{model:GetAttribute("MobSlot")}`, `unexpected model name {model.Name}`)

	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(root and root:IsA("BasePart"), `{model.Name} has no direct HumanoidRootPart`)
	assert(root.CollisionGroup == "Mobs", `{model.Name} root is not in the Mobs collision group`)
	assert(
		humanoid and humanoid.MaxHealth == expected.health and humanoid.Health == expected.health,
		`{model.Name} health is incorrect`
	)
	assert(model:GetAttribute("AnimProfile") == definition.animProfile, `{model.Name} animation profile is incorrect`)
	for _, jointName in expected.joints do
		assert(model:FindFirstChild(jointName, true), `{model.Name} has no {jointName}`)
	end
	assert(root:GetNetworkOwner() == nil, `{model.Name} is not server-owned`)
	for _, descendant in model:GetDescendants() do
		assert(not descendant:IsA("LuaSourceContainer"), `{model.Name} contains executable source`)
	end
end

assert(not PhysicsService:CollisionGroupsAreCollidable("Mobs", "Access_1"), "mobs still collide with players")
assert((Mobs.get("duck") :: any).behavior == "flee", "duck is not configured to flee")
assert((Mobs.get("spider") :: any).behavior == "fight", "spider is not configured to fight")

for mobId, expected in EXPECTED do
	local modelName = `{expected.modelName}_1`
	local old = mobs:FindFirstChild(modelName)
	assert(old and old:IsA("Model"), `{modelName} is missing`)
	local humanoid = old:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{modelName} has no Humanoid`)
	humanoid.Health = 0

	deadline = os.clock() + 5
	local replacement
	repeat
		replacement = mobs:FindFirstChild(modelName)
		if replacement and replacement ~= old and populationReady(mobs) then
			break
		end
		task.wait(0.05)
	until os.clock() >= deadline

	assert(replacement and replacement ~= old, `{modelName} did not respawn immediately`)
	assert(replacement:GetAttribute("MobId") == mobId, `{modelName} respawned as the wrong species`)
	assert(populationReady(mobs), `population changed after respawning {modelName}`)
end

print("[MobSmoke] PASS: 6 frogs, 4 fleeing ducks, and 3 hostile spiders are clean, rigged, and respawn")
RunService:Stop()

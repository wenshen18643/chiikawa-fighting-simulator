local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Assets = require(Shared.Modules.Config.Assets)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)

RunService:Run()

local homeFields
for _, zone in Ingredients.ZONES do
	if zone.id == "home_fields" then
		homeFields = zone
		break
	end
end

assert(homeFields, "Home Fields forage zone is missing")
assert(homeFields.distance == 150, "Home Fields must remain 150 studs from the Town plaza")
assert(homeFields.angle == 90, "Home Fields must remain north of the Town plaza")
assert(homeFields.radius == 45, "Home Fields must use a 45-stud radius")
assert(homeFields.clumps == 6, "Home Fields must have six clump slots")
assert(homeFields.perClump == 5, "Home Fields clumps must contain five nodes")
assert(homeFields.clumps * homeFields.perClump == 30, "Home Fields full population must be 30 nodes")
assert(homeFields.lifecycle == "clump-reroll", "Home Fields must reroll only after a whole clump is cleared")
assert(homeFields.minClumpSpacing == 20, "Home Fields clumps must target 20 studs of separation")
assert(homeFields.reserveDecor == true, "Home Fields must be reserved from unrelated world dressing")

local weights = {}
for _, entry in homeFields.ingredients do
	weights[entry.id] = entry.weight
end
assert(weights.carrot == 3 and weights.potato == 3 and weights.rice == 2, "Home Fields weights must be 3:3:2")

local riceAsset = Assets.get("rice")
assert(riceAsset and riceAsset.template == "Rice", "wild Rice must use the sanitized local Rice template")

local rolls = 8_000
local counts = { carrot = 0, potato = 0, rice = 0 }
local rng = Random.new(74_031)
for _ = 1, rolls do
	local ingredientId = Ingredients.rollIngredient(homeFields, rng)
	assert(ingredientId and counts[ingredientId] ~= nil, "weighted roll returned an unknown Home Fields ingredient")
	counts[ingredientId] += 1
end
assert(math.abs(counts.carrot / rolls - 3 / 8) < 0.03, "carrot rolls drifted too far from 3/8")
assert(math.abs(counts.potato / rolls - 3 / 8) < 0.03, "potato rolls drifted too far from 3/8")
assert(math.abs(counts.rice / rolls - 2 / 8) < 0.03, "rice rolls drifted too far from 2/8")

local town = Areas.get(1)
assert(town, "Town area is missing")
local centre = Layout.forageZoneCentre(town, homeFields)
local offset = centre - town.origin
assert(math.abs(Vector3.new(offset.X, 0, offset.Z).Magnitude - 150) < 0.001, "Home Fields centre is misplaced")
assert(math.abs(offset.X) < 0.001 and offset.Z > 0, "Home Fields centre must be due north of Town")
assert(Layout.isReserved(Layout.reservedZones(town), offset.X, offset.Z), "Home Fields is not reserved from dressing")

for _, zone in Ingredients.ZONES do
	if zone ~= homeFields then
		assert(zone.lifecycle == "node-regrow", `{zone.id} must retain fixed per-node regrowth`)
	end
end

print("[ForagingRulesSmoke] PASS")
RunService:Stop()

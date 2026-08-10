local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Assets = require(Shared.Modules.Config.Assets)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)
local Sections = require(Shared.Modules.Config.Sections)

RunService:Run()

local town = Areas.get(1)
assert(town, "Town area is missing")

local EXPECTED_PLOTS = {
	wild_carrot_field = { ingredient = "wildCarrot", cell = "C5", centre = Vector2.new(-318, 106) },
	wild_potato_patch = { ingredient = "wildPotato", cell = "C4", centre = Vector2.new(-318, -106) },
	wild_rice_paddy = { ingredient = "wildRice", cell = "C6", centre = Vector2.new(-318, 318) },
}

local seen = {}
for _, plot in Ingredients.PLOTS do
	local expected = EXPECTED_PLOTS[plot.id]
	assert(expected, `unexpected wild plot "{plot.id}"`)
	assert(plot.ingredient == expected.ingredient, `{plot.id} must grow {expected.ingredient}`)
	assert(plot.cell == expected.cell, `{plot.id} must sit in section {expected.cell}`)
	local cell = assert(Sections.byCoord(plot.cell), `{plot.id} names section {plot.cell} which does not exist`)
	assert(Vector2.new(cell.cx, cell.cz) == expected.centre, `{plot.id} moved in world space`)
	assert(plot.rows > 0 and plot.columns > 0, `{plot.id} must plant at least one node`)
	seen[plot.id] = true
end
for id in EXPECTED_PLOTS do
	assert(seen[id], `wild plot "{id}" is missing`)
end

for _, plot in Ingredients.PLOTS do
	local def = Ingredients.get(plot.ingredient)
	assert(def, `{plot.id} names unknown ingredient "{plot.ingredient}"`)
	assert(Ingredients.isWild(def.id), `{def.id} must be registered as a wild ingredient`)

	local farmed = Ingredients.farmedOf(def.id)
	assert(farmed, `{def.id} must map back to a farmed ingredient`)
	assert(Ingredients.wildOf(farmed) == def.id, `{farmed} <-> {def.id} substitution must round-trip`)

	local farmedDef = Ingredients.get(farmed)
	assert(farmedDef, `{farmed} is missing a definition`)
	assert(def.xpMultiplier < farmedDef.xpMultiplier, `wild {def.id} must be worth less XP than farmed {farmed}`)
	assert(Assets.get(def.asset), `{def.id} has no asset spec for "{def.asset}"`)
end

local zones = Layout.reservedZones(town)
for _, plot in Ingredients.PLOTS do
	local cell = Sections.byCoord(plot.cell)
	assert(cell, `{plot.id} names section {plot.cell} which does not exist`)
	assert(Layout.isReserved(zones, cell.cx, cell.cz), `{plot.id} is not reserved from dressing and relief`)
	assert(Ingredients.plotHalfSpan(plot) < Sections.SIZE / 2, `{plot.id} overflows its section`)
end

local carrot = Ingredients.PLOTS[1]
assert(carrot.id == "wild_carrot_field", "the carrot field must stay first so its layout is the reference")
local before = Ingredients.plotHalfSpan(carrot)
assert(math.abs(Ingredients.plotHalfSpan(carrot) - before) < 0.001, "plot span must be deterministic")

for _, zone in Ingredients.ZONES do
	assert(zone.id ~= "home_fields", "Home Fields is replaced by the authored wild plots")
	assert(zone.id ~= "berry_grove" and zone.id ~= "bramble_hollow", `{zone.id} was deleted with the B-column rebuild`)
end

print("[ForagingRulesSmoke] PASS")
RunService:Stop()

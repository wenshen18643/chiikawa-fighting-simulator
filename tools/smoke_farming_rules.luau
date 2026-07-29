local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Farming = require(ReplicatedStorage:WaitForChild("Shared").Modules.Config.Farming)

RunService:Run()

assert(Farming.minimumBid(nil) == 20, "an empty auction must start at Yen 20")
assert(Farming.minimumBid(20) == 30, "a bid must rise by Yen 10")
assert(Farming.isValidBid(20, nil), "the opening Yen 20 bid must be valid")
assert(not Farming.isValidBid(19, nil), "bids below Yen 20 must fail")
assert(not Farming.isValidBid(29, 20), "a raise below Yen 10 must fail")
assert(Farming.isValidBid(10_000, 9_990), "the Yen 10,000 cap must be reachable")
assert(not Farming.isValidBid(10_001, 9_990), "bids above Yen 10,000 must fail")
assert(not Farming.isValidBid(30.5, 20), "fractional Yen bids must fail")

assert(Farming.escrowCharge(80, 50, true) == 30, "a leader must pay only their raise")
assert(Farming.escrowCharge(80, 50, false) == 80, "a new leader must escrow their full bid")

assert(Farming.countPositions({ 1, 2, 3 }, { 3, 4, 5 }) == 5, "leases and bids must count as a union")
assert(Farming.countPositions({ 1 }, { 1 }) == 1, "renewal bidding must not consume a second position")

assert(Farming.growthSeconds("carrot") == 120, "carrots must take two minutes")
assert(Farming.yieldForElapsed("carrot", 119) == 0, "an early carrot must yield nothing")
assert(Farming.yieldForElapsed("carrot", 120) == 8, "a mature carrot crop must yield eight items")
assert(Farming.growthSeconds("potato") == 240, "potatoes must take four minutes")
assert(Farming.yieldForElapsed("potato", 239) == 0, "an early potato must yield nothing")
assert(Farming.yieldForElapsed("potato", 240) == 13, "a mature potato crop must yield thirteen items")
assert(Farming.growthSeconds("rice") == 360, "rice must take six minutes")
assert(Farming.yieldForElapsed("rice", 359) == 0, "early rice must yield nothing")
assert(Farming.yieldForElapsed("rice", 360) == 18, "a mature rice crop must yield eighteen items")
assert(Farming.yieldForElapsed("unknown", 10_000) == 0, "unknown crops must yield nothing")

local seen = {}
for plotId = 1, Farming.PLOT_COUNT do
	local grid = Farming.gridPosition(plotId)
	assert(grid, `plot {plotId} is missing its grid position`)
	local key = `{grid.column}:{grid.row}`
	assert(not seen[key], `plot {plotId} overlaps an existing grid position`)
	seen[key] = true
	assert(grid.column == (plotId - 1) % Farming.COLUMNS + 1, "plot ids must advance west to east")
	assert(grid.row == math.floor((plotId - 1) / Farming.COLUMNS) + 1, "plot ids must advance south to north")
end

print("[FarmingRulesSmoke] PASS")
RunService:Stop()

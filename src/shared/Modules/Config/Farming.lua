--!strict

local Farming = {}

Farming.FOOTPRINT_CELLS = { "F6", "F7", "G6", "G7" }
Farming.FOOTPRINT_CELL_SET = {
	F6 = true,
	F7 = true,
	G6 = true,
	G7 = true,
} :: { [string]: boolean }
Farming.FACING_TARGET_OFFSET = Vector2.zero

Farming.COLUMNS = 3
Farming.ROWS = 5
Farming.PLOT_COUNT = Farming.COLUMNS * Farming.ROWS
Farming.PLOT_SIZE = 30
Farming.AISLE_SIZE = 6
Farming.PLOT_STRIDE = Farming.PLOT_SIZE + Farming.AISLE_SIZE
Farming.PLOT_THICKNESS = 2
Farming.FIELD_WIDTH = Farming.COLUMNS * Farming.PLOT_SIZE + (Farming.COLUMNS - 1) * Farming.AISLE_SIZE
Farming.FIELD_LENGTH = Farming.ROWS * Farming.PLOT_SIZE + (Farming.ROWS - 1) * Farming.AISLE_SIZE
Farming.FIELD_MARGIN = 2

Farming.TERRACE_HEIGHT = 3.5
Farming.TERRACE_MARGIN = Vector2.new(16, 18)
Farming.TERRACE_WIDTH = Farming.FIELD_WIDTH + Farming.TERRACE_MARGIN.X * 2
Farming.TERRACE_LENGTH = Farming.FIELD_LENGTH + Farming.TERRACE_MARGIN.Y * 2
Farming.TERRACE_CORNER_RADIUS = 16
Farming.TERRACE_SLOPE_DEPTH = 8
Farming.RETAINING_STONE_SPACING = 15

Farming.MAIN_RAMP_WIDTH = 16
Farming.MAIN_RAMP_LENGTH = 28
Farming.SIDE_RAMP_WIDTH = 9
Farming.SIDE_RAMP_LENGTH = 24
Farming.SIDE_RAMP_SIDE = -1
Farming.SIDE_RAMP_LOCAL_Z = Farming.PLOT_STRIDE / 2
Farming.TOP_APRON_SIZE = Vector2.new(34, 16)
Farming.BOTTOM_APRON_SIZE = Vector2.new(24, 12)

Farming.ARCH_INSET = 4
Farming.ARCH_OPENING_WIDTH = 18
Farming.ARCH_CLEAR_HEIGHT = 12
Farming.ARCH_TOTAL_HEIGHT = 15

Farming.PATH_WIDTH = Farming.AISLE_SIZE
Farming.VISUAL_AXIS_WIDTH = 10
Farming.PATH_THICKNESS = 0.24
Farming.STEPPING_STONE_SIZE = Vector2.new(3.4, 2.5)
Farming.DECORATION_CLEARANCE = 10

Farming.RENT_PRICE = 20
Farming.LEASE_SECONDS = 10 * 60
Farming.MIN_BID = 20
Farming.MAX_BID = 10_000
Farming.MIN_BID_INCREMENT = 10
Farming.MAX_POSITIONS_PER_USER = 5
Farming.INTERACTION_DISTANCE = 18
Farming.ACTIONS_PER_SECOND = 1

Farming.SEED_COST = 3

export type CropDefinition = {
	id: string,
	growthSeconds: number,
	harvestYield: number,
	plotSpacing: number,
	visualBrightness: number,
	visualSaturation: number,
}

Farming.CROP_IDS = { "carrot", "potato", "rice" }
Farming.CROPS = {
	carrot = {
		id = "carrot",
		growthSeconds = 2 * 60,
		harvestYield = 8,
		plotSpacing = 8,
		visualBrightness = 1.35,
		visualSaturation = 1.08,
	},
	potato = {
		id = "potato",
		growthSeconds = 4 * 60,
		harvestYield = 13,
		plotSpacing = 8,
		visualBrightness = 1.35,
		visualSaturation = 1.08,
	},
	rice = {
		id = "rice",
		growthSeconds = 6 * 60,
		harvestYield = 18,
		plotSpacing = 5,
		visualBrightness = 1,
		visualSaturation = 1,
	},
} :: { [string]: CropDefinition }
Farming.CROP_SET = {
	carrot = true,
	potato = true,
	rice = true,
} :: { [string]: boolean }

function Farming.isFootprintCell(coord: string): boolean
	return Farming.FOOTPRINT_CELL_SET[coord] == true
end

export type GridPosition = {
	column: number,
	row: number,
}

function Farming.gridPosition(plotId: number): GridPosition?
	if plotId % 1 ~= 0 or plotId < 1 or plotId > Farming.PLOT_COUNT then
		return nil
	end
	local zeroBased = plotId - 1
	return {
		column = zeroBased % Farming.COLUMNS + 1,
		row = math.floor(zeroBased / Farming.COLUMNS) + 1,
	}
end

function Farming.cropDefinition(cropId: string): CropDefinition?
	return Farming.CROPS[cropId]
end

function Farming.growthSeconds(cropId: string): number?
	local definition = Farming.cropDefinition(cropId)
	return if definition then definition.growthSeconds else nil
end

function Farming.yieldForElapsed(cropId: string, elapsed: number): number
	local definition = Farming.cropDefinition(cropId)
	if not definition or elapsed < definition.growthSeconds then
		return 0
	end
	return definition.harvestYield
end

function Farming.minimumBid(currentBid: number?): number
	if currentBid == nil then
		return Farming.MIN_BID
	end
	return math.min(Farming.MAX_BID + 1, currentBid + Farming.MIN_BID_INCREMENT)
end

function Farming.isValidBid(amount: number, currentBid: number?): boolean
	return amount == amount
		and amount ~= math.huge
		and amount % 1 == 0
		and amount >= Farming.minimumBid(currentBid)
		and amount <= Farming.MAX_BID
end

function Farming.escrowCharge(amount: number, currentBid: number?, isCurrentLeader: boolean): number
	if isCurrentLeader and currentBid then
		return amount - currentBid
	end
	return amount
end

function Farming.countPositions(leasePlotIds: { number }, leadingBidPlotIds: { number }): number
	local occupied: { [number]: boolean } = {}
	for _, plotId in leasePlotIds do
		occupied[plotId] = true
	end
	for _, plotId in leadingBidPlotIds do
		occupied[plotId] = true
	end

	local count = 0
	for _ in occupied do
		count += 1
	end
	return count
end

function Farming.isCrop(cropId: string): boolean
	return Farming.CROP_SET[cropId] == true
end

return Farming

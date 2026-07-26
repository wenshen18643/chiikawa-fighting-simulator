--[[
	BigNumber — mantissa/exponent numbers for values that outgrow doubles.

	See docs/GAME.md §12. Skill values, Yen and Stamps blow past 2^53 once
	tier-6 worksite multipliers stack with season multipliers, so every one of
	those quantities uses this module instead of a raw number.

	Representation is a PLAIN TABLE with no metatable: { m = mantissa, e = exponent }
	normalised so that 1 <= m < 10, or m == 0 for zero. Plain tables are
	DataStore-safe, so profiles serialise without a conversion pass.

	The game has no negative quantities. Operations assume non-negative inputs
	and Sub clamps at zero rather than going negative.
]]

local BigNumber = {}

export type BigNum = { m: number, e: number }

local SUFFIXES = {
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
	"Sxd",
	"Spd",
	"Ocd",
	"Nod",
	"Vg",
}

-- Beyond this exponent gap the smaller operand cannot affect the mantissa of
-- the larger one at double precision, so addition short-circuits.
local PRECISION_GAP = 15

local function normalise(m: number, e: number): BigNum
	if m == 0 or m ~= m then
		return { m = 0, e = 0 }
	end

	if m == math.huge then
		-- Should not happen, but never hand back an inf that poisons a profile.
		return { m = 1, e = 308 }
	end

	while m >= 10 do
		m /= 10
		e += 1
	end

	while m < 1 do
		m *= 10
		e -= 1
	end

	return { m = m, e = e }
end

function BigNumber.new(mantissa: number, exponent: number): BigNum
	return normalise(mantissa, exponent)
end

function BigNumber.zero(): BigNum
	return { m = 0, e = 0 }
end

function BigNumber.one(): BigNum
	return { m = 1, e = 0 }
end

function BigNumber.fromNumber(value: number): BigNum
	if value <= 0 then
		return BigNumber.zero()
	end
	return normalise(value, 0)
end

--[[
	Accepts whatever config authors find natural: a plain number, a {m, e}
	table, or an already-built BigNum. Config tables stay readable this way.
]]
function BigNumber.coerce(value: number | BigNum): BigNum
	if type(value) == "number" then
		return BigNumber.fromNumber(value)
	end
	return normalise(value.m, value.e)
end

function BigNumber.clone(a: BigNum): BigNum
	return { m = a.m, e = a.e }
end

function BigNumber.isZero(a: BigNum): boolean
	return a.m == 0
end

--[[
	Round-trip validation for values loaded from a DataStore. A corrupted or
	hand-edited profile must not be able to inject NaN into the gain formula.
]]
function BigNumber.isValid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	local m, e = value.m, value.e
	if type(m) ~= "number" or type(e) ~= "number" then
		return false
	end
	if m ~= m or e ~= e or m == math.huge or e == math.huge then
		return false
	end
	return m >= 0 and (m == 0 or (m >= 1 and m < 10))
end

function BigNumber.compare(a: BigNum, b: BigNum): number
	if a.m == 0 and b.m == 0 then
		return 0
	elseif a.m == 0 then
		return -1
	elseif b.m == 0 then
		return 1
	end

	if a.e ~= b.e then
		return if a.e < b.e then -1 else 1
	end
	if a.m == b.m then
		return 0
	end
	return if a.m < b.m then -1 else 1
end

function BigNumber.lt(a: BigNum, b: BigNum): boolean
	return BigNumber.compare(a, b) < 0
end

function BigNumber.lte(a: BigNum, b: BigNum): boolean
	return BigNumber.compare(a, b) <= 0
end

function BigNumber.gt(a: BigNum, b: BigNum): boolean
	return BigNumber.compare(a, b) > 0
end

function BigNumber.gte(a: BigNum, b: BigNum): boolean
	return BigNumber.compare(a, b) >= 0
end

function BigNumber.eq(a: BigNum, b: BigNum): boolean
	return BigNumber.compare(a, b) == 0
end

function BigNumber.add(a: BigNum, b: BigNum): BigNum
	if a.m == 0 then
		return BigNumber.clone(b)
	elseif b.m == 0 then
		return BigNumber.clone(a)
	end

	local hi, lo = a, b
	if a.e < b.e then
		hi, lo = b, a
	end

	local gap = hi.e - lo.e
	if gap > PRECISION_GAP then
		return BigNumber.clone(hi)
	end

	return normalise(hi.m + lo.m / 10 ^ gap, hi.e)
end

-- Clamps at zero: the game has no debt and no negative skills.
function BigNumber.sub(a: BigNum, b: BigNum): BigNum
	if b.m == 0 then
		return BigNumber.clone(a)
	end
	if BigNumber.lte(a, b) then
		return BigNumber.zero()
	end

	local gap = a.e - b.e
	if gap > PRECISION_GAP then
		return BigNumber.clone(a)
	end

	return normalise(a.m - b.m / 10 ^ gap, a.e)
end

function BigNumber.mul(a: BigNum, b: BigNum): BigNum
	if a.m == 0 or b.m == 0 then
		return BigNumber.zero()
	end
	return normalise(a.m * b.m, a.e + b.e)
end

function BigNumber.mulNumber(a: BigNum, scalar: number): BigNum
	if a.m == 0 or scalar <= 0 then
		return BigNumber.zero()
	end
	return normalise(a.m * scalar, a.e)
end

function BigNumber.div(a: BigNum, b: BigNum): BigNum
	if b.m == 0 then
		error("BigNumber.div: division by zero", 2)
	end
	if a.m == 0 then
		return BigNumber.zero()
	end
	return normalise(a.m / b.m, a.e - b.e)
end

function BigNumber.divNumber(a: BigNum, scalar: number): BigNum
	if scalar == 0 then
		error("BigNumber.divNumber: division by zero", 2)
	end
	return normalise(a.m / scalar, a.e)
end

-- 10^exponent, the cheap way to express season multipliers (10 ^ seasons).
function BigNumber.pow10(exponent: number): BigNum
	return { m = 1, e = exponent }
end

function BigNumber.pow(a: BigNum, power: number): BigNum
	if a.m == 0 then
		return BigNumber.zero()
	end
	local log = (math.log10(a.m) + a.e) * power
	local e = math.floor(log)
	return normalise(10 ^ (log - e), e)
end

-- log10 of the value. Used wherever a BigNum has to drive a bounded number,
-- e.g. stamina scaling off Grit.
function BigNumber.log10(a: BigNum?): number
	if not a or type(a) ~= "table" or not a.m or a.m == 0 then
		return 0
	end
	return math.log10(a.m) + a.e
end

-- Saturates to math.huge past double range. Never feed the result back into a
-- BigNum; this is for display and for bounded number formulas only.
function BigNumber.toNumber(a: BigNum?): number
	if not a or type(a) ~= "table" or not a.m or a.m == 0 then
		return 0
	end
	if a.e > 308 then
		return math.huge
	end
	return a.m * 10 ^ a.e
end

function BigNumber.toString(a: BigNum?): string
	if not a or type(a) ~= "table" or not a.m or a.m == 0 then
		return "0"
	end

	if a.e < 3 then
		local value = a.m * 10 ^ a.e
		if a.e < 0 then
			return string.format("%.2f", value)
		end
		return string.format("%d", math.floor(value))
	end

	local tier = math.floor(a.e / 3)
	local suffix = SUFFIXES[tier]
	local scaled = a.m * 10 ^ (a.e - tier * 3)

	if not suffix then
		return string.format("%.2fe%d", a.m, a.e)
	end

	return string.format("%.2f%s", scaled, suffix)
end

return BigNumber

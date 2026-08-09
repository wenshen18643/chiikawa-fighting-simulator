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

local PRECISION_GAP = 15

local function normalise(m: number, e: number): BigNum
	if m == 0 or m ~= m then
		return { m = 0, e = 0 }
	end

	if m == math.huge then
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

function BigNumber.gte(a: BigNum, b: BigNum): boolean
	return BigNumber.compare(a, b) >= 0
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

function BigNumber.log10(a: BigNum?): number
	if not a or type(a) ~= "table" or not a.m or a.m == 0 then
		return 0
	end
	return math.log10(a.m) + a.e
end

function BigNumber.toNumber(a: BigNum?): number
	if not a or type(a) ~= "table" or not a.m or a.m == 0 then
		return 0
	end
	if a.e > 308 then
		return math.huge
	end
	return a.m * 10 ^ a.e
end

local PLAIN_DIGITS = 4

local function grouped(value: number): string
	local text = string.format("%d", value)
	local sign, digits = text:match("^(-?)(%d+)$")
	if not digits then
		return text
	end

	local spaced = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return sign .. (spaced:gsub("^,", ""))
end

function BigNumber.toString(a: BigNum?): string
	if not a or type(a) ~= "table" or not a.m or a.m == 0 then
		return "0"
	end

	if a.e < 0 then
		return string.format("%.2f", a.m * 10 ^ a.e)
	end

	if a.e < PLAIN_DIGITS then
		return grouped(math.floor(a.m * 10 ^ a.e + 0.5))
	end

	local tier = math.floor(a.e / 3)
	local scaled = a.m * 10 ^ (a.e - tier * 3)

	if scaled >= 999.995 then
		tier += 1
		scaled /= 1000
	end

	local suffix = SUFFIXES[tier]
	if not suffix then
		return string.format("%.2fe%d", a.m, a.e)
	end

	if scaled < 9.9995 then
		return string.format("%.2f%s", scaled, suffix)
	elseif scaled < 99.995 then
		return string.format("%.1f%s", scaled, suffix)
	end
	return string.format("%.0f%s", scaled, suffix)
end

return BigNumber

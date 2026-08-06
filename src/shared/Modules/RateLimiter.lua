--!strict

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_rate: number,
		_burst: number,
		_tokens: number,
		_lastRefill: number,
	},
	RateLimiter
))

function RateLimiter.new(ratePerSecond: number, burst: number?): RateLimiter
	assert(ratePerSecond > 0, "ratePerSecond must be positive")
	assert(burst == nil or burst > 0, "burst must be positive")
	local capacity = burst or ratePerSecond
	return setmetatable({
		_rate = ratePerSecond,
		_burst = capacity,
		_tokens = capacity,
		_lastRefill = os.clock(),
	}, RateLimiter)
end

function RateLimiter.setRate(self: RateLimiter, ratePerSecond: number, burst: number?)
	assert(ratePerSecond > 0, "ratePerSecond must be positive")
	assert(burst == nil or burst > 0, "burst must be positive")
	self._rate = ratePerSecond
	self._burst = burst or ratePerSecond
	if self._tokens > self._burst then
		self._tokens = self._burst
	end
end

function RateLimiter._refill(self: RateLimiter)
	local now = os.clock()
	local elapsed = now - self._lastRefill
	if elapsed <= 0 then
		return
	end
	self._lastRefill = now
	self._tokens = math.min(self._burst, self._tokens + elapsed * self._rate)
end

function RateLimiter.consume(self: RateLimiter, count: number?): boolean
	local amount = count or 1
	assert(amount > 0, "count must be positive")
	self:_refill()
	if self._tokens >= amount then
		self._tokens -= amount
		return true
	end
	return false
end

return RateLimiter

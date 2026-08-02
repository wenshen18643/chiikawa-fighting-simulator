local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		rate: number,
		burst: number,
		tokens: number,
		lastRefill: number,
		dropped: number,
	},
	RateLimiter
))

function RateLimiter.new(ratePerSecond: number, burst: number?): RateLimiter
	return setmetatable({
		rate = ratePerSecond,
		burst = burst or ratePerSecond,
		tokens = burst or ratePerSecond,
		lastRefill = os.clock(),
		dropped = 0,
	}, RateLimiter)
end

function RateLimiter:setRate(ratePerSecond: number, burst: number?)
	self.rate = ratePerSecond
	self.burst = burst or ratePerSecond
	if self.tokens > self.burst then
		self.tokens = self.burst
	end
end

function RateLimiter:_refill()
	local now = os.clock()
	local elapsed = now - self.lastRefill
	if elapsed <= 0 then
		return
	end
	self.lastRefill = now
	self.tokens = math.min(self.burst, self.tokens + elapsed * self.rate)
end

function RateLimiter:consume(count: number?): boolean
	local amount = count or 1
	self:_refill()
	if self.tokens >= amount then
		self.tokens -= amount
		return true
	end
	self.dropped += amount
	return false
end

return RateLimiter

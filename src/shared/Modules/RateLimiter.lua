--[[
	Token-bucket rate limiter. See docs/GAME.md §13.

	Server-side only in practice: every remote that credits anything goes
	through one of these. Excess requests are DROPPED, not queued and not
	credited — a client that sends 200 work actions in a second gets the
	capped number and nothing else happens to them (§2 rule 3: no punishment,
	just no reward).

	The burst allowance exists so a player on a bad connection whose packets
	arrive bunched is not silently under-credited for input they really made.
]]

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

-- The cap can change at runtime (a gamepass purchase mid-session), so callers
-- push the new rate in rather than rebuilding the bucket and losing its state.
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

-- Returns true if the action is allowed. Consumes a token when it is.
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

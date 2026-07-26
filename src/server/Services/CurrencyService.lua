--[[
	Owns Yen and Stamps. See docs/GAME.md §8 and §13.

	There is no client-writable currency remote by design. Purchases go through
	spend(), which validates the balance server-side and returns false rather
	than trusting anything the client claims to be able to afford.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)

local DataService = require(script.Parent.DataService)

type BigNum = BigNumber.BigNum

local CurrencyService = {}

local VALID = { yen = true, stamps = true }

function CurrencyService.get(profile: any, currency: string): BigNum
	return profile.currencies[currency] or BigNumber.zero()
end

function CurrencyService.award(profile: any, currency: string, amount: BigNum)
	if not VALID[currency] then
		warn(`[CurrencyService] award to unknown currency "{currency}"`)
		return
	end
	if BigNumber.isZero(amount) then
		return
	end
	profile.currencies[currency] = BigNumber.add(profile.currencies[currency], amount)
end

--[[
	Returns false and changes nothing when the player cannot afford it. Callers
	must check the return value before granting anything — this is the only
	guard between a spoofed purchase request and a free item.
]]
function CurrencyService.spend(profile: any, currency: string, amount: BigNum): boolean
	if not VALID[currency] then
		return false
	end
	local balance = profile.currencies[currency]
	if BigNumber.lt(balance, amount) then
		return false
	end
	profile.currencies[currency] = BigNumber.sub(balance, amount)
	return true
end

function CurrencyService.canAfford(profile: any, currency: string, amount: BigNum): boolean
	return BigNumber.gte(CurrencyService.get(profile, currency), amount)
end

-- §8: the passive wage. Paid in slices so the HUD number visibly moves rather
-- than jumping once a minute.
function CurrencyService.init()
	task.spawn(function()
		local interval = Constants.CURRENCY.WAGE_TICK_INTERVAL
		local fraction = interval / 60

		while true do
			task.wait(interval)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile then
					local perMinute = Formulas.yenPerMinute(profile)
					CurrencyService.award(profile, "yen", BigNumber.mulNumber(perMinute, fraction))
					profile.meta.playtime += interval
				end
			end
		end
	end)
end

return CurrencyService

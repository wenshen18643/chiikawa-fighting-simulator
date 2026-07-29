--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)

export type Credit = {
	id: string,
	yen: number?,
	ingredientId: string?,
	itemCount: number?,
	kusatoriGain: BigNumber.BigNum?,
	reason: string?,
}

type MailboxRecord = {
	credits: { Credit },
}

local MAX_RECEIPTS = 128
local RETRIES = 3

local FarmMailboxService = {}

local store: GlobalDataStore? = nil
local useMemory = false
local memoryMailboxes: { [number]: { Credit } } = {}

local function copyCredit(credit: Credit): Credit
	return {
		id = credit.id,
		yen = credit.yen,
		ingredientId = credit.ingredientId,
		itemCount = credit.itemCount,
		kusatoriGain = if credit.kusatoriGain then BigNumber.clone(credit.kusatoriGain) else nil,
		reason = credit.reason,
	}
end

local function mailboxKey(userId: number): string
	return string.format("Player_%d", userId)
end

local function validRecord(value: any): MailboxRecord
	if type(value) ~= "table" or type(value.credits) ~= "table" then
		return { credits = {} }
	end
	return value :: MailboxRecord
end

local function retry(operation: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, RETRIES do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < RETRIES then
			task.wait(attempt)
		end
	end
	return false, lastError
end

local function rememberReceipt(profile: any, creditId: string)
	local farm = profile.farm
	if type(farm) ~= "table" then
		farm = { claimedCredits = {}, claimedCreditOrder = {} }
		profile.farm = farm
	end
	if type(farm.claimedCredits) ~= "table" then
		farm.claimedCredits = {}
	end
	if type(farm.claimedCreditOrder) ~= "table" then
		farm.claimedCreditOrder = {}
	end

	if farm.claimedCredits[creditId] then
		return
	end

	farm.claimedCredits[creditId] = true
	table.insert(farm.claimedCreditOrder, creditId)
	while #farm.claimedCreditOrder > MAX_RECEIPTS do
		local expiredId = table.remove(farm.claimedCreditOrder, 1)
		farm.claimedCredits[expiredId] = nil
	end
end

function FarmMailboxService.apply(player: Player, profile: any, credit: Credit): boolean
	if profile.farm and profile.farm.claimedCredits and profile.farm.claimedCredits[credit.id] then
		return false
	end

	if credit.yen and credit.yen > 0 then
		CurrencyService.award(profile, "yen", BigNumber.fromNumber(credit.yen))
	end

	if credit.ingredientId and credit.itemCount and credit.itemCount > 0 then
		local ingredients = profile.currencies.ingredients
		ingredients[credit.ingredientId] = (ingredients[credit.ingredientId] or 0) + credit.itemCount
	end

	if credit.kusatoriGain and not BigNumber.isZero(credit.kusatoriGain) then
		SkillService.award(player, profile, "kusatori", credit.kusatoriGain)
	end

	rememberReceipt(profile, credit.id)
	return true
end

function FarmMailboxService.enqueue(userId: number, credit: Credit): boolean
	if useMemory then
		local mailbox = memoryMailboxes[userId]
		if not mailbox then
			mailbox = {}
			memoryMailboxes[userId] = mailbox
		end
		for _, existing in ipairs(mailbox) do
			if existing.id == credit.id then
				return true
			end
		end
		table.insert(mailbox, copyCredit(credit))
		return true
	end

	if not store then
		return false
	end

	local ok, result = retry(function()
		return store:UpdateAsync(mailboxKey(userId), function(value: any)
			local record = validRecord(value)
			for _, existing in ipairs(record.credits) do
				if existing.id == credit.id then
					return record
				end
			end
			table.insert(record.credits, copyCredit(credit))
			return record
		end)
	end)
	if not ok then
		warn(string.format("[FarmMailbox] Could not enqueue credit %s: %s", credit.id, tostring(result)))
	end
	return ok
end

local function readCredits(userId: number): { Credit }?
	if useMemory then
		local source = memoryMailboxes[userId] or {}
		local result = {}
		for _, credit in ipairs(source) do
			table.insert(result, copyCredit(credit))
		end
		return result
	end

	if not store then
		return nil
	end

	local ok, result = retry(function()
		return store:GetAsync(mailboxKey(userId))
	end)
	if not ok then
		warn(string.format("[FarmMailbox] Could not read mailbox for %d: %s", userId, tostring(result)))
		return nil
	end
	return validRecord(result).credits
end

local function removeCredits(userId: number, appliedIds: { [string]: boolean })
	if useMemory then
		local remaining = {}
		for _, credit in ipairs(memoryMailboxes[userId] or {}) do
			if not appliedIds[credit.id] then
				table.insert(remaining, credit)
			end
		end
		memoryMailboxes[userId] = remaining
		return
	end

	if not store then
		return
	end

	local ok, result = retry(function()
		return store:UpdateAsync(mailboxKey(userId), function(value: any)
			local record = validRecord(value)
			local remaining = {}
			for _, credit in ipairs(record.credits) do
				if not appliedIds[credit.id] then
					table.insert(remaining, credit)
				end
			end
			record.credits = remaining
			return record
		end)
	end)
	if not ok then
		warn(string.format("[FarmMailbox] Could not clean mailbox for %d: %s", userId, tostring(result)))
	end
end

function FarmMailboxService.claim(player: Player, profile: any)
	local credits = readCredits(player.UserId)
	if not credits or #credits == 0 then
		return
	end

	local appliedIds: { [string]: boolean } = {}
	local appliedCount = 0
	for _, credit in ipairs(credits) do
		if player.Parent ~= Players then
			break
		end
		if FarmMailboxService.apply(player, profile, credit) then
			appliedCount += 1
		end
		appliedIds[credit.id] = true
	end

	if next(appliedIds) then
		removeCredits(player.UserId, appliedIds)
	end
	if appliedCount > 0 and player.Parent == Players then
		NotifyService.send(
			player,
			string.format("Received %d farming credit%s.", appliedCount, if appliedCount == 1 then "" else "s")
		)
	end
end

function FarmMailboxService.init()
	useMemory = DataService.getBackend() == "memory"
	if not useMemory then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Constants.DATA.FARM_MAILBOX_STORE_NAME)
		end)
		if ok then
			store = result
		else
			warn(string.format("[FarmMailbox] DataStore unavailable: %s", tostring(result)))
		end
	end

	DataService.onLoaded(function(player, profile)
		task.spawn(FarmMailboxService.claim, player, profile)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.get(player)
		if profile then
			task.spawn(FarmMailboxService.claim, player, profile)
		end
	end
end

return FarmMailboxService

--[[
	Profile persistence. See docs/GAME.md §16.

	Backend is pluggable:
	  - If Packages/ProfileService is present (wally install), it is used, and
	    profiles are session-locked as the spec requires.
	  - Otherwise this falls back to a plain DataStore with retries and a
	    BindToClose flush, so the place runs in Studio before dependencies are
	    installed.

	The fallback is NOT session-locked. It is fine for solo testing and NOT fine
	for production — two servers holding the same player can duplicate currency.
	Run `wally install` before any public test.

	BigNums are plain {m, e} tables (see BigNumber), so profiles serialise with
	no conversion pass. The only values needing care are CFrames, which are
	stored as component arrays.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Areas = require(Shared.Areas)
local Skills = require(Shared.Modules.Config.Skills)

local DataService = {}

local profiles: { [Player]: any } = {}
local releaseCallbacks: { (player: Player, profile: any) -> () } = {}
local loadedCallbacks: { (player: Player, profile: any) -> () } = {}

-- ProfileService handles, kept beside the plain data so the rest of the
-- codebase only ever sees `profile` and never has to know which backend won.
DataService._handles = {} :: { [Player]: any }

local ProfileService = nil
local profileStore = nil
local dataStore = nil
-- "profileservice" | "datastore" | "memory"
local backend = "memory"

--------------------------------------------------------------------------------
-- Template
--------------------------------------------------------------------------------

local function buildTemplate(): any
	local skills = {}
	local certifications = {}
	local studyProgress = {}
	local examAttempts = {}
	for _, skillId in Skills.ORDER do
		skills[skillId] = BigNumber.zero()
		certifications[skillId] = 0
		studyProgress[skillId] = 0
		examAttempts[skillId] = 0
	end

	return {
		skills = skills,
		certifications = certifications,
		studyProgress = studyProgress,
		examAttempts = examAttempts,
		currencies = {
			yen = BigNumber.fromNumber(Constants.CURRENCY.STARTING_YEN),
			stamps = BigNumber.fromNumber(Constants.CURRENCY.STARTING_STAMPS),
			ingredients = {},
			seasonings = {},
			materials = {},
		},
		seasons = 0,
		--[[
			Which skill training raises (§5). Server-owned so a client cannot
			switch skill per-click to launder gains; changed through
			Work.SelectSkill, which validates it.

			Existing profiles pick this up through reconcile without a migration,
			since it is a new scalar with a default.
		]]
		selectedSkill = Skills.ORDER[1],
		companions = {},
		gear = {},
		recipes = {},
		-- Cooked dishes owned, {recipeId = count}.
		dishes = {},
		--[[
			Yoroi-san's work orders. `active` is orderId -> progress and holds at
			most one; `completed` is the chain you have finished for good; `done`
			is which of `day`'s standing orders you have already claimed, and is
			cleared the first time you take one on a new day.
		]]
		workOrders = { completed = {}, active = {}, rank = 0 },
		-- String keys throughout: DataStore serialises through JSON, which has
		-- no integer keys, so {[1] = true} would come back as {["1"] = true}.
		unlockedRegions = { [tostring(Areas.STARTING_AREA)] = true },
		home = { furniture = {}, comfort = Constants.HOME.BASE_COMFORT },
		gamepasses = {},
		boosts = {},
		stamina = { current = Constants.STAMINA.BASE_MAX, max = Constants.STAMINA.BASE_MAX },
		settings = { autoWork = false, vfxQuality = "high", musicVolume = 1 },
		farm = { claimedCredits = {}, claimedCreditOrder = {} },
		version = Constants.DATA.SCHEMA_VERSION,
		meta = { createdAt = 0, lastPlayed = 0, playtime = 0, introShown = false },
	}
end

DataService.TEMPLATE = buildTemplate()

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

--------------------------------------------------------------------------------
-- Repair & migration
--------------------------------------------------------------------------------

--[[
	Fills in anything a stored profile is missing and replaces anything that is
	not a valid BigNum. A corrupted skill value must never reach the gain
	formula — a single NaN there would propagate into every future save.
]]
-- Player-populated collections. Reconcile must NOT walk into these: their keys
-- are data, not schema, and merging template keys in would resurrect items a
-- player spent or unlocks they lost to a season reset.
local OPEN_MAPS = {
	ingredients = true,
	seasonings = true,
	materials = true,
	unlockedRegions = true,
	gamepasses = true,
	companions = true,
	boosts = true,
	recipes = true,
	dishes = true,
	furniture = true,
	active = true,
	completed = true,
	claimedCredits = true,
}

local function reconcile(profile: any): any
	local template = DataService.TEMPLATE

	local function walk(target: any, source: any)
		for key, value in source do
			if target[key] == nil then
				target[key] = deepCopy(value)
			elseif type(value) == "table" and type(target[key]) == "table" and not OPEN_MAPS[key] then
				walk(target[key], value)
			end
		end
	end

	walk(profile, template)

	-- Removed with the worksite pads. Reconcile only ever adds, so an old save
	-- would otherwise carry this dead table for the life of the profile.
	profile.unlockedWorksites = nil

	if profile.selectedSkill then
		profile.selectedSkill = Skills.canonicalize(profile.selectedSkill)
	end

	for _, skillId in Skills.ORDER do
		if not BigNumber.isValid(profile.skills[skillId]) then
			local legacyVal = nil
			if skillId == "tobatsu" then
				legacyVal = profile.skills.subjugation or profile.skills.strength
			elseif skillId == "resilience" then
				legacyVal = profile.skills.grit or profile.skills.durability
			elseif skillId == "kusatori" then
				legacyVal = profile.skills.weeding or profile.skills.agility
			elseif skillId == "examprep" then
				legacyVal = profile.skills.craft or profile.skills.special
			end

			if BigNumber.isValid(legacyVal) then
				profile.skills[skillId] = legacyVal
			else
				profile.skills[skillId] = BigNumber.zero()
			end
		end
		if type(profile.certifications[skillId]) ~= "number" then
			profile.certifications[skillId] = 0
		end
		if type(profile.studyProgress[skillId]) ~= "number" then
			profile.studyProgress[skillId] = 0
		else
			profile.studyProgress[skillId] = math.clamp(profile.studyProgress[skillId], 0, 1)
		end
		if type(profile.examAttempts[skillId]) ~= "number" then
			profile.examAttempts[skillId] = 0
		end
	end

	for _, currency in { "yen", "stamps" } do
		if not BigNumber.isValid(profile.currencies[currency]) then
			warn(`[DataService] repairing invalid currency "{currency}"`)
			profile.currencies[currency] = BigNumber.zero()
		end
	end

	if type(profile.seasons) ~= "number" or profile.seasons < 0 then
		profile.seasons = 0
	end

	-- Reap expired boosts rather than carrying dead rows forever.
	local now = os.time()
	for index = #profile.boosts, 1, -1 do
		if (profile.boosts[index].expiresAt or 0) <= now then
			table.remove(profile.boosts, index)
		end
	end

	profile.version = Constants.DATA.SCHEMA_VERSION
	return profile
end

DataService.reconcile = reconcile

--------------------------------------------------------------------------------
-- Backends
--------------------------------------------------------------------------------

local function tryLoadProfileService()
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if not packages then
		return nil
	end
	local module = packages:FindFirstChild("ProfileService")
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn(`[DataService] ProfileService present but failed to load: {result}`)
		return nil
	end
	return result
end

--[[
	Which persistence backend can actually be used here.

	DataStoreService:GetDataStore() THROWS in an unpublished place ("You must
	publish this place to the web to access DataStore"), and GetAsync throws
	separately when Studio API access is switched off. Either one used to abort
	DataService.init() outright, which meant PlayerAdded was never connected, no
	profile ever loaded, and every gameplay action was silently refused because
	DataService.get() returned nil.

	So the probe is explicit and the failure is a DEGRADE, not a crash: an
	in-memory backend keeps the game fully playable in Studio, and says loudly
	that nothing will be saved.
]]
local function probeDataStore(): (any?, string?)
	if game.PlaceId == 0 then
		return nil, "place is not published"
	end

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Constants.DATA.STORE_NAME)
	end)
	if not ok then
		return nil, tostring(store)
	end

	-- GetDataStore can succeed while requests still fail, so make one cheap
	-- read before trusting it with a player's save.
	local reachable, err = pcall(function()
		return store:GetAsync("__probe")
	end)
	if not reachable then
		return nil, tostring(err)
	end

	return store, nil
end

local function keyFor(player: Player): string
	return Constants.DATA.KEY_PREFIX .. player.UserId
end

local function fallbackLoad(player: Player): any
	if backend == "memory" then
		return reconcile(deepCopy(DataService.TEMPLATE))
	end

	local key = keyFor(player)
	for attempt = 1, Constants.DATA.LOAD_RETRIES do
		local ok, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if ok then
			return if result then reconcile(result) else reconcile(deepCopy(DataService.TEMPLATE))
		end
		warn(`[DataService] load attempt {attempt} failed for {player.Name}: {result}`)
		task.wait(Constants.DATA.RETRY_BACKOFF * attempt)
	end
	return nil
end

local function fallbackSave(player: Player, profile: any): boolean
	if backend == "memory" then
		return true -- nothing to write to; the warning was issued at startup
	end

	local ok, err = pcall(function()
		dataStore:SetAsync(keyFor(player), profile)
	end)
	if not ok then
		warn(`[DataService] save failed for {player.Name}: {err}`)
	end
	return ok
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function DataService.get(player: Player): any?
	return profiles[player]
end

--[[
	Yields until the player's profile is available, or returns nil if they left
	first. Every service that touches a profile on join goes through this rather
	than racing PlayerAdded ordering.
]]
function DataService.await(player: Player, timeout: number?): any?
	local deadline = os.clock() + (timeout or 20)
	while not profiles[player] do
		if not player:IsDescendantOf(Players) then
			return nil
		end
		if os.clock() > deadline then
			return nil
		end
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.onLoaded(callback: (player: Player, profile: any) -> ())
	table.insert(loadedCallbacks, callback)
end

function DataService.onRelease(callback: (player: Player, profile: any) -> ())
	table.insert(releaseCallbacks, callback)
end

local function finishLoad(player: Player, profile: any)
	profile.meta.lastPlayed = os.time()
	if profile.meta.createdAt == 0 then
		profile.meta.createdAt = os.time()
	end
	profiles[player] = profile

	for _, callback in loadedCallbacks do
		local ok, err = pcall(callback, player, profile)
		if not ok then
			warn(`[DataService] onLoaded callback errored: {err}`)
		end
	end
end

local function onPlayerAdded(player: Player)
	if profileStore then
		local profile = profileStore:LoadProfileAsync(keyFor(player))
		if not profile then
			player:Kick("Your save is in use on another server. Please rejoin in a moment.")
			return
		end
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			profiles[player] = nil
			player:Kick("Your save was released. Please rejoin.")
		end)

		if not player:IsDescendantOf(Players) then
			profile:Release()
			return
		end

		reconcile(profile.Data)
		DataService._handles[player] = profile
		finishLoad(player, profile.Data)
	else
		local data = fallbackLoad(player)
		if not data then
			player:Kick("Could not load your save. Please rejoin.")
			return
		end
		if not player:IsDescendantOf(Players) then
			return
		end
		finishLoad(player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end

	for _, callback in releaseCallbacks do
		local ok, err = pcall(callback, player, profile)
		if not ok then
			warn(`[DataService] onRelease callback errored: {err}`)
		end
	end

	profile.meta.lastPlayed = os.time()
	profiles[player] = nil

	if profileStore then
		local handle = DataService._handles[player]
		if handle then
			handle:Release()
			DataService._handles[player] = nil
		end
	else
		fallbackSave(player, profile)
	end
end

function DataService.saveAll()
	if backend ~= "datastore" then
		-- ProfileService owns its own cadence; memory has nothing to flush.
		return
	end
	for player, profile in profiles do
		fallbackSave(player, profile)
	end
end

function DataService.init()
	local store, reason = probeDataStore()

	if not store then
		backend = "memory"
		warn("========================================================================")
		warn(`[DataService] DataStores are unavailable: {reason}`)
		warn("[DataService] Running IN-MEMORY. The game is fully playable, but NO")
		warn("[DataService] PROGRESS WILL BE SAVED when you leave.")
		warn("[DataService] To fix: publish the place, then in Studio enable")
		warn("[DataService] Game Settings > Security > Enable Studio Access to API Services.")
		warn("========================================================================")
	else
		dataStore = store
		ProfileService = tryLoadProfileService()

		if ProfileService then
			backend = "profileservice"
			profileStore = ProfileService.GetProfileStore(Constants.DATA.STORE_NAME, DataService.TEMPLATE)
			print("[DataService] backend: ProfileService (session-locked)")
		else
			backend = "datastore"
			warn("[DataService] backend: unlocked DataStore. ProfileService is not installed -")
			warn("[DataService] run `wally install` before any public test.")
		end
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	if backend ~= "profileservice" then
		task.spawn(function()
			while true do
				task.wait(Constants.DATA.AUTOSAVE_INTERVAL)
				DataService.saveAll()
			end
		end)
	end

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, player in Players:GetPlayers() do
			onPlayerRemoving(player)
		end
		task.wait(2)
	end)
end

-- Lets other services tell the player the truth about their session.
function DataService.getBackend(): string
	return backend
end

return DataService

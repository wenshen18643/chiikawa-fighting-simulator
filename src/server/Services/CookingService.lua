--[[
	Server-authoritative kitchen: one cooking station in Town, the stir-click
	minigame that trains resilience, and eating dishes for timed buffs.

	See docs/GAME.md and Config/Recipes.lua. The client only reports three
	intentions — a recipe was chosen, a stir click happened, a dish was eaten.
	Ingredient costs, click counts, distance and rate limits all live here.

	--------------------------------------------------------------------------------
	NO REFUNDS
	--------------------------------------------------------------------------------

	Selecting a recipe spends its ingredients immediately. Walking away from the
	station abandons the dish and they are NOT given back: cooking is commitment.
	Refund-free also keeps every exit from a session on a single code path —
	there is no second branch where spent ingredients come back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local Recipes = require(Shared.Modules.Config.Recipes)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Modules.Config.Layout)

local DataService = require(script.Parent.DataService)
local KitchenBuilder = require(script.Parent.KitchenBuilder)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)
local WorldService = require(script.Parent.WorldService)

local CookingService = {}

type Session = {
	recipeId: string,
	needed: number,
	progress: number,
}

local COOKING = Constants.COOKING

local sessions: { [Player]: Session } = {}
local limiters: { [Player]: RateLimiter.RateLimiter } = {}

-- Centre of the cooking pot, nil until the kitchen is built (or forever, if
-- the pot model failed to load — in which case cooking refuses to start).
local stationPosition: Vector3? = nil

local openRemote: RemoteEvent
local eventRemote: RemoteEvent

--------------------------------------------------------------------------------
-- The kitchen
--------------------------------------------------------------------------------

--[[
	The builder owns geometry. This service owns the interaction that geometry
	represents, including the actual position used for server distance checks.
]]
local function attachPrompt(rootPart: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Cook"
	prompt.ObjectText = "Cooking Pot"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = rootPart

	-- The prompt already enforced proximity and line of sight; there is
	-- nothing left to validate, the client just opens the recipe UI.
	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player)
	end)
end

--[[
	A proper room at the configured B5 destination. Layout owns its XZ and
	orientation; KitchenBuilder seats and constructs it, returning only the pot
	geometry gameplay needs.
]]
local function buildKitchen()
	local area = Areas.get(1)
	local regionFolder = WorldService.getRegionFolder(1)
	if not area or not regionFolder then
		warn("[CookingService] Town region folder is missing (did WorldService run first?) - no kitchen built")
		return
	end

	local built = KitchenBuilder.build(regionFolder, Layout.kitchenCFrame(area))
	stationPosition = built.stationPosition
	if built.stationRoot then
		attachPrompt(built.stationRoot)
	end
end

--------------------------------------------------------------------------------
-- Cooking
--------------------------------------------------------------------------------

--[[
	How many stir clicks `def` costs this cook. Every whole resilience exponent
	shaves CLICKS_PER_RESILIENCE_EXPONENT off the base, floored at a fraction of
	it — resilience helps, but no dish stirs itself. The log is clamped at zero
	(the same guard Formulas.maxStamina uses) so a sub-1 value can never ADD clicks.
]]
local function clicksNeeded(profile: any, def: Recipes.RecipeDefinition): number
	local exponents = math.floor(math.max(BigNumber.log10(profile.skills.resilience), 0))
	return math.max(
		math.ceil(def.baseClicks * COOKING.MIN_CLICKS_FRACTION),
		def.baseClicks - COOKING.CLICKS_PER_RESILIENCE_EXPONENT * exponents
	)
end

local function nearStation(root: BasePart): boolean
	return stationPosition ~= nil
		and (root.Position - stationPosition :: Vector3).Magnitude <= COOKING.STATION_RADIUS + 8
end

local function onSelect(player: Player, recipeId: any)
	if type(recipeId) ~= "string" then
		return
	end
	local def = Recipes.get(recipeId)
	if not def then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	-- Checked here rather than trusted from the menu: the client decides what to
	-- grey out, the server decides what may be cooked.
	if not Recipes.isUnlocked(def, profile) then
		NotifyService.send(player, "You have not been taught that one yet.", "locked")
		return
	end
	if sessions[player] then
		NotifyService.send(player, "Finish your current dish first!", "info")
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not nearStation(root) then
		return
	end

	local ingredients = profile.currencies.ingredients
	for _, ingredient in def.ingredients do
		if (ingredients[ingredient.id] or 0) < ingredient.count then
			NotifyService.send(player, "Missing ingredients!", "locked")
			return
		end
	end
	for _, ingredient in def.ingredients do
		ingredients[ingredient.id] -= ingredient.count
	end

	local needed = clicksNeeded(profile, def)
	sessions[player] = { recipeId = recipeId, needed = needed, progress = 0 }
	eventRemote:FireClient(player, "started", recipeId, needed)
	-- Spectator flag: the client reads this to play the stir anim while a
	-- dish is on, and we clear it on every way out of a session.
	character:SetAttribute("Cooking", true)
end

local function onClick(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end

	if not nearStation(root) then
		-- Walking away abandons the dish. See the header: no refund, one path.
		sessions[player] = nil
		character:SetAttribute("Cooking", false)
		eventRemote:FireClient(player, "cancelled", session.recipeId)
		return
	end

	local limiter = limiters[player]
	if not limiter then
		limiter = RateLimiter.new(COOKING.MAX_CLICKS_PER_SECOND, 1)
		limiters[player] = limiter
	end
	-- Over the cap: dropped, never credited. §2 rule 3 — no punishment either.
	if not limiter:consume() then
		return
	end

	session.progress += 1
	if session.progress < session.needed then
		eventRemote:FireClient(player, "progress", session.recipeId, session.progress, session.needed)
		return
	end

	-- The dish is done.
	sessions[player] = nil
	character:SetAttribute("Cooking", false)

	local profile = DataService.get(player)
	if not profile then
		return
	end

	local recipeId = session.recipeId
	profile.dishes[recipeId] = (profile.dishes[recipeId] or 0) + 1

	-- Every click invested pays resilience: needed clicks, not surviving ones,
	-- so a high-resilience cook is not paid less for being better at this.
	local gain =
		BigNumber.mulNumber(Formulas.gainPerAction(profile, "resilience"), session.needed * COOKING.XP_PER_CLICK)
	SkillService.award(player, profile, "resilience", gain)

	eventRemote:FireClient(player, "done", recipeId, gain)

	local def = Recipes.get(recipeId)
	NotifyService.send(player, `Cooked {def and def.name or recipeId}!`, "reward")
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function CookingService.init()
	openRemote = Remotes.event("Cook", "Open")
	eventRemote = Remotes.event("Cook", "Event")
	Remotes.event("Cook", "Select").OnServerEvent:Connect(onSelect)
	Remotes.event("Cook", "Click").OnServerEvent:Connect(onClick)

	buildKitchen()

	Players.PlayerRemoving:Connect(function(player)
		-- A session in flight dies with the player. Same rule as walking away:
		-- the ingredients are spent, the dish is lost.
		sessions[player] = nil
		limiters[player] = nil
	end)
end

return CookingService

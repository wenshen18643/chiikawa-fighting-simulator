local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Constants = require(Shared.Modules.Constants)
local Formulas = require(Shared.Modules.Formulas)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local Ingredients = require(Shared.Modules.Config.Ingredients)
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
local cookedCallbacks: { (Player, string) -> () } = {}
local sessions: { [Player]: Session } = {}
local limiters: { [Player]: RateLimiter.RateLimiter } = {}
local stationPosition: Vector3? = nil
local openRemote: RemoteEvent
local eventRemote: RemoteEvent

function CookingService.onCooked(callback: (Player, string) -> ())
	table.insert(cookedCallbacks, callback)
end

local function attachPrompt(rootPart: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Cook"
	prompt.ObjectText = "Cooking Pot"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = rootPart

	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player)
	end)
end

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
	local spend: { { id: string, count: number } } = {}
	local wildUsed = false

	for _, ingredient in def.ingredients do
		local fromFarmed = math.min(ingredients[ingredient.id] or 0, ingredient.count)
		local short = ingredient.count - fromFarmed
		local wildId = Ingredients.wildOf(ingredient.id)
		local fromWild = if wildId then math.min(ingredients[wildId] or 0, short) else 0

		if short - fromWild > 0 then
			NotifyService.send(player, "Missing ingredients!", "locked")
			return
		end

		if fromFarmed > 0 then
			table.insert(spend, { id = ingredient.id, count = fromFarmed })
		end
		if wildId and fromWild > 0 then
			table.insert(spend, { id = wildId, count = fromWild })
			wildUsed = true
		end
	end

	for _, entry in spend do
		ingredients[entry.id] -= entry.count
	end

	local baseClicks = def.baseClicks
	if wildUsed then
		baseClicks = math.ceil(baseClicks * (1 + COOKING.WILD_CLICK_SURCHARGE))
	end

	local needed = Formulas.cookClicks(profile, baseClicks)
	sessions[player] = { recipeId = recipeId, needed = needed, progress = 0 }
	eventRemote:FireClient(player, "started", recipeId, needed)
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
	if not limiter:consume() then
		return
	end

	session.progress += 1
	if session.progress < session.needed then
		eventRemote:FireClient(player, "progress", session.recipeId, session.progress, session.needed)
		return
	end

	sessions[player] = nil
	character:SetAttribute("Cooking", false)

	local profile = DataService.get(player)
	if not profile then
		return
	end

	local recipeId = session.recipeId
	profile.dishes[recipeId] = (profile.dishes[recipeId] or 0) + 1

	local gain =
		BigNumber.mulNumber(Formulas.gainPerAction(profile, "resilience"), session.needed * COOKING.XP_PER_CLICK)
	SkillService.award(player, profile, "resilience", gain)

	eventRemote:FireClient(player, "done", recipeId, gain)

	local def = Recipes.get(recipeId)
	NotifyService.send(player, `Cooked {def and def.name or recipeId}!`, "reward")

	for _, callback in cookedCallbacks do
		task.spawn(callback, player, recipeId)
	end
end

function CookingService.init()
	openRemote = Remotes.event("Cook", "Open")
	eventRemote = Remotes.event("Cook", "Event")
	Remotes.event("Cook", "Select").OnServerEvent:Connect(onSelect)
	Remotes.event("Cook", "Click").OnServerEvent:Connect(onClick)

	buildKitchen()

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		limiters[player] = nil
	end)
end

return CookingService

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local RateLimiter = require(Shared.Modules.RateLimiter)
local Remotes = require(Shared.Modules.Remotes)
local UI = require(Shared.UI)
local CompanionService = require(script.Parent.CompanionService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local ReplicationService = require(script.Parent.ReplicationService)

type ProfileState = CompanionSkins.ProfileState
type DrawDefinition = CompanionSkins.DrawDefinition
type SkinDefinition = CompanionSkins.SkinDefinition

type PullResult = {
	skinId: string,
	rarity: string,
	isNew: boolean,
}

local GachaService = {}
local PROMPT_NAME = "GachaPrompt"
local INTERACTION_DISTANCE = 20
local PULL_RATE = 2
local PULL_BURST = 2
local MANAGE_RATE = 5
local MANAGE_BURST = 5
local openRemote: RemoteEvent
local eventRemote: RemoteEvent
local npcAnchor: BasePart? = nil
local rng = Random.new()
local pullLimiters: { [Player]: RateLimiter.RateLimiter } = {}
local manageLimiters: { [Player]: RateLimiter.RateLimiter } = {}
local busy: { [Player]: boolean } = {}

local function limiterFor(
	collection: { [Player]: RateLimiter.RateLimiter },
	player: Player,
	rate: number,
	burst: number
): RateLimiter.RateLimiter
	local limiter = collection[player]
	if not limiter then
		limiter = RateLimiter.new(rate, burst)
		collection[player] = limiter
	end
	return limiter
end

local function rootFor(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function withinReach(player: Player): boolean
	local anchor = npcAnchor
	local root = rootFor(player)
	return anchor ~= nil
		and anchor.Parent ~= nil
		and root ~= nil
		and (root.Position - anchor.Position).Magnitude <= INTERACTION_DISTANCE
end

local function copyStringNumberMap(source: { [string]: number }): { [string]: number }
	return table.clone(source)
end

local function copyStringMap(source: { [string]: string }): { [string]: string }
	return table.clone(source)
end

local function bestByCharacter(profile: any): { [string]: string }
	local result = {}
	for _, characterId in CompanionSkins.CHARACTER_ORDER do
		local rarity = CompanionSkins.bestOwnedRarity(profile, characterId)
		if rarity then
			result[characterId] = rarity.id
		end
	end
	return result
end

local function buildState(profile: any, state: ProfileState): { [string]: any }
	local companions = profile.companions
	return {
		yen = profile.currencies.yen,
		unlimitedYen = CurrencyService.isUnlimited("yen"),
		capacity = CompanionSkins.CAPACITY,
		used = CompanionSkins.totalCopies(state),
		copies = copyStringNumberMap(state.copies),
		equipped = copyStringMap(state.equipped),
		rarePlusMisses = state.rarePlusMisses,
		legendaryMisses = state.legendaryMisses,
		bestByCharacter = bestByCharacter(profile),
		selectedCharacter = if type(companions) == "table" then companions.selected else nil,
	}
end

local function deny(player: Player, message: string, profile: any?, state: ProfileState?)
	NotifyService.send(player, message, "locked")
	eventRemote:FireClient(player, {
		kind = "denied",
		message = message,
		state = if profile and state then buildState(profile, state) else nil,
	})
end

local function beginMutation(player: Player): boolean
	if busy[player] then
		return false
	end
	busy[player] = true
	return true
end

local function finishMutation(player: Player)
	busy[player] = nil
end

local function simulatePulls(
	state: ProfileState,
	draw: DrawDefinition,
	count: number
): ({ PullResult }, { [string]: number }, number, number)
	local results = {} :: { PullResult }
	local copies = copyStringNumberMap(state.copies)
	local rarePlusMisses = state.rarePlusMisses
	local legendaryMisses = state.legendaryMisses

	for _ = 1, count do
		local minimumOrder = 1
		if legendaryMisses >= CompanionSkins.LEGENDARY_PITY - 1 then
			minimumOrder = 5
		elseif rarePlusMisses >= CompanionSkins.RARE_PLUS_PITY - 1 then
			minimumOrder = 3
		end

		local rarityId = (CompanionSkins.rollRarity(draw, minimumOrder, rng) :: any) :: CompanionSkins.RarityId
		local rarity = CompanionSkins.RARITIES[rarityId]
		local skin = CompanionSkins.rollSkin(rarityId, rng)
		local previous = copies[skin.id] or 0
		copies[skin.id] = previous + 1

		table.insert(results, {
			skinId = skin.id,
			rarity = rarityId,
			isNew = previous == 0,
		})

		if rarity.order >= CompanionSkins.RARITIES.rare.order then
			rarePlusMisses = 0
		else
			rarePlusMisses += 1
		end
		if rarityId == "legendary" then
			legendaryMisses = 0
		else
			legendaryMisses += 1
		end
	end

	return results, copies, rarePlusMisses, legendaryMisses
end

local function parsePullRequest(request: unknown): (DrawDefinition?, number?)
	if type(request) ~= "table" then
		return nil, nil
	end
	local payload = request :: { [string]: unknown }
	local drawId = payload.drawId
	local count = payload.count
	if type(drawId) ~= "string" or type(count) ~= "number" or count % 1 ~= 0 then
		return nil, nil
	end
	if not CompanionSkins.ALLOWED_BATCHES[count] then
		return nil, nil
	end
	return CompanionSkins.getDraw(drawId), count
end

function GachaService.open(player: Player)
	if not withinReach(player) then
		return
	end
	local profile = DataService.get(player)
	local state = profile and CompanionSkins.getState(profile)
	if not profile or not state then
		return
	end
	openRemote:FireClient(player, buildState(profile, state))
end

function GachaService.pull(player: Player, request: unknown): boolean
	if not limiterFor(pullLimiters, player, PULL_RATE, PULL_BURST):consume() then
		return false
	end
	local draw, count = parsePullRequest(request)
	if not draw or not count then
		return false
	end
	if not beginMutation(player) then
		return false
	end

	local ok, result = pcall(function(): boolean
		if not withinReach(player) then
			deny(player, "Stand beside Gacha Guy to draw skins.")
			return false
		end

		local profile = DataService.get(player)
		local state = profile and CompanionSkins.getState(profile)
		if not profile or not state then
			return false
		end

		if CompanionSkins.totalCopies(state) + count > CompanionSkins.CAPACITY then
			deny(player, `You need {count} free skin slots for this draw.`, profile, state)
			return false
		end

		local cost = BigNumber.fromNumber(draw.cost * count)
		if not CurrencyService.canAfford(profile, "yen", cost) then
			deny(player, `You need {draw.cost * count} yen for {count} draw(s).`, profile, state)
			return false
		end

		local results, copies, rarePlusMisses, legendaryMisses = simulatePulls(state, draw, count)
		if not CurrencyService.spend(profile, "yen", cost) then
			deny(player, "Your yen changed before the draw could finish.", profile, state)
			return false
		end

		state.copies = copies
		state.rarePlusMisses = rarePlusMisses
		state.legendaryMisses = legendaryMisses

		eventRemote:FireClient(player, {
			kind = "pull",
			drawId = draw.id,
			results = results,
			state = buildState(profile, state),
		})
		ReplicationService.pushTo(player)
		return true
	end)

	finishMutation(player)
	if not ok then
		warn(`[GachaService] pull failed for {player.Name}: {result}`)
		return false
	end
	return result
end

local function parseEquipRequest(request: unknown): (string?, string?, boolean)
	if type(request) ~= "table" then
		return nil, nil, false
	end
	local payload = request :: { [string]: unknown }
	local characterId = payload.characterId
	local skinId = payload.skinId
	if type(characterId) ~= "string" or (skinId ~= nil and type(skinId) ~= "string") then
		return nil, nil, false
	end
	return characterId, skinId :: string?, true
end

function GachaService.equip(player: Player, request: unknown): boolean
	if not limiterFor(manageLimiters, player, MANAGE_RATE, MANAGE_BURST):consume() then
		return false
	end
	local characterId, skinId, valid = parseEquipRequest(request)
	if not valid or not characterId or not CompanionSkins.CHARACTERS[characterId] then
		return false
	end
	if not beginMutation(player) then
		return false
	end

	local ok, result = pcall(function(): boolean
		if not withinReach(player) then
			deny(player, "Stand beside Gacha Guy to change skins.")
			return false
		end
		local profile = DataService.get(player)
		local state = profile and CompanionSkins.getState(profile)
		if not profile or not state then
			return false
		end

		if skinId then
			local skin = CompanionSkins.get(skinId)
			if not skin or skin.characterId ~= characterId or (state.copies[skinId] or 0) <= 0 then
				deny(player, "You do not own that skin for this companion.", profile, state)
				return false
			end
			state.equipped[characterId] = skinId
		else
			state.equipped[characterId] = nil
		end

		local companions = profile.companions
		if type(companions) == "table" and companions.selected == characterId then
			CompanionService.refreshAppearance(player)
		end
		eventRemote:FireClient(player, { kind = "state", state = buildState(profile, state) })
		return true
	end)

	finishMutation(player)
	if not ok then
		warn(`[GachaService] equip failed for {player.Name}: {result}`)
		return false
	end
	return result
end

local function parseSellRequest(request: unknown): (SkinDefinition?, number?)
	if type(request) ~= "table" then
		return nil, nil
	end
	local payload = request :: { [string]: unknown }
	local skinId = payload.skinId
	local count = payload.count
	if
		type(skinId) ~= "string"
		or type(count) ~= "number"
		or count % 1 ~= 0
		or count < 1
		or count > CompanionSkins.CAPACITY
	then
		return nil, nil
	end
	return CompanionSkins.get(skinId), count
end

function GachaService.sell(player: Player, request: unknown): boolean
	if not limiterFor(manageLimiters, player, MANAGE_RATE, MANAGE_BURST):consume() then
		return false
	end
	local skin, count = parseSellRequest(request)
	if not skin or not count then
		return false
	end
	if not beginMutation(player) then
		return false
	end

	local ok, result = pcall(function(): boolean
		if not withinReach(player) then
			deny(player, "Stand beside Gacha Guy to sell skins.")
			return false
		end
		local profile = DataService.get(player)
		local state = profile and CompanionSkins.getState(profile)
		if not profile or not state then
			return false
		end

		local owned = state.copies[skin.id] or 0
		local reserved = if state.equipped[skin.characterId] == skin.id then 1 else 0
		if count > owned - reserved then
			deny(player, "Unequip that copy or choose a smaller sale amount.", profile, state)
			return false
		end

		local remaining = owned - count
		state.copies[skin.id] = if remaining > 0 then remaining else nil
		local rarity = CompanionSkins.RARITIES[skin.rarity]
		local payout = rarity.resaleYen * count
		CurrencyService.award(profile, "yen", BigNumber.fromNumber(payout))

		eventRemote:FireClient(player, {
			kind = "sold",
			skinId = skin.id,
			count = count,
			payout = payout,
			state = buildState(profile, state),
		})
		ReplicationService.pushTo(player)
		return true
	end)

	finishMutation(player)
	if not ok then
		warn(`[GachaService] sell failed for {player.Name}: {result}`)
		return false
	end
	return result
end

local function findAnchor(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				best = descendant
				bestVolume = volume
			end
		end
	end
	return best
end

local function bindNpc()
	local safeZone = Workspace:WaitForChild("SafeZone", 60)
	local model = safeZone and safeZone:FindFirstChild("GachaGuy")
	if not (model and model:IsA("Model")) then
		warn("[GachaService] GachaGuy was not placed inside Workspace.SafeZone")
		return
	end

	local anchor = findAnchor(model)
	if not anchor then
		warn("[GachaService] GachaGuy has no BasePart for interaction")
		return
	end
	npcAnchor = anchor

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Draw skins"
	prompt.ObjectText = "Gacha Guy"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(GachaService.open)

	UI.sign(anchor, {
		name = "GachaSign",
		title = "Companion Skins",
		subtitle = "draw · equip · trade back",
		offset = Vector3.new(0, 8, 0),
		extent = UDim2.fromScale(14, 4.2),
		maxDistance = 120,
	})
end

function GachaService.init()
	openRemote = Remotes.event("Gacha", "Open")
	eventRemote = Remotes.event("Gacha", "Event")

	Remotes.event("Gacha", "Pull").OnServerEvent:Connect(GachaService.pull)
	Remotes.event("Gacha", "Equip").OnServerEvent:Connect(GachaService.equip)
	Remotes.event("Gacha", "Sell").OnServerEvent:Connect(GachaService.sell)

	Players.PlayerRemoving:Connect(function(player)
		pullLimiters[player] = nil
		manageLimiters[player] = nil
		busy[player] = nil
	end)

	task.spawn(bindNpc)
end

return GachaService

--[[
	Certification. See docs/GAME.md §6.

	Every skill has its own grade ladder, and Exam Prep's order is the ceiling on
	all the others, so the one lever worth pulling is always legible: raise Exam
	Prep, then everything else can climb again.

	Three shapes of exam:
	  Tobatsu, Resilience   stat value and the cap. Nothing to answer.
	  Kusatori              the same, plus the plant-identification deck.
	  Exam Prep             the same, plus a full readiness bar and one item
	                        from each pillar, so the ceiling cannot rise
	                        without a lap of the world.

	Eligibility is computed here and shipped whole. The counter UI renders what
	it is told and asks for nothing, which is the only way the cap, the item
	counts and the readiness bar can never disagree with the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Certifications = require(Shared.Modules.Config.Certifications)
local Constants = require(Shared.Modules.Constants)
local ExamQuestions = require(Shared.Modules.Config.ExamQuestions)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)

local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local StudyService = require(script.Parent.StudyService)
local WorldService = require(script.Parent.WorldService)

local ExamService = {}

local DESK_MODEL = "StudyDeskProp"
local CAP_SKILL = Certifications.CAP_SKILL
local QUIZ_SKILL = Constants.EXAM.QUIZ_SKILL

type Session = {
	skillId: string,
	order: number,
	deck: { string },
	index: number,
	correct: number,
	questionId: string?,
	locked: boolean,
}

local sessions: { [Player]: Session } = {}
local reviewRemaining: { [Player]: { [string]: number } } = {}
local randoms: { [Player]: Random } = {}

local eventRemote: RemoteEvent
local openRemote: RemoteEvent

local function rngFor(player: Player): Random
	local rng = randoms[player]
	if not rng then
		rng = Random.new(player.UserId * 17 + os.time())
		randoms[player] = rng
	end
	return rng
end

local function reviewFor(player: Player, skillId: string): number
	local held = reviewRemaining[player]
	return if held then held[skillId] or 0 else 0
end

local function setReview(player: Player, skillId: string, count: number)
	local held = reviewRemaining[player]
	if not held then
		held = {}
		reviewRemaining[player] = held
	end
	held[skillId] = if count > 0 then count else nil
end

--------------------------------------------------------------------------------
-- Eligibility
--------------------------------------------------------------------------------

local function itemRows(profile: any, order: number): { { id: string, name: string, need: number, have: number } }
	local rows = {}
	for ingredientId, need in Certifications.itemsForOrder(order) do
		local definition = Ingredients.get(ingredientId)
		table.insert(rows, {
			id = ingredientId,
			name = if definition then definition.name else ingredientId,
			need = need,
			have = profile.currencies.ingredients[ingredientId] or 0,
		})
	end
	table.sort(rows, function(left, right)
		return left.id < right.id
	end)
	return rows
end

--[[
	One row of the counter, and the single source of truth for whether a sit is
	allowed. `onSit` calls this again rather than trusting whatever the client
	was last shown.
]]
function ExamService.eligibility(profile: any, skillId: string): any
	local canonical = Skills.canonicalize(skillId)
	local order = profile.certifications[canonical] or 0
	local nextOrder = order + 1
	local requirement = BigNumber.coerce(Certifications.requirementForOrder(nextOrder))
	local current = profile.skills[canonical] or BigNumber.zero()

	local row = {
		skillId = canonical,
		order = order,
		nextOrder = nextOrder,
		grade = Certifications.describe(order),
		nextGrade = Certifications.describe(nextOrder),
		multiplier = Certifications.gainMultiplier(order),
		nextMultiplier = Certifications.gainMultiplier(nextOrder),
		requirement = requirement,
		current = current,
		cap = Certifications.capFor(profile),
		capped = Certifications.isCapped(profile, canonical, nextOrder),
		quizzed = canonical == QUIZ_SKILL,
		readiness = if canonical == CAP_SKILL then StudyService.readiness(profile) else 1,
		items = if canonical == CAP_SKILL then itemRows(profile, nextOrder) else {},
		ready = false,
		reason = "",
	}

	if row.capped then
		row.reason = `Exam Prep {Certifications.describe(row.cap)} caps you here.`
		return row
	end
	if not (BigNumber.isValid(current) and BigNumber.gte(current, requirement)) then
		local definition = Skills.get(canonical)
		local name = if definition then definition.name else canonical
		row.reason = `Raise {name} to {BigNumber.toString(requirement)}.`
		return row
	end
	if row.readiness < 1 then
		row.reason = "Fill your readiness bookmark in the study book."
		return row
	end
	for _, item in row.items do
		if item.have < item.need then
			row.reason = `Bring {item.need} {item.name}.`
			return row
		end
	end

	row.ready = true
	return row
end

local function rowsFor(player: Player, profile: any): { any }
	local rows = {}
	for _, skillId in Skills.ORDER do
		local row = ExamService.eligibility(profile, skillId)
		local review = reviewFor(player, row.skillId)
		if row.ready and review > 0 then
			row.ready = false
			row.reason = `Review {review} more card(s).`
		end
		row.review = review
		table.insert(rows, row)
	end
	return rows
end

local function sendCounter(player: Player, profile: any)
	openRemote:FireClient(player, {
		cap = Certifications.capFor(profile),
		capSkill = CAP_SKILL,
		rows = rowsFor(player, profile),
	})
end

--------------------------------------------------------------------------------
-- Awarding
--------------------------------------------------------------------------------

local function spendItems(profile: any, order: number): boolean
	local cost = Certifications.itemsForOrder(order)
	local held = profile.currencies.ingredients

	for ingredientId, need in cost do
		if (held[ingredientId] or 0) < need then
			return false
		end
	end
	for ingredientId, need in cost do
		local left = (held[ingredientId] or 0) - need
		held[ingredientId] = if left > 0 then left else nil
	end
	return true
end

local function certify(player: Player, profile: any, skillId: string, order: number)
	profile.certifications[skillId] = order
	profile.examAttempts[skillId] = (profile.examAttempts[skillId] or 0) + 1
	setReview(player, skillId, 0)

	local definition = Skills.get(skillId)
	local name = if definition then definition.name else skillId
	NotifyService.send(player, `{name} {Certifications.describe(order)}! Well earned.`, "unlock")

	if skillId == CAP_SKILL then
		NotifyService.send(player, `Every other grade can now reach {Certifications.describe(order)}.`, "unlock")
	end
end

--------------------------------------------------------------------------------
-- The plant deck
--------------------------------------------------------------------------------

local function sendQuestion(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	local questionId = session.deck[session.index]
	if not questionId then
		return
	end
	session.questionId = questionId
	session.locked = false

	eventRemote:FireClient(player, {
		kind = "question",
		skillId = session.skillId,
		questionId = questionId,
		options = ExamQuestions.optionsFor(questionId, rngFor(player)),
		index = session.index,
		total = #session.deck,
	})
end

local function finish(player: Player, profile: any)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil

	local passed = session.correct >= Constants.EXAM.PASSING_ANSWERS
	if passed then
		certify(player, profile, session.skillId, session.order)
	else
		profile.examAttempts[session.skillId] = (profile.examAttempts[session.skillId] or 0) + 1
		setReview(player, session.skillId, Constants.EXAM.REVIEW_AFTER_FAILURE)
		NotifyService.send(player, "Almost there. Review two cards with a friend, then try again.", "info")
	end

	eventRemote:FireClient(player, {
		kind = "result",
		skillId = session.skillId,
		passed = passed,
		grade = Certifications.describe(if passed then session.order else session.order - 1),
		correct = session.correct,
		total = #session.deck,
		attempts = profile.examAttempts[session.skillId] or 0,
		review = reviewFor(player, session.skillId),
		rows = rowsFor(player, profile),
		cap = Certifications.capFor(profile),
	})
end

local function onAnswer(player: Player, optionId: any)
	if type(optionId) ~= "string" or not ExamQuestions.get(optionId) then
		return
	end

	local profile = DataService.get(player)
	local session = sessions[player]
	if not profile or not session or session.locked or not session.questionId then
		return
	end
	session.locked = true

	local correct = optionId == session.questionId
	if correct then
		session.correct += 1
	end

	eventRemote:FireClient(player, {
		kind = "feedback",
		skillId = session.skillId,
		correct = correct,
		selectedId = optionId,
		correctId = session.questionId,
		index = session.index,
		total = #session.deck,
	})

	task.delay(1.1, function()
		if sessions[player] ~= session or not player:IsDescendantOf(Players) then
			return
		end
		session.index += 1
		if session.index > #session.deck then
			finish(player, profile)
		else
			sendQuestion(player)
		end
	end)
end

--------------------------------------------------------------------------------
-- Sitting
--------------------------------------------------------------------------------

local function onSit(player: Player, skillId: any)
	if type(skillId) ~= "string" or not Skills.exists(skillId) then
		return
	end

	local profile = DataService.get(player)
	if not profile or sessions[player] then
		return
	end

	local canonical = Skills.canonicalize(skillId)
	local row = ExamService.eligibility(profile, canonical)
	local review = reviewFor(player, canonical)

	if not row.ready or review > 0 then
		NotifyService.send(player, if review > 0 then `Review {review} more card(s).` else row.reason, "locked")
		sendCounter(player, profile)
		return
	end

	if canonical == QUIZ_SKILL then
		local deck = ExamQuestions.shuffle(ExamQuestions.ORDER, rngFor(player))
		while #deck > Constants.EXAM.QUESTIONS do
			table.remove(deck)
		end
		sessions[player] = {
			skillId = canonical,
			order = row.nextOrder,
			deck = deck,
			index = 1,
			correct = 0,
			locked = false,
		}
		sendQuestion(player)
		return
	end

	if canonical == CAP_SKILL then
		-- Checked twice on purpose: eligibility ran before the yield-free path
		-- below, but spending is the only step that can fail on a stale count.
		if not spendItems(profile, row.nextOrder) then
			sendCounter(player, profile)
			return
		end
		StudyService.spendReadiness(profile)
	end

	certify(player, profile, canonical, row.nextOrder)

	eventRemote:FireClient(player, {
		kind = "result",
		skillId = canonical,
		passed = true,
		grade = Certifications.describe(row.nextOrder),
		rows = rowsFor(player, profile),
		cap = Certifications.capFor(profile),
	})
end

local function onClose(player: Player)
	sessions[player] = nil
end

--------------------------------------------------------------------------------
-- The desk
--------------------------------------------------------------------------------

local function attachPrompt(model: Model)
	local anchor = model.PrimaryPart or model:FindFirstChild("TableTop")
	if not anchor or not anchor:IsA("BasePart") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sit an exam"
	prompt.ObjectText = "Exam Hall"
	prompt.MaxActivationDistance = Constants.EXAM.PROMPT_DISTANCE
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		local profile = DataService.get(player)
		if profile then
			sendCounter(player, profile)
		end
	end)
end

function ExamService.init()
	openRemote = Remotes.event("Exam", "Open")
	eventRemote = Remotes.event("Exam", "Event")
	Remotes.event("Exam", "Sit").OnServerEvent:Connect(onSit)
	Remotes.event("Exam", "Answer").OnServerEvent:Connect(onAnswer)
	Remotes.event("Exam", "Close").OnServerEvent:Connect(onClose)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		reviewRemaining[player] = nil
		randoms[player] = nil
	end)

	task.spawn(function()
		WorldService.awaitDressed()

		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Model") and descendant.Name == DESK_MODEL then
				attachPrompt(descendant)
			end
		end
	end)
end

return ExamService

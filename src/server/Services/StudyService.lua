--[[
	Server-authoritative Study -> Recall -> Exam loop.

	The client only reports three intentions: a page was completed, an offered
	plant was chosen, or the player wants to sit the exam. Question order,
	readiness, retries and certification awards all live here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Certifications = require(Shared.Modules.Config.Certifications)
local ChiikawaFacts = require(Shared.Modules.Config.ChiikawaFacts)
local Constants = require(Shared.Modules.Constants)
local ExamQuestions = require(Shared.Modules.Config.ExamQuestions)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)

local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)
local WorksiteService = require(script.Parent.WorksiteService)

local StudyService = {}

type Prompt = {
	mode: "study" | "exam",
	questionId: string,
	factId: number?,
	options: { string },
	phase: "preview" | "answer" | "locked",
}

type ExamSession = {
	deck: { string },
	index: number,
	correct: number,
}

local pageCounts: { [Player]: number } = {}
local lastPages: { [Player]: number } = {}
local lastQuestions: { [Player]: string } = {}
local lastFacts: { [Player]: number } = {}
local prompts: { [Player]: Prompt } = {}
local exams: { [Player]: ExamSession } = {}
local reviewRemaining: { [Player]: number } = {}
local randoms: { [Player]: Random } = {}

local eventRemote: RemoteEvent

local function rngFor(player: Player): Random
	local rng = randoms[player]
	if not rng then
		rng = Random.new(player.UserId * 31 + os.time())
		randoms[player] = rng
	end
	return rng
end

local function readiness(profile: any): number
	local value = profile.studyProgress[Constants.STUDY.SUBJECT]
	return if type(value) == "number" then math.clamp(value, 0, 1) else 0
end

local function hasSkillRequirement(profile: any): boolean
	local current = profile.skills[Constants.STUDY.SUBJECT]
	return BigNumber.isValid(current)
		and BigNumber.gte(current, BigNumber.coerce(Certifications.requirementForOrder(1)))
end

local function studyWorksite(player: Player, profile: any): string?
	local spot = WorksiteService.getOccupied(player)
	if spot and WorksiteService.validate(player, profile, spot) then
		local worksite = Worksites.get(spot.worksiteId)
		if worksite and Skills.canonicalize(worksite.skill) == "examprep" then
			return spot.worksiteId
		end
	end
	return nil
end

local function focusExpiresAt(profile: any): number
	local now = os.time()
	for _, boost in profile.boosts do
		if boost.id == "study_focus" and boost.expiresAt > now then
			return boost.expiresAt
		end
	end
	return 0
end

local function grantFocus(profile: any): number
	local expiresAt = os.time() + Constants.STUDY.FOCUS_BUFF_DURATION
	for _, boost in profile.boosts do
		if boost.id == "study_focus" then
			boost.multiplier = Constants.STUDY.FOCUS_BUFF_MULTIPLIER
			boost.skill = "examprep"
			boost.expiresAt = expiresAt
			return expiresAt
		end
	end
	table.insert(profile.boosts, {
		id = "study_focus",
		multiplier = Constants.STUDY.FOCUS_BUFF_MULTIPLIER,
		skill = "examprep",
		expiresAt = expiresAt,
	})
	return expiresAt
end

local function awardPage(player: Player, profile: any): BigNumber.BigNum
	local worksiteId = studyWorksite(player, profile)
	local gain = Formulas.gainPerAction(profile, "examprep", worksiteId)
	if not worksiteId then
		gain = BigNumber.mulNumber(gain, Constants.WORK.OFF_PAD_MULTIPLIER)
	end
	SkillService.award(player, profile, "examprep", gain)
	return gain
end

local function pickQuestion(player: Player): string
	local rng = rngFor(player)
	local choices = ExamQuestions.shuffle(ExamQuestions.ORDER, rng)
	for _, questionId in choices do
		if questionId ~= lastQuestions[player] then
			lastQuestions[player] = questionId
			return questionId
		end
	end
	return choices[1]
end

local function pickFact(player: Player): number
	local factId = ChiikawaFacts.pickId(rngFor(player), lastFacts[player])
	lastFacts[player] = factId
	return factId
end

local function currentFact(player: Player): number
	return lastFacts[player] or pickFact(player)
end

local function helperFor(player: Player, profile: any, prompt: Prompt): any?
	local selected = profile.companions and profile.companions.selected
	local rng = rngFor(player)
	if selected == "hachiware" then
		local wrong = {}
		for _, optionId in prompt.options do
			if optionId ~= prompt.questionId then
				table.insert(wrong, optionId)
			end
		end
		return {
			kind = "hachiware",
			text = "Hachiware crossed out one answer.",
			crossedOut = wrong[rng:NextInteger(1, #wrong)],
		}
	elseif selected == "usagi" and rng:NextNumber() <= 0.3 then
		local definition = ExamQuestions.get(prompt.questionId)
		return {
			kind = "usagi",
			text = `Usagi blurts out: {definition and definition.name or "Yaha!"}`,
			revealed = prompt.questionId,
		}
	end
	return nil
end

local function sendStudyQuestion(player: Player, profile: any, pageFactId: number?)
	if prompts[player] or exams[player] then
		return
	end

	local questionId = pickQuestion(player)
	local factId = pageFactId or pickFact(player)
	local prompt: Prompt = {
		mode = "study",
		questionId = questionId,
		factId = factId,
		options = ExamQuestions.optionsFor(questionId, rngFor(player)),
		phase = "preview",
	}
	prompts[player] = prompt
	eventRemote:FireClient(player, {
		kind = "preview",
		questionId = questionId,
		factId = factId,
		readiness = readiness(profile),
	})

	task.delay(Constants.STUDY.PREVIEW_DURATION, function()
		if prompts[player] ~= prompt or not player:IsDescendantOf(Players) then
			return
		end
		prompt.phase = "answer"
		eventRemote:FireClient(player, {
			kind = "question",
			mode = "study",
			questionId = prompt.questionId,
			options = prompt.options,
			helper = helperFor(player, profile, prompt),
			readiness = readiness(profile),
		})
	end)
end

local function onPage(player: Player)
	local profile = DataService.get(player)
	if not profile or prompts[player] or exams[player] then
		return
	end
	if Skills.canonicalize(profile.selectedSkill or "") ~= "examprep" then
		return
	end

	local now = os.clock()
	if now - (lastPages[player] or -math.huge) < Constants.STUDY.PAGE_DEBOUNCE then
		return
	end
	lastPages[player] = now
	pageCounts[player] = (pageCounts[player] or 0) + 1
	local gain = awardPage(player, profile)
	local factId = pickFact(player)

	eventRemote:FireClient(player, {
		kind = "page",
		page = pageCounts[player],
		gain = gain,
		factId = factId,
		focusExpiresAt = focusExpiresAt(profile),
	})

	if rngFor(player):NextNumber() <= Constants.STUDY.FACT_CHANCE then
		sendStudyQuestion(player, profile, factId)
	end
end

local function examReady(player: Player, profile: any): boolean
	return (profile.certifications[Constants.STUDY.SUBJECT] or 0) < 1
		and readiness(profile) >= 1
		and hasSkillRequirement(profile)
		and (reviewRemaining[player] or 0) <= 0
end

local function sendExamQuestion(player: Player)
	local session = exams[player]
	if not session then
		return
	end

	local questionId = session.deck[session.index]
	if not questionId then
		return
	end
	local prompt: Prompt = {
		mode = "exam",
		questionId = questionId,
		options = ExamQuestions.optionsFor(questionId, rngFor(player)),
		phase = "answer",
	}
	prompts[player] = prompt
	eventRemote:FireClient(player, {
		kind = "question",
		mode = "exam",
		questionId = questionId,
		options = prompt.options,
		index = session.index,
		total = #session.deck,
	})
end

local function finishExam(player: Player, profile: any)
	local session = exams[player]
	if not session then
		return
	end

	profile.examAttempts[Constants.STUDY.SUBJECT] = (profile.examAttempts[Constants.STUDY.SUBJECT] or 0) + 1
	local attempts = profile.examAttempts[Constants.STUDY.SUBJECT]
	local passed = session.correct >= Constants.STUDY.EXAM_PASSING_ANSWERS
	exams[player] = nil
	prompts[player] = nil

	if passed then
		profile.certifications[Constants.STUDY.SUBJECT] = 1
		profile.studyProgress[Constants.STUDY.SUBJECT] = 0
		reviewRemaining[player] = 0
		NotifyService.send(player, "Kusatori Grade 5! Your careful studying paid off.", "unlock")
	else
		reviewRemaining[player] = Constants.STUDY.REVIEW_AFTER_FAILURE
		NotifyService.send(player, "Almost there. Review two cards with a friend, then try again.", "info")
	end

	eventRemote:FireClient(player, {
		kind = "result",
		passed = passed,
		correct = session.correct,
		total = #session.deck,
		attempts = attempts,
		reviewRemaining = reviewRemaining[player],
	})
end

local function onAnswer(player: Player, optionId: any)
	if type(optionId) ~= "string" or not ExamQuestions.get(optionId) then
		return
	end

	local profile = DataService.get(player)
	local prompt = prompts[player]
	if not profile or not prompt or prompt.phase ~= "answer" then
		return
	end
	prompt.phase = "locked"

	local correct = optionId == prompt.questionId
	if prompt.mode == "study" then
		local before = readiness(profile)
		local gain = if correct then Constants.STUDY.CORRECT_PROGRESS else Constants.STUDY.LEARNING_PROGRESS
		profile.studyProgress[Constants.STUDY.SUBJECT] = math.clamp(before + gain, 0, 1)
		local buffAwarded = correct and rngFor(player):NextNumber() <= Constants.STUDY.FOCUS_BUFF_CHANCE
		local buffExpiresAt = if buffAwarded then grantFocus(profile) else focusExpiresAt(profile)
		if correct and (reviewRemaining[player] or 0) > 0 then
			reviewRemaining[player] -= 1
		end
		prompts[player] = nil

		local isReady = examReady(player, profile)
		eventRemote:FireClient(player, {
			kind = "feedback",
			mode = "study",
			correct = correct,
			selectedId = optionId,
			correctId = prompt.questionId,
			readiness = readiness(profile),
			examReady = isReady,
			reviewRemaining = reviewRemaining[player] or 0,
			buffAwarded = buffAwarded,
			focusExpiresAt = buffExpiresAt,
		})
		if before < 1 and readiness(profile) >= 1 then
			NotifyService.send(player, "Your Grade 5 exam booklet is ready.", "unlock")
		elseif (reviewRemaining[player] or 0) == 0 and isReady then
			NotifyService.send(player, "Review complete. You can sit the exam again.", "unlock")
		end
		return
	end

	local session = exams[player]
	if not session then
		prompts[player] = nil
		return
	end
	if correct then
		session.correct += 1
	end
	eventRemote:FireClient(player, {
		kind = "feedback",
		mode = "exam",
		correct = correct,
		selectedId = optionId,
		correctId = prompt.questionId,
		index = session.index,
		total = #session.deck,
	})

	task.delay(1.1, function()
		if exams[player] ~= session or not player:IsDescendantOf(Players) then
			return
		end
		prompts[player] = nil
		session.index += 1
		if session.index > #session.deck then
			finishExam(player, profile)
		else
			sendExamQuestion(player)
		end
	end)
end

local function onSitExam(player: Player)
	local profile = DataService.get(player)
	if not profile or prompts[player] or exams[player] then
		return
	end
	if (profile.certifications[Constants.STUDY.SUBJECT] or 0) >= 1 then
		NotifyService.send(player, "You already hold Kusatori Grade 5.", "info")
		return
	end
	if readiness(profile) < 1 then
		NotifyService.send(player, "Fill your Readiness bookmark before sitting the exam.", "locked")
		return
	end
	if not hasSkillRequirement(profile) then
		NotifyService.send(player, "Practise Kusatori to 100 before sitting Grade 5.", "locked")
		return
	end
	if (reviewRemaining[player] or 0) > 0 then
		NotifyService.send(player, `Review {reviewRemaining[player]} more card(s), then try again.`, "info")
		return
	end

	local deck = ExamQuestions.shuffle(ExamQuestions.ORDER, rngFor(player))
	while #deck > Constants.STUDY.EXAM_QUESTIONS do
		table.remove(deck)
	end
	exams[player] = { deck = deck, index = 1, correct = 0 }
	sendExamQuestion(player)
end

local function onClose(player: Player)
	-- A closed book cannot retain an invisible prompt. Clearing both sessions
	-- also invalidates delayed preview callbacks through their identity check.
	prompts[player] = nil
	exams[player] = nil
end

function StudyService.snapshot(player: Player, profile: any): any
	local subject = Constants.STUDY.SUBJECT
	return {
		subject = subject,
		readiness = readiness(profile),
		skillReady = hasSkillRequirement(profile),
		examReady = examReady(player, profile),
		attempts = profile.examAttempts[subject] or 0,
		certificationOrder = profile.certifications[subject] or 0,
		reviewRemaining = reviewRemaining[player] or 0,
		focusExpiresAt = focusExpiresAt(profile),
		factId = currentFact(player),
	}
end

function StudyService.init()
	eventRemote = Remotes.event("Study", "Event")
	Remotes.event("Study", "Page").OnServerEvent:Connect(onPage)
	Remotes.event("Study", "Answer").OnServerEvent:Connect(onAnswer)
	Remotes.event("Study", "SitExam").OnServerEvent:Connect(onSitExam)
	Remotes.event("Study", "Close").OnServerEvent:Connect(onClose)

	Players.PlayerRemoving:Connect(function(player)
		pageCounts[player] = nil
		lastPages[player] = nil
		lastQuestions[player] = nil
		lastFacts[player] = nil
		prompts[player] = nil
		exams[player] = nil
		reviewRemaining[player] = nil
		randoms[player] = nil
	end)
end

return StudyService

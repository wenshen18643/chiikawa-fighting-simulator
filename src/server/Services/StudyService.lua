--[[
	Server-authoritative study loop: pages, quick recall, and the readiness bar.

	The client only reports two intentions: a page was completed, or an offered
	plant was chosen. Question order, progress and the focus buff live here.

	Being certified is NOT here. Studying raises Exam Prep and fills its
	readiness bar; ExamService decides what that bar is worth.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local ChiikawaFacts = require(Shared.Modules.Config.ChiikawaFacts)
local Constants = require(Shared.Modules.Constants)
local ExamQuestions = require(Shared.Modules.Config.ExamQuestions)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)

local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local SkillService = require(script.Parent.SkillService)

local StudyService = {}

local SUBJECT = "examprep"

type Prompt = {
	questionId: string,
	factId: number?,
	options: { string },
	phase: "preview" | "answer" | "locked",
}

local pageCounts: { [Player]: number } = {}
local lastPages: { [Player]: number } = {}
local lastQuestions: { [Player]: string } = {}
local lastFacts: { [Player]: number } = {}
local prompts: { [Player]: Prompt } = {}
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
			boost.skill = SUBJECT
			boost.expiresAt = expiresAt
			return expiresAt
		end
	end
	table.insert(profile.boosts, {
		id = "study_focus",
		multiplier = Constants.STUDY.FOCUS_BUFF_MULTIPLIER,
		skill = SUBJECT,
		expiresAt = expiresAt,
	})
	return expiresAt
end

local function awardPage(player: Player, profile: any): BigNumber.BigNum
	local gain = BigNumber.mulNumber(Formulas.gainMultiplier(profile, SUBJECT), Constants.STUDY.PAGE_BASE_GAIN)
	SkillService.award(player, profile, SUBJECT, gain)
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

function StudyService.readiness(profile: any): number
	local value = profile.studyProgress[SUBJECT]
	return if type(value) == "number" then math.clamp(value, 0, 1) else 0
end

function StudyService.spendReadiness(profile: any)
	profile.studyProgress[SUBJECT] = 0
end

local function sendStudyQuestion(player: Player, profile: any, pageFactId: number?)
	if prompts[player] then
		return
	end

	local questionId = pickQuestion(player)
	local factId = pageFactId or pickFact(player)
	local prompt: Prompt = {
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
		readiness = StudyService.readiness(profile),
	})

	task.delay(Constants.STUDY.PREVIEW_DURATION, function()
		if prompts[player] ~= prompt or not player:IsDescendantOf(Players) then
			return
		end
		prompt.phase = "answer"
		eventRemote:FireClient(player, {
			kind = "question",
			questionId = prompt.questionId,
			options = prompt.options,
			helper = helperFor(player, profile, prompt),
			readiness = StudyService.readiness(profile),
		})
	end)
end

local function onPage(player: Player)
	local profile = DataService.get(player)
	if not profile or prompts[player] then
		return
	end
	if Skills.canonicalize(profile.selectedSkill or "") ~= SUBJECT then
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
	local before = StudyService.readiness(profile)
	local gain = if correct then Constants.STUDY.CORRECT_PROGRESS else Constants.STUDY.LEARNING_PROGRESS
	profile.studyProgress[SUBJECT] = math.clamp(before + gain, 0, 1)
	local buffAwarded = correct and rngFor(player):NextNumber() <= Constants.STUDY.FOCUS_BUFF_CHANCE
	local buffExpiresAt = if buffAwarded then grantFocus(profile) else focusExpiresAt(profile)
	prompts[player] = nil

	eventRemote:FireClient(player, {
		kind = "feedback",
		correct = correct,
		selectedId = optionId,
		correctId = prompt.questionId,
		readiness = StudyService.readiness(profile),
		buffAwarded = buffAwarded,
		focusExpiresAt = buffExpiresAt,
	})

	if before < 1 and StudyService.readiness(profile) >= 1 then
		NotifyService.send(player, "Your notes are ready. The Exam Hall desk is in Town.", "unlock")
	end
end

local function onClose(player: Player)
	-- A closed book cannot retain an invisible prompt. Clearing the session also
	-- invalidates delayed preview callbacks through their identity check.
	prompts[player] = nil
end

function StudyService.snapshot(player: Player, profile: any): any
	return {
		subject = SUBJECT,
		readiness = StudyService.readiness(profile),
		attempts = profile.examAttempts[SUBJECT] or 0,
		certificationOrder = profile.certifications[SUBJECT] or 0,
		focusExpiresAt = focusExpiresAt(profile),
		factId = currentFact(player),
	}
end

function StudyService.init()
	eventRemote = Remotes.event("Study", "Event")
	Remotes.event("Study", "Page").OnServerEvent:Connect(onPage)
	Remotes.event("Study", "Answer").OnServerEvent:Connect(onAnswer)
	Remotes.event("Study", "Close").OnServerEvent:Connect(onClose)

	Players.PlayerRemoving:Connect(function(player)
		pageCounts[player] = nil
		lastPages[player] = nil
		lastQuestions[player] = nil
		lastFacts[player] = nil
		prompts[player] = nil
		randoms[player] = nil
	end)
end

return StudyService

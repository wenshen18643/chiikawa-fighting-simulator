local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Certifications = require(Shared.Modules.Config.Certifications)
local ExamQuestions = require(Shared.Modules.Config.ExamQuestions)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local UI = require(Shared.UI)

local WorkController = require(script.Parent.Parent.Controllers.WorkController)

local ExamCounter = {}

local ROW_HEIGHT = 96
local ROW_TALL = 136
local GAP = 10

local screen: ScreenGui
local scrim: Frame
local panel: Frame
local setOpen: (boolean) -> ()
local capLabel: TextLabel
local list: ScrollingFrame
local quiz: Frame

local sitRemote: RemoteEvent
local answerRemote: RemoteEvent
local closeRemote: RemoteEvent

local isOpen = false
local quizLocked = false
local currentQuestion: any = nil

local function accentFor(skillId: string): Color3
	local definition = Skills.get(skillId)
	return (definition and definition.color) or UI.color.leaf
end

local function nameFor(skillId: string): string
	local definition = Skills.get(skillId)
	return (definition and definition.name) or skillId
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function setPanelMode(showQuiz: boolean)
	quiz.Visible = showQuiz
	list.Visible = not showQuiz
	capLabel.Visible = not showQuiz
end

local function progressOf(row: any): number
	local current = math.max(BigNumber.log10(row.current), 0)
	local target = BigNumber.log10(row.requirement)
	local floor = math.max(target - 1, 0)
	if target <= floor then
		return 1
	end
	return math.clamp((current - floor) / (target - floor), 0, 1)
end

local function buildRow(row: any, index: number)
	local accent = accentFor(row.skillId)
	local tall = #row.items > 0

	local card = UI.card(list, row.skillId, {
		surface = "sunken",
		radius = UI.radius.chip,
		zIndex = list.ZIndex + 1,
		stroke = false,
	})
	card.Size = UDim2.new(1, -4, 0, if tall then ROW_TALL else ROW_HEIGHT)
	card.LayoutOrder = index
	UI.stroke(card, if row.ready then accent else UI.color.line, UI.Theme.stroke.base)

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.Position = UDim2.fromOffset(12, 12)
	disc.Size = UDim2.fromOffset(46, 46)
	disc.BackgroundColor3 = accent
	disc.BackgroundTransparency = 0.82
	disc.BorderSizePixel = 0
	disc.ZIndex = card.ZIndex + 1
	disc.Parent = card
	UI.corner(disc, UI.radius.pill)
	UI.stroke(disc, accent, UI.Theme.stroke.base)

	UI.skillGlyph(disc, row.skillId, {
		color = accent,
		extent = UDim2.fromOffset(24, 24),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		zIndex = card.ZIndex + 2,
	})

	UI.label(card, "Name", {
		text = nameFor(row.skillId):upper(),
		font = UI.font.display,
		size = UI.text.body,
		color = UI.color.ink,
		extent = UDim2.new(1, -190, 0, 20),
		position = UDim2.fromOffset(68, 12),
		zIndex = card.ZIndex + 1,
	})

	UI.label(card, "Grades", {
		text = `{row.grade}  →  {row.nextGrade}`,
		font = UI.font.bold,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -190, 0, 16),
		position = UDim2.fromOffset(68, 32),
		zIndex = card.ZIndex + 1,
	})

	UI.label(card, "Multiplier", {
		text = `x{string.format("%.2f", row.multiplier)}  →  x{string.format("%.2f", row.nextMultiplier)}`,
		font = UI.font.bold,
		size = UI.text.caption,
		color = accent,
		extent = UDim2.new(1, -190, 0, 16),
		position = UDim2.fromOffset(68, 48),
		zIndex = card.ZIndex + 1,
	})

	local track, fill = UI.bar(card, "Progress", accent)
	track.Size = UDim2.new(1, -206, 0, 6)
	track.Position = UDim2.fromOffset(68, 70)
	track.ZIndex = card.ZIndex + 1
	fill.Size = UDim2.fromScale(if row.capped then 0 else progressOf(row), 1)

	UI.label(card, "Reason", {
		text = if row.ready
			then `Ready. {BigNumber.toString(row.current)} / {BigNumber.toString(row.requirement)}`
			else row.reason,
		font = UI.font.light,
		size = UI.text.caption,
		color = if row.ready then accent else UI.color.inkFaint,
		wrapped = true,
		extent = UDim2.new(1, -206, 0, 16),
		position = UDim2.fromOffset(68, 78),
		zIndex = card.ZIndex + 1,
	})

	for itemIndex, item in row.items do
		local enough = item.have >= item.need
		UI.chip(card, `Item_{item.id}`, {
			text = `{item.name}  {item.have}/{item.need}`,
			color = if enough then UI.color.paperRaised else UI.color.paperSunken,
			textColor = if enough then accent else UI.color.inkFaint,
			textSize = UI.text.caption,
			extent = UDim2.fromOffset(132, 24),
			position = UDim2.fromOffset(68 + (itemIndex - 1) * 138, 100),
			zIndex = card.ZIndex + 1,
		})
	end

	UI.button(card, "Sit", {
		text = if row.ready then (if row.quizzed then "SIT QUIZ" else "CERTIFY") else "LOCKED",
		textSize = UI.text.caption,
		color = if row.ready then accent else UI.color.paperSunken,
		textColor = if row.ready then UI.color.paperDeep else UI.color.inkFaint,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		extent = UDim2.fromOffset(110, 34),
		zIndex = card.ZIndex + 2,
		states = row.ready,
		onActivated = if row.ready
			then function()
				sitRemote:FireServer(row.skillId)
			end
			else nil,
	})
end

local function canvasHeight(rows: { any }, extra: number): number
	local total = extra
	for _, row in rows do
		total += (if #row.items > 0 then ROW_TALL else ROW_HEIGHT) + GAP
	end
	return total
end

local function renderRows(payload: any)
	setPanelMode(false)
	clear(list)

	capLabel.Text = `Exam Prep {Certifications.describe(payload.cap or 0)}  ·  every other grade caps here`

	for index, row in payload.rows do
		buildRow(row, index)
	end

	list.CanvasSize = UDim2.fromOffset(0, canvasHeight(payload.rows, 0))
end

local function renderQuiz(payload: any, selectedId: string?, correctId: string?, locked: boolean)
	setPanelMode(true)
	clear(quiz)
	quizLocked = locked

	local definition = ExamQuestions.get(payload.questionId)
	if not definition then
		return
	end
	local accent = accentFor(payload.skillId)

	UI.label(quiz, "Eyebrow", {
		text = `{nameFor(payload.skillId):upper()} EXAM  ·  {payload.index}/{payload.total}`,
		font = UI.font.bold,
		size = UI.text.caption,
		color = accent,
		extent = UDim2.new(1, 0, 0, 16),
		zIndex = quiz.ZIndex + 1,
	})

	UI.label(quiz, "Clue", {
		text = definition.clue,
		font = UI.font.display,
		size = UI.text.title,
		color = UI.color.ink,
		wrapped = true,
		extent = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, 22),
		zIndex = quiz.ZIndex + 1,
	})

	for index, optionId in payload.options do
		local option = ExamQuestions.get(optionId)
		if not option then
			continue
		end

		local chosen = optionId == selectedId
		local right = optionId == correctId
		local surface = if not locked
			then UI.color.paperRaised
			elseif right then UI.color.leaf
			elseif chosen then UI.color.blush
			else UI.color.paperSunken

		local button = Instance.new("TextButton")
		button.Name = optionId
		button.Text = ""
		button.AutoButtonColor = false
		button.Active = not locked
		button.BackgroundColor3 = surface
		button.BackgroundTransparency = if locked and not right and not chosen then 0.4 else 0
		button.BorderSizePixel = 0
		button.Position = UDim2.new(0, 0, 0, 84 + (index - 1) * 74)
		button.Size = UDim2.new(1, 0, 0, 66)
		button.ZIndex = quiz.ZIndex + 1
		button.Parent = quiz
		UI.corner(button, UI.radius.chip)
		UI.stroke(button, if locked and right then UI.color.leafDeep else UI.color.line, UI.Theme.stroke.base)

		local diagram = Instance.new("Frame")
		diagram.Name = "Diagram"
		diagram.BackgroundTransparency = 1
		diagram.Position = UDim2.fromOffset(8, 4)
		diagram.Size = UDim2.fromOffset(58, 58)
		diagram.ZIndex = quiz.ZIndex + 2
		diagram.Parent = button
		UI.plant(diagram, option, quiz.ZIndex + 3)

		UI.label(button, "Name", {
			text = option.name,
			font = UI.font.bold,
			size = UI.text.body,
			color = UI.color.ink,
			extent = UDim2.new(1, -84, 0, 22),
			position = UDim2.fromOffset(74, 12),
			zIndex = quiz.ZIndex + 4,
		})
		UI.label(button, "Hint", {
			text = if locked and right
				then "correct plant"
				elseif locked and chosen then "your answer"
				else "choose this plant",
			font = UI.font.light,
			size = UI.text.caption,
			color = UI.color.inkSoft,
			extent = UDim2.new(1, -84, 0, 16),
			position = UDim2.fromOffset(74, 34),
			zIndex = quiz.ZIndex + 4,
		})

		button.Activated:Connect(function()
			if quizLocked then
				return
			end
			quizLocked = true
			answerRemote:FireServer(optionId)
		end)
	end
end

local function renderResult(payload: any)
	setPanelMode(false)
	clear(list)

	local accent = accentFor(payload.skillId)
	local heading = UI.card(list, "Result", {
		surface = "sunken",
		radius = UI.radius.chip,
		zIndex = list.ZIndex + 1,
		stroke = false,
	})
	heading.Size = UDim2.new(1, -4, 0, 96)
	heading.LayoutOrder = 0
	UI.stroke(heading, if payload.passed then accent else UI.color.line, UI.Theme.stroke.heavy)

	UI.label(heading, "Verdict", {
		text = if payload.passed then "Certified!" else "Almost there",
		font = UI.font.display,
		size = UI.text.title,
		color = if payload.passed then accent else UI.color.inkSoft,
		extent = UDim2.new(1, -24, 0, 26),
		position = UDim2.fromOffset(12, 12),
		zIndex = heading.ZIndex + 1,
	})
	local passedText = if payload.skillId == Certifications.CAP_SKILL
		then `{nameFor(payload.skillId)} {payload.grade}. Every other grade can now reach {Certifications.describe(payload.cap or 0)}.`
		else `{nameFor(payload.skillId)} {payload.grade}. Every press in it earns more from here.`

	UI.label(heading, "Detail", {
		text = if payload.passed
			then passedText
			else `{payload.correct} of {payload.total} right. Review {payload.review or 0} card(s), then try again.`,
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		wrapped = true,
		extent = UDim2.new(1, -24, 0, 40),
		position = UDim2.fromOffset(12, 42),
		zIndex = heading.ZIndex + 1,
	})

	for index, row in payload.rows do
		buildRow(row, index)
	end

	list.CanvasSize = UDim2.fromOffset(0, canvasHeight(payload.rows, 96 + GAP))
end

function ExamCounter.setOpen(open: boolean)
	setOpen(open)
end

function ExamCounter.build(parent: Instance)
	scrim, panel, setOpen = UI.modal(parent, "ExamCounter", {
		extent = UDim2.fromScale(0.62, 0.82),
		zIndex = 32,
		onToggled = function(open)
			isOpen = open
			WorkController.setInputLocked("exam-counter", open)
			if not open then
				currentQuestion = nil
				closeRemote:FireServer()
			end
		end,
	})
	UI.padding(panel, UI.space.loose)

	UI.label(panel, "Title", {
		text = "Exam Hall",
		font = UI.font.display,
		size = UI.text.display,
		extent = UDim2.new(1, -120, 0, 32),
	})

	capLabel = UI.label(panel, "Cap", {
		text = "",
		font = UI.font.bold,
		size = UI.text.caption,
		color = UI.color.inkFaint,
		extent = UDim2.new(1, -120, 0, 16),
		position = UDim2.fromOffset(0, 34),
	})

	UI.button(panel, "Close", {
		text = "CLOSE",
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 2),
		extent = UDim2.fromOffset(88, 28),
		zIndex = panel.ZIndex + 1,
		onActivated = function()
			ExamCounter.setOpen(false)
		end,
	})

	list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.Position = UDim2.fromOffset(0, 60)
	list.Size = UDim2.new(1, 0, 1, -60)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = UI.color.line
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = panel.ZIndex + 1
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = list

	quiz = Instance.new("Frame")
	quiz.Name = "Quiz"
	quiz.Position = UDim2.fromOffset(0, 60)
	quiz.Size = UDim2.new(1, 0, 1, -60)
	quiz.BackgroundTransparency = 1
	quiz.Visible = false
	quiz.ZIndex = panel.ZIndex + 1
	quiz.Parent = panel

	return scrim
end

function ExamCounter.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "ExamCounter"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 13
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	sitRemote = Remotes.event("Exam", "Sit")
	answerRemote = Remotes.event("Exam", "Answer")
	closeRemote = Remotes.event("Exam", "Close")

	ExamCounter.build(screen)

	Remotes.event("Exam", "Open").OnClientEvent:Connect(function(payload)
		renderRows(payload)
		if not isOpen then
			ExamCounter.setOpen(true)
		end
	end)

	Remotes.event("Exam", "Event").OnClientEvent:Connect(function(payload)
		if payload.kind == "question" then
			currentQuestion = payload
			renderQuiz(payload, nil, nil, false)
		elseif payload.kind == "feedback" and currentQuestion then
			renderQuiz(currentQuestion, payload.selectedId, payload.correctId, true)
		elseif payload.kind == "result" then
			currentQuestion = nil
			renderResult(payload)
		end
	end)
end

return ExamCounter

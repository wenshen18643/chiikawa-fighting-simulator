--[[
	The open-book Study & Recall interface.

	Most of the game uses dark arcade panels. This one deliberate exception is a
	bright paper booklet inside the same heavy outline: the UI becomes the prop
	the character is holding. All plants are drawn from Frames, so there are no
	image uploads and every option remains crisp on phone screens.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local ChiikawaFacts = require(Shared.Modules.Config.ChiikawaFacts)
local ExamQuestions = require(Shared.Modules.Config.ExamQuestions)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)
local UI = require(Shared.UI)

local StateController = require(script.Parent.Parent.Controllers.StateController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)

local StudySession = {}

local BOOK_PAPER = Color3.fromRGB(255, 248, 222)
local BOOK_PAPER_DEEP = Color3.fromRGB(246, 229, 190)
local BOOK_INK = Color3.fromRGB(61, 48, 55)
local BOOK_PENCIL = Color3.fromRGB(255, 138, 226)
local BOOK_GREEN = Color3.fromRGB(104, 198, 91)
local BOOK_RED = Color3.fromRGB(222, 92, 96)
local BOOK_GOLD = Color3.fromRGB(238, 183, 62)

local screen: ScreenGui
local bookmark: Frame
local bookmarkFill: Frame
local bookmarkTitle: TextLabel
local bookmarkDetail: TextLabel
local examButton: TextButton
local scrim: TextButton
local book: Frame
local leftPage: Frame
local rightPage: Frame
local seam: Frame
local closeButton: TextButton

local pageRemote: RemoteEvent
local answerRemote: RemoteEvent
local sitExamRemote: RemoteEvent
local closeRemote: RemoteEvent

local modalOpen = false
local currentQuestionPayload: any = nil
local optionButtons: { [string]: TextButton } = {}
local renderSerial = 0
local viewMode = "closed"
local dismissed = false
local pageNumber = 0
local latestStudy: any = nil
local readingPageLabel: TextLabel? = nil
local readingGainLabel: TextLabel? = nil
local readingFactLabel: TextLabel? = nil
local readingFocusLabel: TextLabel? = nil
local readingReadinessFill: Frame? = nil
local readingReadinessLabel: TextLabel? = nil

local function textLabel(parent: Instance, name: string, config: { [string]: any }): TextLabel
	local label = UI.label(parent, name, {
		text = config.text or "",
		font = config.font or UI.font.body,
		size = config.size or UI.text.body,
		color = config.color or BOOK_INK,
		align = config.align or Enum.TextXAlignment.Left,
		wrapped = config.wrapped,
		position = config.position,
		extent = config.extent,
		zIndex = config.zIndex or 43,
		scaled = config.scaled,
	})
	label.TextYAlignment = config.verticalAlign or Enum.TextYAlignment.Center
	return label
end

local function clearPage(page: Frame)
	for _, child in page:GetChildren() do
		child:Destroy()
	end
end

local function setModalOpen(open: boolean)
	modalOpen = open
	scrim.Visible = open
	WorkController.setInputLocked("study-session", open)
	if open then
		bookmark.Visible = false
	else
		viewMode = "closed"
	end
end

local LEAF_ANGLES = {
	[1] = { 0 },
	[2] = { -48, 48 },
	[3] = { -62, 0, 62 },
	[4] = { -72, -24, 24, 72 },
}

local function drawPlant(parent: Instance, definition: any, zIndex: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = `Plant_{definition.id}`
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = zIndex
	holder.Parent = parent

	local ground = Instance.new("Frame")
	ground.Name = "Ground"
	ground.AnchorPoint = Vector2.new(0.5, 0.5)
	ground.Position = UDim2.fromScale(0.5, 0.83)
	ground.Size = UDim2.fromScale(0.55, 0.08)
	ground.BackgroundColor3 = BOOK_PAPER_DEEP
	ground.BorderSizePixel = 0
	ground.ZIndex = zIndex
	ground.Parent = holder
	UI.corner(ground, 999)

	local stem = Instance.new("Frame")
	stem.Name = "Stem"
	stem.AnchorPoint = Vector2.new(0.5, 1)
	stem.Position = UDim2.fromScale(0.5, 0.82)
	stem.Size = UDim2.fromScale(0.045, 0.42)
	stem.BackgroundColor3 = Color3.fromRGB(74, 144, 72)
	stem.BorderSizePixel = 0
	stem.ZIndex = zIndex + 1
	stem.Parent = holder
	UI.corner(stem, 999)

	local angles = LEAF_ANGLES[definition.leafCount] or LEAF_ANGLES[2]
	for index, angle in angles do
		local leaf = Instance.new("Frame")
		leaf.Name = `Leaf_{index}`
		leaf.AnchorPoint = Vector2.new(0.5, 0.5)
		local radians = math.rad(angle)
		leaf.Position = UDim2.fromScale(0.5 + math.sin(radians) * 0.21, 0.57 - math.cos(radians) * 0.08)
		leaf.Size = if definition.leafShape == "narrow"
			then UDim2.fromScale(0.13, 0.34)
			else UDim2.fromScale(0.3, 0.18)
		leaf.Rotation = angle
		leaf.BackgroundColor3 = definition.leafColor
		leaf.BorderSizePixel = 0
		leaf.ZIndex = zIndex + 2
		leaf.Parent = holder
		UI.corner(leaf, 999)
		UI.stroke(leaf, BOOK_INK, 1.5)

		if definition.marking ~= "plain" and definition.marking ~= "bud" then
			local mark = Instance.new("Frame")
			mark.Name = "Mark"
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromScale(0.5, 0.5)
			mark.Size = if definition.marking == "spots"
				then UDim2.fromScale(0.22, 0.34)
				else UDim2.fromScale(0.16, 0.75)
			mark.Rotation = if definition.marking == "thorns" then 45 else 0
			mark.BackgroundColor3 = definition.accentColor
			mark.BorderSizePixel = 0
			mark.ZIndex = zIndex + 3
			mark.Parent = leaf
			UI.corner(mark, 999)
		end
	end

	if definition.marking == "bud" then
		local bud = Instance.new("Frame")
		bud.Name = "Bud"
		bud.AnchorPoint = Vector2.new(0.5, 0.5)
		bud.Position = UDim2.fromScale(0.5, 0.32)
		bud.Size = UDim2.fromScale(0.22, 0.22)
		bud.BackgroundColor3 = definition.accentColor
		bud.BorderSizePixel = 0
		bud.ZIndex = zIndex + 3
		bud.Parent = holder
		UI.corner(bud, 999)
		UI.stroke(bud, BOOK_INK, 1.5)
	end

	return holder
end

local function addPageNumber(parent: Frame, text: string)
	textLabel(parent, "PageNumber", {
		text = text,
		font = UI.font.bold,
		size = UI.text.caption,
		color = Color3.fromRGB(143, 120, 112),
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0.5, -45, 1, -28),
		extent = UDim2.fromOffset(90, 18),
		zIndex = 44,
	})
end

local function addPlantStudyCard(questionId: string)
	local definition = ExamQuestions.get(questionId)
	if not definition then
		return
	end

	textLabel(leftPage, "Eyebrow", {
		text = "KUSATORI FIELD NOTE",
		font = UI.font.bold,
		size = UI.text.caption,
		color = BOOK_GREEN,
		position = UDim2.fromScale(0.08, 0.06),
		extent = UDim2.fromScale(0.84, 0.08),
	})
	textLabel(leftPage, "PlantName", {
		text = definition.name,
		font = UI.font.display,
		size = UI.text.display,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromScale(0.08, 0.14),
		extent = UDim2.fromScale(0.84, 0.11),
	})

	local plant = Instance.new("Frame")
	plant.Name = "Diagram"
	plant.BackgroundTransparency = 1
	plant.Position = UDim2.fromScale(0.2, 0.27)
	plant.Size = UDim2.fromScale(0.6, 0.55)
	plant.ZIndex = 43
	plant.Parent = leftPage
	drawPlant(plant, definition, 44)
	addPageNumber(leftPage, "LOOK")
end

local function addLesson(factId: number?)
	local fact = ChiikawaFacts.get(factId) or "Chiikawa's world is full of kind friends and surprising challenges."

	textLabel(rightPage, "Remember", {
		text = "Chiikawa note",
		font = UI.font.display,
		size = UI.text.title,
		color = BOOK_PENCIL,
		position = UDim2.fromScale(0.1, 0.11),
		extent = UDim2.fromScale(0.8, 0.1),
	})
	local factLabel = textLabel(rightPage, "Lesson", {
		text = fact,
		font = UI.font.bold,
		size = UI.text.title,
		scaled = true,
		wrapped = true,
		verticalAlign = Enum.TextYAlignment.Top,
		position = UDim2.fromScale(0.1, 0.27),
		extent = UDim2.fromScale(0.8, 0.38),
	})
	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MinTextSize = UI.text.small
	textSizeConstraint.MaxTextSize = UI.text.title
	textSizeConstraint.Parent = factLabel
	textLabel(rightPage, "Instruction", {
		text = "The page will turn in a moment...",
		font = UI.font.light,
		size = UI.text.small,
		color = Color3.fromRGB(128, 105, 102),
		wrapped = true,
		position = UDim2.fromScale(0.1, 0.68),
		extent = UDim2.fromScale(0.8, 0.12),
	})
	addPageNumber(rightPage, "A LITTLE CHIIKAWA FACT")
end

local function updateReadingStats()
	local study = latestStudy
	if not study then
		return
	end
	local readiness = math.clamp(study.readiness or 0, 0, 1)
	if readingReadinessFill and readingReadinessFill.Parent then
		readingReadinessFill.Size = UDim2.fromScale(readiness, 1)
	end
	if readingReadinessLabel and readingReadinessLabel.Parent then
		readingReadinessLabel.Text = `GRADE 5 READINESS  {math.floor(readiness * 100 + 0.5)}%`
	end
	if readingFocusLabel and readingFocusLabel.Parent then
		local remaining = math.max(0, (study.focusExpiresAt or 0) - os.time())
		readingFocusLabel.Text = if remaining > 0 then `FOCUS x2  •  {remaining}s` else "10% chance to find a field note"
		readingFocusLabel.TextColor3 = if remaining > 0 then BOOK_GOLD else Color3.fromRGB(128, 105, 102)
	end
end

local function animatePageFlip()
	local sheet = Instance.new("Frame")
	sheet.Name = "TurningPage"
	sheet.AnchorPoint = Vector2.new(0, 0)
	sheet.Position = UDim2.fromScale(0.5, 0)
	sheet.Size = UDim2.fromScale(0.5, 1)
	sheet.BackgroundColor3 = Color3.fromRGB(255, 253, 240)
	sheet.BorderSizePixel = 0
	sheet.ZIndex = 52
	sheet.Parent = book
	UI.corner(sheet, 20)

	local fold = Instance.new("Frame")
	fold.AnchorPoint = Vector2.new(1, 0)
	fold.Position = UDim2.fromScale(1, 0)
	fold.Size = UDim2.new(0, 18, 1, 0)
	fold.BackgroundColor3 = BOOK_PAPER_DEEP
	fold.BorderSizePixel = 0
	fold.ZIndex = 53
	fold.Parent = sheet

	local closeTween = UI.motion.play(sheet, UI.motion.snap, {
		Position = UDim2.fromScale(0.49, 0),
		Size = UDim2.fromScale(0.025, 1),
	})
	closeTween.Completed:Connect(function()
		if not sheet.Parent then
			return
		end
		sheet.AnchorPoint = Vector2.new(1, 0)
		sheet.Position = UDim2.fromScale(0.5, 0)
		local openTween = UI.motion.play(sheet, UI.motion.snap, {
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.5, 1),
		})
		openTween.Completed:Connect(function()
			sheet:Destroy()
		end)
	end)
end

local function showPageGain(gain: any)
	if not modalOpen or dismissed or not BigNumber.isValid(gain) then
		return
	end

	local compact = screen.AbsoluteSize.X < 650
	local label = UI.label(book, `PageGain_{pageNumber}`, {
		text = `+{BigNumber.toString(gain)}`,
		font = UI.font.display,
		size = UI.text.title,
		color = BOOK_PENCIL,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromOffset(210, 56),
		anchor = Vector2.new(0.5, 0.5),
		position = if compact then UDim2.fromScale(0.5, 0.72) else UDim2.fromScale(0.75, 0.55),
		zIndex = 60,
	})
	label.TextStrokeColor3 = BOOK_PAPER
	label.TextStrokeTransparency = 0.15
	label.TextTransparency = 1
	label.TextSize = math.floor(UI.text.title * 0.45)

	UI.motion.to(label, UI.motion.pop, {
		TextSize = UI.text.title,
		TextTransparency = 0,
	})
	task.delay(0.12, function()
		if not label.Parent then
			return
		end
		local rise = UI.motion.play(label, UI.motion.riseOut, {
			Position = label.Position - UDim2.fromOffset(0, 72),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		rise.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

local function renderReading()
	viewMode = "reading"
	currentQuestionPayload = nil
	closeButton.Visible = true
	clearPage(leftPage)
	clearPage(rightPage)
	optionButtons = {}

	textLabel(leftPage, "Eyebrow", {
		text = "EXAM PREP",
		font = UI.font.bold,
		size = UI.text.caption,
		color = BOOK_PENCIL,
		position = UDim2.fromScale(0.3, 0.07),
		extent = UDim2.fromScale(0.62, 0.08),
	})
	local readingFact = ChiikawaFacts.get(latestStudy and latestStudy.factId)
		or "Chiikawa's world is full of kind friends and surprising challenges."
	readingFactLabel = textLabel(leftPage, "Fact", {
		text = readingFact,
		font = UI.font.display,
		size = UI.text.display,
		scaled = true,
		wrapped = true,
		verticalAlign = Enum.TextYAlignment.Top,
		position = UDim2.fromScale(0.08, 0.17),
		extent = UDim2.fromScale(0.84, 0.2),
	})
	local headlineSizeConstraint = Instance.new("UITextSizeConstraint")
	headlineSizeConstraint.MinTextSize = UI.text.small
	headlineSizeConstraint.MaxTextSize = UI.text.display
	headlineSizeConstraint.Parent = readingFactLabel
	readingReadinessLabel = textLabel(leftPage, "Readiness", {
		text = "GRADE 5 READINESS  0%",
		font = UI.font.bold,
		size = UI.text.caption,
		color = BOOK_GREEN,
		position = UDim2.fromScale(0.08, 0.45),
		extent = UDim2.fromScale(0.84, 0.08),
	})
	local readinessTrack = Instance.new("Frame")
	readinessTrack.Name = "ReadinessTrack"
	readinessTrack.Position = UDim2.fromScale(0.08, 0.54)
	readinessTrack.Size = UDim2.fromScale(0.84, 0.035)
	readinessTrack.BackgroundColor3 = Color3.fromRGB(215, 199, 168)
	readinessTrack.BorderSizePixel = 0
	readinessTrack.ZIndex = 44
	readinessTrack.Parent = leftPage
	UI.corner(readinessTrack, 999)
	readingReadinessFill = Instance.new("Frame")
	readingReadinessFill.Name = "Fill"
	readingReadinessFill.Size = UDim2.fromScale(0, 1)
	readingReadinessFill.BackgroundColor3 = BOOK_GREEN
	readingReadinessFill.BorderSizePixel = 0
	readingReadinessFill.ZIndex = 45
	readingReadinessFill.Parent = readinessTrack
	UI.corner(readingReadinessFill, 999)

	readingFocusLabel = textLabel(leftPage, "Focus", {
		text = "10% chance to find a field note",
		font = UI.font.bold,
		size = UI.text.small,
		color = Color3.fromRGB(128, 105, 102),
		wrapped = true,
		position = UDim2.fromScale(0.08, 0.62),
		extent = UDim2.fromScale(0.84, 0.1),
	})

	if latestStudy and latestStudy.examReady then
		UI.button(leftPage, "SitExam", {
			text = "Sit Grade 5 exam",
			font = UI.font.bold,
			textSize = UI.text.small,
			textColor = BOOK_INK,
			color = Color3.fromRGB(204, 240, 178),
			extent = UDim2.fromScale(0.7, 0.11),
			position = UDim2.fromScale(0.15, 0.76),
			zIndex = 45,
			stroke = true,
			onActivated = function()
				sitExamRemote:FireServer()
			end,
		})
	end
	addPageNumber(leftPage, "FIELD NOTES")

	readingPageLabel = textLabel(rightPage, "Page", {
		text = `PAGE {pageNumber + 1}`,
		font = UI.font.bold,
		size = UI.text.caption,
		color = Color3.fromRGB(143, 120, 112),
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromScale(0.1, 0.08),
		extent = UDim2.fromScale(0.8, 0.08),
	})

	local flip = Instance.new("TextButton")
	flip.Name = "FlipPage"
	flip.Text = "FLIP PAGE"
	flip.Font = UI.font.display
	flip.TextSize = UI.text.title
	flip.TextColor3 = BOOK_INK
	flip.AutoButtonColor = false
	flip.Position = UDim2.fromScale(0.1, 0.2)
	flip.Size = UDim2.fromScale(0.8, 0.5)
	flip.BackgroundColor3 = Color3.fromRGB(255, 252, 235)
	flip.BorderSizePixel = 0
	flip.ZIndex = 44
	flip.Parent = rightPage
	UI.corner(flip, UI.radius.card)
	UI.stroke(flip, BOOK_PENCIL, 3)
	textLabel(flip, "Hint", {
		text = "Click anywhere on this page",
		font = UI.font.light,
		size = UI.text.small,
		color = Color3.fromRGB(128, 105, 102),
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromScale(0.08, 0.63),
		extent = UDim2.fromScale(0.84, 0.2),
		zIndex = 45,
	})
	readingGainLabel = textLabel(rightPage, "Gain", {
		text = "Each flip earns Exam Prep",
		font = UI.font.bold,
		size = UI.text.small,
		color = BOOK_PENCIL,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromScale(0.1, 0.76),
		extent = UDim2.fromScale(0.8, 0.08),
	})

	local busy = false
	flip.Activated:Connect(function()
		if busy or viewMode ~= "reading" then
			return
		end
		busy = true
		animatePageFlip()
		pageRemote:FireServer()
		task.delay(0.4, function()
			busy = false
		end)
	end)
	updateReadingStats()
end

local function choiceColor(optionId: string, selectedId: string?, correctId: string?, locked: boolean): Color3
	if not locked then
		return Color3.fromRGB(255, 252, 239)
	end
	if optionId == correctId then
		return Color3.fromRGB(214, 244, 194)
	end
	if optionId == selectedId then
		return Color3.fromRGB(255, 211, 207)
	end
	return Color3.fromRGB(238, 228, 206)
end

local function addOption(
	optionId: string,
	index: number,
	crossedOut: string?,
	revealed: string?,
	selectedId: string?,
	correctId: string?,
	locked: boolean
)
	local definition = ExamQuestions.get(optionId)
	if not definition then
		return
	end

	local button = Instance.new("TextButton")
	button.Name = optionId
	button.Text = ""
	button.AutoButtonColor = not locked
	button.Active = not locked and optionId ~= crossedOut
	button.Position = UDim2.fromScale(0.07, 0.12 + (index - 1) * 0.27)
	button.Size = UDim2.fromScale(0.86, 0.22)
	button.BackgroundColor3 = choiceColor(optionId, selectedId, correctId, locked)
	button.BackgroundTransparency = if optionId == crossedOut then 0.55 else 0
	button.BorderSizePixel = 0
	button.ZIndex = 44
	button.Parent = rightPage
	UI.corner(button, UI.radius.chip)
	UI.stroke(button, if optionId == revealed then BOOK_GOLD else BOOK_INK, if optionId == revealed then 3 else 2)

	local diagram = Instance.new("Frame")
	diagram.Name = "Diagram"
	diagram.BackgroundTransparency = 1
	diagram.Position = UDim2.fromScale(0.02, 0.08)
	diagram.Size = UDim2.fromScale(0.25, 0.84)
	diagram.ZIndex = 45
	diagram.Parent = button
	drawPlant(diagram, definition, 46)

	textLabel(button, "Name", {
		text = definition.name,
		font = UI.font.bold,
		size = UI.text.body,
		position = UDim2.fromScale(0.31, 0.15),
		extent = UDim2.fromScale(0.62, 0.36),
		zIndex = 47,
	})
	textLabel(button, "Choose", {
		text = if optionId == crossedOut then "crossed out"
			elseif locked and optionId == correctId then "correct plant"
			elseif locked and optionId == selectedId then "your answer"
			else "choose this plant",
		font = UI.font.light,
		size = UI.text.caption,
		color = Color3.fromRGB(128, 105, 102),
		position = UDim2.fromScale(0.31, 0.52),
		extent = UDim2.fromScale(0.62, 0.25),
		zIndex = 47,
	})

	if optionId == crossedOut then
		textLabel(button, "Cross", {
			text = "×",
			font = UI.font.display,
			size = 34,
			color = BOOK_RED,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromScale(0.82, 0.22),
			extent = UDim2.fromScale(0.13, 0.56),
			zIndex = 48,
		})
	end

	button.Activated:Connect(function()
		if locked or optionId == crossedOut then
			return
		end
		for _, entry in optionButtons do
			entry.Active = false
			entry.AutoButtonColor = false
		end
		answerRemote:FireServer(optionId)
	end)
	optionButtons[optionId] = button
end

local function renderQuestion(payload: any, selectedId: string?, correctId: string?, locked: boolean)
	viewMode = if payload.mode == "exam" then "exam" else "recall"
	closeButton.Visible = true
	clearPage(leftPage)
	clearPage(rightPage)
	optionButtons = {}

	local definition = ExamQuestions.get(payload.questionId)
	if not definition then
		return
	end

	local exam = payload.mode == "exam"
	textLabel(leftPage, "Eyebrow", {
		text = if exam then `GRADE 5 EXAM  •  {payload.index}/{payload.total}` else "QUICK RECALL",
		font = UI.font.bold,
		size = UI.text.caption,
		color = if exam then BOOK_RED else BOOK_GREEN,
		position = UDim2.fromScale(0.08, 0.07),
		extent = UDim2.fromScale(0.84, 0.08),
	})
	textLabel(leftPage, "Prompt", {
		text = definition.clue,
		font = UI.font.display,
		size = UI.text.title,
		wrapped = true,
		verticalAlign = Enum.TextYAlignment.Top,
		position = UDim2.fromScale(0.08, 0.18),
		extent = UDim2.fromScale(0.84, 0.34),
	})

	local helper = payload.helper
	if helper then
		textLabel(leftPage, "Helper", {
			text = helper.text,
			font = UI.font.bold,
			size = UI.text.small,
			color = if helper.kind == "usagi" then BOOK_GOLD else BOOK_PENCIL,
			wrapped = true,
			verticalAlign = Enum.TextYAlignment.Top,
			position = UDim2.fromScale(0.08, 0.59),
			extent = UDim2.fromScale(0.84, 0.16),
		})
	end

	if locked then
		local wasCorrect = selectedId == correctId
		textLabel(leftPage, "Feedback", {
			text = if wasCorrect then "You remembered!" else "Now it is in your notes.",
			font = UI.font.display,
			size = UI.text.title,
			color = if wasCorrect then BOOK_GREEN else BOOK_PENCIL,
			wrapped = true,
			position = UDim2.fromScale(0.08, 0.55),
			extent = UDim2.fromScale(0.84, 0.18),
		})
	end

	local crossedOut = helper and helper.crossedOut or nil
	local revealed = helper and helper.revealed or nil
	for index, optionId in payload.options do
		addOption(optionId, index, crossedOut, revealed, selectedId, correctId, locked)
	end
	addPageNumber(leftPage, if exam then "ANSWER CAREFULLY" else "TAKE YOUR TIME")
end

local function renderPreview(payload: any)
	viewMode = "preview"
	closeButton.Visible = true
	clearPage(leftPage)
	clearPage(rightPage)
	addPlantStudyCard(payload.questionId)
	addLesson(payload.factId)
end

local function renderResult(payload: any)
	viewMode = "result"
	closeButton.Visible = true
	clearPage(leftPage)
	clearPage(rightPage)
	optionButtons = {}

	textLabel(leftPage, "Eyebrow", {
		text = "KUSATORI GRADE 5",
		font = UI.font.bold,
		size = UI.text.caption,
		color = if payload.passed then BOOK_GREEN else BOOK_PENCIL,
		position = UDim2.fromScale(0.08, 0.12),
		extent = UDim2.fromScale(0.84, 0.08),
	})
	textLabel(leftPage, "Score", {
		text = `{payload.correct} / {payload.total}`,
		font = UI.font.display,
		size = 54,
		color = if payload.passed then BOOK_GREEN else BOOK_INK,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromScale(0.08, 0.27),
		extent = UDim2.fromScale(0.84, 0.22),
	})
	textLabel(leftPage, "Attempt", {
		text = `Attempt {payload.attempts}`,
		font = UI.font.bold,
		size = UI.text.small,
		color = Color3.fromRGB(128, 105, 102),
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromScale(0.08, 0.51),
		extent = UDim2.fromScale(0.84, 0.08),
	})

	textLabel(rightPage, "Result", {
		text = if payload.passed then "You passed!" else "Almost there",
		font = UI.font.display,
		size = UI.text.display,
		color = if payload.passed then BOOK_GREEN else BOOK_PENCIL,
		position = UDim2.fromScale(0.1, 0.14),
		extent = UDim2.fromScale(0.8, 0.12),
	})
	textLabel(rightPage, "Message", {
		text = if payload.passed
			then "Grade 5 doubles your Kusatori gains and raises your wage. Your friends are cheering."
			else `Your readiness is safe. Review {payload.reviewRemaining} cards, then sit the exam again.`,
		font = UI.font.body,
		size = UI.text.body,
		wrapped = true,
		verticalAlign = Enum.TextYAlignment.Top,
		position = UDim2.fromScale(0.1, 0.31),
		extent = UDim2.fromScale(0.8, 0.28),
	})

	UI.button(rightPage, "Continue", {
		text = if payload.passed then "Celebrate" else "Review together",
		font = UI.font.bold,
		textSize = UI.text.body,
		textColor = BOOK_INK,
		color = if payload.passed then Color3.fromRGB(204, 240, 178) else Color3.fromRGB(255, 213, 239),
		extent = UDim2.fromScale(0.72, 0.14),
		position = UDim2.fromScale(0.14, 0.67),
		zIndex = 45,
		stroke = true,
		onActivated = function()
			setModalOpen(false)
		end,
	})
	addPageNumber(leftPage, "RESULT")
	addPageNumber(rightPage, if payload.passed then "GRADE 5" else "TRY AGAIN")
end

local function activeSkill(snapshot: any): string?
	local worksiteId = snapshot.currentWorksite or snapshot.blockedWorksite
	if worksiteId then
		local worksite = Worksites.get(worksiteId)
		if worksite then
			return Skills.canonicalize(worksite.skill)
		end
	end
	return snapshot.selectedSkill and Skills.canonicalize(snapshot.selectedSkill) or nil
end

local function updateBookmark(snapshot: any)
	local study = snapshot.study
	if not study then
		bookmark.Visible = false
		return
	end
	latestStudy = study
	if viewMode == "reading" then
		updateReadingStats()
	end

	local studying = activeSkill(snapshot) == "examprep"
	bookmark.Visible = studying and not modalOpen
	bookmarkFill.Size = UDim2.fromScale(math.clamp(study.readiness or 0, 0, 1), 1)

	if (study.certificationOrder or 0) >= 1 then
		bookmarkTitle.Text = "Kusatori Grade 5 earned"
		bookmarkDetail.Text = "Your field notes paid off."
		examButton.Visible = false
	elseif (study.reviewRemaining or 0) > 0 then
		bookmarkTitle.Text = `Review {study.reviewRemaining} more card(s)`
		bookmarkDetail.Text = "Your readiness is safe. Keep studying."
		examButton.Visible = false
	elseif study.examReady then
		bookmarkTitle.Text = "Grade 5 exam ready"
		bookmarkDetail.Text = "Five questions • four to pass"
		examButton.Visible = true
	elseif (study.readiness or 0) >= 1 and not study.skillReady then
		bookmarkTitle.Text = "Readiness 100%"
		bookmarkDetail.Text = "Practise Kusatori to 100 next."
		examButton.Visible = false
	else
		bookmarkTitle.Text = `Readiness {math.floor((study.readiness or 0) * 100 + 0.5)}%`
		bookmarkDetail.Text = "Turn pages to find the next field note."
		examButton.Visible = false
	end
	local focusRemaining = math.max(0, (study.focusExpiresAt or 0) - os.time())
	if focusRemaining > 0 and not examButton.Visible then
		bookmarkDetail.Text = `Focus x2 active • {focusRemaining}s`
	end
end

local function applyResponsiveLayout()
	local compact = screen.AbsoluteSize.X < 650
	bookmark.Size = if compact then UDim2.fromOffset(216, 92) else UDim2.fromOffset(272, 100)
	bookmark.Position = if compact then UDim2.new(1, -12, 0, 12) else UDim2.new(1, -18, 0.5, -50)

	book.Size = if compact then UDim2.new(1, -24, 1, -48) else UDim2.new(1, -80, 1, -80)
	if compact then
		leftPage.Position = UDim2.fromScale(0, 0)
		leftPage.Size = UDim2.fromScale(1, 0.43)
		rightPage.Position = UDim2.fromScale(0, 0.43)
		rightPage.Size = UDim2.fromScale(1, 0.57)
		seam.Position = UDim2.fromScale(0, 0.43)
		seam.Size = UDim2.new(1, 0, 0, 4)
	else
		leftPage.Position = UDim2.fromScale(0, 0)
		leftPage.Size = UDim2.fromScale(0.5, 1)
		rightPage.Position = UDim2.fromScale(0.5, 0)
		rightPage.Size = UDim2.fromScale(0.5, 1)
		seam.Position = UDim2.fromScale(0.5, 0)
		seam.Size = UDim2.new(0, 4, 1, 0)
	end
end

local function buildBookmark(parent: ScreenGui)
	bookmark = UI.card(parent, "ReadinessBookmark", {
		color = UI.color.paper,
		radius = UI.radius.card,
		zIndex = 20,
		stroke = false,
	})
	bookmark.AnchorPoint = Vector2.new(1, 0)
	UI.padding(bookmark, UI.space.base)
	UI.stroke(bookmark, BOOK_PENCIL, UI.Theme.stroke.heavy)

	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.Position = UDim2.fromOffset(-8, 10)
	ribbon.Size = UDim2.fromOffset(8, 44)
	ribbon.BackgroundColor3 = BOOK_PENCIL
	ribbon.BorderSizePixel = 0
	ribbon.ZIndex = 21
	ribbon.Parent = bookmark
	UI.corner(ribbon, 4)

	bookmarkTitle = UI.label(bookmark, "Title", {
		text = "Readiness 0%",
		font = UI.font.display,
		size = UI.text.body,
		extent = UDim2.new(1, 0, 0, 22),
		zIndex = 22,
	})
	bookmarkDetail = UI.label(bookmark, "Detail", {
		text = "Turn pages to find a field note.",
		font = UI.font.light,
		size = UI.text.caption,
		color = UI.color.inkSoft,
		position = UDim2.fromOffset(0, 24),
		extent = UDim2.new(1, 0, 0, 18),
		zIndex = 22,
	})

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 52)
	track.Size = UDim2.new(1, 0, 0, 9)
	track.BackgroundColor3 = UI.color.line
	track.BorderSizePixel = 0
	track.ZIndex = 22
	track.Parent = bookmark
	UI.corner(track, 999)

	bookmarkFill = Instance.new("Frame")
	bookmarkFill.Name = "Fill"
	bookmarkFill.Size = UDim2.fromScale(0, 1)
	bookmarkFill.BackgroundColor3 = BOOK_PENCIL
	bookmarkFill.BorderSizePixel = 0
	bookmarkFill.ZIndex = 23
	bookmarkFill.Parent = track
	UI.corner(bookmarkFill, 999)

	examButton = UI.button(bookmark, "SitExam", {
		text = "Sit exam",
		textSize = UI.text.small,
		color = BOOK_PENCIL,
		textColor = UI.color.paperDeep,
		extent = UDim2.fromOffset(92, 27),
		position = UDim2.new(1, -92, 1, -27),
		zIndex = 24,
		stroke = true,
		onActivated = function()
			dismissed = false
			examButton.Text = "Opening..."
			examButton.Active = false
			sitExamRemote:FireServer()
			task.delay(1.5, function()
				if examButton then
					examButton.Text = "Sit exam"
					examButton.Active = true
				end
			end)
		end,
	})
	examButton.Visible = false
	bookmark.Visible = false
end

local function buildBook(parent: ScreenGui)
	scrim = Instance.new("TextButton")
	scrim.Name = "StudyScrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.fromRGB(13, 14, 22)
	scrim.BackgroundTransparency = 0.28
	scrim.BorderSizePixel = 0
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Active = true
	scrim.ZIndex = 40
	scrim.Parent = parent

	book = Instance.new("Frame")
	book.Name = "OpenBook"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.5)
	book.BackgroundColor3 = BOOK_PAPER
	book.BorderSizePixel = 0
	book.ZIndex = 41
	book.Parent = scrim
	UI.corner(book, 24)
	UI.stroke(book, UI.color.line, 5)

	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(1400, 900)
	size.MinSize = Vector2.new(300, 330)
	size.Parent = book

	leftPage = Instance.new("Frame")
	leftPage.Name = "LeftPage"
	leftPage.BackgroundColor3 = BOOK_PAPER
	leftPage.BorderSizePixel = 0
	leftPage.ClipsDescendants = true
	leftPage.ZIndex = 42
	leftPage.Parent = book

	rightPage = Instance.new("Frame")
	rightPage.Name = "RightPage"
	rightPage.BackgroundColor3 = Color3.fromRGB(255, 252, 235)
	rightPage.BorderSizePixel = 0
	rightPage.ClipsDescendants = true
	rightPage.ZIndex = 42
	rightPage.Parent = book

	seam = Instance.new("Frame")
	seam.Name = "BookSeam"
	seam.BackgroundColor3 = Color3.fromRGB(212, 190, 155)
	seam.BorderSizePixel = 0
	seam.ZIndex = 49
	seam.Parent = book

	local ribbon = Instance.new("Frame")
	ribbon.Name = "ConfidenceRibbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 0)
	ribbon.Position = UDim2.new(0.82, 0, 1, -8)
	ribbon.Size = UDim2.fromOffset(30, 44)
	ribbon.BackgroundColor3 = BOOK_PENCIL
	ribbon.BorderSizePixel = 0
	ribbon.Rotation = 2
	ribbon.ZIndex = 50
	ribbon.Parent = book
	UI.corner(ribbon, 5)

	closeButton = UI.button(book, "CloseBook", {
		text = "X",
		font = UI.font.display,
		textSize = 25,
		textColor = Color3.new(1, 1, 1),
		color = BOOK_RED,
		extent = UDim2.fromOffset(42, 42),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -14, 0, 14),
		radius = UI.radius.pill,
		zIndex = 61,
		stroke = true,
		onActivated = function()
			dismissed = true
			renderSerial += 1
			currentQuestionPayload = nil
			closeRemote:FireServer()
			setModalOpen(false)
			local snapshot = StateController.snapshot
			if snapshot then
				updateBookmark(snapshot)
			end
		end,
	})
	closeButton.Visible = true

	scrim.Visible = false
end

local function onStudyEvent(payload: any)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	if dismissed then
		return
	end
	if payload.kind == "page" then
		pageNumber = if type(payload.page) == "number" then payload.page else pageNumber + 1
		if latestStudy and type(payload.factId) == "number" then
			latestStudy.factId = payload.factId
		end
		if latestStudy and type(payload.focusExpiresAt) == "number" then
			latestStudy.focusExpiresAt = payload.focusExpiresAt
			latestStudy.readiness = payload.readiness or latestStudy.readiness
			latestStudy.reviewRemaining = payload.reviewRemaining or latestStudy.reviewRemaining
			latestStudy.examReady = payload.examReady == true
		end
		if readingPageLabel and readingPageLabel.Parent then
			readingPageLabel.Text = `PAGE {pageNumber + 1}`
		end
		if readingGainLabel and readingGainLabel.Parent and BigNumber.isValid(payload.gain) then
			readingGainLabel.Text = `+{BigNumber.toString(payload.gain)} Exam Prep`
		end
		if readingFactLabel and readingFactLabel.Parent then
			local fact = ChiikawaFacts.get(payload.factId)
			if fact then
				readingFactLabel.Text = fact
			end
		end
		showPageGain(payload.gain)
		updateReadingStats()
		return
	end
	renderSerial += 1
	local serial = renderSerial
	if payload.kind == "preview" then
		setModalOpen(true)
		renderPreview(payload)
	elseif payload.kind == "question" then
		currentQuestionPayload = payload
		setModalOpen(true)
		renderQuestion(payload, nil, nil, false)
	elseif payload.kind == "feedback" and currentQuestionPayload then
		-- The feedback packet has no option list, so keep the last issued
		-- question payload and layer the authoritative result over it.
		local previous = currentQuestionPayload
		renderQuestion(previous, payload.selectedId, payload.correctId, true)
		if latestStudy and type(payload.focusExpiresAt) == "number" then
			latestStudy.focusExpiresAt = payload.focusExpiresAt
		end
		if payload.buffAwarded then
			local feedback = leftPage:FindFirstChild("Feedback")
			if feedback and feedback:IsA("TextLabel") then
				feedback.Text = "Focused! x2 Exam Prep for 30 seconds."
				feedback.TextColor3 = BOOK_GOLD
			end
		end
		if payload.mode == "study" then
			task.delay(1.25, function()
				if renderSerial == serial then
					renderReading()
				end
			end)
		end
	elseif payload.kind == "result" then
		currentQuestionPayload = nil
		setModalOpen(true)
		renderResult(payload)
	end
end

function StudySession.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "StudySession"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 12
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	pageRemote = Remotes.event("Study", "Page")
	answerRemote = Remotes.event("Study", "Answer")
	sitExamRemote = Remotes.event("Study", "SitExam")
	closeRemote = Remotes.event("Study", "Close")

	buildBookmark(screen)
	buildBook(screen)
	applyResponsiveLayout()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout)

	StateController.onChanged(updateBookmark)
	Remotes.event("Study", "Event").OnClientEvent:Connect(onStudyEvent)
	WorkController.onSelected(function(skillId)
		if Skills.canonicalize(skillId) == "examprep" then
			dismissed = false
			setModalOpen(true)
			renderReading()
		end
	end)

	task.spawn(function()
		while screen.Parent do
			task.wait(0.5)
			if viewMode == "reading" then
				updateReadingStats()
			end
		end
	end)
end

return StudySession

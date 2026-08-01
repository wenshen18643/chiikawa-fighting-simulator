--[[
	Visual field-guide cards. Studied in the book, tested by the Kusatori exam.

	The names are original to this game rather than copied exam questions. Each
	plant has a silhouette, colour and marking that the UI can draw from Frames,
	so the exercise remains readable on every device without image assets.
]]

export type PlantDefinition = {
	id: string,
	name: string,
	clue: string,
	lesson: string,
	leafCount: number,
	leafColor: Color3,
	accentColor: Color3,
	leafShape: "round" | "narrow",
	marking: "plain" | "spots" | "stripe" | "thorns" | "bud",
}

local ExamQuestions = {}

ExamQuestions.ORDER = {
	"roundleaf",
	"dotweed",
	"sunbud",
	"stripegrass",
	"thornsprig",
	"moonbloom",
}

ExamQuestions.DEFINITIONS = {
	roundleaf = {
		id = "roundleaf",
		name = "Roundleaf",
		clue = "Which plant has two round mint leaves and no markings?",
		lesson = "Roundleaf has TWO round mint leaves. Its leaves are plain.",
		leafCount = 2,
		leafColor = Color3.fromRGB(110, 210, 132),
		accentColor = Color3.fromRGB(228, 255, 212),
		leafShape = "round",
		marking = "plain",
	},
	dotweed = {
		id = "dotweed",
		name = "Dotweed",
		clue = "Which plant has three blue leaves with pale spots?",
		lesson = "Dotweed has THREE blue leaves. Look for its pale spots.",
		leafCount = 3,
		leafColor = Color3.fromRGB(92, 168, 220),
		accentColor = Color3.fromRGB(220, 245, 255),
		leafShape = "round",
		marking = "spots",
	},
	sunbud = {
		id = "sunbud",
		name = "Sunbud",
		clue = "Which plant carries a golden bud above two yellow leaves?",
		lesson = "Sunbud has TWO yellow leaves and one bright golden bud.",
		leafCount = 2,
		leafColor = Color3.fromRGB(225, 190, 74),
		accentColor = Color3.fromRGB(255, 221, 82),
		leafShape = "round",
		marking = "bud",
	},
	stripegrass = {
		id = "stripegrass",
		name = "Stripegrass",
		clue = "Which plant has four narrow leaves with a pale stripe?",
		lesson = "Stripegrass has FOUR narrow green leaves and a pale centre stripe.",
		leafCount = 4,
		leafColor = Color3.fromRGB(76, 176, 92),
		accentColor = Color3.fromRGB(205, 244, 166),
		leafShape = "narrow",
		marking = "stripe",
	},
	thornsprig = {
		id = "thornsprig",
		name = "Thornsprig",
		clue = "Which red three-leaf plant has dark thorn marks?",
		lesson = "Thornsprig has THREE red leaves with dark thorn marks. Handle it carefully.",
		leafCount = 3,
		leafColor = Color3.fromRGB(216, 94, 98),
		accentColor = Color3.fromRGB(92, 46, 58),
		leafShape = "narrow",
		marking = "thorns",
	},
	moonbloom = {
		id = "moonbloom",
		name = "Moonbloom",
		clue = "Which plant has one violet leaf beneath a pale moon bud?",
		lesson = "Moonbloom has ONE violet leaf and a pale moon-shaped bud.",
		leafCount = 1,
		leafColor = Color3.fromRGB(155, 112, 210),
		accentColor = Color3.fromRGB(234, 218, 255),
		leafShape = "round",
		marking = "bud",
	},
} :: { [string]: PlantDefinition }

function ExamQuestions.get(questionId: string): PlantDefinition?
	return ExamQuestions.DEFINITIONS[questionId]
end

function ExamQuestions.shuffle(ids: { string }, rng: Random): { string }
	local result = table.clone(ids)
	for index = #result, 2, -1 do
		local other = rng:NextInteger(1, index)
		result[index], result[other] = result[other], result[index]
	end
	return result
end

function ExamQuestions.optionsFor(answerId: string, rng: Random): { string }
	local distractors = {}
	for _, questionId in ExamQuestions.ORDER do
		if questionId ~= answerId then
			table.insert(distractors, questionId)
		end
	end
	distractors = ExamQuestions.shuffle(distractors, rng)
	return ExamQuestions.shuffle({ answerId, distractors[1], distractors[2] }, rng)
end

return ExamQuestions

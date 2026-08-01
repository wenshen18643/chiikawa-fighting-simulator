--[[
	Player-facing copy for the Field Guide.

	Kept as data so the renderer in ControlsPanel can concentrate on layout,
	input and responsive behaviour. The guide describes the playable build, not
	future design documents: systems without a player-facing loop are called out
	as unavailable rather than presented as promises.
]]

local TutorialContent = {}

export type Row = {
	label: string,
	value: string,
	note: string?,
	accent: string?,
}

export type Block = {
	title: string,
	body: string?,
	bullets: { string }?,
	rows: { Row }?,
	style: "plain" | "skills" | "table" | "timeline"?,
}

export type Page = {
	key: string,
	label: string,
	title: string,
	kicker: string,
	accent: string,
	blocks: { Block },
}

local function controlsFor(device: "keyboard" | "gamepad" | "touch"): { Row }
	if device == "touch" then
		return {
			{ label = "Stick", value = "Walk around" },
			{ label = "Jump", value = "Jump and gain a little Resilience" },
			{ label = "WORK", value = "One tap starts one work action" },
			{ label = "1–4", value = "Tap a round skill button to select it" },
			{ label = "Prompt", value = "Tap to talk, forage or use the kitchen" },
			{ label = "Platter", value = "Open your inventory" },
			{ label = "Pin", value = "Toggle the local minimap" },
			{ label = "Map", value = "Open the Atlas, ladder and fast travel" },
			{ label = "?", value = "Open this Field Guide again" },
		}
	elseif device == "gamepad" then
		return {
			{ label = "L-Stick", value = "Walk around" },
			{ label = "L3", value = "Sprint; it costs no stamina" },
			{ label = "A", value = "Jump and gain a little Resilience" },
			{ label = "R2", value = "One press starts one work action" },
			{ label = "Skill bar", value = "Choose which skill open-ground work trains" },
			{ label = "X", value = "Talk, forage or cook when a prompt appears" },
			{ label = "Y", value = "Open your inventory" },
			{ label = "Select", value = "Open the Atlas, ladder and fast travel" },
			{ label = "Start", value = "Open this Field Guide again" },
		}
	end

	return {
		{ label = "W A S D", value = "Walk around" },
		{ label = "Shift", value = "Sprint; it costs no stamina" },
		{ label = "Space", value = "Jump and gain a little Resilience" },
		{ label = "Left click", value = "One click starts one work action" },
		{ label = "1  2  3  4", value = "Select Tobatsu, Resilience, Kusatori or Exam Prep" },
		{ label = "E", value = "Talk, forage or cook when a prompt appears" },
		{ label = "I", value = "Open your inventory" },
		{ label = "M", value = "Toggle the local minimap" },
		{ label = "N", value = "Open the Atlas, ladder and fast travel" },
		{ label = "H / F1", value = "Open this Field Guide again" },
	}
end

function TutorialContent.pages(device: "keyboard" | "gamepad" | "touch"): { Page }
	return {
		{
			key = "start",
			label = "Start here",
			title = "A small job, done well",
			kicker = "TRAIN · EXPLORE · EARN · BRING A FRIEND",
			accent = "kusatori",
			blocks = {
				{
					title = "The whole loop",
					body = "Choose one of four skills and work to raise it. Certification grades multiply what each skill earns, and your four skills together decide how far the world opens up.",
					bullets = {
						"One press is one action. Holding Work does not repeat it.",
						"You can train anywhere. There is nowhere you have to stand.",
						"Running and jumping add small Resilience gains, so travel is productive.",
					},
				},
				{
					title = "Your first good decision",
					body = "Select Kusatori and pull weeds — it pays Yen directly and raises your passive wage on top of the skill itself. The Roadside Weed Patch north of the plaza is the easiest place to start.",
				},
				{
					title = "Nothing is lost",
					body = "Sprinting is free. Running out of stamina causes a short rest, not a failure. "
						.. "Mushroom Frogs and Wolves can hurt you outside Home; Ducks flee when struck. "
						.. "Character defeat loses nothing and there is no PvP.",
				},
			},
		},
		{
			key = "controls",
			label = "Controls",
			title = "Controls",
			kicker = if device == "touch"
				then "TOUCH"
				elseif device == "gamepad" then "CONTROLLER"
				else "KEYBOARD + MOUSE",
			accent = "resilience",
			blocks = {
				{
					title = "Default inputs",
					rows = controlsFor(device),
					style = "table",
				},
				{
					title = "What Work trains",
					bullets = {
						"Work always trains the skill you selected on the bottom bar.",
						"Kusatori needs something to pull: weeds, or a plant worth foraging.",
						"Facing a mob turns Work into an attack, which pays Tobatsu instead.",
					},
				},
			},
		},
		{
			key = "training",
			label = "Training",
			title = "Four ways to grow",
			kicker = "THE ROUND BUTTONS ALONG THE BOTTOM",
			accent = "tobatsu",
			blocks = {
				{
					title = "The four skills",
					rows = {
						{
							label = "1 · Tobatsu",
							value = "Sasumata and subduing practice",
							note = "The work button is also your attack. Face a nearby mob to earn bonus Tobatsu; stronger mobs pay more.",
							accent = "tobatsu",
						},
						{
							label = "2 · Resilience",
							value = "Endurance under pressure",
							note = "Also gained in small amounts by running and jumping; improves stamina over time.",
							accent = "resilience",
						},
						{
							label = "3 · Kusatori",
							value = "Weed-pulling work",
							note = "Pays Yen directly and makes your passive wage larger.",
							accent = "kusatori",
						},
						{
							label = "4 · Exam Prep",
							value = "Studying at desks",
							note = "Press 4 to open the book. Only page flips grant points; each has a 10% field-note chance.",
							accent = "examprep",
						},
					},
					style = "skills",
				},
				{
					title = "Stamina",
					bullets = {
						"You start with 100 stamina. An accepted active action costs 1.",
						"Stamina begins at 6 regeneration per second; Resilience improves the maximum and regeneration.",
						"At zero, you rest for about 5 seconds and then continue.",
						"Every skill is earned by doing something. Standing still earns nothing, and there is no offline progress.",
					},
				},
			},
		},
		{
			key = "progress",
			label = "Progress",
			title = "The skill ladder",
			kicker = "EACH SKILL EARNS ITS OWN GRADES",
			accent = "examprep",
			blocks = {
				{
					title = "Certification grades",
					body = "Each grade multiplies what that skill earns by 1.5, and every grade needs ten times the stat of the one before. Grades are separate per skill: 10,000 Kusatori does nothing for Tobatsu.",
					rows = {
						{ label = "Grade 5", value = "100", note = "×1.5" },
						{ label = "Grade 4", value = "1,000", note = "×2.3" },
						{ label = "Grade 3", value = "10,000", note = "×3.4" },
					},
					style = "table",
				},
				{
					title = "Exam Prep is the ceiling",
					body = "No skill can pass the grade your Exam Prep holds. Exam Prep Grade 3 means every other skill stops at Grade 3, so studying is what unlocks the next rung everywhere at once.",
				},
				{
					title = "Sitting an exam",
					bullets = {
						"Exams happen at the Exam Hall desk in Town, not in the book.",
						"Tobatsu and Resilience need only the stat and the Exam Prep cap.",
						"Kusatori adds a five-question plant exam. Four correct answers pass.",
						"Exam Prep adds a full Readiness bar and one item from each pillar: ore, fish and forage.",
						"Press 4 and flip pages to raise Exam Prep and fill Readiness. Recalling a plant has a 15% chance of Focus: ×2 for 30 seconds.",
					},
				},
			},
		},
		{
			key = "world",
			label = "World + Yen",
			title = "One long road east",
			kicker = "REGIONS OPEN AUTOMATICALLY",
			accent = "gold",
			blocks = {
				{
					title = "Where things grow",
					body = "Town is the whole map. Ingredients grow in fixed patches, and the further out a patch is, the more Kusatori it takes to pull anything from it.",
					rows = {
						{ label = "Home Fields", value = "Carrot, potato, rice", note = "north, close in" },
						{ label = "Berry Grove", value = "Blue and purple berries", note = "west" },
						{ label = "Mushroom Hollow", value = "Brown and white mushrooms", note = "south-east" },
						{ label = "Bramble Hollow", value = "Black berries", note = "south-west, far" },
						{ label = "Sausage Forest", value = "Pink and gold sausage", note = "south-west, guarded" },
						{ label = "Snow Berry Thicket", value = "White berries", note = "south-east, furthest" },
					},
					style = "table",
				},
				{
					title = "Yen",
					bullets = {
						"Your base wage is 60 Yen per minute, paid automatically in smaller slices.",
						"Kusatori increases that wage and also pays 0.25 Yen per point gained.",
						"Yen can be accumulated, but the regular shop and spending loop are not playable yet.",
						"Stamps are visible but do not yet have an earning or spending loop.",
					},
				},
				{
					title = "Friends and travel",
					bullets = {
						"Use the Friend Stand near Town spawn to choose a follower. Hachiware and Usagi can help during practice recall.",
						"NPC dialogue advances in order each time you talk to that character.",
						"Open regions are walkable and available for free fast travel in the Atlas.",
						"Other players can see your work animations, but there is no trading, party reward or PvP.",
					},
				},
				{
					title = "Not playable yet",
					body = "Crafting, recipes, gear, higher certification grades, Season resets, furniture placement and Comfort upgrades are future systems. NPCs and HUD labels may mention them, but they currently have no player-facing action.",
				},
			},
		},
		{
			key = "first_shift",
			label = "First 30 min",
			title = "Your first shift",
			kicker = "A 30-MINUTE ROUTE WITH NO WASTED STEPS",
			accent = "kusatori",
			blocks = {
				{
					title = "First 30 minutes",
					body = "Tap the round boxes as you finish each stop. Marks last for this play session.",
					rows = {
						{
							label = "0–2 min",
							value = "Read the HUD",
							note = "Find Yen, wage, the four round skill buttons and the stamina ring.",
							accent = "resilience",
						},
						{
							label = "2–5 min",
							value = "Leave the cottage",
							note = "Sprint, jump, watch Resilience tick upward, and talk to one Town character.",
							accent = "resilience",
						},
						{
							label = "5–7 min",
							value = "Choose a companion",
							note = "Use the Friend Stand near spawn. Every choice is cosmetic.",
							accent = "examprep",
						},
						{
							label = "7–10 min",
							value = "Select Kusatori",
							note = "Choose skill 3 and follow the lantern path north to the Roadside Weed Patch.",
							accent = "kusatori",
						},
						{
							label = "10–20 min",
							value = "Pull weeds",
							note = "Press once per weed, watch Yen rise, and confirm the stat climbs on the bottom bar.",
							accent = "kusatori",
						},
						{
							label = "20–23 min",
							value = "Study for the ceiling",
							note = "Press 4, flip pages to 100 Exam Prep, and fill the Readiness bookmark.",
							accent = "examprep",
						},
						{
							label = "23–27 min",
							value = "Certify at the Exam Hall",
							note = "Bring 1 Iron Ore, 1 Crucian and 1 Carrot to the desk in Town. Exam Prep Grade 5 lifts the cap on every skill.",
							accent = "gold",
						},
						{
							label = "27–30 min",
							value = "Plan for the Woods",
							note = "Open the map and Atlas, check what is still closed, then aim for 50,000 combined skill.",
							accent = "gold",
						},
					},
					style = "timeline",
				},
				{
					title = "The early-game rule",
					body = "Kusatori to 10,000 → Tier 2 ×6 → 50,000 combined skill → Woods. Leave the game from any convenient place; passive training stops when the session ends.",
				},
			},
		},
	}
end

return TutorialContent

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
			{ label = "Prompt", value = "Tap to talk or use the Friend Stand" },
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
			{ label = "X", value = "Talk when a prompt appears" },
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
		{ label = "E", value = "Talk when a prompt appears" },
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
					body = "Choose one of four skills, work to raise it, and move to stronger coloured pads as their requirements open. Your four skills combine to unlock six connected regions.",
					bullets = {
						"One press is one action. Holding Work does not repeat it.",
						"You can train anywhere at base rate; usable pads multiply the gain.",
						"Running and jumping add small Resilience gains, so travel is productive.",
					},
				},
				{
					title = "Your first good decision",
					body = "Select Kusatori, follow the arrow to the Roadside Weed Patch, and work toward 10,000. Its Tier 2 pad pays ×6, while Kusatori also raises your wage and pays Yen directly.",
				},
				{
					title = "Nothing is lost",
					body = "Sprinting is free. Running out of stamina causes a short rest, not a failure. "
						.. "Mushroom Frogs and Spiders can hurt you outside Home; Ducks flee when struck. "
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
					title = "How Work reads your position",
					bullets = {
						"On open ground, Work trains the skill you selected on the bottom bar.",
						"On a usable pad, that pad chooses the skill and adds its multiplier.",
						"On a locked pad, clicks practise its skill at base rate, but standing still earns nothing there.",
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
					title = "Stamina and passive work",
					bullets = {
						"You start with 100 stamina. An accepted active action costs 1.",
						"Stamina begins at 6 regeneration per second; Resilience improves the maximum and regeneration.",
						"At zero, you rest for about 5 seconds and then continue.",
						"Standing on a usable pad trains automatically at half rate, except Exam Prep: every point needs a page flip.",
						"Passive pad work only runs while you remain in the server; there is no offline progress.",
					},
				},
			},
		},
		{
			key = "progress",
			label = "Progress",
			title = "The skill ladder",
			kicker = "EACH SKILL UNLOCKS ITS OWN PADS",
			accent = "examprep",
			blocks = {
				{
					title = "Pad tiers",
					body = "A later area carries its new tier and all earlier tiers. Requirements are separate per skill: 10,000 Kusatori does not unlock Tier 2 Tobatsu.",
					rows = {
						{ label = "Tier 1 · Town", value = "Free", note = "×2" },
						{ label = "Tier 2 · Town", value = "10,000", note = "×6" },
						{ label = "Tier 3 · Woods", value = "100,000", note = "×25" },
						{ label = "Tier 4 · Riverside", value = "1,000,000", note = "×50" },
						{ label = "Tier 5 · Mountain", value = "10,000,000", note = "×500" },
						{ label = "Tier 6 · Island", value = "100,000,000", note = "×1,000" },
						{ label = "Tier 7 · Ruins", value = "1,000,000,000", note = "×5,000" },
					},
					style = "table",
				},
				{
					title = "Veteran shortcut",
					body = "Push one useful skill to its next pad before spreading gains evenly. A new multiplier is an engine: once it opens, every future press and passive tick in that skill becomes stronger.",
				},
				{
					title = "Kusatori Grade 5",
					bullets = {
						"Press 4, flip pages, and watch for the 10% chance that a field note appears.",
						"Recall the right plant for a 15% chance at Focus: 2x Exam Prep from flips for 30 seconds.",
						"At 100% Readiness and 100 Kusatori, sit the five-question exam from the pink bookmark.",
						"Four correct answers pass. Failure keeps Readiness and asks for two short review cards.",
						"Grade 5 doubles Kusatori gains and adds 50% to the base passive wage multiplier.",
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
					title = "Region gates",
					body = "All four skill values count toward these totals. Nothing must be bought or claimed; the next eastern gate opens as soon as the requirement is met.",
					rows = {
						{ label = "Town", value = "Open from the start" },
						{ label = "Woods", value = "50,000 total skill" },
						{ label = "Riverside", value = "500,000 total skill" },
						{ label = "Mountain", value = "5,000,000 total skill" },
						{ label = "Island", value = "50,000,000 total skill" },
						{ label = "Old Ruins", value = "500,000,000 total skill" },
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
							note = "Choose skill 3 and follow the Work Core arrow to the Tier 1 Roadside Weed Patch.",
							accent = "kusatori",
						},
						{
							label = "10–20 min",
							value = "Work the ×2 pad",
							note = "Press once per action, watch Yen rise, and confirm that standing still also trains on a usable pad.",
							accent = "kusatori",
						},
						{
							label = "20–23 min",
							value = "Move up when ready",
							note = "At 10,000 Kusatori, step off and follow the arrow to the Tier 2 ×6 pad. Otherwise keep the ×2 pad.",
							accent = "gold",
						},
						{
							label = "23–27 min",
							value = "Sample the other skills",
							note = "Visit the Exam Prep desk, turn pages toward a field note, and try its visual recall question.",
							accent = "tobatsu",
						},
						{
							label = "27–30 min",
							value = "Plan for the Woods",
							note = "Open the map and Atlas, inspect the Ladder, then aim for 50,000 combined skill.",
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

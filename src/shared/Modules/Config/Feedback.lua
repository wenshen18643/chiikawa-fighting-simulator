--[[
	What each skill LOOKS and SOUNDS like when performed.

	--------------------------------------------------------------------------
	HOW A GESTURE IS AUTHORED
	--------------------------------------------------------------------------

	A key is a pose for the RIGHT arm at a normalised time `t` (0..1 across
	`duration`). Every angle is in degrees and is a DELTA from the rig's rest
	pose, so the same numbers drive R6 and R15.

		pitch   shoulder swing.  NEGATIVE is up/back, POSITIVE is down/forward.
		yaw     shoulder twist outward from the body.
		roll    shoulder raise out to the side.
		elbow   forearm flex.    POSITIVE brings the hand toward the shoulder.
		wrist   hand flex.

	`arms = "both"` mirrors the right arm onto the left: yaw and roll negate,
	pitch and elbow do not. That is right for symmetric gestures (shielding),
	and wrong for a gesture where the hands do different jobs — so a key may
	carry a `left` table that overrides the mirror for that arm. Exam Prep uses
	it: the right hand holds the book still while the left turns a page, and
	mirroring would have both hands doing the same thing to opposite sides of
	nothing.

	THE ELBOW IS NOT OPTIONAL. An arm driven from the shoulder alone is a rigid
	stick on a pivot — it cannot bring a book to a face or coil before a swing,
	which is most of what makes these read as actions rather than as arm waving.

	TIMING. Each gesture spends real time on anticipation and on follow-through,
	because an action that is only its middle frame reads as a teleport. Roughly:
	wind up over the first third, strike fast, then absorb and settle. Note the
	near-duplicate keys (0.30/0.38 on tobatsu) — that pause at the top of the
	windup is deliberate and is what sells the weight of the swing.

	`duration` is the SLOWEST a gesture ever plays, not a rate limit — clicks are
	never held back for it. WorkController compresses the clip toward the actual
	click cadence, so this is what one click looks like when you are not spamming.
	These are tuned as the slowest that reads well, not the slowest that looks
	best in isolation.
]]

local Feedback = {}

export type ArmPose = {
	pitch: number,
	yaw: number?,
	roll: number?,
	elbow: number?,
	wrist: number?,
}

export type GestureKey = {
	t: number,
	pitch: number,
	yaw: number?,
	roll: number?,
	elbow: number?,
	wrist: number?,
	-- Overrides the mirrored right arm for gestures where the hands differ.
	left: ArmPose?,
}

export type Gesture = {
	arms: string,
	duration: number,
	keys: { GestureKey },
}

export type SoundSpec = {
	id: string,
	volume: number,
	pitchMin: number,
	pitchMax: number,
}

export type SkillFeedback = {
	gesture: Gesture,
	sound: SoundSpec,
}

local function sound(volume: number): SoundSpec
	return {
		id = "",
		volume = volume,
		pitchMin = 0.93,
		pitchMax = 1.07,
	}
end

Feedback.SKILLS = {
	--[[
		Tobatsu — overhead Sasumata strike.

		Coil for the first third, strike through in an eighth of a second, then
		absorb the impact and settle. The elbow does the opposite of the
		shoulder: folded tight at the top of the windup, snapping straight
		through the strike, which is what gives the swing its whip.
	]]
	tobatsu = {
		gesture = {
			arms = "right",
			duration = 0.50,
			keys = {
				{ t = 0.00, pitch = 0, yaw = 0, roll = 0, elbow = 10 },
				{ t = 0.30, pitch = -95, yaw = -6, roll = 8, elbow = 74 }, -- windup, arm coiled overhead
				{ t = 0.38, pitch = -104, yaw = -8, roll = 10, elbow = 84 }, -- held top of the coil
				{ t = 0.60, pitch = 78, yaw = 4, roll = -4, elbow = 6 }, -- strike, elbow snaps straight
				{ t = 0.73, pitch = 62, yaw = 6, roll = -2, elbow = 28 }, -- absorb the impact
				{ t = 0.87, pitch = 24, yaw = 2, roll = 0, elbow = 20 },
				{ t = 1.00, pitch = 0, yaw = 0, roll = 0, elbow = 10 },
			},
		},
		sound = sound(0.45),
	},

	--[[
		Resilience — bracing under the waterfall.

		Both arms come up to shield the face, then tremble. The tremble is three
		tight keys rather than a sine wave so it stays readable through the
		spline; a smooth oscillation at this amplitude just looks like drift.
	]]
	resilience = {
		gesture = {
			arms = "both",
			duration = 0.55,
			keys = {
				{ t = 0.00, pitch = 0, yaw = 0, roll = 0, elbow = 14 },
				{ t = 0.20, pitch = -58, yaw = 26, roll = 38, elbow = 92 }, -- arms up to shield
				{ t = 0.40, pitch = -63, yaw = 30, roll = 44, elbow = 98 }, -- tremble
				{ t = 0.52, pitch = -57, yaw = 24, roll = 36, elbow = 90 },
				{ t = 0.64, pitch = -62, yaw = 29, roll = 42, elbow = 97 },
				{ t = 0.82, pitch = -46, yaw = 18, roll = 28, elbow = 76 }, -- hold firm
				{ t = 1.00, pitch = 0, yaw = 0, roll = 0, elbow = 14 },
			},
		},
		sound = sound(0.35),
	},

	--[[
		Kusatori — grab the weed, yank it out, toss it away.

		The brief hold at 0.26/0.34 is the grip closing. The yank flexes the
		elbow hard rather than only rotating the shoulder, so the hand travels
		to the chest the way a real pull does.
	]]
	kusatori = {
		gesture = {
			arms = "right",
			duration = 0.42,
			keys = {
				{ t = 0.00, pitch = 0, yaw = 0, roll = 0, elbow = 12 },
				{ t = 0.26, pitch = 72, yaw = 12, roll = -8, elbow = 22 }, -- reach down
				{ t = 0.34, pitch = 76, yaw = 13, roll = -7, elbow = 18 }, -- grip closes
				{ t = 0.58, pitch = -34, yaw = -14, roll = 20, elbow = 78 }, -- yank to the chest
				{ t = 0.74, pitch = -6, yaw = -24, roll = 12, elbow = 30 }, -- toss it behind
				{ t = 1.00, pitch = 0, yaw = 0, roll = 0, elbow = 12 },
			},
		},
		sound = sound(0.40),
	},

	--[[
		Exam Prep — reading, and turning a page.

		The two arms do different jobs, so every key past the lift carries a
		`left` override. What makes this read as studying is that the RIGHT arm
		does not move between 0.34 and 0.84: it holds the book at reading height
		with the elbow folded to ~95 degrees, and only the left hand travels, out
		to the far page at 0.52 and sweeping back across at 0.68. GestureController
		syncs the book prop's page flip to exactly that window.
	]]
	examprep = {
		gesture = {
			arms = "both",
			duration = 0.78,
			keys = {
				{
					t = 0.00,
					pitch = 0,
					yaw = 0,
					roll = 0,
					elbow = 14,
					left = { pitch = 0, yaw = 0, roll = 0, elbow = 14 },
				},
				{
					t = 0.18, -- both hands lift the book to chest height
					pitch = 42,
					yaw = -16,
					roll = 6,
					elbow = 88,
					left = { pitch = 40, yaw = 16, roll = -6, elbow = 84 },
				},
				{
					t = 0.34, -- settled into the reading pose
					pitch = 46,
					yaw = -14,
					roll = 8,
					elbow = 95,
					left = { pitch = 44, yaw = 14, roll = -8, elbow = 92 },
				},
				{
					t = 0.52, -- right holds steady; left reaches for the far page
					pitch = 46,
					yaw = -14,
					roll = 8,
					elbow = 95,
					left = { pitch = 30, yaw = 40, roll = -18, elbow = 62 },
				},
				{
					t = 0.68, -- left sweeps the page across
					pitch = 46,
					yaw = -14,
					roll = 8,
					elbow = 95,
					left = { pitch = 38, yaw = -6, roll = 10, elbow = 84 },
				},
				{
					t = 0.84, -- back to reading
					pitch = 45,
					yaw = -14,
					roll = 8,
					elbow = 93,
					left = { pitch = 43, yaw = 14, roll = -8, elbow = 90 },
				},
				{
					t = 1.00,
					pitch = 0,
					yaw = 0,
					roll = 0,
					elbow = 14,
					left = { pitch = 0, yaw = 0, roll = 0, elbow = 14 },
				},
			},
		},
		sound = sound(0.38),
	},

	--[[
		Farm plucks and kitchen gestures — full-body clips in Config/PlayerAnims,
		one per ingredient (Config/Ingredients). Only `gesture.duration` is read:
		it is the window the clip is time-fitted to, locally and for spectators.
	]]
	farm_carrot = {
		gesture = { duration = 1.0 },
		sound = sound(0.4),
	},
	farm_potato = {
		gesture = { duration = 1.2 },
		sound = sound(0.4),
	},
	farm_rice = {
		gesture = { duration = 1.1 },
		sound = sound(0.4),
	},
	farm_berry_shake = {
		gesture = { duration = 1.0 },
		sound = sound(0.4),
	},
	farm_berry_pick = {
		gesture = { duration = 0.9 },
		sound = sound(0.4),
	},
	farm_berry_pluck = {
		gesture = { duration = 1.0 },
		sound = sound(0.4),
	},
	farm_berry_reach = {
		gesture = { duration = 1.2 },
		sound = sound(0.4),
	},
	farm_mushroom_twist = {
		gesture = { duration = 0.9 },
		sound = sound(0.4),
	},
	farm_mushroom_pull = {
		gesture = { duration = 1.1 },
		sound = sound(0.4),
	},
	farm_sausage_pull = {
		gesture = { duration = 1.2 },
		sound = sound(0.4),
	},
	farm_sausage_yank = {
		gesture = { duration = 1.3 },
		sound = sound(0.4),
	},
	cook_stir = {
		gesture = { duration = 1.2 },
		sound = sound(0.35),
	},
	cook_complete = {
		gesture = { duration = 1.35 },
		sound = sound(0.35),
	},
} :: { [string]: SkillFeedback }

-- Aliases
Feedback.SKILLS.strength = Feedback.SKILLS.tobatsu
Feedback.SKILLS.subjugation = Feedback.SKILLS.tobatsu
Feedback.SKILLS.durability = Feedback.SKILLS.resilience
Feedback.SKILLS.grit = Feedback.SKILLS.resilience
Feedback.SKILLS.agility = Feedback.SKILLS.kusatori
Feedback.SKILLS.weeding = Feedback.SKILLS.kusatori
Feedback.SKILLS.special = Feedback.SKILLS.examprep
Feedback.SKILLS.craft = Feedback.SKILLS.examprep

Feedback.MOVEMENT_SOUND = sound(0.22)

function Feedback.get(skillId: string): SkillFeedback?
	return Feedback.SKILLS[skillId]
end

function Feedback.missingSounds(): { string }
	local missing = {}
	for skillId, entry in Feedback.SKILLS do
		if entry.sound.id == "" then
			table.insert(missing, skillId)
		end
	end
	table.sort(missing)
	return missing
end

return Feedback

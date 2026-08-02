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
	tobatsu = {
		gesture = {
			arms = "right",
			duration = 0.50,
			keys = {
				{ t = 0.00, pitch = 0, yaw = 0, roll = 0, elbow = 10 },
				{ t = 0.30, pitch = -95, yaw = -6, roll = 8, elbow = 74 },
				{ t = 0.38, pitch = -104, yaw = -8, roll = 10, elbow = 84 },
				{ t = 0.60, pitch = 78, yaw = 4, roll = -4, elbow = 6 },
				{ t = 0.73, pitch = 62, yaw = 6, roll = -2, elbow = 28 },
				{ t = 0.87, pitch = 24, yaw = 2, roll = 0, elbow = 20 },
				{ t = 1.00, pitch = 0, yaw = 0, roll = 0, elbow = 10 },
			},
		},
		sound = sound(0.45),
	},

	resilience = {
		gesture = {
			arms = "both",
			duration = 0.55,
			keys = {
				{ t = 0.00, pitch = 0, yaw = 0, roll = 0, elbow = 14 },
				{ t = 0.20, pitch = -58, yaw = 26, roll = 38, elbow = 92 },
				{ t = 0.40, pitch = -63, yaw = 30, roll = 44, elbow = 98 },
				{ t = 0.52, pitch = -57, yaw = 24, roll = 36, elbow = 90 },
				{ t = 0.64, pitch = -62, yaw = 29, roll = 42, elbow = 97 },
				{ t = 0.82, pitch = -46, yaw = 18, roll = 28, elbow = 76 },
				{ t = 1.00, pitch = 0, yaw = 0, roll = 0, elbow = 14 },
			},
		},
		sound = sound(0.35),
	},

	kusatori = {
		gesture = {
			arms = "right",
			duration = 0.42,
			keys = {
				{ t = 0.00, pitch = 0, yaw = 0, roll = 0, elbow = 12 },
				{ t = 0.26, pitch = 72, yaw = 12, roll = -8, elbow = 22 },
				{ t = 0.34, pitch = 76, yaw = 13, roll = -7, elbow = 18 },
				{ t = 0.58, pitch = -34, yaw = -14, roll = 20, elbow = 78 },
				{ t = 0.74, pitch = -6, yaw = -24, roll = 12, elbow = 30 },
				{ t = 1.00, pitch = 0, yaw = 0, roll = 0, elbow = 12 },
			},
		},
		sound = sound(0.40),
	},

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
					t = 0.18,
					pitch = 42,
					yaw = -16,
					roll = 6,
					elbow = 88,
					left = { pitch = 40, yaw = 16, roll = -6, elbow = 84 },
				},
				{
					t = 0.34,
					pitch = 46,
					yaw = -14,
					roll = 8,
					elbow = 95,
					left = { pitch = 44, yaw = 14, roll = -8, elbow = 92 },
				},
				{
					t = 0.52,
					pitch = 46,
					yaw = -14,
					roll = 8,
					elbow = 95,
					left = { pitch = 30, yaw = 40, roll = -18, elbow = 62 },
				},
				{
					t = 0.68,
					pitch = 46,
					yaw = -14,
					roll = 8,
					elbow = 95,
					left = { pitch = 38, yaw = -6, roll = 10, elbow = 84 },
				},
				{
					t = 0.84,
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

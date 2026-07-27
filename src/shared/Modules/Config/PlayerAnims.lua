local Skills = require(script.Parent.Skills)

local PlayerAnims = {}

local LEGS_LIGHT = {
	hipL = 0.3,
	hipR = 0.3,
	kneeL = 0.35,
	kneeR = 0.35,
	root = 0.55,
}

PlayerAnims.CLIPS = {

	tobatsu = {
		length = 0.82,
		mask = LEGS_LIGHT,
		tracks = {
			root = {
				{ t = 0.00, pitch = 0, yaw = 0 },
				{ t = 0.30, pitch = 7, yaw = -12 },
				{ t = 0.46, pitch = -14, yaw = 6 },
				{ t = 0.66, pitch = -6, yaw = 2 },
				{ t = 1.00, pitch = 0, yaw = 0 },
			},
			waist = {
				{ t = 0.00, pitch = 0, yaw = 0 },
				{ t = 0.30, pitch = 9, yaw = -16 },
				{ t = 0.46, pitch = -20, yaw = 8 },
				{ t = 0.66, pitch = -8, yaw = 3 },
				{ t = 1.00, pitch = 0, yaw = 0 },
			},
			neck = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.30, pitch = -8 },
				{ t = 0.46, pitch = 14 },
				{ t = 1.00, pitch = 0 },
			},
			shoulderR = {
				{ t = 0.00, pitch = 6, roll = 4 },
				{ t = 0.30, pitch = -142, roll = 16 },
				{ t = 0.46, pitch = 62, roll = 6 },
				{ t = 0.66, pitch = 34, roll = 4 },
				{ t = 1.00, pitch = 6, roll = 4 },
			},
			shoulderL = {
				{ t = 0.00, pitch = 6, roll = -4 },
				{ t = 0.30, pitch = -128, roll = -20 },
				{ t = 0.46, pitch = 54, roll = -8 },
				{ t = 0.66, pitch = 30, roll = -6 },
				{ t = 1.00, pitch = 6, roll = -4 },
			},
			elbowR = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.30, pitch = 96 },
				{ t = 0.46, pitch = 8 },
				{ t = 1.00, pitch = 10 },
			},
			elbowL = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.30, pitch = 88 },
				{ t = 0.46, pitch = 8 },
				{ t = 1.00, pitch = 10 },
			},
			hipR = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.30, pitch = -14 },
				{ t = 0.46, pitch = 20 },
				{ t = 1.00, pitch = 0 },
			},
			kneeR = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.46, pitch = -22 },
				{ t = 1.00, pitch = 0 },
			},
		},
	},

	resilience = {
		length = 0.95,
		mask = LEGS_LIGHT,
		tracks = {
			root = {
				{ t = 0.00, pitch = 0, y = 0 },
				{ t = 0.22, pitch = -10, y = -0.22 },
				{ t = 0.40, pitch = -16, y = -0.34 },
				{ t = 0.58, pitch = -11, y = -0.2 },
				{ t = 1.00, pitch = 0, y = 0 },
			},
			waist = {
				{ t = 0.00, pitch = 0, roll = 0 },
				{ t = 0.22, pitch = -14, roll = 0 },
				{ t = 0.40, pitch = -22, roll = -5 },
				{ t = 0.52, pitch = -19, roll = 5 },
				{ t = 1.00, pitch = 0, roll = 0 },
			},
			neck = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.30, pitch = -22 },
				{ t = 0.60, pitch = -18 },
				{ t = 1.00, pitch = 0 },
			},
			shoulderR = {
				{ t = 0.00, pitch = 6, roll = 4 },
				{ t = 0.24, pitch = 92, roll = 34 },
				{ t = 0.44, pitch = 104, roll = 40 },
				{ t = 0.66, pitch = 88, roll = 32 },
				{ t = 1.00, pitch = 6, roll = 4 },
			},
			shoulderL = {
				{ t = 0.00, pitch = 6, roll = -4 },
				{ t = 0.24, pitch = 92, roll = -34 },
				{ t = 0.44, pitch = 104, roll = -40 },
				{ t = 0.66, pitch = 88, roll = -32 },
				{ t = 1.00, pitch = 6, roll = -4 },
			},
			elbowR = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.24, pitch = 104 },
				{ t = 0.44, pitch = 118 },
				{ t = 1.00, pitch = 10 },
			},
			elbowL = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.24, pitch = 104 },
				{ t = 0.44, pitch = 118 },
				{ t = 1.00, pitch = 10 },
			},
			kneeL = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.40, pitch = -30 },
				{ t = 1.00, pitch = 0 },
			},
			kneeR = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.40, pitch = -30 },
				{ t = 1.00, pitch = 0 },
			},
		},
	},

	kusatori = {
		length = 1.05,
		mask = LEGS_LIGHT,
		tracks = {
			root = {
				{ t = 0.00, pitch = 0, y = 0 },
				{ t = 0.26, pitch = -22, y = -0.26 },
				{ t = 0.48, pitch = -26, y = -0.3 },
				{ t = 0.64, pitch = 12, y = 0.06 },
				{ t = 0.80, pitch = 4, y = 0 },
				{ t = 1.00, pitch = 0, y = 0 },
			},
			waist = {
				{ t = 0.00, pitch = 0, yaw = 0 },
				{ t = 0.26, pitch = -34, yaw = -10 },
				{ t = 0.48, pitch = -40, yaw = -12 },
				{ t = 0.64, pitch = 16, yaw = 6 },
				{ t = 1.00, pitch = 0, yaw = 0 },
			},
			neck = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.30, pitch = -18 },
				{ t = 0.64, pitch = 12 },
				{ t = 1.00, pitch = 0 },
			},
			shoulderR = {
				{ t = 0.00, pitch = 6, roll = 4 },
				{ t = 0.28, pitch = 54, roll = 10 },
				{ t = 0.48, pitch = 68, roll = 8 },
				{ t = 0.62, pitch = -40, roll = 14 },
				{ t = 0.78, pitch = -18, roll = 8 },
				{ t = 1.00, pitch = 6, roll = 4 },
			},
			shoulderL = {
				{ t = 0.00, pitch = 6, roll = -4 },
				{ t = 0.28, pitch = 26, roll = -16 },
				{ t = 0.48, pitch = 30, roll = -20 },
				{ t = 0.62, pitch = -22, roll = -26 },
				{ t = 1.00, pitch = 6, roll = -4 },
			},
			elbowR = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.48, pitch = 26 },
				{ t = 0.62, pitch = 96 },
				{ t = 1.00, pitch = 10 },
			},
			elbowL = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.48, pitch = 34 },
				{ t = 0.62, pitch = 62 },
				{ t = 1.00, pitch = 10 },
			},
			hipL = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.48, pitch = 26 },
				{ t = 1.00, pitch = 0 },
			},
			kneeL = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.48, pitch = -34 },
				{ t = 1.00, pitch = 0 },
			},
			kneeR = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.48, pitch = -20 },
				{ t = 1.00, pitch = 0 },
			},
		},
	},

	examprep = {
		length = 1.35,
		mask = {
			hipL = 0.2,
			hipR = 0.2,
			kneeL = 0.2,
			kneeR = 0.2,
			root = 0.4,
		},
		tracks = {
			root = {
				{ t = 0.00, pitch = 0, roll = 0 },
				{ t = 0.24, pitch = -6, roll = -2 },
				{ t = 0.56, pitch = -7, roll = 2 },
				{ t = 0.82, pitch = -5, roll = -2 },
				{ t = 1.00, pitch = 0, roll = 0 },
			},
			waist = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.24, pitch = -10 },
				{ t = 0.80, pitch = -9 },
				{ t = 1.00, pitch = 0 },
			},
			neck = {
				{ t = 0.00, pitch = 0, yaw = 0 },
				{ t = 0.22, pitch = -26, yaw = -6 },
				{ t = 0.50, pitch = -28, yaw = 7 },
				{ t = 0.78, pitch = -25, yaw = -5 },
				{ t = 1.00, pitch = 0, yaw = 0 },
			},
			shoulderR = {
				{ t = 0.00, pitch = 6, roll = 4 },
				{ t = 0.20, pitch = 64, roll = 14 },
				{ t = 0.80, pitch = 66, roll = 15 },
				{ t = 1.00, pitch = 6, roll = 4 },
			},
			shoulderL = {
				{ t = 0.00, pitch = 6, roll = -4 },
				{ t = 0.20, pitch = 62, roll = -16 },
				{ t = 0.48, pitch = 74, roll = -34 },
				{ t = 0.64, pitch = 60, roll = -12 },
				{ t = 1.00, pitch = 6, roll = -4 },
			},
			elbowR = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.20, pitch = 74 },
				{ t = 0.80, pitch = 76 },
				{ t = 1.00, pitch = 10 },
			},
			elbowL = {
				{ t = 0.00, pitch = 10 },
				{ t = 0.20, pitch = 72 },
				{ t = 0.48, pitch = 44 },
				{ t = 0.64, pitch = 70 },
				{ t = 1.00, pitch = 10 },
			},
			wristL = {
				{ t = 0.00, pitch = 0 },
				{ t = 0.46, pitch = -30 },
				{ t = 0.60, pitch = 12 },
				{ t = 1.00, pitch = 0 },
			},
		},
	},
} :: { [string]: any }

function PlayerAnims.get(skillId: string): any
	return PlayerAnims.CLIPS[Skills.canonicalize(skillId)]
end

return PlayerAnims

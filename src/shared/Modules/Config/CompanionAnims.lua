local CompanionAnims = {}

export type Tremble = {
	amplitude: number,
	frequency: number,
	joints: { [string]: number },
}

export type Break = {
	clip: string,
	weight: number,
}

export type Prop = {
	builder: string,
	flashAt: number?,
}

export type Set = {
	walkSpeed: number,
	runSpeed: number,
	tremble: Tremble?,
	breaks: { Break }?,
	breakDelay: { number }?,
	clips: { [string]: any },
}

CompanionAnims.SETS = {
	chiikawa = {
		walkSpeed = 16,
		runSpeed = 30,
		tremble = {
			amplitude = 1.7,
			frequency = 2.4,
			joints = { root = 0.3, head = 0.22, armL = 1.0, armR = 1.0, earL = 0.75, earR = 0.75 },
		},
		breakDelay = { 6, 13 },
		breaks = {
			{ clip = "startle", weight = 2 },
			{ clip = "cry", weight = 1 },
			{ clip = "sway", weight = 2 },
		},
		clips = {
			idle = {
				length = 2.9,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 4.0, roll = -1.5 },
						{ t = 0.28, y = -0.05, pitch = 5.0, roll = 0 },
						{ t = 0.55, y = 0.00, pitch = 4.0, roll = 1.5 },
						{ t = 0.80, y = -0.05, pitch = 5.0, roll = 0 },
					},
					head = {
						{ t = 0.00, pitch = -6, yaw = -7 },
						{ t = 0.30, pitch = -8, yaw = -3 },
						{ t = 0.52, pitch = -5, yaw = 8 },
						{ t = 0.78, pitch = -8, yaw = 2 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.40, pitch = -17, roll = 9 },
						{ t = 0.72, pitch = -10, roll = 5 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.44, pitch = -17, roll = -9 },
						{ t = 0.76, pitch = -10, roll = -5 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.45, pitch = 19, roll = -21 },
						{ t = 0.75, pitch = 13, roll = -16 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.45, pitch = 19, roll = 21 },
						{ t = 0.75, pitch = 13, roll = 16 },
					},
					legL = {
						{ t = 0.00, pitch = 2 },
						{ t = 0.50, pitch = -2 },
					},
					legR = {
						{ t = 0.00, pitch = -2 },
						{ t = 0.50, pitch = 2 },
					},
				},
			},
			walk = {
				length = 0.78,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 3, roll = -2.5 },
						{ t = 0.25, y = 0.08, pitch = 4, roll = 0 },
						{ t = 0.50, y = 0.00, pitch = 3, roll = 2.5 },
						{ t = 0.75, y = 0.08, pitch = 4, roll = 0 },
					},
					head = {
						{ t = 0.00, pitch = -4, yaw = -6 },
						{ t = 0.50, pitch = -6, yaw = 6 },
					},
					earL = {
						{ t = 0.00, pitch = -8, roll = 5 },
						{ t = 0.25, pitch = -19, roll = 8 },
						{ t = 0.50, pitch = -8, roll = 5 },
						{ t = 0.75, pitch = -19, roll = 8 },
					},
					earR = {
						{ t = 0.00, pitch = -8, roll = -5 },
						{ t = 0.25, pitch = -19, roll = -8 },
						{ t = 0.50, pitch = -8, roll = -5 },
						{ t = 0.75, pitch = -19, roll = -8 },
					},
					armL = {
						{ t = 0.00, pitch = 24, roll = -26 },
						{ t = 0.50, pitch = 32, roll = -31 },
					},
					armR = {
						{ t = 0.00, pitch = 32, roll = 26 },
						{ t = 0.50, pitch = 24, roll = 31 },
					},
					legL = {
						{ t = 0.00, pitch = 30 },
						{ t = 0.50, pitch = -27 },
					},
					legR = {
						{ t = 0.00, pitch = -27 },
						{ t = 0.50, pitch = 30 },
					},
				},
			},
			run = {
				length = 0.52,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 7, roll = -4 },
						{ t = 0.25, y = 0.15, pitch = 9, roll = 0 },
						{ t = 0.50, y = 0.00, pitch = 7, roll = 4 },
						{ t = 0.75, y = 0.15, pitch = 9, roll = 0 },
					},
					head = {
						{ t = 0.00, pitch = -3, yaw = -11 },
						{ t = 0.50, pitch = -5, yaw = 11 },
					},
					earL = {
						{ t = 0.00, pitch = -6, roll = 7 },
						{ t = 0.25, pitch = -26, roll = 12 },
						{ t = 0.50, pitch = -6, roll = 7 },
						{ t = 0.75, pitch = -26, roll = 12 },
					},
					earR = {
						{ t = 0.00, pitch = -6, roll = -7 },
						{ t = 0.25, pitch = -26, roll = -12 },
						{ t = 0.50, pitch = -6, roll = -7 },
						{ t = 0.75, pitch = -26, roll = -12 },
					},
					armL = {
						{ t = 0.00, pitch = 96, roll = -34 },
						{ t = 0.50, pitch = 118, roll = -22 },
					},
					armR = {
						{ t = 0.00, pitch = 118, roll = 22 },
						{ t = 0.50, pitch = 96, roll = 34 },
					},
					legL = {
						{ t = 0.00, pitch = 46 },
						{ t = 0.50, pitch = -40 },
					},
					legR = {
						{ t = 0.00, pitch = -40 },
						{ t = 0.50, pitch = 46 },
					},
				},
			},
			action = {
				length = 2.6,
				mask = { legL = 0.4, legR = 0.4, root = 0.75 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 0, roll = 0, yaw = 0 },
						{ t = 0.12, y = -0.11, pitch = -6, roll = 0, yaw = 0 },
						{ t = 0.26, y = 0.22, pitch = 4, roll = -10, yaw = 26 },
						{ t = 0.40, y = 0.00, pitch = 0, roll = -6, yaw = 40 },
						{ t = 0.54, y = 0.22, pitch = 4, roll = 10, yaw = -26 },
						{ t = 0.68, y = 0.00, pitch = 0, roll = 6, yaw = -40 },
						{ t = 0.82, y = 0.27, pitch = -5, roll = 0, yaw = 0 },
						{ t = 1.00, y = 0.00, pitch = 0, roll = 0, yaw = 0 },
					},
					head = {
						{ t = 0.00, pitch = -4 },
						{ t = 0.26, pitch = 9, roll = -6 },
						{ t = 0.54, pitch = -9, roll = 6 },
						{ t = 0.82, pitch = 10 },
						{ t = 1.00, pitch = -4 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.26, pitch = 16, roll = 14 },
						{ t = 0.54, pitch = -20, roll = 4 },
						{ t = 0.82, pitch = 22, roll = 12 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.26, pitch = -20, roll = -4 },
						{ t = 0.54, pitch = 16, roll = -14 },
						{ t = 0.82, pitch = 22, roll = -12 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
					armL = {
						{ t = 0.00, pitch = 14, roll = -16 },
						{ t = 0.20, pitch = 104, roll = -32 },
						{ t = 0.45, pitch = 146, roll = -18 },
						{ t = 0.70, pitch = 100, roll = -36 },
						{ t = 0.86, pitch = 150, roll = -14 },
						{ t = 1.00, pitch = 14, roll = -16 },
					},
					armR = {
						{ t = 0.00, pitch = 14, roll = 16 },
						{ t = 0.20, pitch = 148, roll = 16 },
						{ t = 0.45, pitch = 100, roll = 34 },
						{ t = 0.70, pitch = 150, roll = 14 },
						{ t = 0.86, pitch = 102, roll = 32 },
						{ t = 1.00, pitch = 14, roll = 16 },
					},
					legL = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.26, pitch = 26 },
						{ t = 0.54, pitch = -14 },
						{ t = 0.82, pitch = 22 },
						{ t = 1.00, pitch = 0 },
					},
					legR = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.26, pitch = -14 },
						{ t = 0.54, pitch = 26 },
						{ t = 0.82, pitch = 22 },
						{ t = 1.00, pitch = 0 },
					},
				},
			},
			action_tobatsu = {
				length = 1.5,
				mask = { legL = 0.4, legR = 0.4, root = 0.8 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 4 },
						{ t = 0.12, y = -0.13, pitch = 17 },
						{ t = 0.42, y = -0.14, pitch = 19 },
						{ t = 0.66, y = -0.05, pitch = 11 },
						{ t = 1.00, y = 0.00, pitch = 4 },
					},
					head = {
						{ t = 0.00, pitch = -6, yaw = 0 },
						{ t = 0.14, pitch = -26, yaw = -11 },
						{ t = 0.46, pitch = -17, yaw = 13 },
						{ t = 0.72, pitch = -24, yaw = -7 },
						{ t = 1.00, pitch = -6, yaw = 0 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.12, pitch = 136, roll = -12 },
						{ t = 0.48, pitch = 122, roll = -20 },
						{ t = 1.00, pitch = 15, roll = -17 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.12, pitch = 136, roll = 12 },
						{ t = 0.48, pitch = 122, roll = 20 },
						{ t = 1.00, pitch = 15, roll = 17 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.12, pitch = -36, roll = 2 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.12, pitch = -36, roll = -2 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
				},
			},
			action_resilience = {
				length = 1.8,
				mask = { legL = 0.35, legR = 0.35, root = 0.7 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 4, roll = 0 },
						{ t = 0.16, y = -0.08, pitch = -6, roll = -4 },
						{ t = 0.34, y = -0.07, pitch = -5, roll = 4 },
						{ t = 0.52, y = -0.08, pitch = -6, roll = -4 },
						{ t = 0.70, y = -0.05, pitch = -3, roll = 3 },
						{ t = 1.00, y = 0.00, pitch = 4, roll = 0 },
					},
					head = {
						{ t = 0.00, pitch = -6 },
						{ t = 0.20, pitch = -20 },
						{ t = 0.60, pitch = -16 },
						{ t = 1.00, pitch = -6 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.18, pitch = 74, roll = -34 },
						{ t = 0.44, pitch = 82, roll = -38 },
						{ t = 0.70, pitch = 70, roll = -30 },
						{ t = 1.00, pitch = 15, roll = -17 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.18, pitch = 74, roll = 34 },
						{ t = 0.44, pitch = 82, roll = 38 },
						{ t = 0.70, pitch = 70, roll = 30 },
						{ t = 1.00, pitch = 15, roll = 17 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.24, pitch = -30, roll = 4 },
						{ t = 0.68, pitch = -27, roll = 5 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.24, pitch = -30, roll = -4 },
						{ t = 0.68, pitch = -27, roll = -5 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
				},
			},
			action_kusatori = {
				length = 1.45,
				mask = { legL = 0.4, legR = 0.4, root = 0.8 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 4 },
						{ t = 0.22, y = -0.14, pitch = -14 },
						{ t = 0.44, y = -0.16, pitch = -17 },
						{ t = 0.56, y = 0.10, pitch = 16 },
						{ t = 0.74, y = -0.02, pitch = 9 },
						{ t = 1.00, y = 0.00, pitch = 4 },
					},
					head = {
						{ t = 0.00, pitch = -6 },
						{ t = 0.30, pitch = -22 },
						{ t = 0.56, pitch = 14 },
						{ t = 1.00, pitch = -6 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.30, pitch = 48, roll = -12 },
						{ t = 0.46, pitch = 58, roll = -10 },
						{ t = 0.58, pitch = 128, roll = -22 },
						{ t = 1.00, pitch = 15, roll = -17 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.30, pitch = 48, roll = 12 },
						{ t = 0.46, pitch = 58, roll = 10 },
						{ t = 0.58, pitch = 128, roll = 22 },
						{ t = 1.00, pitch = 15, roll = 17 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.44, pitch = -24, roll = 4 },
						{ t = 0.58, pitch = 26, roll = 14 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.44, pitch = -24, roll = -4 },
						{ t = 0.58, pitch = 26, roll = -14 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
				},
			},
			action_examprep = {
				length = 2.1,
				mask = { legL = 0.3, legR = 0.3, root = 0.6 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 4 },
						{ t = 0.18, y = -0.05, pitch = -8 },
						{ t = 0.44, y = -0.04, pitch = -6 },
						{ t = 0.66, y = -0.06, pitch = -9 },
						{ t = 1.00, y = 0.00, pitch = 4 },
					},
					head = {
						{ t = 0.00, pitch = -6, yaw = 0 },
						{ t = 0.20, pitch = -28, yaw = -5 },
						{ t = 0.40, pitch = -24, yaw = 6 },
						{ t = 0.60, pitch = -29, yaw = -4 },
						{ t = 0.80, pitch = -23, yaw = 5 },
						{ t = 1.00, pitch = -6, yaw = 0 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.20, pitch = 96, roll = -24 },
						{ t = 0.70, pitch = 99, roll = -26 },
						{ t = 1.00, pitch = 15, roll = -17 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.20, pitch = 96, roll = 24 },
						{ t = 0.70, pitch = 99, roll = 26 },
						{ t = 1.00, pitch = 15, roll = 17 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.24, pitch = -22, roll = 7 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.24, pitch = -22, roll = -7 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
				},
			},
			startle = {
				length = 1.05,
				mask = { legL = 0.5, legR = 0.5 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 4 },
						{ t = 0.10, y = 0.15, pitch = 15 },
						{ t = 0.30, y = 0.00, pitch = 17 },
						{ t = 0.60, y = -0.06, pitch = 10 },
						{ t = 1.00, y = 0.00, pitch = 4 },
					},
					head = {
						{ t = 0.00, pitch = -6 },
						{ t = 0.10, pitch = 14 },
						{ t = 0.35, pitch = 10 },
						{ t = 1.00, pitch = -6 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.09, pitch = 26, roll = 16 },
						{ t = 0.40, pitch = -20, roll = 4 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.09, pitch = 26, roll = -16 },
						{ t = 0.40, pitch = -20, roll = -4 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.10, pitch = 128, roll = -40 },
						{ t = 0.45, pitch = 96, roll = -30 },
						{ t = 1.00, pitch = 15, roll = -17 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.10, pitch = 128, roll = 40 },
						{ t = 0.45, pitch = 96, roll = 30 },
						{ t = 1.00, pitch = 15, roll = 17 },
					},
				},
			},
			cry = {
				length = 3.1,
				mask = { legL = 0.3, legR = 0.3 },
				tracks = {
					root = {
						{ t = 0.00, pitch = 4, y = 0 },
						{ t = 0.18, pitch = -12, y = -0.09 },
						{ t = 0.34, pitch = -9, y = -0.05, roll = -3 },
						{ t = 0.46, pitch = -12, y = -0.09, roll = 3 },
						{ t = 0.58, pitch = -9, y = -0.05, roll = -3 },
						{ t = 0.70, pitch = -12, y = -0.09, roll = 3 },
						{ t = 1.00, pitch = 4, y = 0 },
					},
					head = {
						{ t = 0.00, pitch = -6 },
						{ t = 0.20, pitch = -26 },
						{ t = 0.72, pitch = -24 },
						{ t = 1.00, pitch = -6 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.22, pitch = -34, roll = 3 },
						{ t = 0.74, pitch = -32, roll = 4 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.22, pitch = -34, roll = -3 },
						{ t = 0.74, pitch = -32, roll = -4 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.20, pitch = 132, roll = -12 },
						{ t = 0.40, pitch = 138, roll = -16 },
						{ t = 0.60, pitch = 132, roll = -10 },
						{ t = 0.78, pitch = 138, roll = -16 },
						{ t = 1.00, pitch = 15, roll = -17 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.20, pitch = 132, roll = 12 },
						{ t = 0.40, pitch = 138, roll = 16 },
						{ t = 0.60, pitch = 132, roll = 10 },
						{ t = 0.78, pitch = 138, roll = 16 },
						{ t = 1.00, pitch = 15, roll = 17 },
					},
				},
			},
			sway = {
				length = 2.4,
				mask = { legL = 0.35, legR = 0.35 },
				tracks = {
					root = {
						{ t = 0.00, roll = 0, y = 0 },
						{ t = 0.25, roll = -9, y = 0.04 },
						{ t = 0.50, roll = 0, y = 0 },
						{ t = 0.75, roll = 9, y = 0.04 },
						{ t = 1.00, roll = 0, y = 0 },
					},
					head = {
						{ t = 0.00, pitch = -6, roll = 0 },
						{ t = 0.25, pitch = 2, roll = -8 },
						{ t = 0.75, pitch = 2, roll = 8 },
						{ t = 1.00, pitch = -6, roll = 0 },
					},
					earL = {
						{ t = 0.00, pitch = -12, roll = 6 },
						{ t = 0.25, pitch = 4, roll = 14 },
						{ t = 0.75, pitch = 4, roll = -2 },
						{ t = 1.00, pitch = -12, roll = 6 },
					},
					earR = {
						{ t = 0.00, pitch = -12, roll = -6 },
						{ t = 0.25, pitch = 4, roll = 2 },
						{ t = 0.75, pitch = 4, roll = -14 },
						{ t = 1.00, pitch = -12, roll = -6 },
					},
					armL = {
						{ t = 0.00, pitch = 15, roll = -17 },
						{ t = 0.25, pitch = 52, roll = -30 },
						{ t = 0.75, pitch = 30, roll = -14 },
						{ t = 1.00, pitch = 15, roll = -17 },
					},
					armR = {
						{ t = 0.00, pitch = 15, roll = 17 },
						{ t = 0.25, pitch = 30, roll = 14 },
						{ t = 0.75, pitch = 52, roll = 30 },
						{ t = 1.00, pitch = 15, roll = 17 },
					},
				},
			},
		},
	},

	hachiware = {
		walkSpeed = 16,
		runSpeed = 30,
		tremble = {
			amplitude = 0.6,
			frequency = 3.2,
			joints = { root = 1 },
		},
		breakDelay = { 7, 15 },
		breaks = {
			{ clip = "spin", weight = 2 },
			{ clip = "read", weight = 2 },
			{ clip = "cheer", weight = 3 },
		},
		clips = {
			idle = {
				length = 2.2,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, roll = -3, pitch = 0, yaw = -4 },
						{ t = 0.25, y = 0.11, roll = 0, pitch = -2, yaw = 0 },
						{ t = 0.50, y = 0.00, roll = 3, pitch = 0, yaw = 4 },
						{ t = 0.75, y = 0.11, roll = 0, pitch = -2, yaw = 0 },
					},
				},
			},
			walk = {
				length = 0.72,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, roll = -6, pitch = -4 },
						{ t = 0.25, y = 0.18, roll = 0, pitch = -8 },
						{ t = 0.50, y = 0.00, roll = 6, pitch = -4 },
						{ t = 0.75, y = 0.18, roll = 0, pitch = -8 },
					},
				},
			},
			run = {
				length = 0.5,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, roll = -9, pitch = -10 },
						{ t = 0.25, y = 0.34, roll = 0, pitch = -16 },
						{ t = 0.50, y = 0.00, roll = 9, pitch = -10 },
						{ t = 0.75, y = 0.34, roll = 0, pitch = -16 },
					},
				},
			},
			action = {
				length = 1.6,
				mask = { root = 0.85 },
				prop = { builder = "camera", flashAt = 0.46 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 0, z = 0, yaw = 0 },
						{ t = 0.16, y = 0.05, pitch = 8, z = 0.12, yaw = 0 },
						{ t = 0.36, y = 0.02, pitch = 6, z = 0.07, yaw = 0 },
						{ t = 0.46, y = -0.05, pitch = -10, z = -0.12, yaw = 0 },
						{ t = 0.62, y = 0.13, pitch = 3, z = 0, yaw = 8 },
						{ t = 0.80, y = 0.00, pitch = 0, z = 0, yaw = -16 },
						{ t = 1.00, y = 0.00, pitch = 0, z = 0, yaw = 0 },
					},
				},
			},
			action_tobatsu = {
				length = 1.3,
				mask = { root = 0.9 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 0, roll = 0 },
						{ t = 0.12, y = -0.09, pitch = -7, roll = 0 },
						{ t = 0.30, y = 0.30, pitch = 9, roll = -7 },
						{ t = 0.48, y = 0.02, pitch = 0, roll = 6 },
						{ t = 0.64, y = 0.26, pitch = 8, roll = -5 },
						{ t = 0.82, y = 0.00, pitch = 0, roll = 3 },
						{ t = 1.00, y = 0.00, pitch = 0, roll = 0 },
					},
				},
			},
			action_resilience = {
				length = 1.5,
				mask = { root = 0.85 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 0 },
						{ t = 0.18, y = 0.12, pitch = -9 },
						{ t = 0.36, y = 0.00, pitch = 4 },
						{ t = 0.54, y = 0.12, pitch = -9 },
						{ t = 0.72, y = 0.00, pitch = 4 },
						{ t = 1.00, y = 0.00, pitch = 0 },
					},
				},
			},
			action_kusatori = {
				length = 1.6,
				mask = { root = 0.85 },
				prop = { builder = "camera", flashAt = 0.46 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 0, z = 0, yaw = 0 },
						{ t = 0.16, y = 0.05, pitch = 9, z = 0.12 },
						{ t = 0.36, y = 0.02, pitch = 6, z = 0.07 },
						{ t = 0.46, y = -0.05, pitch = -11, z = -0.13 },
						{ t = 0.62, y = 0.14, pitch = 3, z = 0, yaw = 9 },
						{ t = 0.80, y = 0.00, pitch = 0, z = 0, yaw = -17 },
						{ t = 1.00, y = 0.00, pitch = 0, z = 0, yaw = 0 },
					},
				},
			},
			action_examprep = {
				length = 2.4,
				mask = { root = 0.8 },
				prop = { builder = "book" },
				tracks = {
					root = {
						{ t = 0.00, pitch = 0, y = 0, roll = 0 },
						{ t = 0.14, pitch = -15, y = -0.04, roll = 0 },
						{ t = 0.38, pitch = -13, y = -0.01, roll = -3 },
						{ t = 0.60, pitch = -16, y = -0.05, roll = 3 },
						{ t = 0.82, pitch = -12, y = -0.02, roll = -2 },
						{ t = 1.00, pitch = 0, y = 0, roll = 0 },
					},
				},
			},
			spin = {
				length = 1.5,
				mask = { root = 0.9 },
				tracks = {
					root = {
						{ t = 0.00, yaw = 0, y = 0.00, roll = 0 },
						{ t = 0.14, yaw = -20, y = -0.07, roll = 0 },
						{ t = 0.30, yaw = 90, y = 0.20, roll = -8 },
						{ t = 0.55, yaw = 210, y = 0.24, roll = 0 },
						{ t = 0.80, yaw = 330, y = 0.10, roll = 8 },
						{ t = 1.00, yaw = 360, y = 0.00, roll = 0 },
					},
				},
			},
			read = {
				length = 3.4,
				mask = { root = 0.8 },
				prop = { builder = "book" },
				tracks = {
					root = {
						{ t = 0.00, pitch = 0, y = 0, roll = 0 },
						{ t = 0.14, pitch = -14, y = -0.04, roll = 0 },
						{ t = 0.36, pitch = -13, y = -0.02, roll = -3 },
						{ t = 0.58, pitch = -15, y = -0.05, roll = 3 },
						{ t = 0.78, pitch = -12, y = -0.02, roll = -2 },
						{ t = 1.00, pitch = 0, y = 0, roll = 0 },
					},
				},
			},
			cheer = {
				length = 1.35,
				mask = { root = 0.9 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 0, roll = 0 },
						{ t = 0.14, y = -0.10, pitch = -8, roll = 0 },
						{ t = 0.34, y = 0.32, pitch = 10, roll = -6 },
						{ t = 0.54, y = 0.02, pitch = 0, roll = 6 },
						{ t = 0.72, y = 0.22, pitch = 8, roll = -4 },
						{ t = 1.00, y = 0.00, pitch = 0, roll = 0 },
					},
				},
			},
		},
	},

	usagi = {
		walkSpeed = 16,
		runSpeed = 30,
		tremble = {
			amplitude = 1.1,
			frequency = 5.5,
			joints = { earL = 1, earR = 1, root = 0.2 },
		},
		breakDelay = { 4, 9 },
		breaks = {
			{ clip = "earTwitch", weight = 4 },
			{ clip = "lookAround", weight = 3 },
			{ clip = "stomp", weight = 2 },
		},
		clips = {
			idle = {
				length = 3.0,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, pitch = -4, yaw = 0, y = 0 },
						{ t = 0.30, pitch = -5, yaw = -15, y = 0.01 },
						{ t = 0.46, pitch = -5, yaw = -15, y = 0 },
						{ t = 0.64, pitch = -4, yaw = 17, y = 0.01 },
						{ t = 0.86, pitch = -4, yaw = 17, y = 0 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.16, pitch = -16, roll = -9 },
						{ t = 0.23, pitch = -2, roll = -3 },
						{ t = 0.58, pitch = 0, roll = -3 },
						{ t = 0.66, pitch = -13, roll = -8 },
						{ t = 0.73, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.34, pitch = -15, roll = 9 },
						{ t = 0.41, pitch = -1, roll = 3 },
						{ t = 0.80, pitch = 0, roll = 3 },
						{ t = 0.88, pitch = -12, roll = 8 },
						{ t = 0.95, pitch = 0, roll = 3 },
					},
					armL = {
						{ t = 0.00, pitch = 6, roll = -8 },
						{ t = 0.50, pitch = 9, roll = -11 },
					},
					armR = {
						{ t = 0.00, pitch = 6, roll = 8 },
						{ t = 0.50, pitch = 9, roll = 11 },
					},
					legL = {
						{ t = 0.00, pitch = 1 },
						{ t = 0.50, pitch = -1 },
					},
					legR = {
						{ t = 0.00, pitch = -1 },
						{ t = 0.50, pitch = 1 },
					},
				},
			},
			walk = {
				length = 0.7,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -6, roll = -3 },
						{ t = 0.25, y = 0.07, pitch = -7, roll = 0 },
						{ t = 0.50, y = 0.00, pitch = -6, roll = 3 },
						{ t = 0.75, y = 0.07, pitch = -7, roll = 0 },
					},
					earL = {
						{ t = 0.00, pitch = 4, roll = -4 },
						{ t = 0.25, pitch = 16, roll = -7 },
						{ t = 0.50, pitch = 4, roll = -4 },
						{ t = 0.75, pitch = 16, roll = -7 },
					},
					earR = {
						{ t = 0.00, pitch = 4, roll = 4 },
						{ t = 0.25, pitch = 16, roll = 7 },
						{ t = 0.50, pitch = 4, roll = 4 },
						{ t = 0.75, pitch = 16, roll = 7 },
					},
					armL = {
						{ t = 0.00, pitch = 34, roll = -10 },
						{ t = 0.50, pitch = -28, roll = -8 },
					},
					armR = {
						{ t = 0.00, pitch = -28, roll = 8 },
						{ t = 0.50, pitch = 34, roll = 10 },
					},
					legL = {
						{ t = 0.00, pitch = -30 },
						{ t = 0.50, pitch = 34 },
					},
					legR = {
						{ t = 0.00, pitch = 34 },
						{ t = 0.50, pitch = -30 },
					},
				},
			},
			run = {
				length = 0.46,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -10 },
						{ t = 0.22, y = 0.30, pitch = -18 },
						{ t = 0.46, y = 0.32, pitch = -6 },
						{ t = 0.70, y = 0.02, pitch = -12 },
						{ t = 0.86, y = -0.06, pitch = -14 },
					},
					earL = {
						{ t = 0.00, pitch = 12, roll = -5 },
						{ t = 0.30, pitch = 30, roll = -10 },
						{ t = 0.70, pitch = 8, roll = -4 },
					},
					earR = {
						{ t = 0.00, pitch = 12, roll = 5 },
						{ t = 0.30, pitch = 30, roll = 10 },
						{ t = 0.70, pitch = 8, roll = 4 },
					},
					armL = {
						{ t = 0.00, pitch = 40, roll = -14 },
						{ t = 0.30, pitch = -34, roll = -10 },
						{ t = 0.70, pitch = 20, roll = -12 },
					},
					armR = {
						{ t = 0.00, pitch = 40, roll = 14 },
						{ t = 0.30, pitch = -34, roll = 10 },
						{ t = 0.70, pitch = 20, roll = 12 },
					},
					legL = {
						{ t = 0.00, pitch = -34 },
						{ t = 0.26, pitch = 44 },
						{ t = 0.62, pitch = -22 },
					},
					legR = {
						{ t = 0.00, pitch = -34 },
						{ t = 0.26, pitch = 44 },
						{ t = 0.62, pitch = -22 },
					},
				},
			},
			action = {
				length = 1.15,
				mask = { legL = 0.35, legR = 0.35, root = 0.8 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -4 },
						{ t = 0.18, y = -0.11, pitch = -16 },
						{ t = 0.34, y = 0.17, pitch = 12 },
						{ t = 0.52, y = 0.05, pitch = 7 },
						{ t = 1.00, y = 0.00, pitch = -4 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.18, pitch = -18, roll = -2 },
						{ t = 0.34, pitch = 32, roll = -24 },
						{ t = 0.60, pitch = 12, roll = -12 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.18, pitch = -18, roll = 2 },
						{ t = 0.34, pitch = 32, roll = 24 },
						{ t = 0.60, pitch = 12, roll = 12 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
					armL = {
						{ t = 0.00, pitch = 6, roll = -8 },
						{ t = 0.18, pitch = -34, roll = -4 },
						{ t = 0.34, pitch = 152, roll = -22 },
						{ t = 0.56, pitch = 132, roll = -12 },
						{ t = 1.00, pitch = 6, roll = -8 },
					},
					armR = {
						{ t = 0.00, pitch = 6, roll = 8 },
						{ t = 0.18, pitch = -34, roll = 4 },
						{ t = 0.34, pitch = 152, roll = 22 },
						{ t = 0.56, pitch = 132, roll = 12 },
						{ t = 1.00, pitch = 6, roll = 8 },
					},
					legL = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.18, pitch = -24 },
						{ t = 0.34, pitch = 20 },
						{ t = 1.00, pitch = 0 },
					},
					legR = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.18, pitch = -24 },
						{ t = 0.34, pitch = 20 },
						{ t = 1.00, pitch = 0 },
					},
				},
			},
			action_tobatsu = {
				length = 1.25,
				mask = { legL = 0.35, legR = 0.35, root = 0.8 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -4, yaw = 0 },
						{ t = 0.14, y = -0.08, pitch = -14, yaw = 10 },
						{ t = 0.28, y = 0.06, pitch = 8, yaw = -12 },
						{ t = 0.46, y = 0.02, pitch = -2, yaw = 12 },
						{ t = 0.62, y = 0.08, pitch = 9, yaw = -10 },
						{ t = 1.00, y = 0.00, pitch = -4, yaw = 0 },
					},
					armR = {
						{ t = 0.00, pitch = 6, roll = 8 },
						{ t = 0.14, pitch = -34, roll = 6 },
						{ t = 0.28, pitch = 128, roll = 16 },
						{ t = 0.44, pitch = 20, roll = 8 },
						{ t = 0.62, pitch = 132, roll = 14 },
						{ t = 1.00, pitch = 6, roll = 8 },
					},
					armL = {
						{ t = 0.00, pitch = 6, roll = -8 },
						{ t = 0.14, pitch = 118, roll = -14 },
						{ t = 0.30, pitch = 26, roll = -8 },
						{ t = 0.48, pitch = 124, roll = -16 },
						{ t = 1.00, pitch = 6, roll = -8 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.16, pitch = 28, roll = -20 },
						{ t = 0.50, pitch = 14, roll = -10 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.16, pitch = 28, roll = 20 },
						{ t = 0.50, pitch = 14, roll = 10 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
				},
			},
			action_resilience = {
				length = 1.35,
				mask = { root = 0.75 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -4 },
						{ t = 0.16, y = -0.10, pitch = -16 },
						{ t = 0.34, y = -0.08, pitch = -13 },
						{ t = 0.52, y = 0.06, pitch = 6 },
						{ t = 1.00, y = 0.00, pitch = -4 },
					},
					legR = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.22, pitch = 50 },
						{ t = 0.34, pitch = -20 },
						{ t = 0.50, pitch = 0 },
						{ t = 1.00, pitch = 0 },
					},
					armL = {
						{ t = 0.00, pitch = 6, roll = -8 },
						{ t = 0.20, pitch = 64, roll = -30 },
						{ t = 0.56, pitch = 56, roll = -26 },
						{ t = 1.00, pitch = 6, roll = -8 },
					},
					armR = {
						{ t = 0.00, pitch = 6, roll = 8 },
						{ t = 0.20, pitch = 64, roll = 30 },
						{ t = 0.56, pitch = 56, roll = 26 },
						{ t = 1.00, pitch = 6, roll = 8 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.18, pitch = -18, roll = -8 },
						{ t = 0.38, pitch = 24, roll = -16 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.18, pitch = -18, roll = 8 },
						{ t = 0.38, pitch = 24, roll = 16 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
				},
			},
			action_kusatori = {
				length = 1.1,
				mask = { legL = 0.4, legR = 0.4, root = 0.8 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -4 },
						{ t = 0.20, y = -0.12, pitch = -22 },
						{ t = 0.40, y = -0.13, pitch = -24 },
						{ t = 0.52, y = 0.10, pitch = 14 },
						{ t = 1.00, y = 0.00, pitch = -4 },
					},
					armR = {
						{ t = 0.00, pitch = 6, roll = 8 },
						{ t = 0.24, pitch = 62, roll = 6 },
						{ t = 0.42, pitch = 72, roll = 5 },
						{ t = 0.54, pitch = -46, roll = 12 },
						{ t = 1.00, pitch = 6, roll = 8 },
					},
					armL = {
						{ t = 0.00, pitch = 6, roll = -8 },
						{ t = 0.24, pitch = 30, roll = -16 },
						{ t = 0.54, pitch = -26, roll = -22 },
						{ t = 1.00, pitch = 6, roll = -8 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.40, pitch = -20, roll = -6 },
						{ t = 0.54, pitch = 30, roll = -18 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.40, pitch = -20, roll = 6 },
						{ t = 0.54, pitch = 30, roll = 18 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
				},
			},
			action_examprep = {
				length = 1.7,
				mask = { legL = 0.3, legR = 0.3, root = 0.8 },
				tracks = {
					root = {
						{ t = 0.00, pitch = -4, yaw = 0 },
						{ t = 0.16, pitch = -6, yaw = -20 },
						{ t = 0.36, pitch = -6, yaw = -20 },
						{ t = 0.52, pitch = -4, yaw = 18 },
						{ t = 0.74, pitch = -4, yaw = 18 },
						{ t = 1.00, pitch = -4, yaw = 0 },
					},
					armR = {
						{ t = 0.00, pitch = 6, roll = 8 },
						{ t = 0.16, pitch = 96, roll = 10 },
						{ t = 0.40, pitch = 104, roll = 8 },
						{ t = 0.60, pitch = 88, roll = 12 },
						{ t = 1.00, pitch = 6, roll = 8 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.14, pitch = -22, roll = -12 },
						{ t = 0.30, pitch = -2, roll = -3 },
						{ t = 0.56, pitch = -18, roll = -10 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.22, pitch = -20, roll = 11 },
						{ t = 0.38, pitch = -1, roll = 3 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
				},
			},
			earTwitch = {
				length = 0.8,
				mask = { root = 0.4 },
				tracks = {
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.12, pitch = -26, roll = -14 },
						{ t = 0.24, pitch = 4, roll = -1 },
						{ t = 0.40, pitch = -18, roll = -10 },
						{ t = 0.55, pitch = 0, roll = -3 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.20, pitch = -22, roll = 12 },
						{ t = 0.34, pitch = 2, roll = 2 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
					root = {
						{ t = 0.00, yaw = 0 },
						{ t = 0.16, yaw = -7 },
						{ t = 0.44, yaw = 5 },
						{ t = 1.00, yaw = 0 },
					},
				},
			},
			lookAround = {
				length = 1.7,
				mask = { legL = 0.3, legR = 0.3, root = 0.85 },
				tracks = {
					root = {
						{ t = 0.00, yaw = 0, pitch = -4 },
						{ t = 0.14, yaw = -42, pitch = -6 },
						{ t = 0.34, yaw = -42, pitch = -6 },
						{ t = 0.46, yaw = 44, pitch = -6 },
						{ t = 0.68, yaw = 44, pitch = -6 },
						{ t = 0.82, yaw = 0, pitch = -4 },
						{ t = 1.00, yaw = 0, pitch = -4 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.14, pitch = -20, roll = -12 },
						{ t = 0.46, pitch = -6, roll = -4 },
						{ t = 0.68, pitch = -20, roll = -12 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.14, pitch = -6, roll = 4 },
						{ t = 0.46, pitch = -20, roll = 12 },
						{ t = 0.68, pitch = -6, roll = 4 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
				},
			},
			stomp = {
				length = 0.95,
				mask = { root = 0.7 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -4 },
						{ t = 0.20, y = 0.10, pitch = -12 },
						{ t = 0.34, y = -0.05, pitch = 4 },
						{ t = 0.50, y = 0.00, pitch = -2 },
						{ t = 1.00, y = 0.00, pitch = -4 },
					},
					legR = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.20, pitch = 52 },
						{ t = 0.32, pitch = -18 },
						{ t = 0.48, pitch = 0 },
						{ t = 1.00, pitch = 0 },
					},
					earL = {
						{ t = 0.00, pitch = 0, roll = -3 },
						{ t = 0.20, pitch = -14, roll = -8 },
						{ t = 0.36, pitch = 22, roll = -14 },
						{ t = 1.00, pitch = 0, roll = -3 },
					},
					earR = {
						{ t = 0.00, pitch = 0, roll = 3 },
						{ t = 0.20, pitch = -14, roll = 8 },
						{ t = 0.36, pitch = 22, roll = 14 },
						{ t = 1.00, pitch = 0, roll = 3 },
					},
				},
			},
		},
	},

	yoroi = {
		walkSpeed = 12,
		runSpeed = 20,
		tremble = {
			amplitude = 0.35,
			frequency = 0.8,
			joints = { root = 0.5, armL = 1, armR = 1, head = 0.4 },
		},
		breakDelay = { 7, 16 },
		breaks = {
			{ clip = "survey", weight = 3 },
			{ clip = "stamp", weight = 2 },
			{ clip = "beckon", weight = 2 },
		},
		clips = {
			idle = {
				length = 5.4,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 1.5, roll = -0.8 },
						{ t = 0.30, y = -0.06, pitch = 2.5, roll = 0 },
						{ t = 0.55, y = 0.00, pitch = 1.5, roll = 0.8 },
						{ t = 0.80, y = -0.06, pitch = 2.5, roll = 0 },
					},
					head = {
						{ t = 0.00, pitch = 2, yaw = -5 },
						{ t = 0.35, pitch = 0, yaw = -6 },
						{ t = 0.60, pitch = 3, yaw = 6 },
						{ t = 0.85, pitch = 1, yaw = 4 },
					},
					armL = {
						{ t = 0.00, pitch = 26, roll = -9 },
						{ t = 0.50, pitch = 29, roll = -11 },
					},
					armR = {
						{ t = 0.00, pitch = 29, roll = 9 },
						{ t = 0.50, pitch = 26, roll = 11 },
					},
					legL = { { t = 0.00, pitch = 0 } },
					legR = { { t = 0.00, pitch = 0 } },
				},
			},
			walk = {
				length = 1.0,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, roll = -2 },
						{ t = 0.50, y = 0.06, roll = 2 },
					},
					armL = { { t = 0.00, pitch = 18 }, { t = 0.50, pitch = -14 } },
					armR = { { t = 0.00, pitch = -14 }, { t = 0.50, pitch = 18 } },
					legL = { { t = 0.00, pitch = 20 }, { t = 0.50, pitch = -18 } },
					legR = { { t = 0.00, pitch = -18 }, { t = 0.50, pitch = 20 } },
				},
			},
			run = {
				length = 0.7,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = -6 },
						{ t = 0.50, y = 0.14, pitch = -6 },
					},
					armL = { { t = 0.00, pitch = 42 }, { t = 0.50, pitch = -30 } },
					armR = { { t = 0.00, pitch = -30 }, { t = 0.50, pitch = 42 } },
					legL = { { t = 0.00, pitch = 34 }, { t = 0.50, pitch = -30 } },
					legR = { { t = 0.00, pitch = -30 }, { t = 0.50, pitch = 34 } },
				},
			},
			action = {
				length = 1.4,
				mask = { legL = 0.2, legR = 0.2 },
				tracks = {
					root = {
						{ t = 0.00, pitch = 1.5 },
						{ t = 0.30, pitch = 9 },
						{ t = 1.00, pitch = 1.5 },
					},
					armR = {
						{ t = 0.00, pitch = 29, roll = 9 },
						{ t = 0.28, pitch = 96, roll = 16 },
						{ t = 0.55, pitch = 74, roll = 12 },
						{ t = 1.00, pitch = 29, roll = 9 },
					},
					head = {
						{ t = 0.00, pitch = 2 },
						{ t = 0.30, pitch = 12 },
						{ t = 1.00, pitch = 2 },
					},
				},
			},
			survey = {
				length = 4.2,
				mask = { legL = 0.15, legR = 0.15, root = 0.5 },
				tracks = {
					root = {
						{ t = 0.00, pitch = 1.5, yaw = 0 },
						{ t = 0.22, pitch = -2, yaw = -13 },
						{ t = 0.44, pitch = -2, yaw = -13 },
						{ t = 0.60, pitch = -2, yaw = 14 },
						{ t = 0.82, pitch = -2, yaw = 14 },
						{ t = 1.00, pitch = 1.5, yaw = 0 },
					},
					head = {
						{ t = 0.00, pitch = 2, yaw = 0 },
						{ t = 0.18, pitch = -9, yaw = -22 },
						{ t = 0.46, pitch = -9, yaw = -22 },
						{ t = 0.58, pitch = -9, yaw = 24 },
						{ t = 0.84, pitch = -7, yaw = 24 },
						{ t = 1.00, pitch = 2, yaw = 0 },
					},
					armL = {
						{ t = 0.00, pitch = 26, roll = -9 },
						{ t = 0.30, pitch = 20, roll = -13 },
						{ t = 1.00, pitch = 26, roll = -9 },
					},
				},
			},
			stamp = {
				length = 2.0,
				mask = { legL = 0.1, legR = 0.1, root = 0.6 },
				tracks = {
					root = {
						{ t = 0.00, y = 0.00, pitch = 1.5 },
						{ t = 0.30, y = -0.05, pitch = 8 },
						{ t = 0.44, y = -0.09, pitch = 12 },
						{ t = 0.70, y = -0.03, pitch = 6 },
						{ t = 1.00, y = 0.00, pitch = 1.5 },
					},
					armR = {
						{ t = 0.00, pitch = 29, roll = 9 },
						{ t = 0.22, pitch = 74, roll = 14 },
						{ t = 0.42, pitch = 22, roll = 7 },
						{ t = 0.58, pitch = 66, roll = 12 },
						{ t = 0.74, pitch = 24, roll = 7 },
						{ t = 1.00, pitch = 29, roll = 9 },
					},
					head = {
						{ t = 0.00, pitch = 2 },
						{ t = 0.30, pitch = 16 },
						{ t = 0.74, pitch = 14 },
						{ t = 1.00, pitch = 2 },
					},
				},
			},
			beckon = {
				length = 2.4,
				mask = { legL = 0.1, legR = 0.1, root = 0.6 },
				tracks = {
					root = {
						{ t = 0.00, pitch = 1.5, yaw = 0 },
						{ t = 0.25, pitch = 5, yaw = 7 },
						{ t = 0.70, pitch = 4, yaw = 6 },
						{ t = 1.00, pitch = 1.5, yaw = 0 },
					},
					armR = {
						{ t = 0.00, pitch = 29, roll = 9 },
						{ t = 0.18, pitch = 122, roll = 26 },
						{ t = 0.38, pitch = 106, roll = 14 },
						{ t = 0.56, pitch = 124, roll = 28 },
						{ t = 0.74, pitch = 104, roll = 14 },
						{ t = 1.00, pitch = 29, roll = 9 },
					},
					head = {
						{ t = 0.00, pitch = 2, yaw = 0 },
						{ t = 0.24, pitch = -4, yaw = 10 },
						{ t = 0.72, pitch = -3, yaw = 8 },
						{ t = 1.00, pitch = 2, yaw = 0 },
					},
				},
			},
		},
	},
} :: { [string]: Set }

function CompanionAnims.get(id: string): Set?
	return CompanionAnims.SETS[id]
end

return CompanionAnims

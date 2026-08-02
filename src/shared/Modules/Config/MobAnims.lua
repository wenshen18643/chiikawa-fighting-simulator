--!strict

local MobAnims = {}

MobAnims.SETS = {
	mushroomFrog = {
		walkSpeed = 6,
		runSpeed = 12,
		clips = {
			idle = {
				length = 2.2,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 1 },
						{ t = 0.50, y = 0.08, pitch = -2 },
					},
					head = {
						{ t = 0.00, pitch = -2, yaw = -4 },
						{ t = 0.50, pitch = 2, yaw = 4 },
					},
					hat = {
						{ t = 0.00, y = 0, roll = -2 },
						{ t = 0.50, y = 0.04, roll = 2 },
					},
				},
			},
			walk = {
				length = 0.72,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, roll = -4 },
						{ t = 0.25, y = 0.16, roll = 0 },
						{ t = 0.50, y = 0, roll = 4 },
						{ t = 0.75, y = 0.16, roll = 0 },
					},
					legL = { { t = 0.00, pitch = 24 }, { t = 0.50, pitch = -20 } },
					legR = { { t = 0.00, pitch = -20 }, { t = 0.50, pitch = 24 } },
					armL = { { t = 0.00, pitch = -12 }, { t = 0.50, pitch = 14 } },
					armR = { { t = 0.00, pitch = 14 }, { t = 0.50, pitch = -12 } },
					hat = {
						{ t = 0.00, pitch = -5, roll = -4 },
						{ t = 0.50, pitch = 5, roll = 4 },
					},
				},
			},
			run = {
				length = 0.46,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 5, roll = -7 },
						{ t = 0.25, y = 0.28, pitch = 9, roll = 0 },
						{ t = 0.50, y = 0, pitch = 5, roll = 7 },
						{ t = 0.75, y = 0.28, pitch = 9, roll = 0 },
					},
					legL = { { t = 0.00, pitch = 38 }, { t = 0.50, pitch = -34 } },
					legR = { { t = 0.00, pitch = -34 }, { t = 0.50, pitch = 38 } },
					armL = { { t = 0.00, pitch = -24 }, { t = 0.50, pitch = 26 } },
					armR = { { t = 0.00, pitch = 26 }, { t = 0.50, pitch = -24 } },
					hat = {
						{ t = 0.00, pitch = -12, roll = -7 },
						{ t = 0.50, pitch = 10, roll = 7 },
					},
				},
			},
			attack = {
				length = 0.58,
				tracks = {
					root = {
						{ t = 0.00, z = 0, pitch = 0 },
						{ t = 0.22, z = 0.16, pitch = -10 },
						{ t = 0.48, z = -0.5, pitch = 18 },
						{ t = 1.00, z = 0, pitch = 0 },
					},
					head = { { t = 0.00, pitch = 0 }, { t = 0.48, pitch = -18 }, { t = 1.00, pitch = 0 } },
					hat = { { t = 0.00, pitch = 0 }, { t = 0.48, pitch = 22 }, { t = 1.00, pitch = 0 } },
				},
			},
			hit = {
				length = 0.38,
				tracks = {
					root = {
						{ t = 0.00, z = 0, pitch = 0 },
						{ t = 0.28, z = 0.34, pitch = -14, roll = 8 },
						{ t = 1.00, z = 0, pitch = 0, roll = 0 },
					},
					hat = {
						{ t = 0.00, y = 0, roll = 0 },
						{ t = 0.24, y = 0.22, roll = -14 },
						{ t = 1.00, y = 0, roll = 0 },
					},
				},
			},
		},
	},
	duck = {
		walkSpeed = 6,
		runSpeed = 15,
		clips = {
			idle = {
				length = 1.8,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0, roll = -1 }, { t = 0.50, y = 0.05, roll = 1 } },
					head = { { t = 0.00, pitch = -3, yaw = -5 }, { t = 0.50, pitch = 3, yaw = 5 } },
					armL = { { t = 0.00, roll = -2 }, { t = 0.50, roll = 3 } },
					armR = { { t = 0.00, roll = 2 }, { t = 0.50, roll = -3 } },
				},
			},
			walk = {
				length = 0.68,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, roll = -5 },
						{ t = 0.25, y = 0.1, roll = 0 },
						{ t = 0.50, y = 0, roll = 5 },
						{ t = 0.75, y = 0.1, roll = 0 },
					},
					legL = { { t = 0.00, pitch = 25 }, { t = 0.50, pitch = -22 } },
					legR = { { t = 0.00, pitch = -22 }, { t = 0.50, pitch = 25 } },
					armL = { { t = 0.00, roll = -8 }, { t = 0.50, roll = 8 } },
					armR = { { t = 0.00, roll = 8 }, { t = 0.50, roll = -8 } },
					head = { { t = 0.00, yaw = -3 }, { t = 0.50, yaw = 3 } },
				},
			},
			run = {
				length = 0.4,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 6, roll = -9 },
						{ t = 0.25, y = 0.2, pitch = 10, roll = 0 },
						{ t = 0.50, y = 0, pitch = 6, roll = 9 },
						{ t = 0.75, y = 0.2, pitch = 10, roll = 0 },
					},
					legL = { { t = 0.00, pitch = 38 }, { t = 0.50, pitch = -34 } },
					legR = { { t = 0.00, pitch = -34 }, { t = 0.50, pitch = 38 } },
					armL = { { t = 0.00, roll = -22 }, { t = 0.50, roll = 22 } },
					armR = { { t = 0.00, roll = 22 }, { t = 0.50, roll = -22 } },
					head = { { t = 0.00, pitch = -5 }, { t = 0.50, pitch = 7 } },
				},
			},
			hit = {
				length = 0.38,
				tracks = {
					root = {
						{ t = 0.00, z = 0, roll = 0 },
						{ t = 0.28, z = 0.28, roll = 12 },
						{ t = 1.00, z = 0, roll = 0 },
					},
					head = { { t = 0.00, pitch = 0 }, { t = 0.28, pitch = -16 }, { t = 1.00, pitch = 0 } },
					armL = { { t = 0.00, roll = 0 }, { t = 0.28, roll = -28 }, { t = 1.00, roll = 0 } },
					armR = { { t = 0.00, roll = 0 }, { t = 0.28, roll = 28 }, { t = 1.00, roll = 0 } },
				},
			},
		},
	},
	sausageGuardian = {
		walkSpeed = 5,
		runSpeed = 13,
		clips = {
			idle = {
				length = 2.6,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0, roll = -2 }, { t = 0.50, y = 0.06, roll = 2 } },
					armL = { { t = 0.00, roll = -6 }, { t = 0.50, roll = 6 } },
					armR = { { t = 0.00, roll = 6 }, { t = 0.50, roll = -6 } },
				},
			},
			walk = {
				length = 0.78,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 0 },
						{ t = 0.30, y = 0.42, pitch = -10 },
						{ t = 0.62, y = 0, pitch = 8 },
						{ t = 1.00, y = 0, pitch = 0 },
					},
					armL = { { t = 0.00, roll = -10 }, { t = 0.30, roll = -34 }, { t = 1.00, roll = -10 } },
					armR = { { t = 0.00, roll = 10 }, { t = 0.30, roll = 34 }, { t = 1.00, roll = 10 } },
				},
			},
			run = {
				length = 0.5,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 6 },
						{ t = 0.30, y = 0.7, pitch = -16 },
						{ t = 0.62, y = 0, pitch = 14 },
						{ t = 1.00, y = 0, pitch = 6 },
					},
					armL = { { t = 0.00, roll = -16 }, { t = 0.30, roll = -52 }, { t = 1.00, roll = -16 } },
					armR = { { t = 0.00, roll = 16 }, { t = 0.30, roll = 52 }, { t = 1.00, roll = 16 } },
				},
			},
			attack = {
				length = 0.62,
				tracks = {
					root = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.24, pitch = -14 },
						{ t = 0.52, pitch = 26 },
						{ t = 1.00, pitch = 0 },
					},
					armL = { { t = 0.00, pitch = 0 }, { t = 0.52, pitch = -70 }, { t = 1.00, pitch = 0 } },
					armR = { { t = 0.00, pitch = 0 }, { t = 0.52, pitch = -70 }, { t = 1.00, pitch = 0 } },
				},
			},
			hit = {
				length = 0.36,
				tracks = {
					root = {
						{ t = 0.00, pitch = 0, roll = 0 },
						{ t = 0.28, pitch = 12, roll = -10 },
						{ t = 1.00, pitch = 0, roll = 0 },
					},
					armL = { { t = 0.00, roll = 0 }, { t = 0.28, roll = -26 }, { t = 1.00, roll = 0 } },
					armR = { { t = 0.00, roll = 0 }, { t = 0.28, roll = 26 }, { t = 1.00, roll = 0 } },
				},
			},
		},
	},
	wolf = {
		walkSpeed = 9,
		runSpeed = 17,
		clips = {
			idle = {
				length = 2,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0, roll = -1 }, { t = 0.50, y = 0.05, roll = 1 } },
					head = { { t = 0.00, pitch = -2, yaw = -4 }, { t = 0.50, pitch = 3, yaw = 4 } },
					tail = { { t = 0.00, yaw = -12 }, { t = 0.50, yaw = 12 } },
					earL = { { t = 0.00, roll = -2 }, { t = 0.50, roll = 4 } },
					earR = { { t = 0.00, roll = 2 }, { t = 0.50, roll = -4 } },
				},
			},
			walk = {
				length = 0.58,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, roll = -3 },
						{ t = 0.25, y = 0.1, roll = 0 },
						{ t = 0.50, y = 0, roll = 3 },
						{ t = 0.75, y = 0.1, roll = 0 },
					},
					frontL = { { t = 0.00, pitch = 24 }, { t = 0.50, pitch = -22 } },
					frontR = { { t = 0.00, pitch = -22 }, { t = 0.50, pitch = 24 } },
					backL = { { t = 0.00, pitch = -22 }, { t = 0.50, pitch = 24 } },
					backR = { { t = 0.00, pitch = 24 }, { t = 0.50, pitch = -22 } },
					head = { { t = 0.00, yaw = -2 }, { t = 0.50, yaw = 2 } },
					tail = { { t = 0.00, yaw = -9 }, { t = 0.50, yaw = 9 } },
				},
			},
			run = {
				length = 0.36,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 4, roll = -5 },
						{ t = 0.25, y = 0.2, pitch = 8, roll = 0 },
						{ t = 0.50, y = 0, pitch = 4, roll = 5 },
						{ t = 0.75, y = 0.2, pitch = 8, roll = 0 },
					},
					frontL = { { t = 0.00, pitch = 38 }, { t = 0.50, pitch = -34 } },
					frontR = { { t = 0.00, pitch = -34 }, { t = 0.50, pitch = 38 } },
					backL = { { t = 0.00, pitch = -34 }, { t = 0.50, pitch = 38 } },
					backR = { { t = 0.00, pitch = 38 }, { t = 0.50, pitch = -34 } },
					head = { { t = 0.00, pitch = -4 }, { t = 0.50, pitch = 6 } },
					tail = { { t = 0.00, pitch = 8, yaw = -14 }, { t = 0.50, pitch = 8, yaw = 14 } },
				},
			},
			attack = {
				length = 0.58,
				tracks = {
					root = {
						{ t = 0.00, z = 0, pitch = 0 },
						{ t = 0.24, z = 0.18, pitch = -8 },
						{ t = 0.52, z = -0.62, pitch = 16 },
						{ t = 1.00, z = 0, pitch = 0 },
					},
					head = { { t = 0.00, pitch = 0 }, { t = 0.52, pitch = -18 }, { t = 1.00, pitch = 0 } },
					frontL = { { t = 0.00, pitch = 0 }, { t = 0.52, pitch = -24 }, { t = 1.00, pitch = 0 } },
					frontR = { { t = 0.00, pitch = 0 }, { t = 0.52, pitch = -24 }, { t = 1.00, pitch = 0 } },
				},
			},
			hit = {
				length = 0.4,
				tracks = {
					root = {
						{ t = 0.00, z = 0, pitch = 0, roll = 0 },
						{ t = 0.3, z = 0.3, pitch = -9, roll = 11 },
						{ t = 1.00, z = 0, pitch = 0, roll = 0 },
					},
					head = { { t = 0.00, yaw = 0 }, { t = 0.3, yaw = -15 }, { t = 1.00, yaw = 0 } },
					tail = { { t = 0.00, pitch = 0 }, { t = 0.3, pitch = -18 }, { t = 1.00, pitch = 0 } },
				},
			},
		},
	},

	caveSporeling = {
		walkSpeed = 6,
		runSpeed = 11,
		clips = {
			idle = {
				length = 2.6,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0 }, { t = 0.50, y = 0.06 } },
					head = {
						{ t = 0.00, roll = -5, pitch = -2 },
						{ t = 0.50, roll = 5, pitch = 2 },
					},
				},
			},
			walk = {
				length = 0.78,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, roll = -5 },
						{ t = 0.25, y = 0.18, roll = 0 },
						{ t = 0.50, y = 0, roll = 5 },
						{ t = 0.75, y = 0.18, roll = 0 },
					},
					head = { { t = 0.00, roll = 9 }, { t = 0.50, roll = -9 } },
					legL = { { t = 0.00, pitch = 26 }, { t = 0.50, pitch = -22 } },
					legR = { { t = 0.00, pitch = -22 }, { t = 0.50, pitch = 26 } },
				},
			},
			run = {
				length = 0.48,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 6, roll = -9 },
						{ t = 0.25, y = 0.3, pitch = 10, roll = 0 },
						{ t = 0.50, y = 0, pitch = 6, roll = 9 },
						{ t = 0.75, y = 0.3, pitch = 10, roll = 0 },
					},
					head = { { t = 0.00, roll = 16, pitch = -8 }, { t = 0.50, roll = -16, pitch = -8 } },
					legL = { { t = 0.00, pitch = 40 }, { t = 0.50, pitch = -36 } },
					legR = { { t = 0.00, pitch = -36 }, { t = 0.50, pitch = 40 } },
				},
			},
			attack = {
				length = 0.62,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 0 },
						{ t = 0.30, y = -0.22, pitch = -14 },
						{ t = 0.52, y = 0.18, pitch = 20 },
						{ t = 1.00, y = 0, pitch = 0 },
					},
					head = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.30, pitch = -26 },
						{ t = 0.52, pitch = 30 },
						{ t = 1.00, pitch = 0 },
					},
				},
			},
			hit = {
				length = 0.36,
				tracks = {
					root = {
						{ t = 0.00, z = 0, roll = 0 },
						{ t = 0.28, z = 0.3, roll = 12 },
						{ t = 1.00, z = 0, roll = 0 },
					},
					head = { { t = 0.00, roll = 0 }, { t = 0.28, roll = -22 }, { t = 1.00, roll = 0 } },
				},
			},
		},
	},
	cavePebblejaw = {
		walkSpeed = 7,
		runSpeed = 15,
		clips = {
			idle = {
				length = 3,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0 }, { t = 0.50, y = 0.04 } },
					head = { { t = 0.00, pitch = 2 }, { t = 0.50, pitch = -3 } },
				},
			},
			walk = {
				length = 0.66,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0, roll = -2 }, { t = 0.50, y = 0.08, roll = 2 } },
					frontL = { { t = 0.00, pitch = 22 }, { t = 0.50, pitch = -18 } },
					frontR = { { t = 0.00, pitch = -18 }, { t = 0.50, pitch = 22 } },
					backL = { { t = 0.00, pitch = -18 }, { t = 0.50, pitch = 22 } },
					backR = { { t = 0.00, pitch = 22 }, { t = 0.50, pitch = -18 } },
				},
			},
			run = {
				length = 0.4,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = -6 },
						{ t = 0.50, y = 0.16, pitch = -2 },
					},
					head = { { t = 0.00, pitch = -10 }, { t = 0.50, pitch = -4 } },
					frontL = { { t = 0.00, pitch = 40 }, { t = 0.50, pitch = -34 } },
					frontR = { { t = 0.00, pitch = 36 }, { t = 0.50, pitch = -30 } },
					backL = { { t = 0.00, pitch = -34 }, { t = 0.50, pitch = 40 } },
					backR = { { t = 0.00, pitch = -30 }, { t = 0.50, pitch = 36 } },
				},
			},
			attack = {
				length = 0.5,
				tracks = {
					root = {
						{ t = 0.00, z = 0, pitch = 0 },
						{ t = 0.20, z = 0.3, pitch = 12 },
						{ t = 0.46, z = -0.7, pitch = -16 },
						{ t = 1.00, z = 0, pitch = 0 },
					},
					head = {
						{ t = 0.00, pitch = 0 },
						{ t = 0.20, pitch = 26 },
						{ t = 0.46, pitch = -34 },
						{ t = 1.00, pitch = 0 },
					},
				},
			},
			hit = {
				length = 0.34,
				tracks = {
					root = {
						{ t = 0.00, z = 0, roll = 0 },
						{ t = 0.3, z = 0.26, roll = 9 },
						{ t = 1.00, z = 0, roll = 0 },
					},
				},
			},
		},
	},
	caveWisp = {
		walkSpeed = 7,
		runSpeed = 16,
		clips = {
			idle = {
				length = 3.2,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0 }, { t = 0.50, y = 0.22 } },
					armL = { { t = 0.00, yaw = 0 }, { t = 1.00, yaw = 360 } },
					armR = { { t = 0.00, yaw = 120 }, { t = 1.00, yaw = 480 } },
					head = { { t = 0.00, yaw = 240 }, { t = 1.00, yaw = 600 } },
				},
			},
			walk = {
				length = 2,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0, roll = -3 }, { t = 0.50, y = 0.18, roll = 3 } },
					armL = { { t = 0.00, yaw = 0 }, { t = 1.00, yaw = 360 } },
					armR = { { t = 0.00, yaw = 120 }, { t = 1.00, yaw = 480 } },
					head = { { t = 0.00, yaw = 240 }, { t = 1.00, yaw = 600 } },
				},
			},
			run = {
				length = 0.8,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0, pitch = 8 }, { t = 0.50, y = 0.1, pitch = 8 } },
					armL = { { t = 0.00, yaw = 0 }, { t = 1.00, yaw = 360 } },
					armR = { { t = 0.00, yaw = 120 }, { t = 1.00, yaw = 480 } },
					head = { { t = 0.00, yaw = 240 }, { t = 1.00, yaw = 600 } },
				},
			},
			hit = {
				length = 0.42,
				tracks = {
					root = {
						{ t = 0.00, y = 0, z = 0 },
						{ t = 0.3, y = 0.4, z = 0.4 },
						{ t = 1.00, y = 0, z = 0 },
					},
				},
			},
		},
	},
	caveMycelia = {
		walkSpeed = 0,
		runSpeed = 0,
		clips = {
			idle = {
				length = 5.4,
				looped = true,
				tracks = {
					root = { { t = 0.00, y = 0 }, { t = 0.50, y = 0.1 } },
					head = {
						{ t = 0.00, pitch = -2, roll = -2 },
						{ t = 0.50, pitch = 2, roll = 2 },
					},
					armL = { { t = 0.00, pitch = -6 }, { t = 0.50, pitch = 6 } },
					armR = { { t = 0.00, pitch = 6 }, { t = 0.50, pitch = -6 } },
				},
			},
			attack = {
				length = 1.5,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 0 },
						{ t = 0.34, y = -0.16, pitch = -8 },
						{ t = 0.60, y = 0.12, pitch = 10 },
						{ t = 1.00, y = 0, pitch = 0 },
					},
					head = {
						{ t = 0.00, pitch = 0, yaw = 0 },
						{ t = 0.34, pitch = -16, yaw = -20 },
						{ t = 0.60, pitch = 22, yaw = 24 },
						{ t = 1.00, pitch = 0, yaw = 0 },
					},
					armL = {
						{ t = 0.00, pitch = 0, yaw = 0 },
						{ t = 0.34, pitch = -40, yaw = -30 },
						{ t = 0.62, pitch = 54, yaw = 46 },
						{ t = 1.00, pitch = 0, yaw = 0 },
					},
					armR = {
						{ t = 0.00, pitch = 0, yaw = 0 },
						{ t = 0.40, pitch = -34, yaw = 26 },
						{ t = 0.68, pitch = 50, yaw = -42 },
						{ t = 1.00, pitch = 0, yaw = 0 },
					},
				},
			},
			hit = {
				length = 0.5,
				tracks = {
					root = { { t = 0.00, roll = 0 }, { t = 0.3, roll = 4 }, { t = 1.00, roll = 0 } },
					head = { { t = 0.00, roll = 0 }, { t = 0.3, roll = -10 }, { t = 1.00, roll = 0 } },
				},
			},
		},
	},
} :: { [string]: any }

function MobAnims.get(id: string): any
	return MobAnims.SETS[id]
end

return MobAnims

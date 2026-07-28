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
	spider = {
		walkSpeed = 9,
		runSpeed = 17,
		clips = {
			idle = {
				length = 2.1,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = -1, roll = -1 },
						{ t = 0.50, y = 0.07, pitch = 2, roll = 1 },
					},
				},
			},
			walk = {
				length = 0.5,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, yaw = -4, roll = -4 },
						{ t = 0.25, y = 0.13, yaw = 0, roll = 0 },
						{ t = 0.50, y = 0, yaw = 4, roll = 4 },
						{ t = 0.75, y = 0.13, yaw = 0, roll = 0 },
					},
				},
			},
			run = {
				length = 0.3,
				looped = true,
				tracks = {
					root = {
						{ t = 0.00, y = 0, pitch = 5, yaw = -7, roll = -7 },
						{ t = 0.25, y = 0.22, pitch = 9, yaw = 0, roll = 0 },
						{ t = 0.50, y = 0, pitch = 5, yaw = 7, roll = 7 },
						{ t = 0.75, y = 0.22, pitch = 9, yaw = 0, roll = 0 },
					},
				},
			},
			attack = {
				length = 0.55,
				tracks = {
					root = {
						{ t = 0.00, z = 0, pitch = 0 },
						{ t = 0.28, z = 0.24, pitch = -12 },
						{ t = 0.55, z = -0.55, pitch = 20 },
						{ t = 1.00, z = 0, pitch = 0 },
					},
				},
			},
			hit = {
				length = 0.36,
				tracks = {
					root = {
						{ t = 0.00, z = 0, pitch = 0, roll = 0 },
						{ t = 0.3, z = 0.34, pitch = -10, roll = 12 },
						{ t = 1.00, z = 0, pitch = 0, roll = 0 },
					},
				},
			},
		},
	},
} :: { [string]: any }

function MobAnims.get(id: string): any
	return MobAnims.SETS[id]
end

return MobAnims

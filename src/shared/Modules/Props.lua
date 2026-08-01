local Props = {}

local WOOD = Color3.fromRGB(170, 134, 100)
local WOOD_DARK = Color3.fromRGB(130, 98, 72)
local STRAW = Color3.fromRGB(232, 210, 150)
local STONE = Color3.fromRGB(198, 194, 184)
local WHITE = Color3.fromRGB(253, 250, 246)
local PINK = Color3.fromRGB(244, 186, 190)

local function block(ctx, config)
	return ctx.helpers.block(ctx, config)
end

local function group(ctx, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = ctx.parent
	return model
end

local REED = Color3.fromRGB(146, 178, 108)
local REED_DEEP = Color3.fromRGB(112, 148, 86)
local CATTAIL = Color3.fromRGB(138, 104, 76)
local SLATE = Color3.fromRGB(150, 148, 148)
local RUST = Color3.fromRGB(168, 106, 72)

local function groundY(ctx, x, z)
	return (ctx.groundY and ctx.groundY(x, z)) or 0
end

function Props.reedClump(ctx, x, z)
	local model = group(ctx, "ReedClump")
	local gy = groundY(ctx, x, z)
	for index = 1, ctx.rng:NextInteger(6, 11) do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local spread = ctx.rng:NextNumber(0.4, 3.2)
		local height = ctx.rng:NextNumber(3.4, 6.4)
		local lean = ctx.rng:NextNumber(-0.22, 0.22)
		local at = Vector3.new(x + math.cos(angle) * spread, gy + height / 2, z + math.sin(angle) * spread)
		block(ctx, {
			name = `Reed_{index}`,
			size = Vector3.new(0.28, height, 0.28),
			color = if ctx.rng:NextNumber() > 0.4 then REED else REED_DEEP,
			material = Enum.Material.Grass,
			cframe = CFrame.new(ctx.origin + at) * CFrame.Angles(lean, angle, lean),
			parent = model,
			collide = false,
		})
	end
end

function Props.cattailStand(ctx, x, z)
	local model = group(ctx, "CattailStand")
	local gy = groundY(ctx, x, z)
	for index = 1, ctx.rng:NextInteger(3, 6) do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local spread = ctx.rng:NextNumber(0.3, 2.4)
		local height = ctx.rng:NextNumber(4.6, 7.2)
		local px = x + math.cos(angle) * spread
		local pz = z + math.sin(angle) * spread
		local lean = ctx.rng:NextNumber(-0.14, 0.14)
		block(ctx, {
			name = `Stem_{index}`,
			size = Vector3.new(0.24, height, 0.24),
			color = REED_DEEP,
			material = Enum.Material.Grass,
			cframe = CFrame.new(ctx.origin + Vector3.new(px, gy + height / 2, pz)) * CFrame.Angles(lean, 0, lean),
			parent = model,
			collide = false,
		})
		block(ctx, {
			name = `Head_{index}`,
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.5, 0.62, 0.62),
			color = CATTAIL,
			material = Enum.Material.Fabric,
			cframe = CFrame.new(ctx.origin + Vector3.new(px, gy + height - 0.4, pz))
				* CFrame.Angles(0, 0, math.rad(90)),
			parent = model,
			collide = false,
		})
	end
end

function Props.mooringPost(ctx, x, z)
	local model = group(ctx, "MooringPost")
	local gy = groundY(ctx, x, z)
	local height = ctx.rng:NextNumber(3.4, 5)
	block(ctx, {
		name = "Post",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 1.1, 1.1),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
		cframe = CFrame.new(ctx.origin + Vector3.new(x, gy + height / 2, z)) * CFrame.Angles(0, 0, math.rad(90)),
		parent = model,
	})
	block(ctx, {
		name = "Cap",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.4, 0.9, 1.4),
		color = WOOD,
		material = Enum.Material.Wood,
		x = x,
		z = z,
		y = height,
		parent = model,
		collide = false,
	})
	block(ctx, {
		name = "Rope",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.28, 1.5, 1.5),
		color = STRAW,
		material = Enum.Material.Fabric,
		cframe = CFrame.new(ctx.origin + Vector3.new(x, gy + height * 0.62, z)) * CFrame.Angles(0, 0, math.rad(90)),
		parent = model,
		collide = false,
	})
end

function Props.rowBoat(ctx, x, z)
	local model = group(ctx, "RowBoat")
	local yaw = ctx.rng:NextNumber() * math.pi * 2
	local gy = groundY(ctx, x, z)
	local base = CFrame.new(ctx.origin + Vector3.new(x, gy + 0.9, z)) * CFrame.Angles(0, yaw, math.rad(6))

	block(
		ctx,
		{
			name = "Hull",
			size = Vector3.new(4.6, 1.7, 12),
			color = WOOD,
			material = Enum.Material.Wood,
			cframe = base,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Inner",
			size = Vector3.new(3.6, 1.2, 10.6),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
			cframe = base * CFrame.new(0, 0.5, 0),
			parent = model,
			collide = false,
		}
	)
	for _, side in { -1, 1 } do
		block(
			ctx,
			{
				name = "Prow",
				shape = Enum.PartType.Wedge,
				size = Vector3.new(4.6, 1.7, 2.4),
				color = WOOD,
				material = Enum.Material.Wood,
				cframe = base * CFrame.new(0, 0, side * 7) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0),
				parent = model,
				collide = false,
			}
		)
	end
	block(
		ctx,
		{
			name = "Bench",
			size = Vector3.new(3.8, 0.4, 1.2),
			color = WOOD,
			material = Enum.Material.Wood,
			cframe = base * CFrame.new(0, 0.9, 1.4),
			parent = model,
			collide = false,
		}
	)
	block(
		ctx,
		{
			name = "Oar",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(7.5, 0.4, 0.4),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
			cframe = base * CFrame.new(1.6, 1.2, -1) * CFrame.Angles(0, math.rad(24), math.rad(90)),
			parent = model,
			collide = false,
		}
	)
end

function Props.spoilHeap(ctx, x, z)
	local model = group(ctx, "SpoilHeap")
	local gy = groundY(ctx, x, z)
	local main = ctx.rng:NextNumber(5, 9)
	block(
		ctx,
		{
			name = "Heap",
			shape = Enum.PartType.Ball,
			size = Vector3.new(main, main * 0.52, main),
			x = x,
			z = z,
			y = main * 0.2,
			color = SLATE,
			material = Enum.Material.Slate,
			parent = model,
		}
	)
	for index = 1, ctx.rng:NextInteger(5, 9) do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local spread = ctx.rng:NextNumber(0.3, main * 0.62)
		local size = ctx.rng:NextNumber(0.9, 2.2)
		block(ctx, {
			name = `Rubble_{index}`,
			size = Vector3.new(size, size * 0.72, size),
			color = if ctx.rng:NextNumber() > 0.72 then RUST else SLATE,
			material = Enum.Material.Slate,
			cframe = CFrame.new(
				ctx.origin + Vector3.new(x + math.cos(angle) * spread, gy + size * 0.3, z + math.sin(angle) * spread)
			) * CFrame.Angles(ctx.rng:NextNumber(0, 1), ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(0, 1)),
			parent = model,
			collide = false,
		})
	end
end

function Props.timberScaffold(ctx, x, z)
	local model = group(ctx, "TimberScaffold")
	local yaw = ctx.rng:NextNumber() * math.pi * 2
	local gy = groundY(ctx, x, z)
	local base = CFrame.new(ctx.origin + Vector3.new(x, gy, z)) * CFrame.Angles(0, yaw, 0)
	local height = ctx.rng:NextNumber(7, 11)
	local width = 5

	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(ctx, {
				name = "Leg",
				size = Vector3.new(0.7, height, 0.7),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
				cframe = base * CFrame.new(sx * width / 2, height / 2, sz * width / 2),
				parent = model,
			})
		end
	end

	for level = 1, 2 do
		local y = height * (level / 2.4)
		block(
			ctx,
			{
				name = "Rail",
				size = Vector3.new(width + 0.7, 0.4, 0.4),
				color = WOOD,
				material = Enum.Material.Wood,
				cframe = base * CFrame.new(0, y, width / 2),
				parent = model,
				collide = false,
			}
		)
		block(
			ctx,
			{
				name = "Rail",
				size = Vector3.new(0.4, 0.4, width + 0.7),
				color = WOOD,
				material = Enum.Material.Wood,
				cframe = base * CFrame.new(width / 2, y, 0),
				parent = model,
				collide = false,
			}
		)
	end

	block(
		ctx,
		{
			name = "Deck",
			size = Vector3.new(width + 1, 0.5, width + 1),
			color = WOOD,
			material = Enum.Material.WoodPlanks,
			cframe = base * CFrame.new(0, height, 0),
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Brace",
			size = Vector3.new(0.5, 0.5, height * 1.3),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
			cframe = base * CFrame.new(width / 2, height / 2, 0) * CFrame.Angles(math.rad(42), 0, 0),
			parent = model,
			collide = false,
		}
	)
end

function Props.quarryCart(ctx, x, z)
	local model = group(ctx, "QuarryCart")
	local yaw = ctx.rng:NextNumber() * math.pi * 2
	local gy = groundY(ctx, x, z)
	local base = CFrame.new(ctx.origin + Vector3.new(x, gy + 1.5, z)) * CFrame.Angles(0, yaw, 0)

	block(
		ctx,
		{
			name = "Body",
			size = Vector3.new(3.6, 2.4, 5.2),
			color = RUST,
			material = Enum.Material.CorrodedMetal,
			cframe = base,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Load",
			size = Vector3.new(3, 0.8, 4.6),
			color = SLATE,
			material = Enum.Material.Slate,
			cframe = base * CFrame.new(0, 1.3, 0),
			parent = model,
			collide = false,
		}
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1.6, 1.6 } do
			block(ctx, {
				name = "Wheel",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.5, 1.8, 1.8),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
				cframe = base * CFrame.new(sx * 1.9, -1.2, sz) * CFrame.Angles(0, 0, math.rad(90)),
				parent = model,
				collide = false,
			})
		end
	end
	for _, sz in { -1, 1 } do
		block(
			ctx,
			{
				name = "Rail",
				size = Vector3.new(0.5, 0.3, 12),
				color = SLATE,
				material = Enum.Material.Metal,
				cframe = base * CFrame.new(sz * 1.5, -2, 0),
				parent = model,
				collide = false,
			}
		)
	end
end

function Props.oreVein(ctx, x, z, tint)
	local model = group(ctx, "OreVein")
	local gy = groundY(ctx, x, z)
	local color = tint or RUST
	local main = ctx.rng:NextNumber(3.2, 4.6)

	block(
		ctx,
		{
			name = "Matrix",
			shape = Enum.PartType.Ball,
			size = Vector3.new(main, main * 0.86, main),
			x = x,
			z = z,
			y = main * 0.34,
			color = SLATE,
			material = Enum.Material.Slate,
			parent = model,
		}
	)
	for index = 1, ctx.rng:NextInteger(4, 7) do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local spread = ctx.rng:NextNumber(0.2, main * 0.4)
		local size = ctx.rng:NextNumber(0.7, 1.5)
		block(ctx, {
			name = `Crystal_{index}`,
			size = Vector3.new(size, size * 1.6, size),
			color = color,
			material = Enum.Material.Neon,
			cframe = CFrame.new(
				ctx.origin + Vector3.new(x + math.cos(angle) * spread, gy + main * 0.42, z + math.sin(angle) * spread)
			)
				* CFrame.Angles(ctx.rng:NextNumber(-0.5, 0.5), ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(-0.5, 0.5)),
			parent = model,
			collide = false,
		})
	end

	return model
end

function Props.scarecrow(ctx, x, z)
	local model = group(ctx, "Scarecrow")
	block(
		ctx,
		{
			name = "Post",
			size = Vector3.new(0.8, 7, 0.8),
			x = x,
			z = z,
			y = 3.5,
			color = WOOD,
			material = Enum.Material.Wood,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Arms",
			size = Vector3.new(5.6, 0.6, 0.6),
			x = x,
			z = z,
			y = 5.0,
			color = WOOD,
			material = Enum.Material.Wood,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Shirt",
			size = Vector3.new(2.6, 2.4, 1.4),
			x = x,
			z = z,
			y = 4.2,
			color = Color3.fromRGB(230, 130, 130),
			material = Enum.Material.Fabric,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Head",
			shape = Enum.PartType.Ball,
			size = Vector3.new(2, 2, 2),
			x = x,
			z = z,
			y = 6.6,
			color = STRAW,
			material = Enum.Material.Fabric,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "HatBrim",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.4, 3.6, 3.6),
			x = x,
			z = z,
			y = 7.55,
			color = WOOD_DARK,
			material = Enum.Material.Wood,
			parent = model,
			cframe = CFrame.new(ctx.origin + Vector3.new(x, (ctx.groundY and ctx.groundY(x, z) or 0) + 7.55, z))
				* CFrame.Angles(0, 0, math.rad(90)),
		}
	)
	block(
		ctx,
		{
			name = "HatTop",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.2, 2, 2),
			x = x,
			z = z,
			y = 8.3,
			color = WOOD_DARK,
			material = Enum.Material.Wood,
			parent = model,
			cframe = CFrame.new(ctx.origin + Vector3.new(x, (ctx.groundY and ctx.groundY(x, z) or 0) + 8.3, z))
				* CFrame.Angles(0, 0, math.rad(90)),
		}
	)
	for _, side in { -1, 1 } do
		block(
			ctx,
			{
				name = "StrawHand",
				shape = Enum.PartType.Ball,
				size = Vector3.new(1, 1, 1),
				x = x + side * 2.8,
				z = z,
				y = 5.0,
				color = STRAW,
				material = Enum.Material.Fabric,
				parent = model,
				collide = false,
			}
		)
	end
end

function Props.hayBale(ctx, x, z)
	local model = group(ctx, "HayBale")
	local yaw = ctx.rng:NextNumber() * math.pi * 2
	local gy = (ctx.groundY and ctx.groundY(x, z)) or 0
	local base = CFrame.new(ctx.origin + Vector3.new(x, gy + 1.7, z)) * CFrame.Angles(0, yaw, 0)
	block(
		ctx,
		{
			name = "Bale",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(4.6, 3.4, 3.4),
			color = Color3.fromRGB(228, 198, 112),
			material = Enum.Material.Fabric,
			cframe = base * CFrame.Angles(0, 0, math.rad(90)),
			parent = model,
		}
	)
	for _, side in { -1, 1 } do
		block(
			ctx,
			{
				name = "Band",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.5, 3.5, 3.5),
				color = Color3.fromRGB(200, 164, 92),
				material = Enum.Material.Fabric,
				cframe = base * CFrame.new(side * 1.3, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
				parent = model,
				collide = false,
			}
		)
	end
end

function Props.tilledRow(ctx, x, z)
	local model = group(ctx, "TilledRow")
	local yaw = ctx.rng:NextNumber() * math.pi * 2
	local gy = (ctx.groundY and ctx.groundY(x, z)) or 0
	local base = CFrame.new(ctx.origin + Vector3.new(x, gy, z)) * CFrame.Angles(0, yaw, 0)
	local length = 18
	for ridge = 1, 4 do
		local offset = (ridge - 2.5) * 3.2
		block(
			ctx,
			{
				name = `Ridge_{ridge}`,
				size = Vector3.new(2.4, 1, length),
				color = Color3.fromRGB(112, 86, 64),
				material = Enum.Material.Ground,
				cframe = base * CFrame.new(offset, 0.5, 0),
				parent = model,
				collide = false,
			}
		)
		if ridge % 2 == 1 then
			for sprout = 1, 4 do
				local along = (sprout - 2.5) * 4.2
				block(
					ctx,
					{
						name = `Sprout_{ridge}_{sprout}`,
						shape = Enum.PartType.Ball,
						size = Vector3.new(0.9, 0.9, 0.9),
						color = Color3.fromRGB(126, 190, 104),
						material = Enum.Material.Grass,
						cframe = base * CFrame.new(offset, 1.3, along),
						parent = model,
						collide = false,
					}
				)
			end
		end
	end
end

function Props.stoneLantern(ctx, x, z)
	local model = group(ctx, "StoneLantern")
	block(
		ctx,
		{
			name = "Base",
			size = Vector3.new(2.8, 0.9, 2.8),
			x = x,
			z = z,
			y = 0.45,
			color = STONE,
			material = Enum.Material.Cobblestone,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Pillar",
			size = Vector3.new(1.1, 2.4, 1.1),
			x = x,
			z = z,
			y = 2.1,
			color = STONE,
			material = Enum.Material.Cobblestone,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Firebox",
			size = Vector3.new(2, 1.5, 2),
			x = x,
			z = z,
			y = 4.05,
			color = Color3.fromRGB(252, 226, 166),
			material = Enum.Material.Neon,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Cap",
			size = Vector3.new(3, 0.7, 3),
			x = x,
			z = z,
			y = 5.15,
			color = STONE,
			material = Enum.Material.Cobblestone,
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "Finial",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.9, 0.9, 0.9),
			x = x,
			z = z,
			y = 5.9,
			color = STONE,
			material = Enum.Material.Cobblestone,
			parent = model,
			collide = false,
		}
	)
end

function Props.cairn(ctx, x, z)
	local model = group(ctx, "Cairn")
	local sizes = { 3.2, 2.4, 1.6 }
	local y = 0
	for index, size in sizes do
		y += size * 0.34
		block(
			ctx,
			{
				name = `Stone_{index}`,
				shape = Enum.PartType.Ball,
				size = Vector3.new(size, size * 0.68, size),
				x = x + ctx.rng:NextNumber(-0.3, 0.3),
				z = z + ctx.rng:NextNumber(-0.3, 0.3),
				y = y,
				color = Color3.fromRGB(168, 168, 160),
				material = Enum.Material.Slate,
				parent = model,
			}
		)
		y += size * 0.34
	end
end

function Props.boulder(ctx, x, z)
	local model = group(ctx, "Boulder")
	local main = ctx.rng:NextNumber(5, 8)
	block(
		ctx,
		{
			name = "Core",
			shape = Enum.PartType.Ball,
			size = Vector3.new(main, main * 0.8, main),
			x = x,
			z = z,
			y = main * 0.28,
			color = Color3.fromRGB(150, 150, 145),
			material = Enum.Material.Slate,
			parent = model,
		}
	)
	for index = 1, 3 do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local size = main * ctx.rng:NextNumber(0.4, 0.65)
		local at = main * ctx.rng:NextNumber(0.4, 0.6)
		block(
			ctx,
			{
				name = `Lobe_{index}`,
				shape = Enum.PartType.Ball,
				size = Vector3.new(size, size * 0.75, size),
				x = x + math.cos(angle) * at,
				z = z + math.sin(angle) * at,
				y = size * 0.24,
				color = Color3.fromRGB(162, 162, 156),
				material = Enum.Material.Slate,
				parent = model,
			}
		)
	end
end

function Props.pond(ctx, x, z)
	local model = group(ctx, "Pond")
	local radius = ctx.rng:NextNumber(7, 9)
	block(
		ctx,
		{
			name = "Water",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.5, radius * 2, radius * 2),
			color = Color3.fromRGB(150, 200, 230),
			material = Enum.Material.Glass,
			transparency = 0.15,
			x = x,
			z = z,
			y = 0.25,
			parent = model,
			collide = false,
			cframe = CFrame.new(ctx.origin + Vector3.new(x, ((ctx.groundY and ctx.groundY(x, z)) or 0) + 0.25, z))
				* CFrame.Angles(0, 0, math.rad(90)),
		}
	)
	for index = 1, 7 do
		local angle = (index / 7) * math.pi * 2 + ctx.rng:NextNumber(-0.2, 0.2)
		local size = ctx.rng:NextNumber(1.6, 2.6)
		block(
			ctx,
			{
				name = `Rim_{index}`,
				shape = Enum.PartType.Ball,
				size = Vector3.new(size, size * 0.7, size),
				x = x + math.cos(angle) * radius,
				z = z + math.sin(angle) * radius,
				y = size * 0.25,
				color = Color3.fromRGB(168, 168, 160),
				material = Enum.Material.Slate,
				parent = model,
				collide = false,
			}
		)
	end
	for index = 1, 2 do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local at = ctx.rng:NextNumber(1, radius * 0.5)
		block(
			ctx,
			{
				name = `Lily_{index}`,
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.15, 2.2, 2.2),
				color = Color3.fromRGB(104, 168, 84),
				material = Enum.Material.Grass,
				x = x + math.cos(angle) * at,
				z = z + math.sin(angle) * at,
				y = 0.55,
				parent = model,
				collide = false,
				cframe = CFrame.new(
					ctx.origin
						+ Vector3.new(
							x + math.cos(angle) * at,
							((ctx.groundY and ctx.groundY(x, z)) or 0) + 0.55,
							z + math.sin(angle) * at
						)
				) * CFrame.Angles(0, 0, math.rad(90)),
			}
		)
	end
end

function Props.giantMushroom(ctx, x, z)
	local model = group(ctx, "GiantMushroom")
	local height = ctx.rng:NextNumber(8, 14)
	local stemD = height * 0.22
	local capD = height * 0.85
	local capColor = if ctx.rng:NextNumber() > 0.4 then Color3.fromRGB(224, 102, 96) else Color3.fromRGB(168, 128, 96)
	block(
		ctx,
		{
			name = "Stem",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(height, stemD, stemD),
			color = Color3.fromRGB(246, 238, 224),
			material = Enum.Material.SmoothPlastic,
			cframe = CFrame.new(
				ctx.origin + Vector3.new(x, ((ctx.groundY and ctx.groundY(x, z)) or 0) + height / 2 - 0.5, z)
			) * CFrame.Angles(0, 0, math.rad(90)),
			parent = model,
		}
	)
	local capY = ((ctx.groundY and ctx.groundY(x, z)) or 0) + height - 0.5
	block(
		ctx,
		{
			name = "Cap",
			shape = Enum.PartType.Ball,
			size = Vector3.new(capD, capD * 0.6, capD),
			color = capColor,
			material = Enum.Material.SmoothPlastic,
			cframe = CFrame.new(ctx.origin + Vector3.new(x, capY, z)),
			parent = model,
		}
	)
	for spot = 1, 5 do
		local az = ctx.rng:NextNumber() * math.pi * 2
		local r = capD * 0.32 * ctx.rng:NextNumber(0.3, 1)
		local lift = (capD * 0.3) * math.sqrt(math.max(0, 1 - (r / (capD / 2)) ^ 2))
		local size = ctx.rng:NextNumber(0.7, 1.3)
		block(
			ctx,
			{
				name = `Spot_{spot}`,
				shape = Enum.PartType.Ball,
				size = Vector3.new(size, size, size),
				color = Color3.fromRGB(250, 246, 238),
				material = Enum.Material.SmoothPlastic,
				cframe = CFrame.new(ctx.origin + Vector3.new(x + math.cos(az) * r, capY + lift, z + math.sin(az) * r)),
				parent = model,
				collide = false,
			}
		)
	end
end

function Props.snowTree(ctx, x, z)
	local model = group(ctx, "SnowTree")
	local height = ctx.rng:NextNumber(9, 14)
	local canopy = ctx.rng:NextNumber(8, 12)
	local gy = (ctx.groundY and ctx.groundY(x, z)) or 0
	block(
		ctx,
		{
			name = "Trunk",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(height, 1.7, 1.7),
			color = Color3.fromRGB(150, 140, 132),
			material = Enum.Material.Wood,
			cframe = CFrame.new(ctx.origin + Vector3.new(x, gy + height / 2 - 1, z))
				* CFrame.Angles(0, 0, math.rad(90)),
			parent = model,
		}
	)
	local offsets = {
		{ 0, 0.34, 0, 1 },
		{ -0.34, 0.1, 0.2, 0.66 },
		{ 0.32, 0.16, -0.24, 0.58 },
	}
	for index, blob in offsets do
		local size = canopy * blob[4]
		block(
			ctx,
			{
				name = `Canopy_{index}`,
				shape = Enum.PartType.Ball,
				size = Vector3.new(size, size * 0.85, size),
				x = x + canopy * blob[1],
				z = z + canopy * blob[3],
				y = height - 1 + canopy * blob[2],
				color = if index == 1 then Color3.fromRGB(240, 246, 250) else Color3.fromRGB(218, 230, 240),
				material = Enum.Material.Snow,
				parent = model,
				collide = false,
			}
		)
	end
end

function Props.tulip(ctx, x, z)
	local model = group(ctx, "Tulip")
	local colors = {
		Color3.fromRGB(244, 130, 140),
		Color3.fromRGB(250, 210, 120),
		Color3.fromRGB(196, 150, 220),
		Color3.fromRGB(250, 240, 235),
	}
	local color = colors[ctx.rng:NextInteger(1, #colors)]
	local height = ctx.rng:NextNumber(2.2, 3)
	block(
		ctx,
		{
			name = "Stem",
			size = Vector3.new(0.35, height, 0.35),
			x = x,
			z = z,
			y = height / 2,
			color = Color3.fromRGB(104, 168, 84),
			material = Enum.Material.Grass,
			parent = model,
			collide = false,
		}
	)
	block(
		ctx,
		{
			name = "Head",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.2, 1.5, 1.2),
			x = x,
			z = z,
			y = height + 0.5,
			color = color,
			material = Enum.Material.SmoothPlastic,
			parent = model,
			collide = false,
		}
	)
	for _, side in { -1, 1 } do
		block(
			ctx,
			{
				name = "Leaf",
				size = Vector3.new(0.3, 1.4, 0.7),
				color = Color3.fromRGB(104, 168, 84),
				material = Enum.Material.Grass,
				cframe = CFrame.new(ctx.origin + Vector3.new(x, ((ctx.groundY and ctx.groundY(x, z)) or 0) + 0.8, z))
					* CFrame.Angles(0, ctx.rng:NextNumber() * math.pi * 2, side * math.rad(25)),
				parent = model,
				collide = false,
			}
		)
	end
end

function Props.berryCrate(ctx, x, z)
	local model = group(ctx, "BerryCrate")
	local yaw = ctx.rng:NextNumber() * math.pi * 2
	local gy = (ctx.groundY and ctx.groundY(x, z)) or 0
	local base = CFrame.new(ctx.origin + Vector3.new(x, gy, z)) * CFrame.Angles(0, yaw, 0)
	block(
		ctx,
		{
			name = "Floor",
			size = Vector3.new(3.4, 0.3, 3.4),
			color = WOOD,
			material = Enum.Material.Wood,
			cframe = base * CFrame.new(0, 0.15, 0),
			parent = model,
		}
	)
	for side = 1, 4 do
		local angle = math.rad((side - 1) * 90)
		block(
			ctx,
			{
				name = `Wall_{side}`,
				size = Vector3.new(3.4, 1.3, 0.3),
				color = WOOD,
				material = Enum.Material.Wood,
				cframe = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.8, 1.55),
				parent = model,
			}
		)
	end
	local berries = {
		Color3.fromRGB(110, 140, 230),
		Color3.fromRGB(150, 110, 200),
		Color3.fromRGB(70, 60, 90),
		Color3.fromRGB(240, 240, 235),
	}
	for index = 1, 5 do
		block(
			ctx,
			{
				name = `Berry_{index}`,
				shape = Enum.PartType.Ball,
				size = Vector3.new(1, 1, 1),
				color = berries[ctx.rng:NextInteger(1, #berries)],
				material = Enum.Material.SmoothPlastic,
				cframe = base * CFrame.new(ctx.rng:NextNumber(-0.9, 0.9), 1.35, ctx.rng:NextNumber(-0.9, 0.9)),
				parent = model,
				collide = false,
			}
		)
	end
end

function Props.bookStack(ctx, x, z)
	local model = group(ctx, "BookStack")
	local colors = {
		Color3.fromRGB(226, 108, 130),
		Color3.fromRGB(120, 168, 224),
		Color3.fromRGB(242, 196, 108),
		Color3.fromRGB(146, 196, 130),
		Color3.fromRGB(196, 146, 214),
	}
	local count = ctx.rng:NextInteger(3, 5)
	for index = 1, count do
		block(
			ctx,
			{
				name = `Book_{index}`,
				size = Vector3.new(2.6, 0.42, 3.4),
				color = colors[(index - 1) % #colors + 1],
				material = Enum.Material.SmoothPlastic,
				x = x,
				z = z,
				y = 0.21 + (index - 1) * 0.44,
				parent = model,
				collide = false,
				cframe = CFrame.new(
					ctx.origin
						+ Vector3.new(x, ((ctx.groundY and ctx.groundY(x, z)) or 0) + 0.21 + (index - 1) * 0.44, z)
				) * CFrame.Angles(0, math.rad(ctx.rng:NextNumber(-14, 14)), 0),
			}
		)
	end
end

function Props.sandDisc(ctx, x, z)
	local model = group(ctx, "SandDisc")
	local gy = (ctx.groundY and ctx.groundY(x, z)) or 0
	for index, diameter in { 14, 10, 6 } do
		block(
			ctx,
			{
				name = `Ring_{index}`,
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.4, diameter, diameter),
				color = if index % 2 == 1 then Color3.fromRGB(232, 226, 210) else Color3.fromRGB(220, 212, 194),
				material = Enum.Material.Sand,
				cframe = CFrame.new(ctx.origin + Vector3.new(x, gy + 0.2 + index * 0.06, z))
					* CFrame.Angles(0, 0, math.rad(90)),
				parent = model,
				collide = false,
			}
		)
	end
	block(
		ctx,
		{
			name = "Stone",
			shape = Enum.PartType.Ball,
			size = Vector3.new(2.4, 1.8, 2.4),
			x = x + 2,
			z = z - 1,
			y = 0.9,
			color = Color3.fromRGB(168, 168, 160),
			material = Enum.Material.Slate,
			parent = model,
		}
	)
end

function Props.gardenArch(ctx, x, z, yaw, color)
	local model = group(ctx, "GardenArch")
	local gy = (ctx.groundY and ctx.groundY(x, z)) or 0
	local base = CFrame.new(ctx.origin + Vector3.new(x, gy, z)) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		block(
			ctx,
			{
				name = "Post",
				size = Vector3.new(1.7, 10, 1.7),
				color = WOOD,
				material = Enum.Material.Wood,
				cframe = base * CFrame.new(side * 5.5, 5, 0),
				parent = model,
			}
		)
		block(
			ctx,
			{
				name = "Finial",
				shape = Enum.PartType.Ball,
				size = Vector3.new(2.2, 2.2, 2.2),
				color = color,
				material = Enum.Material.SmoothPlastic,
				cframe = base * CFrame.new(side * 5.5, 10.6, 0),
				parent = model,
				collide = false,
			}
		)
	end
	block(
		ctx,
		{
			name = "Lintel",
			size = Vector3.new(14.6, 1.6, 2),
			color = color,
			material = Enum.Material.SmoothPlastic,
			cframe = base * CFrame.new(0, 10.2, 0),
			parent = model,
		}
	)
	block(
		ctx,
		{
			name = "SubLintel",
			size = Vector3.new(11, 1.1, 1.5),
			color = color,
			material = Enum.Material.SmoothPlastic,
			cframe = base * CFrame.new(0, 8.4, 0),
			parent = model,
		}
	)
end

function Props.miniFence(ctx, x1, z1, x2, z2)
	local model = group(ctx, "MiniFence")
	local from = Vector2.new(x1, z1)
	local to = Vector2.new(x2, z2)
	local span = to - from
	local length = span.Magnitude
	if length < 8 then
		return
	end
	local direction = span.Unit
	local yaw = math.atan2(direction.X, direction.Y)
	local gy = function(x, z)
		return (ctx.groundY and ctx.groundY(x, z)) or 0
	end
	local posts = math.floor(length / 7.5)
	for index = 0, posts do
		local at = from + direction * (index * 7.5)
		block(
			ctx,
			{
				name = "Post",
				size = Vector3.new(0.9, 4.5, 0.9),
				x = at.X,
				z = at.Y,
				y = 2.25,
				color = WHITE,
				material = Enum.Material.SmoothPlastic,
				parent = model,
				collide = false,
			}
		)
		block(
			ctx,
			{
				name = "Cap",
				shape = Enum.PartType.Ball,
				size = Vector3.new(1.35, 1.35, 1.35),
				x = at.X,
				z = at.Y,
				y = 4.6,
				color = PINK,
				material = Enum.Material.SmoothPlastic,
				parent = model,
				collide = false,
			}
		)
		if index < posts then
			local mid = at + direction * 3.75
			for _, fraction in { 0.42, 0.78 } do
				block(
					ctx,
					{
						name = "Rail",
						size = Vector3.new(0.45, 0.45, 7.5),
						color = WHITE,
						material = Enum.Material.SmoothPlastic,
						cframe = CFrame.new(ctx.origin + Vector3.new(mid.X, gy(mid.X, mid.Y) + 4.5 * fraction, mid.Y))
							* CFrame.Angles(0, yaw, 0),
						parent = model,
						collide = false,
					}
				)
			end
		end
	end
end

return Props

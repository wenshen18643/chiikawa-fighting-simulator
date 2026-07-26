--[[
	Area 2 — The Woods. Denser, darker, mushrooms.
]]

local Area = require(script.Parent.Area)

return Area.define({
	id = 2,
	key = "woods",
	name = "The Woods",
	flavour = "Mushrooms, a good cave, and your first real work orders.",

	gate = { skillTotal = { m = 5, e = 4 }, certificationTotal = 3 },
	origin = Vector3.new(3300, 0, 0),
	terrain = { material = "Grass", islandSize = 3200 },
	bridgeTo = "riverside",
	palette = {
		ground = Color3.fromRGB(104, 156, 104),
		prop = Color3.fromRGB(78, 122, 78),
		sky = Color3.fromRGB(198, 224, 206),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local half = ctx.area.terrain.islandSize / 2

		-- The cave: a mound of rock into the hillside with a dark mouth. Scaled
		-- up to landmark size — at the old 46 studs it read as a boulder once
		-- the area around it grew.
		local caveX, caveZ = -half * 0.5, half * 0.44
		helpers.block(ctx, {
			name = "CaveMound",
			shape = Enum.PartType.Ball,
			size = Vector3.new(150, 96, 150),
			x = caveX,
			z = caveZ,
			y = 22,
			color = Color3.fromRGB(126, 122, 112),
			material = Enum.Material.Rock,
		})
		helpers.block(ctx, {
			name = "CaveMouth",
			size = Vector3.new(26, 26, 12),
			x = caveX,
			z = caveZ - 62,
			y = 13,
			color = Color3.fromRGB(38, 36, 34),
			material = Enum.Material.Slate,
			collide = false,
		})
		helpers.signpost(ctx, {
			title = "The Cave",
			subtitle = "someone lives here",
			x = caveX + 40,
			z = caveZ - 84,
		})

		-- Boulders spilling away from the mound, so it sits in the landscape
		-- rather than on it.
		helpers.cluster(ctx, caveX, caveZ - 100, 190, 22, function(x, z)
			helpers.stone(ctx, x, z, ctx.rng:NextNumber(5, 13))
		end)

		-- Deep woods: two densities, so the forest has a heart and an edge.
		helpers.cluster(ctx, half * 0.42, -half * 0.42, half * 0.34, 60, function(x, z)
			helpers.tree(ctx, x, z, ctx.rng:NextNumber(18, 30), ctx.rng:NextNumber(14, 21))
		end)
		helpers.scatter(ctx, 90, function(x, z)
			helpers.tree(ctx, x, z, ctx.rng:NextNumber(14, 24), ctx.rng:NextNumber(12, 18))
		end)

		--[[
			Ground cover from the nature pack — grass and flowers, since
			`helpers.bush` already claims the bushes out of it. Falls back to a
			procedural bush when the pack did not load, so this degrades to
			plain undergrowth rather than to bare ground.
		]]
		helpers.scatter(ctx, 70, function(x, z)
			local kind = if ctx.rng:NextNumber() > 0.35 then "grass" else "flower"
			if not helpers.natureProp(ctx, x, z, kind) then
				helpers.bush(ctx, x, z, ctx.rng:NextNumber(4, 8))
			end
		end)

		--[[
			Mushrooms: the area's signature prop. The nature pack ships Mushroom
			1 and 2, but they are tiny (about 1 stud), so they are scaled up to
			the same 2-5 stud range the procedural pair used — otherwise the
			signature prop of the Woods would be invisible from standing height.
		]]
		helpers.scatter(ctx, 46, function(x, z)
			local height = ctx.rng:NextNumber(2, 5)
			local capSize = ctx.rng:NextNumber(3, 7)

			local packed = helpers.natureProp(ctx, x, z, "mushroom")
			if packed then
				local natural = packed:GetExtentsSize().Y
				if natural > 0.01 then
					packed:ScaleTo(packed:GetScale() * ((height + capSize * 0.5) / natural))
					local size = packed:GetExtentsSize()
					packed:PivotTo(
						CFrame.new(ctx.origin + Vector3.new(x, -2 + size.Y / 2, z))
							* CFrame.Angles(0, ctx.rng:NextNumber() * math.pi * 2, 0)
					)
				end
				return
			end

			helpers.block(ctx, {
				name = "MushroomStalk",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(height, 1.4, 1.4),
				cframe = CFrame.new(ctx.origin + Vector3.new(x, -2 + height / 2, z))
					* CFrame.Angles(0, 0, math.rad(90)),
				color = Color3.fromRGB(240, 236, 224),
				collide = false,
			})
			helpers.block(ctx, {
				name = "MushroomCap",
				shape = Enum.PartType.Ball,
				size = Vector3.new(capSize, capSize * 0.6, capSize),
				x = x,
				z = z,
				y = height,
				color = Color3.fromRGB(206, 108, 96),
				collide = false,
			})
		end)
	end,
})

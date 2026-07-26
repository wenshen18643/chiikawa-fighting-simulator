--[[
	Area 4 — The Mountain. Hot springs and cold wind; Grit country.
]]

local Area = require(script.Parent.Area)

return Area.define({
	id = 4,
	key = "mountain",
	name = "The Mountain",
	flavour = "Hot springs and cold wind. Grit country.",

	gate = { skillTotal = { m = 5, e = 6 }, certificationTotal = 10 },
	origin = Vector3.new(11700, 0, 0),
	terrain = { material = "Snow", islandSize = 4400 },
	bridgeTo = "island",
	palette = {
		ground = Color3.fromRGB(180, 180, 190),
		prop = Color3.fromRGB(148, 156, 170),
		sky = Color3.fromRGB(226, 236, 250),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local half = ctx.area.terrain.islandSize / 2

		-- The hot spring: a warm pool ringed with rocks, with a bath house.
		local springX, springZ = -half * 0.5, half * 0.46
		helpers.block(ctx, {
			name = "SpringWater",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.5, 120, 120),
			cframe = CFrame.new(ctx.origin + Vector3.new(springX, -1.2, springZ)) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(158, 214, 216),
			material = Enum.Material.Water,
			transparency = 0.25,
			collide = false,
		})
		helpers.ring(ctx, springX, springZ, 68, 22, function(x, z)
			helpers.stone(ctx, x, z, ctx.rng:NextNumber(6, 12))
		end)
		helpers.hut(ctx, {
			x = springX,
			z = springZ + 108,
			width = 46,
			depth = 30,
			height = 17,
			color = Color3.fromRGB(226, 220, 222),
			roofColor = Color3.fromRGB(126, 138, 158),
		})
		helpers.signpost(ctx, { title = "Hot Spring", subtitle = "warm, finally", x = springX + 46, z = springZ - 82 })

		--[[
			Peaks along the northern and southern edges. Placed by hand rather
			than scattered: they are the area's silhouette, and a random one
			sitting between the plaza and a district would block the view of
			everywhere you can actually go.
		]]
		for index = 1, 9 do
			local size = ctx.rng:NextNumber(170, 320)
			local side = if index % 2 == 0 then 1 else -1
			helpers.block(ctx, {
				name = `Peak_{index}`,
				size = Vector3.new(size, size * 1.5, size),
				shape = Enum.PartType.Ball,
				x = -half * 0.8 + (index - 1) * (half * 0.2),
				z = side * ctx.rng:NextNumber(half * 0.72, half * 0.88),
				y = size * 0.34,
				color = Color3.fromRGB(206, 212, 222),
				material = Enum.Material.Rock,
			})
		end

		-- Bare, snow-dusted trees, thinning toward the peaks.
		helpers.scatter(ctx, 56, function(x, z)
			helpers.tree(ctx, x, z, ctx.rng:NextNumber(10, 20), ctx.rng:NextNumber(7, 12))
		end)
		helpers.scatter(ctx, 44, function(x, z)
			helpers.stone(ctx, x, z, ctx.rng:NextNumber(4, 10))
		end)
	end,
})

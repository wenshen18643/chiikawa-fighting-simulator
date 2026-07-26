--[[
	Area 5 — The Island. Seaside cooking and a very long ferry ride.

	Named before the world became one landmass — it is now a headland rather
	than an island, but the ferry, the jetty and the sand all still read, and
	renaming it would churn the profile's unlockedRegions keys for nothing.
]]

local Area = require(script.Parent.Area)

return Area.define({
	id = 5,
	key = "island",
	name = "The Island",
	flavour = "Seaside cooking and a very long ferry ride.",

	gate = { skillTotal = { m = 5, e = 7 }, certificationTotal = 14 },
	origin = Vector3.new(16900, 0, 0),
	terrain = { material = "Sand", islandSize = 5200 },
	bridgeTo = "ruins",
	palette = {
		ground = Color3.fromRGB(226, 210, 164),
		prop = Color3.fromRGB(232, 206, 150),
		sky = Color3.fromRGB(206, 240, 250),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local half = ctx.area.terrain.islandSize / 2

		-- A jetty running north toward the water, with the ferry moored at its
		-- end. Long enough to be a walk, which is the joke.
		local jettyStart = half * 0.42
		for index = 1, 16 do
			helpers.block(ctx, {
				name = `Jetty_{index}`,
				size = Vector3.new(20, 1.6, 34),
				x = 0,
				z = jettyStart + (index - 1) * 34,
				y = 1.4,
				color = Color3.fromRGB(186, 152, 116),
				material = Enum.Material.WoodPlanks,
			})
		end
		helpers.block(ctx, {
			name = "Ferry",
			size = Vector3.new(56, 22, 86),
			x = 0,
			z = jettyStart + 16 * 34 + 40,
			y = 9,
			color = Color3.fromRGB(220, 214, 206),
			material = Enum.Material.Metal,
		})
		helpers.signpost(ctx, { title = "Ferry", subtitle = "takes ages", x = 30, z = jettyStart - 16 })

		-- The shore kitchen, where Cooking's high tiers live in the fiction.
		helpers.hut(ctx, {
			x = -half * 0.5,
			z = half * 0.5,
			width = 44,
			depth = 32,
			height = 16,
			color = Color3.fromRGB(244, 232, 208),
			roofColor = Color3.fromRGB(206, 146, 110),
		})
		helpers.signpost(ctx, {
			title = "Shore Kitchen",
			subtitle = "salt, heat, patience",
			x = -half * 0.5 + 36,
			z = half * 0.5 - 30,
		})

		-- Palms: a bare trunk with a wide flat canopy. Denser along the shore.
		local function palm(x: number, z: number)
			local height = ctx.rng:NextNumber(16, 26)
			helpers.block(ctx, {
				name = "PalmTrunk",
				size = Vector3.new(1.8, height, 1.8),
				x = x,
				z = z,
				y = height / 2 - 1,
				color = Color3.fromRGB(178, 148, 112),
				material = Enum.Material.Wood,
			})
			helpers.block(ctx, {
				name = "PalmFronds",
				shape = Enum.PartType.Ball,
				size = Vector3.new(22, 6, 22),
				x = x,
				z = z,
				y = height,
				color = Color3.fromRGB(126, 178, 118),
				material = Enum.Material.Grass,
				collide = false,
			})
		end

		helpers.cluster(ctx, half * 0.5, -half * 0.5, half * 0.3, 34, palm)
		helpers.scatter(ctx, 60, palm)
		helpers.scatter(ctx, 46, function(x, z)
			helpers.stone(ctx, x, z, ctx.rng:NextNumber(2, 6))
		end)
	end,
})

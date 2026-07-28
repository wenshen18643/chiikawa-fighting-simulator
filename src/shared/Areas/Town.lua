--[[
	Area 1 — Town & Grass Field. The starting area.
]]

local Area = require(script.Parent.Area)

return Area.define({
	id = 1,
	key = "town",
	name = "Town & Grass Field",
	flavour = "Roadside weeding, tiny study desks, sasumata practice, and hot ramen bowls.",

	gate = { skillTotal = 0, certificationTotal = 0 },
	origin = Vector3.new(0, 0, 0),
	terrain = { material = "LeafyGrass", islandSize = 2600 },
	palette = {
		ground = Color3.fromRGB(150, 200, 130),
		prop = Color3.fromRGB(122, 168, 96),
		sky = Color3.fromRGB(214, 236, 250),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local half = ctx.area.terrain.islandSize / 2

		-- The ramen shop
		helpers.signpost(ctx, {
			title = "Ramen",
			subtitle = "hot bowls",
			x = -half * 0.48 + 34,
			z = half * 0.5 - 30,
		})

		-- The Exam Hall
		helpers.signpost(ctx, {
			title = "Exam Hall",
			subtitle = "grades 5 to 1",
			x = half * 0.48 - 38,
			z = half * 0.52 - 34,
		})

		-- Landmark Study Desk outside Exam Hall
		helpers.studyDesk(ctx, {
			x = half * 0.48 - 18,
			z = half * 0.52 - 36,
			y = 2.4,
		})

		-- Landmark Sasumata Training Dummy outside Subjugation grounds
		helpers.sasumataDummy(ctx, {
			x = -half * 0.48 - 25,
			z = half * 0.35,
			y = 4.5,
		})

		-- Landmark Weeding Patch in Town Square
		helpers.weedingPatch(ctx, {
			x = 0,
			z = half * 0.35,
			y = 1.5,
		})

		-- Landmark Waterfall Zone on Riverside cliff edge
		helpers.waterfallZone(ctx, {
			x = half * 0.65,
			z = -half * 0.45,
			y = 8.0,
		})

		-- A lane of houses along the southern edge
		for index = 1, 7 do
			helpers.hut(ctx, {
				x = -half * 0.62 + (index - 1) * (half * 0.2),
				z = -half * 0.58,
				width = ctx.rng:NextNumber(20, 28),
				depth = ctx.rng:NextNumber(16, 22),
				height = ctx.rng:NextNumber(12, 15),
				roofColor = if index % 2 == 0 then Color3.fromRGB(196, 116, 96) else Color3.fromRGB(150, 156, 186),
			})
		end
		helpers.signpost(ctx, { title = "The Lane", subtitle = "mind the washing", x = 0, z = -half * 0.46 })

		-- Orchard
		helpers.cluster(ctx, -half * 0.3, half * 0.72, half * 0.22, 26, function(x, z)
			helpers.tree(ctx, x, z, ctx.rng:NextNumber(11, 18), ctx.rng:NextNumber(11, 16))
		end)

		helpers.scatter(ctx, 70, function(x, z)
			helpers.tree(ctx, x, z, ctx.rng:NextNumber(9, 17), ctx.rng:NextNumber(10, 15))
		end)
		-- Grass and flowers from the nature pack; bushes if it did not load.
		helpers.scatter(ctx, 48, function(x, z)
			local kind = if ctx.rng:NextNumber() > 0.45 then "grass" else "flower"
			if not helpers.natureProp(ctx, x, z, kind) then
				helpers.bush(ctx, x, z, ctx.rng:NextNumber(3, 6))
			end
		end)

		helpers.scatter(ctx, 40, function(x, z)
			helpers.stone(ctx, x, z, ctx.rng:NextNumber(3, 7))
		end)
	end,
})

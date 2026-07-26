--[[
	Area 3 — Riverside & Market. Stalls, bunting, festival ground.
]]

local Area = require(script.Parent.Area)

return Area.define({
	id = 3,
	key = "riverside",
	name = "Riverside & Market",
	flavour = "Festival grounds. Everything is for sale and everyone is nice.",

	gate = { skillTotal = { m = 5, e = 5 }, certificationTotal = 6 },
	origin = Vector3.new(7200, 0, 0),
	terrain = { material = "Sand", islandSize = 3800 },
	bridgeTo = "mountain",
	palette = {
		ground = Color3.fromRGB(196, 186, 148),
		prop = Color3.fromRGB(206, 172, 120),
		sky = Color3.fromRGB(250, 232, 206),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local half = ctx.area.terrain.islandSize / 2

		local awnings = {
			Color3.fromRGB(226, 132, 120),
			Color3.fromRGB(236, 196, 118),
			Color3.fromRGB(146, 190, 214),
			Color3.fromRGB(186, 166, 214),
		}

		-- Two rows of market stalls facing each other across a lane, north of
		-- the districts. A single row read as a wall; facing rows read as a
		-- market you walk down.
		local marketZ = half * 0.52
		for row, side in { 1, -1 } do
			for index = 1, 9 do
				local x = -half * 0.42 + (index - 1) * (half * 0.105)
				local z = marketZ + side * 40
				helpers.block(ctx, {
					name = `Stall_{row}_{index}`,
					size = Vector3.new(26, 11, 18),
					x = x,
					z = z,
					y = 5.5,
					color = Color3.fromRGB(226, 214, 192),
					material = Enum.Material.WoodPlanks,
				})
				helpers.block(ctx, {
					name = `StallAwning_{row}_{index}`,
					size = Vector3.new(31, 1, 11),
					x = x,
					z = z - side * 13,
					y = 11.5,
					color = awnings[(index + row) % #awnings + 1],
					material = Enum.Material.Fabric,
					collide = false,
				})
			end
		end
		helpers.signpost(ctx, { title = "Market", subtitle = "charm gets a discount", x = 0, z = marketZ - 80 })

		-- The river the area is named for: a broad shallow band running south,
		-- crossed by a plank bridge so it never blocks a route.
		local riverZ = -half * 0.55
		helpers.block(ctx, {
			name = "River",
			size = Vector3.new(half * 1.7, 1.5, 120),
			x = 0,
			z = riverZ,
			y = -0.6,
			color = Color3.fromRGB(150, 200, 214),
			material = Enum.Material.Water,
			transparency = 0.3,
			collide = false,
		})
		helpers.block(ctx, {
			name = "RiverCrossing",
			size = Vector3.new(30, 1.4, 140),
			x = 0,
			z = riverZ,
			y = 1.4,
			color = Color3.fromRGB(186, 152, 116),
			material = Enum.Material.WoodPlanks,
		})

		-- Festival lamps around the market, evenly spaced.
		helpers.ring(ctx, 0, marketZ, half * 0.5, 14, function(x, z)
			helpers.block(ctx, {
				name = "LampPost",
				size = Vector3.new(1.2, 16, 1.2),
				x = x,
				z = z,
				y = 8,
				color = Color3.fromRGB(148, 122, 96),
				material = Enum.Material.Wood,
				collide = false,
			})
			helpers.block(ctx, {
				name = "Lantern",
				shape = Enum.PartType.Ball,
				size = Vector3.new(5, 6, 5),
				x = x,
				z = z,
				y = 17,
				color = Color3.fromRGB(250, 216, 150),
				material = Enum.Material.Neon,
				collide = false,
			})
		end)

		helpers.scatter(ctx, 60, function(x, z)
			helpers.tree(ctx, x, z, ctx.rng:NextNumber(9, 16), ctx.rng:NextNumber(10, 15))
		end)
		-- Grass and flowers from the nature pack; bushes if it did not load.
		helpers.scatter(ctx, 54, function(x, z)
			local kind = if ctx.rng:NextNumber() > 0.4 then "grass" else "flower"
			if not helpers.natureProp(ctx, x, z, kind) then
				helpers.bush(ctx, x, z, ctx.rng:NextNumber(3, 7))
			end
		end)

		helpers.scatter(ctx, 34, function(x, z)
			helpers.stone(ctx, x, z, ctx.rng:NextNumber(3, 6))
		end)
	end,
})

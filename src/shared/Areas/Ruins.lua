--[[
	Area 6 — The Old Ruins. The endgame area: overgrown, quiet, very stubborn weeds.

	The last area, so it has no `bridgeTo` — the eastern edge of the landmass is
	outer perimeter, not a gate.
]]

local Area = require(script.Parent.Area)

return Area.define({
	id = 6,
	key = "ruins",
	name = "The Old Ruins",
	flavour = "Overgrown, quiet, and full of extremely stubborn weeds.",

	gate = { skillTotal = { m = 5, e = 8 }, certificationTotal = 18 },
	origin = Vector3.new(22900, 0, 0),
	terrain = { material = "Mud", islandSize = 6000 },
	palette = {
		ground = Color3.fromRGB(160, 168, 140),
		prop = Color3.fromRGB(126, 136, 108),
		sky = Color3.fromRGB(220, 224, 208),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local half = ctx.area.terrain.islandSize / 2

		--[[
			Broken colonnade at the north edge: pillars at decreasing heights,
			some fallen. At the area's new size this is the one thing you can see
			from the plaza, so it is built long rather than tall.
		]]
		local colonnadeZ = half * 0.5
		for index = 1, 22 do
			local x = -half * 0.55 + (index - 1) * (half * 0.05)
			local height = ctx.rng:NextNumber(10, 46)
			helpers.block(ctx, {
				name = `Pillar_{index}`,
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(height, 12, 12),
				cframe = CFrame.new(ctx.origin + Vector3.new(x, -2 + height / 2, colonnadeZ))
					* CFrame.Angles(0, 0, math.rad(90)),
				color = Color3.fromRGB(206, 202, 188),
				material = Enum.Material.Concrete,
			})
		end

		-- A fallen lintel across a stretch of them.
		helpers.block(ctx, {
			name = "Lintel",
			size = Vector3.new(half * 0.34, 8, 14),
			x = -half * 0.34,
			z = colonnadeZ,
			y = 48,
			color = Color3.fromRGB(198, 194, 180),
			material = Enum.Material.Concrete,
		})

		-- A second, collapsed ring to the south, so the endgame area has more
		-- than one thing in it.
		helpers.ring(ctx, half * 0.42, -half * 0.5, half * 0.2, 16, function(x, z, angle)
			local height = ctx.rng:NextNumber(8, 30)
			helpers.block(ctx, {
				name = "FallenPillar",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(height, 11, 11),
				cframe = CFrame.new(ctx.origin + Vector3.new(x, -2 + height / 2, z))
					* CFrame.Angles(0, angle, math.rad(90 - ctx.rng:NextNumber(0, 24))),
				color = Color3.fromRGB(196, 192, 178),
				material = Enum.Material.Concrete,
			})
		end)

		helpers.signpost(ctx, { title = "The Ruins", subtitle = "older than the walls", x = 0, z = colonnadeZ - 90 })

		-- Overgrowth: low, wide clumps rather than trees.
		helpers.scatter(ctx, 110, function(x, z)
			local size = ctx.rng:NextNumber(8, 20)
			helpers.block(ctx, {
				name = "Overgrowth",
				shape = Enum.PartType.Ball,
				size = Vector3.new(size, size * 0.5, size),
				x = x,
				z = z,
				y = size * 0.15,
				material = Enum.Material.Grass,
				collide = false,
			})
		end)

		helpers.scatter(ctx, 46, function(x, z)
			helpers.stone(ctx, x, z, ctx.rng:NextNumber(5, 12))
		end)
	end,
})

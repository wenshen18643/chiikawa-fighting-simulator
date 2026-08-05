local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Props = require(ReplicatedStorage.Shared.Modules.Props)
local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)
local Area = require(script.Parent.Area)
local SectionDressing = require(script.Parent.SectionDressing)

return Area.define({
	id = 1,
	key = "town",
	name = "Town & Grass Field",
	flavour = "Roadside weeding, tiny study desks, market stalls, and hot ramen bowls.",

	gate = { skillTotal = 0, certificationTotal = 0 },
	origin = Vector3.new(0, 0, 0),
	terrain = { material = "LeafyGrass", islandSize = 1300 },
	palette = {
		ground = Color3.fromRGB(150, 200, 130),
		prop = Color3.fromRGB(122, 168, 96),
		sky = Color3.fromRGB(214, 236, 250),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local desksAt = { name = "Study Desks", x = 150, z = 30 }

		for _, side in { -1, 1 } do
			helpers.prop(ctx, "flowerBed2", side * ctx.plazaRadius * 0.36, ctx.plazaRadius * 0.66, { height = 2.2 })
		end

		for _, area in Streets.PAVING do
			helpers.paving(ctx, area, Streets)
		end
		helpers.paving(ctx, Streets.SQUARE, Streets, Streets.SQUARE_COLOR)

		for _, verge in Streets.VERGES do
			helpers.hedge(ctx, verge, Streets)
		end

		for _, marker in
			{
				{ title = "Library", subtitle = "and the exam hall", x = 70, z = 106 },
				{ title = "Kitchen", subtitle = "something is always on", x = -70, z = 106 },
				{ title = "Market Square", subtitle = "upgrades and work", x = -30, z = -42 },
			}
		do
			helpers.signpost(ctx, marker)
		end

		local KITCHEN_YARD = {
			{ key = "shopStall", x = -118, z = 108, height = 7, yaw = 90 },
			{ key = "shopStall", x = -118, z = 72, height = 7, yaw = -90 },

			{ key = "lowTable", x = -152, z = 138, height = 7 },
			{ key = "floorCushion", x = -143, z = 138, height = 3.5, yaw = -90 },
			{ key = "floorCushion", x = -161, z = 138, height = 3.5, yaw = 90 },
			{ key = "floorCushion", x = -152, z = 147, height = 3.5, yaw = 180 },
			{ key = "ramen", x = -168, z = 144, height = 9 },
			{ key = "lanternTall", x = -134, z = 142, height = 6.5 },
			{ key = "lanternTall", x = -172, z = 142, height = 6.5 },
			{ key = "lowTable", x = -150, z = 42, height = 6.5 },
			{ key = "floorCushion", x = -141, z = 42, height = 3.5, yaw = -90 },
			{ key = "floorCushion", x = -159, z = 42, height = 3.5, yaw = 90 },
			{ key = "teaPot", x = -166, z = 46, height = 3.5 },
			{ key = "lantern", x = -136, z = 38, height = 4.6 },
			{ key = "lantern", x = -166, z = 34, height = 4.6 },
			{ key = "wateringCan", x = -178, z = 100, height = 1.7, yaw = 180, pitch = -35 },
			{ key = "sakuraTree", x = -188, z = 132, height = 17 },
			{ key = "sakuraTree", x = -188, z = 52, height = 16 },
		}

		for _, row in KITCHEN_YARD do
			helpers.prop(ctx, row.key, row.x, row.z, {
				height = row.height,
				rotation = math.rad(row.yaw or 0),
				pitch = row.pitch,
			})
		end

		for _, at in { { -176, 92 }, { -176, 76 }, { -122, 122 }, { -122, 58 } } do
			Props.berryCrate(ctx, at[1], at[2])
		end

		helpers.studyDesk(ctx, { x = desksAt.x, z = desksAt.z, y = 2.4 })

		SectionDressing.dress(ctx)
	end,
})

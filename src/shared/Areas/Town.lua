local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Props = require(ReplicatedStorage.Shared.Modules.Props)
local Sections = require(ReplicatedStorage.Shared.Modules.Config.Sections)
local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)

local Area = require(script.Parent.Area)
local SectionDressing = require(script.Parent.SectionDressing)

return Area.define({
	id = 1,
	key = "town",
	name = "Town & Grass Field",
	flavour = "Roadside weeding, tiny study desks, sasumata practice, and hot ramen bowls.",

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
		local half = ctx.area.terrain.islandSize / 2

		local plazaEdge = ctx.plazaRadius + 12

		local sasumataAt = { name = "Sasumata Yard", x = -half * 0.48 - 25, z = half * 0.35 }
		local weedsAt = { name = "Roadside Weeds", x = 30, z = 190 }
		local desksAt = { name = "Study Desks", x = 150, z = 30 }

		for _, side in { -1, 1 } do
			helpers.prop(ctx, "pinkBench", side * ctx.plazaRadius * 0.4, ctx.plazaRadius * 0.42, {
				height = 3.2,
				rotation = math.rad(90) * side,
			})
			helpers.prop(ctx, "flowerBed2", side * ctx.plazaRadius * 0.36, ctx.plazaRadius * 0.66, { height = 2.2 })
		end

		for _, area in Streets.PAVING do
			helpers.paving(ctx, area, Streets)
		end
		helpers.paving(ctx, Streets.SQUARE, Streets, Streets.SQUARE_COLOR)

		for _, verge in Streets.VERGES do
			helpers.hedge(ctx, verge, Streets)
		end

		for index, landmark in { sasumataAt, weedsAt } do
			local reach = math.sqrt(landmark.x * landmark.x + landmark.z * landmark.z)
			local dirX, dirZ = landmark.x / reach, landmark.z / reach
			helpers.signpost(ctx, {
				title = landmark.name,
				x = dirX * (plazaEdge + 34),
				z = dirZ * (plazaEdge + 34),
			})

			local bed = `flowerBed{(index % 3) + 1}`
			helpers.prop(ctx, bed, dirX * (plazaEdge + 22) - dirZ * 16, dirZ * (plazaEdge + 22) + dirX * 16, {
				height = 2.2,
			})
		end

		local gateZ = -(half - 20)
		for step = 1, 9 do
			local z = -plazaEdge + (gateZ + plazaEdge) * (step / 10)
			if step % 3 == 0 then
				helpers.prop(ctx, "pinkBench", -19, z, { height = 3.2, rotation = math.rad(90) })
				helpers.prop(ctx, `flowerBed{(step % 3) + 1}`, 20, z + 6, { height = 2.2 })
			end
		end

		helpers.signpost(ctx, {
			title = "Ramen",
			subtitle = "hot bowls",
			x = -half * 0.48 + 34,
			z = half * 0.5 - 30,
		})

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

		helpers.sasumataDummy(ctx, { x = sasumataAt.x, z = sasumataAt.z, y = 4.5 })

		helpers.weedingPatch(ctx, { x = weedsAt.x, z = weedsAt.z, y = 1.5 })

		helpers.waterfallZone(ctx, {
			x = half * 0.65,
			z = -half * 0.45,
			y = 8.0,
		})

		helpers.prop(ctx, "bridge", half * 0.65 - 46, -half * 0.45, { height = 7, rotation = math.rad(90) })
		helpers.prop(ctx, "pinkBench", half * 0.65 - 24, -half * 0.45 + 30, { height = 3.2, rotation = math.rad(180) })
		helpers.prop(ctx, "flowerBed3", half * 0.65 - 34, -half * 0.45 + 40, { height = 2.2 })

		local houses = { "house1", "house2", "house3" }

		local function homestead(index: number, x: number, z: number, facing: number, joinZ: number?)
			if Sections.isWild(x, z) then
				return
			end

			local placed = helpers.prop(ctx, houses[(index - 1) % #houses + 1], x, z, {
				height = ctx.rng:NextNumber(13, 16),
				rotation = facing + math.rad(ctx.rng:NextNumber(-7, 7)),
			})
			if not placed then
				helpers.hut(ctx, {
					x = x,
					z = z,
					width = ctx.rng:NextNumber(18, 24),
					depth = ctx.rng:NextNumber(14, 19),
					height = ctx.rng:NextNumber(11, 14),
					roofColor = if index % 2 == 0 then Color3.fromRGB(244, 186, 190) else Color3.fromRGB(168, 206, 232),
				})
			end

			helpers.prop(ctx, `flowerBed{(index % 3) + 1}`, x - 14, z + 13, { height = 2.2 })
			helpers.prop(ctx, "mailBox", x - 10, z + 15, { height = 3.6 })
			if index % 3 == 0 then
				helpers.prop(ctx, "picnicTable", x + 12, z + 17, { height = 3.4 })
			elseif index % 3 == 1 then
				helpers.prop(ctx, "laundryLine", x + 13, z + 18, { height = 5.5 })
			else
				helpers.prop(ctx, "wateringCan", x + 9, z + 14, { height = 1.6 })
			end

			if joinZ and index <= 7 then
				helpers.path(ctx, { fromX = x, fromZ = z + 12, toX = 0, toZ = joinZ, spacing = 10, width = 4.5 })
			end
		end

		for index = 1, 9 do
			local x = -half * 0.44 + (index - 1) * (half * 0.11)
			homestead(index, x, -half * 0.52, 0, -half * 0.4)
		end
		helpers.signpost(ctx, { title = "The Lane", subtitle = "mind the washing", x = 0, z = -half * 0.4 })

		for index = 1, 5 do
			homestead(index + 1, -half * 0.62, -half * 0.16 + (index - 1) * (half * 0.13), math.rad(90))
		end
		helpers.signpost(ctx, { title = "West Row", x = -half * 0.5, z = half * 0.2 })

		SectionDressing.dress(ctx)
	end,
})

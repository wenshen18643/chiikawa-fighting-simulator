--[[
	Area 1 — Town & Grass Field. The starting area.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sections = require(ReplicatedStorage.Shared.Modules.Config.Sections)

local Area = require(script.Parent.Area)
local SectionDressing = require(script.Parent.SectionDressing)

return Area.define({
	id = 1,
	key = "town",
	name = "Town & Grass Field",
	flavour = "Roadside weeding, tiny study desks, sasumata practice, and hot ramen bowls.",

	gate = { skillTotal = 0, certificationTotal = 0 },
	origin = Vector3.new(0, 0, 0),
	-- Halved from 2600. Town is the whole game, so it wants to be walkable
	-- rather than large: at 1300 the tier-3 pad still lands 522 studs out of a
	-- 650-stud half-width, and everything in it got denser for free.
	terrain = { material = "LeafyGrass", islandSize = 1300 },
	palette = {
		ground = Color3.fromRGB(150, 200, 130),
		prop = Color3.fromRGB(122, 168, 96),
		sky = Color3.fromRGB(214, 236, 250),
	},

	decorate = function(ctx)
		local helpers = ctx.helpers
		local half = ctx.area.terrain.islandSize / 2

		--[[
			The market row, and the paths out of it.

			Town is the whole game now, so the plaza has to be somewhere you
			come back to rather than the empty middle of a lawn. Three shop
			fronts face the square, lanterns walk you out of it, and stepping
			stones run to each district so "where do I go" has an answer you
			can see from the doorstep.

			Every prop is placed by HEIGHT rather than by a scale multiplier —
			a shop is nine studs tall next to a five-stud player because that is
			what a shop is, whatever the uploader worked in.
		]]
		local plazaEdge = ctx.plazaRadius + 12
		local padOne = ctx.districtRadius

		-- The fountain is the middle of the town and the thing you orient by.
		helpers.prop(ctx, "fountain", 0, ctx.plazaRadius * 0.42, { height = 9, rotation = 0 })
		for _, side in { -1, 1 } do
			helpers.prop(ctx, "pinkBench", side * ctx.plazaRadius * 0.4, ctx.plazaRadius * 0.42, {
				height = 3.2,
				rotation = math.rad(90) * side,
			})
			helpers.prop(ctx, "flowerBed2", side * ctx.plazaRadius * 0.36, ctx.plazaRadius * 0.66, { height = 2.2 })
		end

		--[[
			The market row. Seven fronts around the western half of the square
			rather than three: a town that feels lived in is mostly a question
			of how much of the horizon has a building on it.
		]]
		local shops = { "shopRed", "shopBlue", "shopStall", "shopBlue", "shopRed", "shopStall", "shopRed" }
		for index, key in shops do
			local angle = math.rad(150 + (index - 1) * 22)
			helpers.prop(ctx, key, math.cos(angle) * (plazaEdge + 26), math.sin(angle) * (plazaEdge + 26), {
				height = if key == "shopStall" then 7 else 10,
				rotation = angle + math.pi,
			})
			if index % 2 == 1 then
				local lampAngle = angle + math.rad(11)
				helpers.prop(
					ctx,
					"lantern",
					math.cos(lampAngle) * (plazaEdge + 6),
					math.sin(lampAngle) * (plazaEdge + 6),
					{
						height = 4.6,
					}
				)
			end
		end

		local districts = {
			{ angle = 50, name = "Sasumata Yard" },
			{ angle = 130, name = "Roadside Weeds" },
			{ angle = 230, name = "Study Desks" },
		}
		for index, district in districts do
			local radians = math.rad(district.angle)
			local dirX, dirZ = math.cos(radians), math.sin(radians)
			-- Out to the tier-1 pad, wherever that has ended up.
			helpers.path(ctx, {
				fromX = dirX * plazaEdge,
				fromZ = dirZ * plazaEdge,
				toX = dirX * padOne,
				toZ = dirZ * padOne,
				spacing = 8,
			})

			-- Lanterns the length of the path, not just at its mouth.
			for step = 1, 3 do
				local along = plazaEdge + (padOne - plazaEdge) * (step / 4)
				for _, side in { -1, 1 } do
					helpers.prop(ctx, "lantern", dirX * along - dirZ * side * 11, dirZ * along + dirX * side * 11, {
						height = 4.4,
					})
				end
			end

			-- A lantern pair where the path leaves the square.
			for _, side in { -1, 1 } do
				helpers.prop(
					ctx,
					"lanternTall",
					dirX * (plazaEdge + 10) - dirZ * side * 9,
					dirZ * (plazaEdge + 10) + dirX * side * 9,
					{
						height = 6.5,
						rotation = radians,
					}
				)
			end

			helpers.signpost(ctx, {
				title = district.name,
				x = dirX * (plazaEdge + 34),
				z = dirZ * (plazaEdge + 34),
			})

			-- Flower beds where the path meets the square, alternating kinds so
			-- four exits do not look like four copies of one exit.
			local bed = `flowerBed{(index % 3) + 1}`
			helpers.prop(ctx, bed, dirX * (plazaEdge + 22) - dirZ * 16, dirZ * (plazaEdge + 22) + dirX * 16, {
				height = 2.2,
			})
		end

		-- The road south, out to the gate in the fence.
		local gateZ = -(half - 20)
		helpers.path(ctx, { fromX = 0, fromZ = -plazaEdge, toX = 0, toZ = gateZ, spacing = 10, width = 9 })
		for step = 1, 9 do
			local z = -plazaEdge + (gateZ + plazaEdge) * (step / 10)
			helpers.prop(ctx, "lantern", -11, z, { height = 4.6 })
			helpers.prop(ctx, "lantern", 11, z, { height = 4.6 })
			if step % 3 == 0 then
				helpers.prop(ctx, "pinkBench", -19, z, { height = 3.2, rotation = math.rad(90) })
				helpers.prop(ctx, `flowerBed{(step % 3) + 1}`, 20, z + 6, { height = 2.2 })
			end
		end

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
			x = 30,
			z = 190,
			y = 1.5,
		})

		-- Landmark Waterfall Zone on the eastern cliff edge
		helpers.waterfallZone(ctx, {
			x = half * 0.65,
			z = -half * 0.45,
			y = 8.0,
		})

		-- A bridge and a bench at the waterfall: the one place worth sitting.
		helpers.prop(ctx, "bridge", half * 0.65 - 46, -half * 0.45, { height = 7, rotation = math.rad(90) })
		helpers.prop(ctx, "pinkBench", half * 0.65 - 24, -half * 0.45 + 30, { height = 3.2, rotation = math.rad(180) })
		helpers.prop(ctx, "flowerBed3", half * 0.65 - 34, -half * 0.45 + 40, { height = 2.2 })

		--[[
			A lane of houses along the southern road, dressed rather than just
			built: a washing line, a post box and a picnic table are what make
			a row of boxes read as somewhere people live.
		]]
		local houses = { "house1", "house2", "house3" }

		--[[
			One house, with the yard that makes it somebody's.

			A house on its own is scenery. A house with a post box, a washing
			line and a path back to the road is a house that is being lived in,
			and that difference is the whole reason the town felt empty before.
		]]
		local function homestead(index: number, x: number, z: number, facing: number, joinZ: number?)
			-- The lane predates the sausage forest and its western half now runs
			-- straight through it. Nobody lives in the forest, so nobody builds
			-- there and no path is laid to it.
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

			if joinZ then
				helpers.path(ctx, { fromX = x, fromZ = z + 12, toX = 0, toZ = joinZ, spacing = 10, width = 4.5 })
			end
		end

		-- The lane along the southern road.
		for index = 1, 9 do
			local x = -half * 0.44 + (index - 1) * (half * 0.11)
			homestead(index, x, -half * 0.52, 0, -half * 0.4)
		end
		helpers.signpost(ctx, { title = "The Lane", subtitle = "mind the washing", x = 0, z = -half * 0.4 })

		-- A second, smaller hamlet on the western side, so the town does not
		-- end the moment you leave the one street it has.
		for index = 1, 5 do
			homestead(index + 1, -half * 0.62, -half * 0.16 + (index - 1) * (half * 0.13), math.rad(90))
		end
		helpers.path(ctx, {
			fromX = -half * 0.54,
			fromZ = -half * 0.1,
			toX = -plazaEdge,
			toZ = 0,
			spacing = 10,
			width = 6,
		})
		helpers.signpost(ctx, { title = "West Row", x = -half * 0.5, z = half * 0.2 })

		-- The sakura orchard is its own section now (Sakura Heights, north row).

		--[[
			The island-wide scatter that used to live here is gone: the ground
			between the plaza and the fence is now a quilt of themed sections,
			each the size of the safe-zone plot (Config/Sections.lua). Meadow
			and grove sections carry the woodland this used to spray everywhere.
		]]
		SectionDressing.dress(ctx)
	end,
})

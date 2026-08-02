--[[
	Area 1 — Town & Grass Field. The starting area.
]]

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
	-- Halved from 2600. Town is the whole game, so it wants to be walkable
	-- rather than large: at 1300 the far fence is a 650-stud walk from the plaza
	-- and everything in it got denser for free.
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
			stones run to each landmark so "where do I go" has an answer you
			can see from the doorstep.

			Every prop is placed by HEIGHT rather than by a scale multiplier —
			a shop is nine studs tall next to a five-stud player because that is
			what a shop is, whatever the uploader worked in.
		]]
		local plazaEdge = ctx.plazaRadius + 12

		local sasumataAt = { name = "Sasumata Yard", x = -half * 0.48 - 25, z = half * 0.35 }
		local weedsAt = { name = "Roadside Weeds", x = 30, z = 190 }
		-- Moved to D4, south of the library it belongs to. The exam counter is
		-- the library's front garden now, not a field two sections away.
		local desksAt = { name = "Study Desks", x = 150, z = 30 }

		--[[
			Nothing stands on the axis of the front door. The plaza centre is
			also the doorstep the player is put down on, so a centrepiece there
			is the first thing they walk into rather than the thing they walk
			toward. The square is dressed from its edges instead.
		]]
		for _, side in { -1, 1 } do
			helpers.prop(ctx, "pinkBench", side * ctx.plazaRadius * 0.4, ctx.plazaRadius * 0.42, {
				height = 3.2,
				rotation = math.rad(90) * side,
			})
			helpers.prop(ctx, "flowerBed2", side * ctx.plazaRadius * 0.36, ctx.plazaRadius * 0.66, { height = 2.2 })
		end

		--[[
			The streets.

			Laid before anything is scattered, because Layout reserves every
			carriageway and the dressing pass reads those reserves: the road has
			to be a fact before the town is allowed to grow up around it.

			The seven-shop arc that used to stand here swept 150 to 282 degrees
			at radius 123, which runs straight through the kitchen's forecourt
			and the market square. The shops are in the market now, where they
			have a square to face rather than a lawn.
		]]
		for _, area in Streets.PAVING do
			helpers.paving(ctx, area, Streets)
		end
		helpers.paving(ctx, Streets.SQUARE, Streets, Streets.SQUARE_COLOR)

		-- The hedges that give the roads an edge, and the lanterns and benches
		-- they carry. Everything a street is furnished with is measured off its
		-- own verge, so nothing can end up standing in the carriageway.
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

			-- Flower beds where the path meets the square, alternating kinds so
			-- four exits do not look like four copies of one exit.
			local bed = `flowerBed{(index % 3) + 1}`
			helpers.prop(ctx, bed, dirX * (plazaEdge + 22) - dirZ * 16, dirZ * (plazaEdge + 22) + dirX * 16, {
				height = 2.2,
			})
		end

		-- The road south, out to the gate in the fence.
		local gateZ = -(half - 20)
		for step = 1, 9 do
			local z = -plazaEdge + (gateZ + plazaEdge) * (step / 10)
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

		--[[
			A sign inside each gate, naming what is through it.

			Placed here rather than left to SectionDressing. That pass walks a
			district's sign in from the cell centre toward the plaza and gives up
			if every candidate is reserved -- and for these three every candidate
			is: the safe volume, the plaza skirt and the building's own reserve
			between them cover the whole approach. So the town's three newest
			districts would have been the only unlabelled ones on the board.

			No arch over any of them. The gate is the threshold; a second one
			built on top of it is set dressing standing in the doorway.
		]]
		for _, marker in
			{
				{ title = "Library", subtitle = "and the exam hall", x = 70, z = 106 },
				{ title = "Kitchen", subtitle = "something is always on", x = -70, z = 106 },
				{ title = "Market Square", subtitle = "upgrades and work", x = -30, z = -42 },
			}
		do
			helpers.signpost(ctx, marker)
		end

		--[[
			The kitchen's forecourt and yard.

			The library reads well because a big building carries a cell on its own.
			The kitchen is 52 x 42 against the library's 84 x 62, so stripping its
			scatter left it standing in a field -- correct in principle, empty in
			practice. What it wants is not scatter back but the same treatment the
			market got: things PLACED, facing the road or the door.

			The building runs X -171..-129, Z 64..116 with its door on the east
			face, and the kitchen road is X -129..-103, Z 83..97 with hedges either
			side of it. Everything below is clear of both.

			A stall serves along its own +X, and CFrame.Angles(0, t, 0) sends +X to
			(cos t, -sin t) -- so 90 serves south and -90 serves north. Both stalls
			here therefore face the road they stand beside.
		]]
		local KITCHEN_YARD = {
			{ key = "shopStall", x = -118, z = 108, height = 7, yaw = 90 },
			{ key = "shopStall", x = -118, z = 72, height = 7, yaw = -90 },

			-- The eating yard north of the building, laid out around one table.
			{ key = "lowTable", x = -152, z = 138, height = 7 },
			{ key = "floorCushion", x = -143, z = 138, height = 3.5, yaw = -90 },
			{ key = "floorCushion", x = -161, z = 138, height = 3.5, yaw = 90 },
			{ key = "floorCushion", x = -152, z = 147, height = 3.5, yaw = 180 },
			{ key = "ramen", x = -168, z = 144, height = 9 },
			{ key = "lanternTall", x = -134, z = 142, height = 6.5 },
			{ key = "lanternTall", x = -172, z = 142, height = 6.5 },

			-- A second, smaller one south of it, so the yard is not one island.
			{ key = "lowTable", x = -150, z = 42, height = 6.5 },
			{ key = "floorCushion", x = -141, z = 42, height = 3.5, yaw = -90 },
			{ key = "floorCushion", x = -159, z = 42, height = 3.5, yaw = 90 },
			{ key = "teaPot", x = -166, z = 46, height = 3.5 },
			{ key = "lantern", x = -136, z = 38, height = 4.6 },
			{ key = "lantern", x = -166, z = 34, height = 4.6 },

			-- Stock against the west wall, where a kitchen keeps it.
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

		-- Landmark Study Desk outside Exam Hall
		helpers.studyDesk(ctx, { x = desksAt.x, z = desksAt.z, y = 2.4 })

		-- Landmark Sasumata Training Dummy outside Subjugation grounds
		helpers.sasumataDummy(ctx, { x = sasumataAt.x, z = sasumataAt.z, y = 4.5 })

		-- Landmark Weeding Patch in Town Square
		helpers.weedingPatch(ctx, { x = weedsAt.x, z = weedsAt.z, y = 1.5 })

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

			-- Keep the three approved southern-lane branches west of the two
			-- eastern branches whose paths were removed.
			if joinZ and index <= 7 then
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

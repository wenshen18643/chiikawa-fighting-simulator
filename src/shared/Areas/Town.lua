local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Props = require(ReplicatedStorage.Shared.Modules.Props)
local SafeZone = require(ReplicatedStorage.Shared.Modules.Config.SafeZone)
local Streets = require(ReplicatedStorage.Shared.Modules.Config.Streets)
local Area = require(script.Parent.Area)
local SectionDressing = require(script.Parent.SectionDressing)
local TABLE_TOP = SafeZone.SURFACE.lowTable
local YARD_REACH = 5
local CRATE_REACH = 4
local DESK_REACH = 6

local KITCHEN_YARD = {
	{ key = "lowTable", x = -152, z = 138, fit = 13 },
	{ key = "floorCushion", x = -142, z = 138, fit = 5, yaw = -90 },
	{ key = "floorCushion", x = -162, z = 138, fit = 5, yaw = 90 },
	{ key = "floorCushion", x = -152, z = 148, fit = 5 },
	{ key = "ramen", x = -152, z = 138, fit = 13, y = TABLE_TOP },
	{ key = "lanternTall", x = -134, z = 142, height = 6.5 },
	{ key = "lanternTall", x = -172, z = 142, height = 6.5 },

	{ key = "lowTable", x = -150, z = 42, fit = 13 },
	{ key = "floorCushion", x = -140, z = 42, fit = 5, yaw = -90 },
	{ key = "floorCushion", x = -160, z = 42, fit = 5, yaw = 90 },
	{ key = "teaPot", x = -150, z = 42, fit = 4.5, y = TABLE_TOP },
	{ key = "lantern", x = -136, z = 36, height = 4.6 },
	{ key = "lantern", x = -166, z = 34, height = 4.6 },

	{ key = "sakuraTree", x = -188, z = 132, height = 17 },
	{ key = "sakuraTree", x = -188, z = 52, height = 16 },
}

local LIBRARY_YARD = {
	{ key = "lowTable", x = 152, z = 152, fit = 13 },
	{ key = "floorCushion", x = 142, z = 152, fit = 5, yaw = -90 },
	{ key = "floorCushion", x = 162, z = 152, fit = 5, yaw = 90 },
	{ key = "floorCushion", x = 152, z = 162, fit = 5 },
	{ key = "teaPot", x = 152, z = 152, fit = 4.5, y = TABLE_TOP },
	{ key = "lanternTall", x = 134, z = 156, height = 6.5 },
	{ key = "lanternTall", x = 170, z = 156, height = 6.5 },

	{ key = "lowTable", x = 150, z = 28, fit = 13 },
	{ key = "floorCushion", x = 140, z = 28, fit = 5, yaw = -90 },
	{ key = "floorCushion", x = 160, z = 28, fit = 5, yaw = 90 },
	{ key = "teaCup", x = 150, z = 28, fit = 2.4, y = TABLE_TOP },
	{ key = "lantern", x = 136, z = 22, height = 4.6 },
	{ key = "lantern", x = 166, z = 20, height = 4.6 },

	{ key = "sakuraTree", x = 186, z = 160, height = 17 },
	{ key = "sakuraTree", x = 186, z = 20, height = 16 },
}

local BERRY_CRATES = { { -176, 92 }, { -176, 76 }, { -122, 122 }, { -122, 58 } }
local BOOK_STACKS = { { 122, 122 }, { 122, 58 }, { 140, 140 }, { 170, 40 } }
local STUDY_DESKS = { { 118, 108 }, { 118, 72 } }

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

		for _, side in { -1, 1 } do
			local x, z = side * ctx.plazaRadius * 0.36, ctx.plazaRadius * 0.66
			SectionDressing.claim(ctx, x, z, CRATE_REACH, helpers.prop(ctx, "flowerBed2", x, z, { height = 2.2 }))
		end

		for _, area in Streets.PAVING do
			helpers.paving(ctx, area, Streets)
		end
		helpers.paving(ctx, Streets.SQUARE, Streets, Streets.SQUARE_COLOR)

		helpers.hedges(ctx, Streets.VERGES, Streets)

		for _, yard in { KITCHEN_YARD, LIBRARY_YARD } do
			for _, row in yard do
				local made = helpers.prop(ctx, row.key, row.x, row.z, {
					height = row.height,
					fit = row.fit,
					y = row.y,
					rotation = math.rad(row.yaw or 0),
				})
				SectionDressing.claim(ctx, row.x, row.z, YARD_REACH, made)
			end
		end

		for _, at in BERRY_CRATES do
			Props.berryCrate(ctx, at[1], at[2])
			SectionDressing.claim(ctx, at[1], at[2], CRATE_REACH)
		end

		for _, at in BOOK_STACKS do
			Props.bookStack(ctx, at[1], at[2])
			SectionDressing.claim(ctx, at[1], at[2], CRATE_REACH)
		end

		for _, at in STUDY_DESKS do
			local desk = helpers.studyDesk(ctx, { x = at[1], z = at[2], y = 2.4 })
			SectionDressing.claim(ctx, at[1], at[2], DESK_REACH, desk)
		end

		SectionDressing.dress(ctx)
	end,
})

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Farming = require(Shared.Modules.Config.Farming)
local Feast = require(Shared.Modules.Config.Feast)
local Sections = require(Shared.Modules.Config.Sections)
local Props = require(Shared.Modules.Props)

local SectionDressing = {}

local SIZE = Sections.SIZE
local LIMIT = Sections.SCATTER_LIMIT

local function samplePoint(ctx, cell, inset)
	for _ = 1, 14 do
		local x = ctx.rng:NextNumber(cell.minX + inset, cell.maxX - inset)
		local z = ctx.rng:NextNumber(cell.minZ + inset, cell.maxZ - inset)
		if math.abs(x) <= LIMIT and math.abs(z) <= LIMIT and not ctx.isReserved(x, z) then
			return x, z
		end
	end
	return nil
end

local function range(ctx, bounds, fallback)
	if not bounds then
		return fallback
	end
	return ctx.rng:NextNumber(bounds[1], bounds[2])
end

local CLEARANCE = { bush = 7, stone = 6, log = 8, prop = 5, coded = 10, tree = 9, house = 14 }

local function solidify(instance)
	if not instance then
		return
	end
	local parts = if instance:IsA("BasePart") then { instance } else instance:GetDescendants()
	for _, part in parts do
		if part:IsA("BasePart") then
			part.CanCollide = true

			part.CanQuery = true
		end
	end
end

local function dressRecipe(ctx, cell, entry, placed)
	local inset = if entry.kind == "tree" or entry.kind == "prop" then 16 else 10
	local clearance = placed and CLEARANCE[entry.kind]
	local function openSpot()
		for _ = 1, 6 do
			local x, z = samplePoint(ctx, cell, inset)
			if not x then
				return nil
			end
			if not clearance then
				return x, z
			end
			local near = false
			for _, at in placed do
				if (at - Vector2.new(x, z)).Magnitude < clearance then
					near = true
					break
				end
			end
			if not near then
				return x, z
			end
		end

		return nil
	end

	for _ = 1, entry.count do
		local x, z = openSpot()
		if x then
			local made
			if entry.kind == "prop" then
				made = ctx.helpers.prop(ctx, entry.key, x, z, {
					height = range(ctx, entry.h, 4),
					upright = entry.upright,
					pitch = entry.pitch,
				})

				if made and entry.edible and Feast.get(entry.key) then
					made:SetAttribute("FeastId", entry.key)
					CollectionService:AddTag(made, Feast.PROP_TAG)
				end
			elseif entry.kind == "tree" then
				made = ctx.helpers.tree(ctx, x, z, range(ctx, entry.h, 12), range(ctx, entry.canopy, 12))
			elseif entry.kind == "bush" then
				made = ctx.helpers.bush(ctx, x, z, range(ctx, entry.s, 4))
			elseif entry.kind == "stone" then
				made = ctx.helpers.stone(ctx, x, z, range(ctx, entry.s, 4))
			elseif entry.kind == "log" then
				made = ctx.helpers.log(ctx, x, z, range(ctx, entry.l, 8))
			elseif entry.kind == "grass" then
				local match = if ctx.rng:NextNumber() > 0.45 then "grass" else "flower"
				if not ctx.helpers.natureProp(ctx, x, z, match) then
					ctx.helpers.bush(ctx, x, z, ctx.rng:NextNumber(3, 6))
				end
			elseif entry.kind == "flower" then
				if not ctx.helpers.prop(ctx, `flowerBed{ctx.rng:NextInteger(1, 3)}`, x, z, { height = 2.1 }) then
					ctx.helpers.bush(ctx, x, z, ctx.rng:NextNumber(3, 5))
				end
			elseif entry.kind == "grassPatch" then
				ctx.helpers.prop(ctx, "grassPatch", x, z, { height = range(ctx, entry.h, 2) })
			elseif entry.kind == "desk" then
				ctx.helpers.studyDesk(ctx, { x = x, z = z, y = 3.2 })
			elseif entry.kind == "house" then
				made = ctx.helpers.prop(
					ctx,
					`house{ctx.rng:NextInteger(1, 3)}`,
					x,
					z,
					{ height = ctx.rng:NextNumber(13, 16) }
				)
			elseif entry.kind == "coded" then
				local build = Props[entry.fn]
				if build then
					build(ctx, x, z)
				end
			end
			if clearance then
				table.insert(placed, Vector2.new(x, z))
				solidify(made)
			end
		end
	end
end

local function towardPlaza(cell, distance)
	local flat = Vector2.new(cell.cx, cell.cz)
	local length = flat.Magnitude
	if length < 1 then
		return cell.cx, cell.cz
	end
	local dir = flat / length
	local at = flat - dir * distance
	return at.X, at.Y
end

local function dressSign(ctx, cell, theme)
	for _, distance in { SIZE / 2 - 26, SIZE / 2 - 60, 30, -30, -(SIZE / 2 - 40) } do
		local x, z = towardPlaza(cell, distance)
		if math.abs(x) <= LIMIT and math.abs(z) <= LIMIT and not ctx.isReserved(x, z) then
			ctx.helpers.signpost(ctx, { title = theme.name, subtitle = theme.sub, x = x, z = z })
			local dir = Vector2.new(cell.cx, cell.cz).Unit
			for _, side in { -1, 1 } do
				local fx = x - dir.Y * side * 6
				local fz = z + dir.X * side * 6
				if not ctx.isReserved(fx, fz) then
					ctx.helpers.prop(ctx, `flowerBed{ctx.rng:NextInteger(1, 3)}`, fx, fz, { height = 2.2 })
				end
			end
			if theme.arch then
				local yaw = math.atan2(-dir.X, -dir.Y)
				Props.gardenArch(ctx, x + dir.X * 7, z + dir.Y * 7, yaw, Color3.fromRGB(244, 186, 190))
			end
			return
		end
	end
end

local function dressCell(ctx, cell)
	if cell.coord == Farming.CELL_COORD then
		return
	end
	local theme = Sections.THEMES[cell.theme]
	if not theme then
		return
	end

	local placed = if theme.wild then {} else nil
	for _, entry in theme.recipe do
		dressRecipe(ctx, cell, entry, placed)
	end

	if not theme.wild then
		dressSign(ctx, cell, theme)
	end
end

local function dressBorder(ctx, i, j, vertical)
	local cellA = Sections.cell(i, j)
	local cellB = if vertical then Sections.cell(i + 1, j) else Sections.cell(i, j + 1)
	if (cellA and cellA.coord == Farming.CELL_COORD) or (cellB and cellB.coord == Farming.CELL_COORD) then
		return
	end
	local themeA = Sections.themeAt(i, j)
	local themeB = if vertical then Sections.themeAt(i + 1, j) else Sections.themeAt(i, j + 1)
	if not themeA or not themeB or themeA == themeB then
		return
	end
	if themeA ~= "farm" and themeB ~= "farm" then
		return
	end
	local wildA = Sections.THEMES[themeA]
	local wildB = Sections.THEMES[themeB]
	if (wildA and wildA.wild) or (wildB and wildB.wild) then
		return
	end

	local minX = if vertical then -Sections.HALF + i * SIZE else -Sections.HALF + (i - 1) * SIZE
	local minZ = if vertical then -Sections.HALF + (j - 1) * SIZE else -Sections.HALF + j * SIZE

	local clear = true
	for step = 0, 4 do
		local along = (step / 4) * (SIZE - 12) + 6
		local x = if vertical then minX else minX + along
		local z = if vertical then minZ + along else minZ
		if ctx.isReserved(x, z) then
			clear = false
			break
		end
	end

	if not clear then
		return
	end

	if vertical then
		Props.miniFence(ctx, minX, minZ + 6, minX, minZ + SIZE - 6)
	else
		Props.miniFence(ctx, minX + 6, minZ, minX + SIZE - 6, minZ)
	end
end

function SectionDressing.dress(ctx)
	for _, cell in Sections.cells() do
		local ok, err = pcall(dressCell, ctx, cell)
		if not ok then
			warn(`[SectionDressing] cell {cell.i},{cell.j} ({cell.theme}) failed: {err}`)
		end
	end

	for i = 1, Sections.GRID - 1 do
		for j = 1, Sections.GRID do
			dressBorder(ctx, i, j, true)
		end
	end
	for j = 1, Sections.GRID - 1 do
		for i = 1, Sections.GRID do
			dressBorder(ctx, i, j, false)
		end
	end
end

return SectionDressing

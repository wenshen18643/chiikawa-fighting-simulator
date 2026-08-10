local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feast = require(Shared.Modules.Config.Feast)
local Sections = require(Shared.Modules.Config.Sections)
local Props = require(Shared.Modules.Props)
local SectionDressing = {}
local SIZE = Sections.SIZE
local LIMIT = Sections.SCATTER_LIMIT

local function standsClear(ctx, x, z, reach)
	if math.abs(x) > LIMIT or math.abs(z) > LIMIT or ctx.isReserved(x, z) then
		return false
	end
	if reach <= 0 then
		return true
	end
	local diagonal = reach * 0.7071
	return not ctx.isReserved(x + reach, z)
		and not ctx.isReserved(x - reach, z)
		and not ctx.isReserved(x, z + reach)
		and not ctx.isReserved(x, z - reach)
		and not ctx.isReserved(x + diagonal, z + diagonal)
		and not ctx.isReserved(x - diagonal, z + diagonal)
		and not ctx.isReserved(x + diagonal, z - diagonal)
		and not ctx.isReserved(x - diagonal, z - diagonal)
end

local OCCUPIED_GRID = 32
local OCCUPIED_STRIDE = 4096
local MIN_GAP = 2.5
local PLACEMENT_ATTEMPTS = 32
local FALLBACK_RADIUS = { key = 4, fn = 8 }

local function bucketOf(occupied, gx, gz)
	return occupied[gx * OCCUPIED_STRIDE + gz]
end

local function occupy(occupied, x, z, radius)
	local key = math.floor(x / OCCUPIED_GRID) * OCCUPIED_STRIDE + math.floor(z / OCCUPIED_GRID)
	local bucket = occupied[key]
	if not bucket then
		bucket = {}
		occupied[key] = bucket
	end
	table.insert(bucket, { x = x, z = z, r = radius })
end

local function crowded(occupied, x, z, reach)
	local gx, gz = math.floor(x / OCCUPIED_GRID), math.floor(z / OCCUPIED_GRID)
	for ox = -1, 1 do
		for oz = -1, 1 do
			local bucket = bucketOf(occupied, gx + ox, gz + oz)
			if bucket then
				for _, at in bucket do
					local dx, dz = x - at.x, z - at.z
					local gap = at.r + reach + MIN_GAP
					if dx * dx + dz * dz < gap * gap then
						return true
					end
				end
			end
		end
	end
	return false
end

local function gridFor(ctx)
	local grid = ctx.occupied
	if not grid then
		grid = {}
		ctx.occupied = grid
	end
	return grid
end

local function footprintOf(made, fallback: number): number
	if made then
		local size = if made:IsA("BasePart") then made.Size else made:GetExtentsSize()
		local span = math.max(size.X, size.Z) / 2
		if span > 0.01 then
			return span
		end
	end
	return fallback
end

local function range(ctx, bounds, fallback)
	if not bounds then
		return fallback
	end
	return ctx.rng:NextNumber(bounds[1], bounds[2])
end

local CLEARANCE = { bush = 7, stone = 6, log = 8, prop = 5, coded = 10, tree = 9, house = 14 }

local function reachOf(entry): number
	local kind = entry.kind
	if kind == "tree" then
		return (if entry.canopy then entry.canopy[2] else 12) * 0.85
	elseif kind == "bush" or kind == "stone" then
		return (if entry.s then entry.s[2] else 5) / 2
	elseif kind == "log" then
		return (if entry.l then entry.l[2] else 8) / 2
	elseif kind == "house" then
		return 11
	elseif kind == "prop" then
		return (if entry.h then entry.h[2] else 4) * 0.4
	elseif kind == "coded" then
		return 7
	elseif kind == "desk" then
		return 6
	end
	return 3
end

local function facingOrigin(x: number, z: number): number
	if math.abs(x) < 0.01 and math.abs(z) < 0.01 then
		return 0
	end
	return math.atan2(-x, -z)
end

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

local function dressRecipe(ctx, cell, entry, occupied, solid)
	local inset = if entry.kind == "tree" or entry.kind == "prop" then 16 else 10
	local reach = reachOf(entry)

	local function openSpot()
		for _ = 1, PLACEMENT_ATTEMPTS do
			local x = ctx.rng:NextNumber(cell.minX + inset, cell.maxX - inset)
			local z = ctx.rng:NextNumber(cell.minZ + inset, cell.maxZ - inset)
			if standsClear(ctx, x, z, reach) and not crowded(occupied, x, z, reach) then
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
					rotation = if entry.faceOrigin then facingOrigin(x, z) else nil,
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
				made = ctx.helpers.bush(ctx, x, z, ctx.rng:NextNumber(3, 6))
			elseif entry.kind == "flower" then
				made = ctx.helpers.prop(ctx, `flowerBed{ctx.rng:NextInteger(1, 3)}`, x, z, { height = 2.1 })
				if not made then
					made = ctx.helpers.bush(ctx, x, z, ctx.rng:NextNumber(3, 5))
				end
			elseif entry.kind == "grassPatch" then
				made = ctx.helpers.prop(ctx, "grassPatch", x, z, { height = range(ctx, entry.h, 2) })
			elseif entry.kind == "desk" then
				made = ctx.helpers.studyDesk(ctx, { x = x, z = z, y = 3.2 })
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
			occupy(occupied, x, z, math.max(footprintOf(made, reach), reach))
			if solid and CLEARANCE[entry.kind] then
				solidify(made)
			end
		end
	end
end

local function dressLayout(ctx, cell, layout, occupied)
	for _, item in layout do
		local x, z = cell.cx + item.x, cell.cz + item.z

		if math.abs(x) > LIMIT or math.abs(z) > LIMIT or ctx.isReserved(x, z) then
			continue
		end

		local made
		if item.fn then
			local build = Props[item.fn]
			if build then
				made = build(ctx, x, z)
			end
		else
			made = ctx.helpers.prop(ctx, item.key, x, z, {
				height = item.h,
				fit = item.fit,
				y = item.y,
				upright = item.upright,
				rotation = if item.yaw then math.rad(item.yaw) else nil,
			})
		end

		occupy(occupied, x, z, item.r or footprintOf(made, if item.fn then FALLBACK_RADIUS.fn else FALLBACK_RADIUS.key))
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

local ENTRANCE_REACH = 4
local ARCH_REACH = 7

local function dressEntrance(ctx, cell, theme, occupied)
	for _, distance in { SIZE / 2 - 26, SIZE / 2 - 60, 30, -30, -(SIZE / 2 - 40) } do
		local x, z = towardPlaza(cell, distance)
		if math.abs(x) <= LIMIT and math.abs(z) <= LIMIT and not ctx.isReserved(x, z) then
			local dir = Vector2.new(cell.cx, cell.cz).Unit
			for _, side in { -1, 1 } do
				local fx = x - dir.Y * side * 6
				local fz = z + dir.X * side * 6
				if not ctx.isReserved(fx, fz) and not crowded(occupied, fx, fz, ENTRANCE_REACH) then
					local made = ctx.helpers.prop(ctx, `flowerBed{ctx.rng:NextInteger(1, 3)}`, fx, fz, { height = 2.2 })
					occupy(occupied, fx, fz, footprintOf(made, ENTRANCE_REACH))
				end
			end
			if theme.arch then
				local ax, az = x + dir.X * 7, z + dir.Y * 7
				if not crowded(occupied, ax, az, ARCH_REACH) then
					Props.gardenArch(ctx, ax, az, math.atan2(-dir.X, -dir.Y), Color3.fromRGB(244, 186, 190))
					occupy(occupied, ax, az, ARCH_REACH)
				end
			end
			return
		end
	end
end

local function dressCell(ctx, cell)
	local theme = Sections.THEMES[cell.theme]
	if not theme or theme.bare then
		return
	end

	local occupied = gridFor(ctx)
	local solid = theme.wild == true or theme.layout ~= nil
	if theme.layout then
		dressLayout(ctx, cell, theme.layout, occupied)
	end

	for _, entry in theme.recipe do
		dressRecipe(ctx, cell, entry, occupied, solid)
	end

	if not solid then
		dressEntrance(ctx, cell, theme, occupied)
	end
end

local function dressBorder(ctx, i, j, vertical)
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

function SectionDressing.claim(ctx, x: number, z: number, radius: number, made: Instance?)
	occupy(gridFor(ctx), x, z, math.max(footprintOf(made, radius), radius))
end

function SectionDressing.dress(ctx)
	for _, cell in Sections.cellsNearestFirst() do
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

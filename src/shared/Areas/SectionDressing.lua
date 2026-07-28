local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Modules.Constants)
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

local function dressRecipe(ctx, cell, entry)
	local inset = if entry.kind == "tree" or entry.kind == "prop" then 16 else 10
	for _ = 1, entry.count do
		local x, z = samplePoint(ctx, cell, inset)
		if x then
			if entry.kind == "prop" then
				ctx.helpers.prop(ctx, entry.key, x, z, {
					height = range(ctx, entry.h, 4),
					upright = entry.upright,
					pitch = entry.pitch,
				})
			elseif entry.kind == "tree" then
				ctx.helpers.tree(ctx, x, z, range(ctx, entry.h, 12), range(ctx, entry.canopy, 12))
			elseif entry.kind == "bush" then
				ctx.helpers.bush(ctx, x, z, range(ctx, entry.s, 4))
			elseif entry.kind == "stone" then
				ctx.helpers.stone(ctx, x, z, range(ctx, entry.s, 4))
			elseif entry.kind == "log" then
				ctx.helpers.log(ctx, x, z, range(ctx, entry.l, 8))
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
				ctx.helpers.prop(ctx, `house{ctx.rng:NextInteger(1, 3)}`, x, z, { height = ctx.rng:NextNumber(13, 16) })
			elseif entry.kind == "coded" then
				local build = Props[entry.fn]
				if build then
					build(ctx, x, z)
				end
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
	local theme = Sections.THEMES[cell.theme]
	if not theme then
		return
	end
	for _, entry in theme.recipe do
		dressRecipe(ctx, cell, entry)
	end
	dressSign(ctx, cell, theme)
end

--[[
	The roads. Every border between two different themes is a road, so the
	section grid is something you can literally walk: farm borders get a picket
	fence instead, everything else gets stone slabs with lanterns scattered
	along them. Same-theme borders stay open field.
]]
local function dressBorder(ctx, i, j, vertical)
	local themeA = Sections.themeAt(i, j)
	local themeB = if vertical then Sections.themeAt(i + 1, j) else Sections.themeAt(i, j + 1)
	if not themeA or not themeB or themeA == themeB then
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

	if clear and (themeA == "farm" or themeB == "farm") then
		if vertical then
			Props.miniFence(ctx, minX, minZ + 6, minX, minZ + SIZE - 6)
		else
			Props.miniFence(ctx, minX + 6, minZ, minX + SIZE - 6, minZ)
		end
		return
	end

	for step = 0, math.floor(SIZE / 6.5) do
		local along = step * 6.5 + ctx.rng:NextNumber(-1.5, 1.5)
		local drift = ctx.rng:NextNumber(-1.2, 1.2)
		local x = if vertical then minX + drift else minX + along
		local z = if vertical then minZ + along else minZ + drift
		if math.abs(x) <= LIMIT and math.abs(z) <= LIMIT and not ctx.isReserved(x, z) then
			local size = ctx.rng:NextNumber(5.5, 6.5)
			ctx.helpers.block(ctx, {
				name = "RoadSlab",
				size = Vector3.new(size, 0.5, size),
				color = if ctx.rng:NextNumber() > 0.86 then Color3.fromRGB(244, 206, 210) else Color3.fromRGB(236, 228, 214),
				material = Enum.Material.Cobblestone,
				x = x,
				z = z,
				y = 0.2,
				collide = false,
			})
			if step % 5 == 2 and ctx.rng:NextNumber() > 0.5 then
				local lx = if vertical then x + 5.5 else x
				local lz = if vertical then z else z + 5.5
				if math.abs(lx) <= LIMIT and math.abs(lz) <= LIMIT and not ctx.isReserved(lx, lz) then
					ctx.helpers.prop(ctx, "lantern", lx, lz, { height = 4.4 })
				end
			end
		end
	end
end

local function surfaceY(ctx, x, z)
	local hit = Workspace:Raycast(ctx.origin + Vector3.new(x, 160, z), Vector3.new(0, -320, 0))
	local top = if hit then hit.Position.Y else Constants.WORLD.TERRAIN_TOP + 1.5
	return math.min(top, ctx.groundY(x, z) + 1.6)
end

local function dressPath(ctx, cell)
	local target = Vector2.new(cell.cx, cell.cz)
	local length = target.Magnitude
	if length < 1 then
		return
	end
	local dir = target / length
	local from = dir * (ctx.plazaRadius + 16)
	local to = target - dir * 60
	local span = to - from
	local steps = math.floor(span.Magnitude / 8)
	for index = 0, steps do
		local at = from + dir * (index * 8)
		local drift = ctx.rng:NextNumber(-1.4, 1.4)
		local x = at.X - dir.Y * drift
		local z = at.Y + dir.X * drift
		local size = 7 * ctx.rng:NextNumber(0.82, 1.1)
		ctx.helpers.block(ctx, {
			name = "PathStone",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.5, size, size),
			color = if ctx.rng:NextNumber() > 0.82 then Color3.fromRGB(244, 206, 210) else Color3.fromRGB(246, 240, 228),
			material = Enum.Material.SmoothPlastic,
			cframe = CFrame.new(ctx.origin + Vector3.new(x, surfaceY(ctx, x, z) + 0.16, z)) * CFrame.Angles(0, 0, math.rad(90)),
			collide = false,
		})
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

	for _, target in Sections.PATH_TARGETS do
		local cell = Sections.cell(target[1], target[2])
		if cell then
			dressPath(ctx, cell)
		end
	end
end

return SectionDressing

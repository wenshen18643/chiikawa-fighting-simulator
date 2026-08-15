--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Budget = require(Shared.Modules.Budget)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Layout = require(Shared.Modules.Config.Layout)
local Mobs = require(Shared.Modules.Config.Mobs)
local SausageForest = require(Shared.Modules.Config.SausageForest)
local Sections = require(Shared.Modules.Config.Sections)
local DataService = require(script.Parent.DataService)
local ForagingService = require(script.Parent.ForagingService)
local MobService = require(script.Parent.MobService)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)
local SausageForestService = {}

type Plan = {
	tier: number,
	guardians: { CFrame },
	boss: { CFrame },
}

local plans: { [number]: Plan } = {}
local tierOfMob: { [string]: number } = {}
local reserved: { Layout.Zone } = {}
local overlapParams = OverlapParams.new()

local function blocked(x: number, z: number, yaw: number?, length: number?): (boolean, number)
	local ground = ForagingService.groundAt(x, z)
	local hits
	if yaw and length then
		hits = Workspace:GetPartBoundsInBox(
			CFrame.new(x, ground + 1.2, z) * CFrame.Angles(0, yaw, 0),
			Vector3.new(length + 1, 2.4, 3),
			overlapParams
		)
	else
		hits = Workspace:GetPartBoundsInRadius(Vector3.new(x, ground + 2, z), 3, overlapParams)
	end
	return #hits > 0, ground
end

local function seedOf(text: string): number
	local sum = 0
	for index = 1, #text do
		sum += string.byte(text, index) * index
	end
	return sum
end

local function standing(x: number, z: number): CFrame
	return CFrame.new(x, ForagingService.groundAt(x, z), z)
end

local PROBE = { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }

local function edgeFactor(x: number, z: number): number
	local fade = SausageForest.EDGE_FADE
	local thin = SausageForest.EDGE_DENSITY
	local factor = 1
	for _, dir in PROBE do
		if not Sections.isWild(x + dir.X * fade * 0.5, z + dir.Y * fade * 0.5) then
			return thin
		end
		if not Sections.isWild(x + dir.X * fade, z + dir.Y * fade) then
			factor = (thin + 1) / 2
		end
	end
	return factor
end

type Plot = {
	cell: Sections.Cell,
	arena: Vector2,
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	rng: Random,
	taken: { Vector2 },
}

local function claim(plot: Plot, x: number, z: number): boolean
	local bounds = plot.bounds
	if x < bounds.minX or x > bounds.maxX or z < bounds.minZ or z > bounds.maxZ then
		return false
	end

	local reach = (plot.arena - Vector2.new(x, z)).Magnitude
	if reach < SausageForest.CLEARING_RADIUS or Layout.isReserved(reserved, x, z) then
		return false
	end

	local closing = math.min((reach - SausageForest.CLEARING_RADIUS) / SausageForest.CLEARING_FADE, 1)
	if plot.rng:NextNumber() > closing * edgeFactor(x, z) then
		return false
	end

	local at = Vector2.new(x, z)
	for _, trunk in plot.taken do
		if (trunk - at).Magnitude < SausageForest.MIN_GAP then
			return false
		end
	end

	if blocked(x, z) then
		return false
	end

	table.insert(plot.taken, at)
	return true
end

local function plantTree(plot: Plot, folder: Folder, x: number, z: number, size: any)
	local species = SausageForest.pick(SausageForest.SPECIES, plot.rng)
	local def = Ingredients.get(species.id)
	if not def then
		return
	end
	ForagingService.plant(def, Vector3.new(x, ForagingService.groundAt(x, z), z), {
		parent = folder,
		height = size.height,
		clicks = def.minClicks + size.extraClicks,
		yield = size.yield,
		yaw = plot.rng:NextNumber(0, math.pi * 2),
		collide = true,
		sink = 0.03,
	})
end

local function plantGroves(plot: Plot, folder: Folder, step: () -> ()): { Vector2 }
	local rng = plot.rng
	local bounds = plot.bounds
	local trunks: { Vector2 } = {}
	local centres: { Vector2 } = {}

	local function room(x: number, z: number): boolean
		local clear = SausageForest.CLEARING_RADIUS + SausageForest.GROVE_SPREAD[1]
		if (plot.arena - Vector2.new(x, z)).Magnitude < clear then
			return false
		end
		for _, centre in centres do
			if (centre - Vector2.new(x, z)).Magnitude < SausageForest.GROVE_GAP then
				return false
			end
		end
		return true
	end

	for _ = 1, SausageForest.GROVES_PER_CELL do
		for _ = 1, 24 do
			local x = rng:NextNumber(bounds.minX, bounds.maxX)
			local z = rng:NextNumber(bounds.minZ, bounds.maxZ)
			if room(x, z) then
				table.insert(centres, Vector2.new(x, z))
				break
			end
		end
	end

	local spread = SausageForest.GROVE_SPREAD
	local perGrove = SausageForest.GROVE_TREES

	for _, centre in centres do
		step()
		if #trunks >= SausageForest.TREES_PER_CELL then
			break
		end
		local count = rng:NextInteger(perGrove[1], perGrove[2])
		for index = 1, count do
			local angle = rng:NextNumber(0, math.pi * 2)
			local reach = if index == 1 then 0 else rng:NextNumber(spread[1], spread[2])
			local x = centre.X + math.cos(angle) * reach
			local z = centre.Y + math.sin(angle) * reach
			if claim(plot, x, z) then
				local size = if index == 1 then SausageForest.SIZES[3] else SausageForest.pick(SausageForest.SIZES, rng)
				plantTree(plot, folder, x, z, size)
				table.insert(trunks, Vector2.new(x, z))
			end
		end
	end

	for _ = 1, SausageForest.TREES_PER_CELL * 2 do
		step()
		if #trunks >= SausageForest.TREES_PER_CELL then
			break
		end
		local x = rng:NextNumber(bounds.minX, bounds.maxX)
		local z = rng:NextNumber(bounds.minZ, bounds.maxZ)
		if claim(plot, x, z) then
			plantTree(plot, folder, x, z, SausageForest.pick(SausageForest.SIZES, rng))
			table.insert(trunks, Vector2.new(x, z))
		end
	end

	return trunks
end

local function scatterFallen(plot: Plot, folder: Folder, trunks: { Vector2 }, step: () -> ())
	local fallen = SausageForest.FALLEN
	local drift = SausageForest.FALLEN_DRIFT
	local rng = plot.rng
	if #trunks == 0 then
		return
	end

	for _ = 1, SausageForest.FALLEN_PER_CELL do
		step()
		local trunk = trunks[rng:NextInteger(1, #trunks)]
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = rng:NextNumber(drift[1], drift[2])
		local x = trunk.X + math.cos(angle) * reach
		local z = trunk.Y + math.sin(angle) * reach
		local species = SausageForest.pick(SausageForest.SPECIES, rng)
		local def = Ingredients.get(species.id)
		if
			not def
			or (plot.arena - Vector2.new(x, z)).Magnitude <= SausageForest.CLEARING_RADIUS
			or Layout.isReserved(reserved, x, z)
		then
			continue
		end

		local length = rng:NextNumber(fallen.length[1], fallen.length[2])
		local yaw = rng:NextNumber(0, math.pi * 2)
		local hit, ground = blocked(x, z, yaw, length)
		if not hit then
			ForagingService.plant(def, Vector3.new(x, ground, z), {
				parent = folder,
				upright = false,
				height = length,
				clicks = math.max(fallen.minClicks, def.minClicks - fallen.clicksOff),
				yield = fallen.yield,
				yaw = yaw,
				roll = rng:NextNumber(-0.25, 0.25),
				sink = fallen.sink,
				collide = true,
			})
		end
	end
end

local function deploy(plan: Plan)
	local bossId = SausageForest.bossId(plan.tier)
	MobService.setLocked(bossId, true)
	MobService.deploy(SausageForest.guardianId(plan.tier), plan.guardians, plan.boss[1].Position)
	MobService.deploy(bossId, plan.boss)
end

local function buildCell(entry: { coord: string, tier: number }, parent: Instance)
	local cell = Sections.byCoord(entry.coord)
	if not cell or cell.theme ~= "sausage" then
		warn(`[SausageForestService] section {entry.coord} is not a sausage section`)
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = `Sausage_{entry.coord}`
	folder.Parent = parent

	local arena = SausageForest.arena(cell)
	local plot: Plot = {
		cell = cell,
		arena = arena,
		bounds = SausageForest.bounds(cell),
		rng = Random.new(seedOf(entry.coord)),
		taken = {},
	}
	local step = Budget.stepper()
	scatterFallen(plot, folder, plantGroves(plot, folder, step), step)

	local guardianId = SausageForest.guardianId(entry.tier)
	local definition = Mobs.get(guardianId)
	local count = if definition then definition.population else 0
	local guardians = {}
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		table.insert(
			guardians,
			standing(
				arena.X + math.cos(angle) * SausageForest.GUARDIAN_RING,
				arena.Y + math.sin(angle) * SausageForest.GUARDIAN_RING
			)
		)
	end

	local plan: Plan = {
		tier = entry.tier,
		guardians = guardians,
		boss = { standing(arena.X, arena.Y) },
	}
	plans[entry.tier] = plan
	tierOfMob[guardianId] = entry.tier
	tierOfMob[SausageForest.bossId(entry.tier)] = entry.tier
	deploy(plan)
end

local function rewardBoss(player: Player, tier: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local reward = SausageForest.BOSS_REWARD
	local count = reward.count * tier
	profile.currencies.ingredients[reward.id] = (profile.currencies.ingredients[reward.id] or 0) + count

	local def = Ingredients.get(reward.id)
	NotifyService.send(player, `The Great Sausage falls! {def and def.name or reward.id} x{count}`, "reward")
end

local function onKilled(definition: Mobs.MobDefinition, _slot: number, killer: Player?)
	local tier = tierOfMob[definition.id]
	local plan = tier and plans[tier]
	if not plan then
		return
	end

	if definition.id == SausageForest.guardianId(tier) then
		if MobService.countAlive(definition.id) > 0 then
			return
		end
		MobService.setLocked(SausageForest.bossId(tier), false)
		if killer then
			NotifyService.send(killer, "The guardians are down. The Great Sausage is exposed.", "reward")
		end
		return
	end

	if killer then
		rewardBoss(killer, tier)
	end
	task.delay(SausageForest.RESPAWN_SECONDS, function()
		deploy(plan)
	end)
end

local function watchClearings()
	while true do
		task.wait(SausageForest.ALERT_INTERVAL)
		for tier, plan in plans do
			local centre = plan.boss[1].Position
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
					continue
				end
				local offset = root.Position - centre
				if Vector2.new(offset.X, offset.Z).Magnitude <= SausageForest.ALERT_RADIUS then
					MobService.alert(SausageForest.guardianId(tier), player)
					break
				end
			end
		end
	end
end

function SausageForestService.init()
	local area = Areas.get(1)
	local regionFolder = area and WorldService.getRegionFolder(area.id)
	if not area or not regionFolder then
		warn("[SausageForestService] no Town region folder - did WorldService run first?")
		return
	end

	reserved = Layout.reservedZones(area)

	local existingRoot = regionFolder:FindFirstChild("SausageForest")
	if existingRoot then
		existingRoot:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "SausageForest"
	root:SetAttribute("RuntimeGenerated", true)
	root.Parent = regionFolder

	MobService.onKilled(onKilled)

	task.spawn(function()
		ForagingService.awaitReady()
		WorldService.awaitDressed()

		overlapParams.FilterType = Enum.RaycastFilterType.Include
		local considered: { Instance } = { root }
		for _, name in { "Scenery", "Forage" } do
			local folder = regionFolder:FindFirstChild(name)
			if folder then
				table.insert(considered, folder)
			end
		end
		overlapParams.FilterDescendantsInstances = considered

		for _, entry in SausageForest.CELLS do
			buildCell(entry, root)
		end
		watchClearings()
	end)
end

return SausageForestService

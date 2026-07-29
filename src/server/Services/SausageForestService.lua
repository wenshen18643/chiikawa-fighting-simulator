--!strict

--[[
	The sausage forest.

	Four board sections rather than a zone circle, because the thing being built
	is a place with a middle: every section has one BIG tree, a ring of guardians
	around it, and ordinary trees everywhere else. The BIG tree cannot be cut
	while a guardian still stands, so the ring is the lock and the guardians are
	the key.

	Depth is the only difficulty dial. Config/SausageForest lists the sections
	shallowest first and Config/Mobs scales the guardians off that tier, so the
	forest gets harder the further in you walk without any per-cell tuning here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Budget = require(Shared.Modules.Budget)
local ModelUtil = require(Shared.Modules.ModelUtil)
local Ingredients = require(Shared.Modules.Config.Ingredients)
local Mobs = require(Shared.Modules.Config.Mobs)
local SausageForest = require(Shared.Modules.Config.SausageForest)
local Sections = require(Shared.Modules.Config.Sections)

local AssetService = require(script.Parent.AssetService)
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

-- A spot inside the cell but outside the fighting clearing.
local function scatterPoint(cell: Sections.Cell, rng: Random): (number?, number?)
	local inset = SausageForest.TREE_INSET
	for _ = 1, 12 do
		local x = rng:NextNumber(cell.minX + inset, cell.maxX - inset)
		local z = rng:NextNumber(cell.minZ + inset, cell.maxZ - inset)
		if Vector2.new(x - cell.cx, z - cell.cz).Magnitude > SausageForest.CLEARING_RADIUS then
			return x, z
		end
	end
	return nil, nil
end

local function plantTrees(cell: Sections.Cell, folder: Folder, rng: Random, step: () -> ())
	for _ = 1, SausageForest.TREES_PER_CELL do
		step()
		local x, z = scatterPoint(cell, rng)
		local species = SausageForest.pick(SausageForest.SPECIES, rng)
		local size = SausageForest.pick(SausageForest.SIZES, rng)
		local def = Ingredients.get(species.id)
		if x and z and def then
			ForagingService.plant(def, Vector3.new(x, ForagingService.groundAt(x, z), z), {
				parent = folder,
				height = size.height,
				clicks = def.minClicks + size.extraClicks,
				yield = size.yield,
				yaw = rng:NextNumber(0, math.pi * 2),
			})
		end
	end
end

--[[
	Fallen sausages, left lying where the asset already lies: no standUpright,
	just a yaw, a roll and enough sink to look settled rather than dropped.
	Untagged, so the Work click never offers to pull one.
]]
local function scatterLitter(cell: Sections.Cell, folder: Folder, rng: Random, step: () -> ())
	local litter = SausageForest.LITTER

	for _ = 1, SausageForest.LITTER_PER_CELL do
		step()
		local x, z = scatterPoint(cell, rng)
		if not x or not z then
			continue
		end

		local asset = SausageForest.pick(SausageForest.SPECIES, rng).id
		local def = Ingredients.get(asset)
		local model = if def then AssetService.clone(def.asset) else nil
		if not model then
			continue
		end

		model.Name = "FallenSausage"

		local _, authored = ModelUtil.worldBox(model)
		local length = rng:NextNumber(litter.length[1], litter.length[2])
		if authored.X > 0.01 then
			model:ScaleTo(model:GetScale() * (length / authored.X))
		end

		local pivot = model:GetPivot()
		model:PivotTo(
			CFrame.new(pivot.Position)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.25, 0.25))
				* pivot.Rotation
		)

		local centre, size = ModelUtil.worldBox(model)
		local ground = ForagingService.groundAt(x, z)
		local target = Vector3.new(x, ground + size.Y * (0.5 - litter.sink), z)
		model:PivotTo(model:GetPivot() + (target - centre))

		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
			end
		end
		model.Parent = folder
	end
end

local function deploy(plan: Plan)
	local bossId = SausageForest.bossId(plan.tier)
	MobService.setLocked(bossId, true)
	-- Guardians patrol the BIG tree, so the tree is their home, not their post.
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

	-- 134 models a cell: sliced so a section of forest costs frames, not a stall.
	local rng = Random.new(seedOf(entry.coord))
	local step = Budget.stepper()
	plantTrees(cell, folder, rng, step)
	scatterLitter(cell, folder, rng, step)

	local guardianId = SausageForest.guardianId(entry.tier)
	local definition = Mobs.get(guardianId)
	local count = if definition then definition.population else 0

	local guardians = {}
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		table.insert(
			guardians,
			standing(
				cell.cx + math.cos(angle) * SausageForest.GUARDIAN_RING,
				cell.cz + math.sin(angle) * SausageForest.GUARDIAN_RING
			)
		)
	end

	local plan: Plan = {
		tier = entry.tier,
		guardians = guardians,
		boss = { standing(cell.cx, cell.cz) },
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
	-- The whole section comes back together: a lone respawned guardian guarding
	-- nothing, or a bare BIG tree, would both read as broken.
	task.delay(SausageForest.RESPAWN_SECONDS, function()
		deploy(plan)
	end)
end

--[[
	One sweep for every clearing. Polled rather than a touch part: the trigger
	is a circle around the BIG tree, and a player who logs in standing inside it
	must be noticed just the same as one who walked in.
]]
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

	local root = Instance.new("Folder")
	root.Name = "SausageForest"
	root.Parent = regionFolder

	for _, entry in SausageForest.CELLS do
		buildCell(entry, root)
	end

	MobService.onKilled(onKilled)
	task.spawn(watchClearings)
end

return SausageForestService

--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Airdrop = require(Shared.Modules.Config.Airdrop)
local ModelUtil = require(Shared.Modules.ModelUtil)

local AirdropService = {}

local rng = Random.new()

local CYLINDER = CFrame.Angles(0, math.rad(90), 0)
local DISC = CFrame.Angles(0, 0, math.rad(90))

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local created = Instance.new("Part")
	created.Name = name
	if shape then
		created.Shape = shape
	end
	created.Size = size
	created.CFrame = cframe
	created.Color = color
	created.Material = material or Enum.Material.SmoothPlastic
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	created.Parent = parent
	return created
end

local function emitter(parent: BasePart, texture: string, color: Color3): ParticleEmitter
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = texture
	puff.Color = ColorSequence.new(color)
	puff.Rate = 0
	puff.Rotation = NumberRange.new(0, 360)
	puff.Parent = parent
	return puff
end

--------------------------------------------------------------------------------
-- Plane
--------------------------------------------------------------------------------

local function buildEngine(plane: Model, side: number)
	local engine = part(
		plane,
		"Engine",
		Vector3.new(10, 5, 5),
		CFrame.new(side * 14, 0.6, 2) * CYLINDER,
		Airdrop.PLANE_METAL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	part(
		plane,
		"Prop",
		Vector3.new(0.5, 9, 9),
		CFrame.new(side * 14, 0.6, 7.4) * CYLINDER,
		Airdrop.PROP_COLOR,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)

	local exhaust = emitter(engine, "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(252, 250, 246))
	exhaust.EmissionDirection = Enum.NormalId.Right
	exhaust.Rate = 9
	exhaust.Lifetime = NumberRange.new(0.7, 1.2)
	exhaust.Speed = NumberRange.new(16, 24)
	exhaust.SpreadAngle = Vector2.new(8, 8)
	exhaust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 6),
	})
	exhaust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	exhaust.LightEmission = 0.3
end

local function buildPlane(): Model
	local plane = Instance.new("Model")
	plane.Name = "SupplyPlane"

	local fuselage = part(
		plane,
		"Fuselage",
		Vector3.new(36, 10, 10),
		CYLINDER,
		Airdrop.PLANE_COLOR,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	plane.PrimaryPart = fuselage

	part(plane, "Nose", Vector3.new(10, 10, 10), CFrame.new(0, 0, 18), Airdrop.PLANE_COLOR, nil, Enum.PartType.Ball)
	part(plane, "Tail", Vector3.new(8, 8, 8), CFrame.new(0, 0.8, -18), Airdrop.PLANE_COLOR, nil, Enum.PartType.Ball)
	part(plane, "Wing", Vector3.new(58, 1.6, 13), CFrame.new(0, 2.2, -1), Airdrop.PLANE_COLOR)
	part(plane, "Fin", Vector3.new(1.4, 10, 8), CFrame.new(0, 6.4, -15), Airdrop.PLANE_TRIM)
	part(plane, "Tailplane", Vector3.new(22, 1.2, 5.4), CFrame.new(0, 3.6, -16), Airdrop.PLANE_COLOR)
	part(plane, "Hatch", Vector3.new(9, 1.4, 13), CFrame.new(0, -4.3, -2), Airdrop.PLANE_TRIM)

	for _, side in { -1, 1 } do
		part(plane, "Stripe", Vector3.new(1.2, 2.2, 24), CFrame.new(side * 4.5, 1.2, -1), Airdrop.PLANE_TRIM)
		buildEngine(plane, side)
	end

	return plane
end

--------------------------------------------------------------------------------
-- Parachute
--------------------------------------------------------------------------------

local function buildChute(diameter: number, cordDrop: number, color: Color3): Model
	local chute = Instance.new("Model")
	chute.Name = "Parachute"

	local canopy = part(
		chute,
		"Canopy",
		Vector3.new(diameter, diameter * 0.62, diameter),
		CFrame.identity,
		color,
		Enum.Material.Fabric,
		Enum.PartType.Ball
	)
	chute.PrimaryPart = canopy

	part(
		chute,
		"Vent",
		Vector3.new(diameter * 0.22, diameter * 0.22, diameter * 0.22),
		CFrame.new(0, diameter * 0.29, 0),
		Airdrop.VENT_COLOR,
		Enum.Material.Fabric,
		Enum.PartType.Ball
	)

	local gores = 6
	local anchorPoint = Vector3.new(0, -cordDrop, 0)

	for index = 1, gores do
		local angle = (index / gores) * math.pi * 2
		local rim = Vector3.new(math.cos(angle) * diameter * 0.42, -diameter * 0.15, math.sin(angle) * diameter * 0.42)

		part(
			chute,
			"Gore",
			Vector3.new(diameter * 0.34, diameter * 0.3, diameter * 0.34),
			CFrame.new(rim),
			if index % 2 == 0 then Airdrop.VENT_COLOR else color,
			Enum.Material.Fabric,
			Enum.PartType.Ball
		)

		local span = anchorPoint - rim
		part(
			chute,
			"Cord",
			Vector3.new(0.3, 0.3, span.Magnitude),
			CFrame.lookAt(rim + span / 2, anchorPoint),
			Airdrop.CORD_COLOR,
			Enum.Material.Fabric
		)
	end

	return chute
end

--------------------------------------------------------------------------------
-- Effects
--------------------------------------------------------------------------------

local function poof(parent: Instance, at: Vector3, color: Color3, radius: number)
	local core = part(parent, "Poof", Vector3.new(1, 1, 1), CFrame.new(at), color)
	core.Transparency = 1

	local sparkle = emitter(core, "rbxasset://textures/particles/sparkles_main.dds", color)
	sparkle.Lifetime = NumberRange.new(0.5, 1.1)
	sparkle.Speed = NumberRange.new(24, 52)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Acceleration = Vector3.new(0, -34, 0)
	sparkle.LightEmission = 0.9
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})

	local smoke = emitter(core, "rbxasset://textures/particles/smoke_main.dds", Airdrop.VENT_COLOR)
	smoke.Lifetime = NumberRange.new(0.6, 1.1)
	smoke.Speed = NumberRange.new(10, 22)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.2),
		NumberSequenceKeypoint.new(1, radius * 0.7),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})

	sparkle:Emit(30)
	smoke:Emit(12)

	local ring = part(
		parent,
		"PopRing",
		Vector3.new(0.5, radius, radius),
		CFrame.new(at) * DISC,
		color,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0.25

	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.5, radius * 3.2, radius * 3.2),
		Transparency = 1,
	}):Play()

	Debris:AddItem(ring, 0.6)
	Debris:AddItem(core, 2.5)
end

local function dissolve(chute: Model)
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, descendant in chute:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, info, {
				Transparency = 1,
				Size = descendant.Size * 1.35,
			}):Play()
		end
	end
	Debris:AddItem(chute, 0.3)
end

--------------------------------------------------------------------------------
-- Delivery
--------------------------------------------------------------------------------

local function descend(
	payload: Model,
	target: Vector3,
	dropY: number,
	basePivot: CFrame,
	centreOffset: Vector3
): boolean
	local _, size = ModelUtil.worldBox(payload)
	local diameter = math.max(Airdrop.CANOPY_MIN, math.max(size.X, size.Z) * Airdrop.CANOPY_SPAN)
	local cordDrop = diameter * Airdrop.CORD_DROP
	local color = Airdrop.CANOPY_COLORS[rng:NextInteger(1, #Airdrop.CANOPY_COLORS)]

	local distance = dropY - target.Y
	local fallen = 0
	local velocity = 0
	local elapsed = 0
	local opened = 0
	local chute: Model? = nil

	while fallen < distance do
		local delta = task.wait(Airdrop.STEP)
		if not payload.Parent then
			if chute then
				chute:Destroy()
			end
			return false
		end

		elapsed += delta

		if elapsed < Airdrop.FREEFALL then
			velocity += Airdrop.GRAVITY * delta
		else
			if not chute then
				local rig = buildChute(diameter, cordDrop, color)
				rig.Parent = payload.Parent
				chute = rig
			end
			opened = math.min(opened + delta / Airdrop.POP_TIME, 1)
			velocity += (Airdrop.CHUTE_SPEED - velocity) * math.min(delta * Airdrop.CHUTE_BRAKE, 1)
		end

		fallen = math.min(fallen + velocity * delta, distance)

		local damp = math.clamp((distance - fallen) / Airdrop.SWAY_FADE, 0, 1)
		local swayX = math.sin(elapsed * Airdrop.SWAY_SPEED) * Airdrop.SWAY * damp
		local swayZ = math.cos(elapsed * Airdrop.SWAY_SPEED * 0.7) * Airdrop.SWAY * 0.6 * damp
		local drift = Vector3.new(swayX, -fallen, swayZ)

		payload:PivotTo(basePivot + drift)

		if chute then
			local scale = 0.25 + 0.75 * opened
			local top = basePivot.Position + centreOffset + drift + Vector3.new(0, size.Y * 0.5 + cordDrop * scale, 0)
			chute:ScaleTo(scale)
			chute:PivotTo(CFrame.new(top) * CFrame.Angles(math.rad(-swayZ * 0.7), 0, math.rad(swayX * 0.7)))
		end
	end

	local folder = payload.Parent
	if not folder then
		if chute then
			chute:Destroy()
		end
		return false
	end

	ModelUtil.seat(payload, target, 0)

	if chute then
		local canopy = chute.PrimaryPart
		if canopy then
			poof(folder, canopy.Position, color, diameter * 0.45)
		end
		dissolve(chute)
	end

	poof(folder, target + Vector3.new(0, 1.5, 0), Airdrop.VENT_COLOR, math.max(size.Y * 0.5, 6))
	return true
end

function AirdropService.deliver(payload: Model, target: Vector3, yaw: number, onLanded: (() -> ())?)
	local folder = payload.Parent
	if not folder then
		return
	end

	local cruiseY = target.Y + Airdrop.CRUISE_HEIGHT
	local dropY = cruiseY - Airdrop.BELLY
	local overhead = Vector3.new(target.X, cruiseY, target.Z)

	local angle = rng:NextNumber(0, math.pi * 2)
	local heading = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local start = overhead - heading * Airdrop.APPROACH
	local finish = overhead + heading * Airdrop.DEPART

	ModelUtil.seat(payload, Vector3.new(target.X, dropY, target.Z), yaw)
	local basePivot = payload:GetPivot()
	local centre = ModelUtil.worldBox(payload)
	local centreOffset = centre - basePivot.Position

	local plane = buildPlane()
	plane:PivotTo(CFrame.lookAt(start, start + heading))
	plane.Parent = folder

	task.spawn(function()
		local total = (finish - start).Magnitude
		local flown = 0
		local released = false

		while flown < total do
			local delta = task.wait(Airdrop.STEP)
			if not payload.Parent then
				plane:Destroy()
				return
			end

			flown += Airdrop.PLANE_SPEED * delta
			local at = start + heading * math.min(flown, total)
			plane:PivotTo(CFrame.lookAt(at, at + heading))

			if released then
				continue
			end

			if flown >= Airdrop.APPROACH then
				released = true
				task.spawn(function()
					if descend(payload, target, dropY, basePivot, centreOffset) and onLanded then
						onLanded()
					end
				end)
			else
				payload:PivotTo(basePivot + (at - overhead))
			end
		end

		plane:Destroy()
	end)
end

return AirdropService

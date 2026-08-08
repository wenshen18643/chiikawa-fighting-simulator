--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinLook = require(Shared.Modules.SkinLook)
local WeaponFrames = require(Shared.Modules.WeaponFrames)
local WeaponLook = {}

export type PartSpec = {
	shape: Enum.PartType?,
	size: Vector3,
	offset: Vector3,
	angles: Vector3?,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	spin: number?,
	orbit: { radius: number, height: number?, count: number }?,
}

export type AuraSpec = SkinLook.AuraSpec
export type ParticleSpec = SkinLook.ParticleSpec
export type LightSpec = SkinLook.LightSpec
export type TrailSpec = SkinLook.TrailSpec
export type HighlightSpec = SkinLook.HighlightSpec

export type Look = {
	frame: string,
	palette: { [string]: Color3 }?,
	material: { [string]: Enum.Material }?,
	reflectance: { [string]: number }?,
	parts: { PartSpec }?,
	aura: AuraSpec?,
	scale: number?,
}

WeaponLook.SPIN_ATTRIBUTE = SkinLook.SPIN_ATTRIBUTE
WeaponLook.DECORATION_TAG = SkinLook.DECORATION_TAG

local MAX_PARTICLE_RATE = 8
local MAX_LIGHT_BRIGHTNESS = 2.4
local MAX_LIGHT_RANGE = 16
local ZONE_ORDER = { "all", "haft", "grip", "head", "edge", "cap" }

WeaponLook.DEFAULT = {
	frame = "sasumata",
	palette = {
		haft = Color3.fromRGB(146, 116, 84),
		head = Color3.fromRGB(134, 106, 78),
		edge = Color3.fromRGB(104, 82, 60),
		grip = Color3.fromRGB(170, 150, 120),
		cap = Color3.fromRGB(104, 82, 60),
	},
	material = { all = Enum.Material.Wood, grip = Enum.Material.Fabric },
} :: Look

local function paint<T>(zones: WeaponFrames.Zones, source: { [string]: T }?, write: (BasePart, T) -> ())
	if not source then
		return
	end
	local applied: { [string]: boolean } = {}

	local function run(zone: string)
		applied[zone] = true
		local value = source[zone]
		local parts = if value ~= nil then zones[zone] else nil
		if not parts then
			return
		end
		for _, part in parts do
			write(part, value :: T)
		end
	end

	for _, zone in ZONE_ORDER do
		run(zone)
	end
	for zone in source do
		if not applied[zone] then
			run(zone)
		end
	end
end

local function buildPiece(model: Model, spec: PartSpec, scale: number, index: number, copy: number): BasePart
	local part = Instance.new("Part")
	part.Name = `Charm_{index}_{copy}`
	part.Shape = spec.shape or Enum.PartType.Block
	part.Size = spec.size * scale
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:AddTag(WeaponLook.DECORATION_TAG)
	part.Parent = model
	return part
end

local function orientation(spec: PartSpec): CFrame
	local turn = spec.angles or Vector3.zero
	return CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
end

local function placeStatic(haft: BasePart, part: BasePart, spec: PartSpec, scale: number)
	part.CFrame = haft.CFrame * CFrame.new(spec.offset * scale) * orientation(spec)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = haft
	weld.Part1 = part
	weld.Parent = part
end

local function placeSpinning(haft: BasePart, part: BasePart, spec: PartSpec, scale: number, radius: Vector3)
	local pivot = haft.CFrame * CFrame.new(spec.offset * scale)
	part.CFrame = pivot * CFrame.new(radius) * orientation(spec)

	local motor = Instance.new("Motor6D")
	motor.Name = `SkinSpin_{part.Name}`
	motor.Part0 = haft
	motor.Part1 = part
	motor.C0 = haft.CFrame:Inverse() * pivot
	motor.C1 = part.CFrame:Inverse() * pivot
	motor.Parent = haft

	part:SetAttribute(WeaponLook.SPIN_ATTRIBUTE, spec.spin)
end

local function addParticle(host: BasePart, spec: ParticleSpec)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WeaponAura"
	emitter.Color = ColorSequence.new(spec.color)
	emitter.LightEmission = 0.45
	emitter.Lifetime = NumberRange.new(spec.lifetime * 0.7, spec.lifetime)
	emitter.Rate = math.min(spec.rate, MAX_PARTICLE_RATE)
	emitter.Rotation = NumberRange.new(0, 180)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, spec.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Speed = NumberRange.new(spec.speed * 0.6, spec.speed)
	emitter.SpreadAngle = Vector2.one * (spec.spread or 25)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = host
end

local function addLight(host: BasePart, spec: LightSpec)
	local light = Instance.new("PointLight")
	light.Name = "WeaponGlow"
	light.Color = spec.color
	light.Brightness = math.min(spec.brightness, MAX_LIGHT_BRIGHTNESS)
	light.Range = math.min(spec.range, MAX_LIGHT_RANGE)
	light.Shadows = false
	light.Parent = host
end

local function addTrail(haft: BasePart, spec: TrailSpec)
	local width = spec.width or 0.45
	local top = Instance.new("Attachment")
	top.Name = "WeaponTrailTop"
	top.Position = Vector3.new(0, haft.Size.Y * width, 0)
	top.Parent = haft

	local bottom = Instance.new("Attachment")
	bottom.Name = "WeaponTrailBottom"
	bottom.Position = Vector3.new(0, -haft.Size.Y * width, 0)
	bottom.Parent = haft

	local trail = Instance.new("Trail")
	trail.Name = "WeaponTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(spec.color)
	trail.Lifetime = spec.lifetime
	trail.LightEmission = 0.5
	trail.MinLength = 0.2
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = haft
end

local function addHighlight(model: Model, spec: HighlightSpec)
	local highlight = Instance.new("Highlight")
	highlight.Name = "WeaponRim"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = spec.fill
	highlight.FillTransparency = spec.fillTransparency or 0.82
	highlight.OutlineColor = spec.outline
	highlight.OutlineTransparency = 0.25
	highlight.Parent = model
end

function WeaponLook.build(look: Look?, scale: number): (Model, CFrame)
	local resolved = look or WeaponLook.DEFAULT
	local size = scale * (resolved.scale or 1)
	local model, zones, grip = WeaponFrames.get(resolved.frame)(size)
	local haft = model.PrimaryPart :: BasePart

	paint(zones, resolved.palette, function(part, colour)
		part.Color = colour
	end)
	paint(zones, resolved.material, function(part, material)
		part.Material = material
	end)
	paint(zones, resolved.reflectance, function(part, amount)
		part.Reflectance = amount
	end)

	if resolved.parts then
		for index, spec in resolved.parts do
			local orbit = spec.orbit
			if orbit then
				local count = math.max(1, orbit.count)
				for copy = 1, count do
					local angle = (copy - 1) / count * math.pi * 2
					local radius = Vector3.new(
						math.cos(angle) * orbit.radius,
						orbit.height or 0,
						math.sin(angle) * orbit.radius
					) * size
					local part = buildPiece(model, spec, size, index, copy)
					placeSpinning(haft, part, spec, size, radius)
				end
			else
				local part = buildPiece(model, spec, size, index, 1)
				if spec.spin then
					placeSpinning(haft, part, spec, size, Vector3.zero)
				else
					placeStatic(haft, part, spec, size)
				end
			end
		end
	end

	local aura = resolved.aura
	if aura then
		local crown = (if zones.head then zones.head[1] else nil) or haft
		if aura.particle then
			addParticle(crown, aura.particle)
		end
		if aura.light then
			addLight(crown, aura.light)
		end
		if aura.trail then
			addTrail(haft, aura.trail)
		end
		if aura.highlight then
			addHighlight(model, aura.highlight)
		end
	end

	return model, CFrame.new(grip.Position * size) * grip.Rotation
end

return WeaponLook

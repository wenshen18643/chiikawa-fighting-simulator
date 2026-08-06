--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local SkinLook = {}

export type PartSpec = {
	anchor: string,
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

export type ParticleSpec = {
	color: Color3,
	rate: number,
	size: number,
	speed: number,
	lifetime: number,
	spread: number?,
}

export type LightSpec = {
	color: Color3,
	brightness: number,
	range: number,
}

export type TrailSpec = {
	color: Color3,
	lifetime: number,
	width: number?,
}

export type HighlightSpec = {
	fill: Color3,
	outline: Color3,
	fillTransparency: number?,
}

export type AuraSpec = {
	particle: ParticleSpec?,
	light: LightSpec?,
	trail: TrailSpec?,
	highlight: HighlightSpec?,
}

export type Look = {
	palette: { [string]: Color3 }?,
	material: { [string]: Enum.Material }?,
	reflectance: { [string]: number }?,
	parts: { PartSpec }?,
	aura: AuraSpec?,
	scale: number?,
}

SkinLook.SPIN_ATTRIBUTE = "SkinSpin"
SkinLook.DECORATION_TAG = "SkinDecoration"

local MAX_PARTICLE_RATE = 12
local MAX_LIGHT_BRIGHTNESS = 3
local MAX_LIGHT_RANGE = 22

local JOINT_ZONES: { [string]: { string } } = {
	head = { "head" },
	body = { "root" },
	earL = { "earL" },
	earR = { "earR" },
	armL = { "armL" },
	armR = { "armR" },
	legL = { "legL" },
	legR = { "legR" },
	ears = { "earL", "earR" },
	arms = { "armL", "armR" },
	legs = { "legL", "legR" },
	limbs = { "armL", "armR", "legL", "legR" },
}

local COLOUR_ZONES: { [string]: { [string]: Color3 } } = {
	usagi = {
		dark = Color3.fromRGB(17, 17, 17),
		trim = Color3.fromRGB(248, 248, 248),
		blush = Color3.fromRGB(255, 201, 201),
		coat = Color3.fromRGB(255, 249, 201),
	},
}

local ANCHOR_FALLBACK = { "head", "body", "armR", "legR" }

local ZONE_ORDER = {
	"all",
	"coat",
	"trim",
	"dark",
	"blush",
	"limbs",
	"body",
	"head",
	"ears",
	"arms",
	"legs",
	"earL",
	"earR",
	"armL",
	"armR",
	"legL",
	"legR",
}

local function sameColour(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end

local function push(into: { BasePart }, part: BasePart?)
	if part and not table.find(into, part) then
		table.insert(into, part)
	end
end

function SkinLook.zones(model: Model, characterId: string): { [string]: { BasePart } }
	local resolved: { [string]: { BasePart } } = {}
	local joints = Skeleton.resolve(model)
	local everything: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= model.PrimaryPart then
			table.insert(everything, descendant)
		end
	end
	resolved.all = everything

	if joints then
		for zone, canonicals in JOINT_ZONES do
			local parts: { BasePart } = {}
			for _, canonical in canonicals do
				local joint = joints[canonical]
				if joint and joint:IsA("Motor6D") then
					push(parts, joint.Part1)
				end
			end
			if #parts > 0 then
				resolved[zone] = parts
			end
		end
	end

	if not resolved.body then
		local named = model:FindFirstChild("Torso", true) or model:FindFirstChild("Body", true)
		if named and named:IsA("BasePart") then
			resolved.body = { named }
		end
	end
	if not resolved.head then
		local named = model:FindFirstChild("Head", true) or model:FindFirstChild("Handle", true)
		if named and named:IsA("BasePart") then
			resolved.head = { named }
		end
	end

	local palette = COLOUR_ZONES[characterId]
	if palette then
		for zone, source in palette do
			local parts: { BasePart } = {}
			for _, part in everything do
				if sameColour(part.Color, source) then
					table.insert(parts, part)
				end
			end
			if #parts > 0 then
				resolved[zone] = parts
			end
		end
	end

	return resolved
end

local function anchorFor(zones: { [string]: { BasePart } }, name: string): BasePart?
	local direct = zones[name]
	if direct and direct[1] then
		return direct[1]
	end
	for _, fallback in ANCHOR_FALLBACK do
		local list = zones[fallback]
		if list and list[1] then
			return list[1]
		end
	end
	local everything = zones.all
	return if everything then everything[1] else nil
end

local function buildPiece(model: Model, anchor: BasePart, spec: PartSpec, index: number, copy: number): BasePart
	local part = Instance.new("Part")
	part.Name = `Skin_{index}_{copy}`
	part.Shape = spec.shape or Enum.PartType.Block
	part.Size = anchor.Size * spec.size
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0
	part.Anchored = anchor.Anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:AddTag(SkinLook.DECORATION_TAG)
	part.Parent = model
	return part
end

local function placeStatic(anchor: BasePart, part: BasePart, spec: PartSpec, offset: Vector3)
	local turn = spec.angles or Vector3.zero
	part.CFrame = anchor.CFrame
		* CFrame.new(anchor.Size * offset)
		* CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

local function placeSpinning(anchor: BasePart, part: BasePart, spec: PartSpec, offset: Vector3, radius: Vector3)
	local turn = spec.angles or Vector3.zero
	local pivot = anchor.CFrame * CFrame.new(anchor.Size * offset)
	part.CFrame = pivot * CFrame.new(radius) * CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))

	local motor = Instance.new("Motor6D")
	motor.Name = `SkinSpin_{part.Name}`
	motor.Part0 = anchor
	motor.Part1 = part
	motor.C0 = anchor.CFrame:Inverse() * pivot
	motor.C1 = part.CFrame:Inverse() * pivot
	motor.Parent = anchor

	part:SetAttribute(SkinLook.SPIN_ATTRIBUTE, spec.spin)
end

local function addParticle(root: BasePart, spec: ParticleSpec)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SkinAura"
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
	emitter.Parent = root
end

local function addLight(root: BasePart, spec: LightSpec)
	local light = Instance.new("PointLight")
	light.Name = "SkinGlow"
	light.Color = spec.color
	light.Brightness = math.min(spec.brightness, MAX_LIGHT_BRIGHTNESS)
	light.Range = math.min(spec.range, MAX_LIGHT_RANGE)
	light.Shadows = false
	light.Parent = root
end

local function addTrail(root: BasePart, spec: TrailSpec)
	local width = spec.width or 0.45
	local top = Instance.new("Attachment")
	top.Name = "SkinTrailTop"
	top.Position = Vector3.new(0, root.Size.Y * width, 0)
	top.Parent = root

	local bottom = Instance.new("Attachment")
	bottom.Name = "SkinTrailBottom"
	bottom.Position = Vector3.new(0, -root.Size.Y * width, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "SkinTrail"
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
	trail.Parent = root
end

local function addHighlight(model: Model, spec: HighlightSpec)
	local highlight = Instance.new("Highlight")
	highlight.Name = "SkinRim"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = spec.fill
	highlight.FillTransparency = spec.fillTransparency or 0.82
	highlight.OutlineColor = spec.outline
	highlight.OutlineTransparency = 0.25
	highlight.Parent = model
end

function SkinLook.apply(model: Model, characterId: string, look: Look?): { BasePart }
	local created: { BasePart } = {}
	if not look then
		return created
	end

	local zones = SkinLook.zones(model, characterId)

	local function paint<T>(source: { [string]: T }?, write: (BasePart, T) -> ())
		if not source then
			return
		end
		local applied: { [string]: boolean } = {}

		local function run(zone: string)
			local value = source[zone]
			local parts = if value ~= nil then zones[zone] else nil
			applied[zone] = true
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

	paint(look.palette, function(part, colour)
		part.Color = colour
	end)
	paint(look.material, function(part, material)
		part.Material = material
	end)
	paint(look.reflectance, function(part, amount)
		part.Reflectance = amount
	end)

	if look.parts then
		for index, spec in look.parts do
			local anchor = anchorFor(zones, spec.anchor)
			if not anchor then
				continue
			end

			local orbit = spec.orbit
			if orbit then
				local count = math.max(1, orbit.count)
				local span = anchor.Size
				for copy = 1, count do
					local angle = (copy - 1) / count * math.pi * 2
					local radius = Vector3.new(
						math.cos(angle) * orbit.radius * span.X,
						(orbit.height or 0) * span.Y,
						math.sin(angle) * orbit.radius * span.Z
					)
					local part = buildPiece(model, anchor, spec, index, copy)
					placeSpinning(anchor, part, spec, spec.offset, radius)
					table.insert(created, part)
				end
			else
				local part = buildPiece(model, anchor, spec, index, 1)
				if spec.spin then
					placeSpinning(anchor, part, spec, spec.offset, Vector3.zero)
				else
					placeStatic(anchor, part, spec, spec.offset)
				end
				table.insert(created, part)
			end
		end
	end

	local aura = look.aura
	if aura then
		local root = model.PrimaryPart
			or (if zones.body then zones.body[1] else nil)
			or (if zones.all then zones.all[1] else nil)
		local crown = (if zones.head then zones.head[1] else nil) or root
		if root and crown then
			if aura.particle then
				addParticle(crown, aura.particle)
			end
			if aura.light then
				addLight(crown, aura.light)
			end
			if aura.trail then
				addTrail(root, aura.trail)
			end
			if aura.highlight then
				addHighlight(model, aura.highlight)
			end
		end
	end

	return created
end

return SkinLook

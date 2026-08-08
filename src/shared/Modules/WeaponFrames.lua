--!strict

local WeaponFrames = {}

export type Zones = { [string]: { BasePart } }

export type Options = {
	color: Color3?,
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
}

export type Rig = {
	model: Model,
	haft: BasePart,
	zones: Zones,
	add: (zone: string, name: string, size: Vector3, position: Vector3, angles: Vector3?, options: Options?) -> BasePart,
}

export type Frame = (scale: number) -> (Model, Zones, CFrame)

local WOOD = Color3.fromRGB(176, 138, 96)
local IRON = Color3.fromRGB(126, 130, 138)
local STEEL = Color3.fromRGB(198, 204, 214)
local CREAM = Color3.fromRGB(248, 242, 232)
local ROPE = Color3.fromRGB(206, 178, 140)

local function decorate(part: BasePart, parent: Instance)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

local function newRig(name: string, scale: number, haftSize: Vector3, haftColor: Color3): Rig
	local model = Instance.new("Model")
	model.Name = name

	local haft = Instance.new("Part")
	haft.Name = "Haft"
	haft.Size = haftSize * scale
	haft.Color = haftColor
	haft.Material = Enum.Material.SmoothPlastic
	haft.CFrame = CFrame.new()
	decorate(haft, model)
	model.PrimaryPart = haft

	local zones: Zones = { all = { haft }, haft = { haft } }

	local function put(zone: string, part: BasePart)
		local list = zones[zone]
		if not list then
			list = {}
			zones[zone] = list
		end
		table.insert(list, part)
	end

	local function add(
		zone: string,
		partName: string,
		size: Vector3,
		position: Vector3,
		angles: Vector3?,
		options: Options?
	): BasePart
		local settings: Options = options or {}
		local turn = angles or Vector3.zero
		local part = Instance.new("Part")
		part.Name = partName
		part.Shape = settings.shape or Enum.PartType.Block
		part.Size = size * scale
		part.Color = settings.color or haftColor
		part.Material = settings.material or Enum.Material.SmoothPlastic
		part.Transparency = settings.transparency or 0
		part.Reflectance = settings.reflectance or 0
		part.CFrame = haft.CFrame
			* CFrame.new(position * scale)
			* CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
		decorate(part, model)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = haft
		weld.Part1 = part
		weld.Parent = part

		put(zone, part)
		put("all", part)
		return part
	end

	return { model = model, haft = haft, zones = zones, add = add }
end

local function poleGrip(drop: number): CFrame
	return CFrame.new(0, drop, -0.3) * CFrame.Angles(math.rad(-100), 0, 0)
end

local PRONG_SPLAY = 13
local BARBS_PER_PRONG = 3

local function sasumata(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Sasumata", scale, Vector3.new(0.2, 3.4, 0.2), Color3.fromRGB(243, 167, 193))
	local add = rig.add

	add("head", "ForkNeck", Vector3.new(0.86, 0.2, 0.2), Vector3.new(0, 1.66, 0))

	local prongLength = 1.3
	local splay = math.rad(PRONG_SPLAY)

	for _, side in { -1, 1 } do
		local lean = splay * side
		local baseX = 0.43 * side
		local baseY = 1.66
		local reach = Vector3.new(math.sin(lean), math.cos(lean), 0) * prongLength

		add(
			"head",
			if side < 0 then "LeftProng" else "RightProng",
			Vector3.new(0.18, prongLength, 0.2),
			Vector3.new(baseX, baseY, 0) + reach * 0.5,
			Vector3.new(0, 0, -math.deg(lean))
		)
		add(
			"head",
			if side < 0 then "LeftTip" else "RightTip",
			Vector3.new(0.22, 0.22, 0.22),
			Vector3.new(baseX, baseY, 0) + reach,
			nil,
			{ shape = Enum.PartType.Ball }
		)

		for index = 1, BARBS_PER_PRONG do
			local along = (index - 0.35) / BARBS_PER_PRONG
			add(
				"edge",
				"Barb",
				Vector3.new(0.14, 0.26, 0.3),
				Vector3.new(baseX - 0.16 * side, baseY, 0) + reach * along,
				Vector3.new(0, 90 * side, -math.deg(lean)),
				{ shape = Enum.PartType.Wedge, color = Color3.fromRGB(226, 124, 158) }
			)
		end
	end

	add("grip", "GripBand", Vector3.new(0.26, 0.8, 0.26), Vector3.new(0, -0.85, 0), nil, { color = CREAM })
	add(
		"cap",
		"ButtCap",
		Vector3.new(0.26, 0.26, 0.26),
		Vector3.new(0, -1.7, 0),
		nil,
		{ shape = Enum.PartType.Ball, color = Color3.fromRGB(226, 124, 158) }
	)

	return rig.model, rig.zones, poleGrip(-0.35)
end

local function club(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Club", scale, Vector3.new(0.24, 3, 0.24), WOOD)
	local add = rig.add

	add("head", "HeadBlock", Vector3.new(0.52, 1.15, 0.52), Vector3.new(0, 1.16, 0))
	add(
		"head",
		"HeadCrown",
		Vector3.new(0.52, 0.52, 0.52),
		Vector3.new(0, 1.72, 0),
		nil,
		{ shape = Enum.PartType.Ball }
	)

	local knobs = {
		Vector3.new(0.3, 1.36, 0),
		Vector3.new(-0.3, 1.06, 0),
		Vector3.new(0, 1.36, 0.3),
		Vector3.new(0, 1.06, -0.3),
	}
	for index, offset in knobs do
		add("edge", `Knob_{index}`, Vector3.new(0.2, 0.2, 0.2), offset, nil, {
			shape = Enum.PartType.Ball,
			color = Color3.fromRGB(138, 104, 70),
		})
	end

	add("grip", "GripWrap", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0, -1, 0), nil, { color = ROPE })
	add("cap", "ButtCap", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, -1.55, 0), nil, {
		shape = Enum.PartType.Ball,
		color = Color3.fromRGB(138, 104, 70),
	})

	return rig.model, rig.zones, poleGrip(-0.5)
end

local function staff(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Staff", scale, Vector3.new(0.2, 3.6, 0.2), Color3.fromRGB(248, 222, 118))
	local add = rig.add

	for _, side in { -1, 1 } do
		local suffix = if side < 0 then "Bottom" else "Top"
		add("head", `Collar{suffix}`, Vector3.new(0.32, 0.18, 0.32), Vector3.new(0, 1.6 * side, 0), nil, { color = IRON })
		add("head", `Nozzle{suffix}`, Vector3.new(0.36, 0.44, 0.36), Vector3.new(0, 1.88 * side, 0), nil, { color = IRON })
		add("edge", `Spark{suffix}`, Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 2.14 * side, 0), nil, {
			shape = Enum.PartType.Ball,
			color = Color3.fromRGB(255, 236, 148),
			material = Enum.Material.Neon,
		})
	end

	add("grip", "GripWrap", Vector3.new(0.28, 1.05, 0.28), Vector3.new(0, 0, 0), nil, { color = ROPE })
	add("cap", "FaceMark", Vector3.new(0.3, 0.3, 0.06), Vector3.new(0, 0.78, -0.13), nil, { color = CREAM })

	return rig.model, rig.zones, poleGrip(-0.2)
end

local function sword(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Sword", scale, Vector3.new(0.2, 1, 0.24), Color3.fromRGB(96, 74, 66))
	local add = rig.add

	add("head", "Blade", Vector3.new(0.36, 2.4, 0.11), Vector3.new(0, 1.7, 0), nil, {
		color = STEEL,
		material = Enum.Material.Metal,
		reflectance = 0.12,
	})
	add("edge", "Fuller", Vector3.new(0.09, 2.2, 0.14), Vector3.new(0, 1.66, 0), nil, {
		color = Color3.fromRGB(238, 244, 252),
		material = Enum.Material.Metal,
	})
	add("edge", "BladeTip", Vector3.new(0.36, 0.44, 0.11), Vector3.new(0, 3.12, 0), Vector3.new(0, 0, 180), {
		shape = Enum.PartType.Wedge,
		color = STEEL,
		material = Enum.Material.Metal,
		reflectance = 0.12,
	})

	add("grip", "GripWrap", Vector3.new(0.22, 0.72, 0.26), Vector3.new(0, -0.06, 0), nil, { color = ROPE })
	add("cap", "Guard", Vector3.new(0.94, 0.18, 0.28), Vector3.new(0, 0.5, 0), nil, {
		color = Color3.fromRGB(214, 178, 96),
		material = Enum.Material.Metal,
		reflectance = 0.18,
	})
	add("cap", "Pommel", Vector3.new(0.28, 0.28, 0.28), Vector3.new(0, -0.52, 0), nil, {
		shape = Enum.PartType.Ball,
		color = Color3.fromRGB(214, 178, 96),
		material = Enum.Material.Metal,
		reflectance = 0.18,
	})

	return rig.model, rig.zones, CFrame.new(0, -0.18, -0.26) * CFrame.Angles(math.rad(-100), 0, 0)
end

local function binyoyo(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Binyoyo", scale, Vector3.new(0.12, 2.3, 0.12), Color3.fromRGB(206, 214, 226))
	local add = rig.add

	for index = 1, 4 do
		add("haft", `Coil_{index}`, Vector3.new(0.26, 0.1, 0.26), Vector3.new(0, -0.55 + index * 0.36, 0), nil, {
			shape = Enum.PartType.Ball,
			color = Color3.fromRGB(178, 190, 208),
		})
	end

	add("head", "EggLower", Vector3.new(0.62, 0.62, 0.62), Vector3.new(0, 1.42, 0), nil, {
		shape = Enum.PartType.Ball,
		color = CREAM,
	})
	add("head", "EggUpper", Vector3.new(0.46, 0.46, 0.46), Vector3.new(0, 1.7, 0), nil, {
		shape = Enum.PartType.Ball,
		color = CREAM,
	})
	add("edge", "Shine", Vector3.new(0.22, 0.08, 0.16), Vector3.new(-0.18, 1.54, -0.2), Vector3.new(0, 0, 24), {
		color = Color3.fromRGB(255, 255, 255),
	})

	add("grip", "GripWrap", Vector3.new(0.2, 0.66, 0.2), Vector3.new(0, -0.72, 0), nil, { color = ROPE })
	add("cap", "TailBead", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, -1.18, 0), nil, {
		shape = Enum.PartType.Ball,
		color = Color3.fromRGB(178, 190, 208),
	})

	return rig.model, rig.zones, poleGrip(-0.3)
end

local function mallet(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Mallet", scale, Vector3.new(0.22, 2.6, 0.22), WOOD)
	local add = rig.add

	add("head", "HeadDrum", Vector3.new(1.4, 0.54, 0.54), Vector3.new(0, 1.14, 0))
	for _, side in { -1, 1 } do
		add(
			"edge",
			if side < 0 then "FaceLeft" else "FaceRight",
			Vector3.new(0.14, 0.6, 0.6),
			Vector3.new(0.71 * side, 1.14, 0),
			nil,
			{ color = Color3.fromRGB(138, 104, 70) }
		)
	end

	add("grip", "GripWrap", Vector3.new(0.28, 0.82, 0.28), Vector3.new(0, -0.82, 0), nil, { color = ROPE })
	add("cap", "ButtCap", Vector3.new(0.26, 0.26, 0.26), Vector3.new(0, -1.36, 0), nil, {
		shape = Enum.PartType.Ball,
		color = Color3.fromRGB(138, 104, 70),
	})

	return rig.model, rig.zones, poleGrip(-0.4)
end

local function morningstar(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Morningstar", scale, Vector3.new(0.22, 2.2, 0.22), Color3.fromRGB(88, 74, 66))
	local add = rig.add

	for index = 1, 3 do
		add("haft", `Link_{index}`, Vector3.new(0.18, 0.18, 0.18), Vector3.new(0, 0.95 + index * 0.26, 0), nil, {
			shape = Enum.PartType.Ball,
			color = IRON,
			material = Enum.Material.Metal,
		})
	end

	local headY = 2.3
	add("head", "Ball", Vector3.new(0.72, 0.72, 0.72), Vector3.new(0, headY, 0), nil, {
		shape = Enum.PartType.Ball,
		color = IRON,
		material = Enum.Material.Metal,
	})

	local spikes = {
		{ Vector3.new(0, 0.5, 0), Vector3.zero },
		{ Vector3.new(0.5, 0, 0), Vector3.new(0, 0, -90) },
		{ Vector3.new(-0.5, 0, 0), Vector3.new(0, 0, 90) },
		{ Vector3.new(0, 0, 0.5), Vector3.new(90, 0, 0) },
		{ Vector3.new(0, 0, -0.5), Vector3.new(-90, 0, 0) },
		{ Vector3.new(0, -0.5, 0), Vector3.new(180, 0, 0) },
	}
	for index, spike in spikes do
		add("edge", `Spike_{index}`, Vector3.new(0.16, 0.38, 0.16), spike[1] + Vector3.new(0, headY, 0), spike[2], {
			color = STEEL,
			material = Enum.Material.Metal,
		})
	end

	add("grip", "GripWrap", Vector3.new(0.28, 0.82, 0.28), Vector3.new(0, -0.56, 0), nil, { color = ROPE })
	add("cap", "ButtCap", Vector3.new(0.26, 0.26, 0.26), Vector3.new(0, -1.16, 0), nil, {
		shape = Enum.PartType.Ball,
		color = IRON,
		material = Enum.Material.Metal,
	})

	return rig.model, rig.zones, poleGrip(-0.2)
end

local function axe(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Axe", scale, Vector3.new(0.2, 2.8, 0.2), WOOD)
	local add = rig.add

	add("head", "Poll", Vector3.new(0.3, 0.74, 0.36), Vector3.new(0, 1.14, -0.08), nil, {
		color = IRON,
		material = Enum.Material.Metal,
	})
	add("edge", "Blade", Vector3.new(0.13, 1.02, 0.62), Vector3.new(0, 1.14, 0.42), nil, {
		color = STEEL,
		material = Enum.Material.Metal,
		reflectance = 0.1,
	})
	add("edge", "BladeEdge", Vector3.new(0.13, 1.02, 0.26), Vector3.new(0, 1.14, 0.86), Vector3.new(0, -90, 0), {
		shape = Enum.PartType.Wedge,
		color = Color3.fromRGB(238, 244, 252),
		material = Enum.Material.Metal,
		reflectance = 0.1,
	})

	add("grip", "GripWrap", Vector3.new(0.26, 0.82, 0.26), Vector3.new(0, -0.9, 0), nil, { color = ROPE })
	add("cap", "ButtCap", Vector3.new(0.26, 0.26, 0.26), Vector3.new(0, -1.46, 0), nil, {
		shape = Enum.PartType.Ball,
		color = Color3.fromRGB(138, 104, 70),
	})

	return rig.model, rig.zones, poleGrip(-0.45)
end

local function wand(scale: number): (Model, Zones, CFrame)
	local rig = newRig("Wand", scale, Vector3.new(0.16, 2, 0.16), CREAM)
	local add = rig.add
	local heartY = 1.28
	local heartColor = Color3.fromRGB(250, 132, 172)
	for _, side in { -1, 1 } do
		add(
			"head",
			if side < 0 then "HeartLobeLeft" else "HeartLobeRight",
			Vector3.new(0.42, 0.42, 0.16),
			Vector3.new(0.17 * side, heartY, 0),
			nil,
			{ shape = Enum.PartType.Ball, color = heartColor }
		)
	end
	add("head", "HeartPoint", Vector3.new(0.56, 0.44, 0.16), Vector3.new(0, heartY - 0.32, 0), Vector3.new(0, 0, 180), {
		shape = Enum.PartType.Wedge,
		color = heartColor,
	})

	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		add(
			"edge",
			`Wing{tag}Inner`,
			Vector3.new(0.52, 0.32, 0.08),
			Vector3.new(0.54 * side, heartY + 0.04, 0),
			Vector3.new(0, 0, -26 * side),
			{ color = Color3.fromRGB(255, 252, 248) }
		)
		add(
			"edge",
			`Wing{tag}Outer`,
			Vector3.new(0.36, 0.24, 0.08),
			Vector3.new(0.82 * side, heartY - 0.24, 0),
			Vector3.new(0, 0, -46 * side),
			{ color = Color3.fromRGB(255, 252, 248) }
		)
	end

	add("grip", "Ribbon", Vector3.new(0.24, 0.52, 0.24), Vector3.new(0, 0.16, 0), nil, { color = heartColor })
	add("cap", "StarBead", Vector3.new(0.24, 0.24, 0.24), Vector3.new(0, -1.02, 0), nil, {
		shape = Enum.PartType.Ball,
		color = Color3.fromRGB(255, 226, 150),
		material = Enum.Material.Neon,
	})

	return rig.model, rig.zones, CFrame.new(0, -0.24, -0.28) * CFrame.Angles(math.rad(-100), 0, 0)
end

WeaponFrames.FRAMES = {
	sasumata = sasumata,
	club = club,
	staff = staff,
	sword = sword,
	binyoyo = binyoyo,
	mallet = mallet,
	morningstar = morningstar,
	axe = axe,
	wand = wand,
} :: { [string]: Frame }

WeaponFrames.DEFAULT_FRAME = "sasumata"

function WeaponFrames.get(id: string): Frame
	return WeaponFrames.FRAMES[id] or sasumata
end

return WeaponFrames

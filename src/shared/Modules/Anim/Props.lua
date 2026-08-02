local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Props = {}

local function piece(parent: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local BUILDERS = {}

function BUILDERS.camera(size: number): (Model, CFrame)
	local model = Instance.new("Model")
	model.Name = "AnimProp_Camera"

	local body = piece(
		model,
		"Body",
		Vector3.new(1.0, 0.66, 0.42) * size,
		Color3.fromRGB(58, 58, 64),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = body

	local lens = piece(
		model,
		"Lens",
		Vector3.new(0.38, 0.38, 0.27) * size,
		Color3.fromRGB(28, 28, 32),
		Enum.Material.SmoothPlastic
	)
	lens.Shape = Enum.PartType.Cylinder
	lens.CFrame = body.CFrame * CFrame.new(0, 0, -0.31 * size) * CFrame.Angles(0, math.rad(90), 0)

	local glass =
		piece(model, "Glass", Vector3.new(0.1, 0.25, 0.25) * size, Color3.fromRGB(150, 210, 235), Enum.Material.Glass)
	glass.Shape = Enum.PartType.Cylinder
	glass.CFrame = body.CFrame * CFrame.new(0, 0, -0.43 * size) * CFrame.Angles(0, math.rad(90), 0)

	local shutter = piece(
		model,
		"Shutter",
		Vector3.new(0.19, 0.13, 0.19) * size,
		Color3.fromRGB(206, 92, 92),
		Enum.Material.SmoothPlastic
	)
	shutter.CFrame = body.CFrame * CFrame.new(-0.29 * size, 0.39 * size, 0)

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = body
		end
	end

	return model, CFrame.identity
end

function BUILDERS.book(size: number): (Model, CFrame)
	local model = Instance.new("Model")
	model.Name = "AnimProp_Book"

	local spine = piece(
		model,
		"Spine",
		Vector3.new(0.12, 0.86, 0.72) * size,
		Color3.fromRGB(178, 96, 88),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = spine

	for index, side in { -1, 1 } do
		local cover = piece(
			model,
			`Cover{index}`,
			Vector3.new(0.72, 0.86, 0.07) * size,
			Color3.fromRGB(178, 96, 88),
			Enum.Material.SmoothPlastic
		)
		cover.CFrame = spine.CFrame * CFrame.new(side * 0.38 * size, 0, 0) * CFrame.Angles(math.rad(side * -18), 0, 0)

		local pages = piece(
			model,
			`Pages{index}`,
			Vector3.new(0.65, 0.79, 0.05) * size,
			Color3.fromRGB(246, 242, 230),
			Enum.Material.SmoothPlastic
		)
		pages.CFrame = cover.CFrame * CFrame.new(0, 0, -0.06 * size)
	end

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= spine then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = spine
			weld.Part1 = part
			weld.Parent = spine
		end
	end

	return model, CFrame.Angles(math.rad(-52), 0, 0)
end

function Props.build(builder: string, size: number): (Model?, CFrame?)
	local make = BUILDERS[builder]
	if not make then
		return nil, nil
	end
	return make(size)
end

function Props.flash(at: CFrame, size: number, parent: Instance)
	local burst = Instance.new("Part")
	burst.Name = "AnimPropFlash"
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(0.5, 0.5, 0.5) * size
	burst.Color = Color3.fromRGB(255, 253, 240)
	burst.Material = Enum.Material.Neon
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CFrame = at * CFrame.new(0, 0, -0.7 * size)
	burst.Parent = parent

	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 16 * size
	light.Color = Color3.fromRGB(255, 250, 235)
	light.Parent = burst

	TweenService:Create(burst, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(2.4, 2.4, 2.4) * size,
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.22), { Brightness = 0 }):Play()

	Debris:AddItem(burst, 0.3)
end

return Props

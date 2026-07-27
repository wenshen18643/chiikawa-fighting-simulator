--[[
	Builds a mascot out of parts: a round body with a belly, ears, eyes, blush
	and stubby limbs.

	--------------------------------------------------------------------------
	WHY THIS IS SHARED AND NOT PART OF NpcService
	--------------------------------------------------------------------------

	It started inside NpcService, which was right while the cast standing in the
	world was the only thing made of these shapes. It is not any more:
	CompanionService offers the same silhouettes as followers, and the companion
	roster names NPCs by id so that the friend walking behind you is visibly the
	same character you met in town.

	Two copies of "what a mascot looks like" would drift the first time anyone
	changed an ear.

	--------------------------------------------------------------------------
	THE ROOT CFRAME IS AN ARGUMENT, NOT A LATER STEP
	--------------------------------------------------------------------------

	Pieces are welded to the root with WeldConstraint, and a WeldConstraint only
	preserves the offset it was created with. Moving an assembled mascot means
	`Model:PivotTo`, never `root.CFrame = ...`, which moves the root out from
	under its own ears. Building at the final CFrame keeps callers away from
	that trap entirely.

	The result is UNANCHORED. NpcService anchors its cast; CompanionService
	needs them loose for the constraints that carry them around.
]]

local Mascot = {}

export type Build = {
	bodyColor: Color3,
	bellyColor: Color3,
	earStyle: "round" | "tall" | "pointed" | "none",
	earColor: Color3?,
	height: number,
	blush: boolean,
}

local EYE_COLOR = Color3.fromRGB(48, 42, 38)
local BLUSH_COLOR = Color3.fromRGB(246, 176, 176)

--[[
	Distance from the root to the lowest point of the assembled mascot, as a
	multiple of its height — the foot, not the body. Callers place mascots by
	their feet; this is what turns a ground position into a root position.
]]
Mascot.ROOT_TO_FOOT = 0.53

local function piece(parent: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Ball
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weld(root: BasePart, target: BasePart, offset: CFrame)
	target.CFrame = root.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = target
	w.Parent = root
end

local function buildEars(model: Model, root: BasePart, build: Build, headTop: number)
	if build.earStyle == "none" then
		return
	end

	local color = build.earColor or build.bodyColor
	local spread = build.height * 0.26

	for _, side in { -1, 1 } do
		if build.earStyle == "round" then
			local ear = piece(model, "Ear", Vector3.new(1, 1, 1) * (build.height * 0.34), color)
			weld(root, ear, CFrame.new(side * spread, headTop * 0.82, 0))
		elseif build.earStyle == "tall" then
			-- A Cylinder part runs along its X axis: Size.X is the length and
			-- Y/Z are the diameter. The Z rotation below stands it upright.
			local ear = piece(
				model,
				"Ear",
				Vector3.new(build.height * 0.75, build.height * 0.2, build.height * 0.2),
				color,
				Enum.PartType.Cylinder
			)
			weld(
				root,
				ear,
				CFrame.new(side * spread * 0.8, headTop * 1.15, 0) * CFrame.Angles(0, 0, math.rad(90 + side * 12))
			)
		else -- pointed
			local ear = piece(
				model,
				"Ear",
				Vector3.new(build.height * 0.26, build.height * 0.4, build.height * 0.26),
				color,
				Enum.PartType.Wedge
			)
			weld(root, ear, CFrame.new(side * spread, headTop * 0.95, 0) * CFrame.Angles(0, 0, math.rad(side * 14)))
		end
	end
end

local function buildFace(model: Model, root: BasePart, build: Build)
	local h = build.height
	local eyeSize = h * 0.11
	local front = -h * 0.42

	for _, side in { -1, 1 } do
		local eye = piece(model, "Eye", Vector3.new(1, 1, 1) * eyeSize, EYE_COLOR)
		weld(root, eye, CFrame.new(side * h * 0.16, h * 0.06, front))

		if build.blush then
			local blush = piece(model, "Blush", Vector3.new(1, 1, 1) * (h * 0.14), BLUSH_COLOR)
			weld(root, blush, CFrame.new(side * h * 0.3, -h * 0.06, front * 0.88))
		end
	end

	local mouth = piece(model, "Mouth", Vector3.new(h * 0.08, h * 0.05, h * 0.08), EYE_COLOR)
	weld(root, mouth, CFrame.new(0, -h * 0.08, front))
end

local function buildLimbs(model: Model, root: BasePart, build: Build)
	local h = build.height

	for _, side in { -1, 1 } do
		local arm = piece(model, "Arm", Vector3.new(h * 0.16, h * 0.28, h * 0.16), build.bodyColor)
		weld(root, arm, CFrame.new(side * h * 0.44, -h * 0.06, 0) * CFrame.Angles(0, 0, math.rad(side * 20)))

		local foot = piece(model, "Foot", Vector3.new(h * 0.2, h * 0.14, h * 0.28), build.bodyColor)
		weld(root, foot, CFrame.new(side * h * 0.18, -h * 0.46, -h * 0.06))
	end
end

--[[
	An assembled mascot standing at `rootCFrame`, unanchored, with its body part
	as PrimaryPart.
]]
function Mascot.build(build: Build, rootCFrame: CFrame, name: string?): Model
	local h = build.height

	local model = Instance.new("Model")
	model.Name = name or "Mascot"

	local root = Instance.new("Part")
	root.Name = "Body"
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.new(h, h, h)
	root.Color = build.bodyColor
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = false
	root.CanCollide = false
	root.CanQuery = true
	root.CFrame = rootCFrame
	root.Parent = model
	model.PrimaryPart = root

	-- Belly patch, slightly proud of the body so it does not z-fight.
	local belly = piece(model, "Belly", Vector3.new(1, 1, 1) * (h * 0.62), build.bellyColor)
	weld(root, belly, CFrame.new(0, -h * 0.1, -h * 0.16))

	buildEars(model, root, build, h * 0.5)
	buildFace(model, root, build)
	buildLimbs(model, root, build)

	return model
end

return Mascot

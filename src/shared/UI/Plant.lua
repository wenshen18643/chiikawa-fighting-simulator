--[[
	The field-guide plant diagram, drawn from Frames.

	Shared because two surfaces show the same specimen: the study book teaches
	it, and the Exam Hall counter tests it. Drawing rather than uploading keeps
	every leaf crisp on a phone and keeps the two views identical by
	construction.
]]

local Primitives = require(script.Parent.Primitives)

local Plant = {}

Plant.PAPER_DEEP = Color3.fromRGB(246, 229, 190)
Plant.INK = Color3.fromRGB(61, 48, 55)

local STEM = Color3.fromRGB(74, 144, 72)

local LEAF_ANGLES = {
	[1] = { 0 },
	[2] = { -48, 48 },
	[3] = { -62, 0, 62 },
	[4] = { -72, -24, 24, 72 },
}

function Plant.draw(parent: Instance, definition: any, zIndex: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = `Plant_{definition.id}`
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = zIndex
	holder.Parent = parent

	local ground = Instance.new("Frame")
	ground.Name = "Ground"
	ground.AnchorPoint = Vector2.new(0.5, 0.5)
	ground.Position = UDim2.fromScale(0.5, 0.83)
	ground.Size = UDim2.fromScale(0.55, 0.08)
	ground.BackgroundColor3 = Plant.PAPER_DEEP
	ground.BorderSizePixel = 0
	ground.ZIndex = zIndex
	ground.Parent = holder
	Primitives.corner(ground, 999)

	local stem = Instance.new("Frame")
	stem.Name = "Stem"
	stem.AnchorPoint = Vector2.new(0.5, 1)
	stem.Position = UDim2.fromScale(0.5, 0.82)
	stem.Size = UDim2.fromScale(0.045, 0.42)
	stem.BackgroundColor3 = STEM
	stem.BorderSizePixel = 0
	stem.ZIndex = zIndex + 1
	stem.Parent = holder
	Primitives.corner(stem, 999)

	local angles = LEAF_ANGLES[definition.leafCount] or LEAF_ANGLES[2]
	for index, angle in angles do
		local leaf = Instance.new("Frame")
		leaf.Name = `Leaf_{index}`
		leaf.AnchorPoint = Vector2.new(0.5, 0.5)
		local radians = math.rad(angle)
		leaf.Position = UDim2.fromScale(0.5 + math.sin(radians) * 0.21, 0.57 - math.cos(radians) * 0.08)
		leaf.Size = if definition.leafShape == "narrow" then UDim2.fromScale(0.13, 0.34) else UDim2.fromScale(0.3, 0.18)
		leaf.Rotation = angle
		leaf.BackgroundColor3 = definition.leafColor
		leaf.BorderSizePixel = 0
		leaf.ZIndex = zIndex + 2
		leaf.Parent = holder
		Primitives.corner(leaf, 999)
		Primitives.stroke(leaf, Plant.INK, 1.5)

		if definition.marking ~= "plain" and definition.marking ~= "bud" then
			local mark = Instance.new("Frame")
			mark.Name = "Mark"
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromScale(0.5, 0.5)
			mark.Size = if definition.marking == "spots"
				then UDim2.fromScale(0.22, 0.34)
				else UDim2.fromScale(0.16, 0.75)
			mark.Rotation = if definition.marking == "thorns" then 45 else 0
			mark.BackgroundColor3 = definition.accentColor
			mark.BorderSizePixel = 0
			mark.ZIndex = zIndex + 3
			mark.Parent = leaf
			Primitives.corner(mark, 999)
		end
	end

	if definition.marking == "bud" then
		local bud = Instance.new("Frame")
		bud.Name = "Bud"
		bud.AnchorPoint = Vector2.new(0.5, 0.5)
		bud.Position = UDim2.fromScale(0.5, 0.32)
		bud.Size = UDim2.fromScale(0.22, 0.22)
		bud.BackgroundColor3 = definition.accentColor
		bud.BorderSizePixel = 0
		bud.ZIndex = zIndex + 3
		bud.Parent = holder
		Primitives.corner(bud, 999)
		Primitives.stroke(bud, Plant.INK, 1.5)
	end

	return holder
end

return Plant

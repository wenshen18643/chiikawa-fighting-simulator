--!strict

local ModelUtil = {}

--[[
	World-axis bounding box.

	Model:GetExtentsSize and Model:GetBoundingBox are aligned to the model's
	PrimaryPart, or to its first part when there is none -- so they do not change
	when the model is rotated, and reading "how tall is this now" off them gives
	the authored girth of a tree lying on its side. Everything here needs the
	real world box, so it is measured from the parts.
]]
function ModelUtil.worldBox(model: Model): (Vector3, Vector3)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cframe = part.CFrame
			local half = part.Size / 2
			local x = cframe.RightVector * half.X
			local y = cframe.UpVector * half.Y
			local z = cframe.LookVector * half.Z
			local reach = Vector3.new(
				math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
				math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
				math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z)
			)
			min = min:Min(cframe.Position - reach)
			max = max:Max(cframe.Position + reach)
		end
	end

	if min.X == math.huge then
		return model:GetPivot().Position, Vector3.zero
	end
	return (min + max) / 2, max - min
end

--[[
	The sausage assets are authored lying along their X axis: they grow out of
	the ground sideways, and height scaling measures Y, so a model lying down is
	scaled by its own girth and comes out enormous.
]]
function ModelUtil.standUpright(model: Model)
	local _, size = ModelUtil.worldBox(model)
	if size.Y >= size.X and size.Y >= size.Z then
		return
	end
	local pitch = if size.X > size.Z then CFrame.Angles(0, 0, math.rad(90)) else CFrame.Angles(math.rad(90), 0, 0)
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position) * pitch * pivot.Rotation)
end

function ModelUtil.scaleToHeight(model: Model, height: number): boolean
	local _, size = ModelUtil.worldBox(model)
	if size.Y <= 0.01 then
		return false
	end
	model:ScaleTo(model:GetScale() * (height / size.Y))
	return true
end

-- Seats the model's world footprint on `position`, keeping whatever pitch
-- standUpright applied. AssetService.place builds a fresh CFrame and drops it.
function ModelUtil.placeStanding(model: Model, position: Vector3, yaw: number)
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, yaw, 0) * pivot.Rotation)

	local centre, size = ModelUtil.worldBox(model)
	local footing = Vector3.new(centre.X, centre.Y - size.Y / 2, centre.Z)
	model:PivotTo(model:GetPivot() + (position - footing))
end

function ModelUtil.firstPart(model: Model): BasePart?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

return ModelUtil

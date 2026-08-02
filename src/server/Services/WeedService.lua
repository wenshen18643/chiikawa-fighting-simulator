local CollectionService = game:GetService("CollectionService")
local WorldService = require(script.Parent.WorldService)
local WeedService = {}

WeedService.PULL_RADIUS = 10
WeedService.REGROW_SECONDS = 30

export type Section = {
	parts: { BasePart },
	center: Vector3,
	transparency: { [BasePart]: number },
	pulled: boolean,
}

local sections: { Section } = {}

function WeedService.registerPatch(model: Model, isSection: (Instance) -> boolean)
	CollectionService:AddTag(model, "Weed")

	for _, child in model:GetChildren() do
		if not isSection(child) then
			continue
		end

		local parts: { BasePart } = {}
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
		for _, descendant in child:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
		if #parts == 0 then
			continue
		end

		local center = Vector3.zero
		for _, part in parts do
			center += part.Position
		end
		center /= #parts

		local transparency: { [BasePart]: number } = {}
		for _, part in parts do
			transparency[part] = part.Transparency
		end

		table.insert(sections, {
			parts = parts,
			center = center,
			transparency = transparency,
			pulled = false,
		})
	end
end

function WeedService.nearestPullable(position: Vector3, maxDist: number): Section?
	local best: Section? = nil
	local bestDist = maxDist

	for _, section in sections do
		if section.pulled then
			continue
		end
		local delta = section.center - position
		local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = section
		end
	end

	return best
end

function WeedService.pull(section: Section)
	if section.pulled then
		return
	end
	section.pulled = true

	for _, part in section.parts do
		part.Transparency = 1
	end

	task.delay(WeedService.REGROW_SECONDS, function()
		section.pulled = false
		for part, transparency in section.transparency do
			if part.Parent then
				part.Transparency = transparency
			end
		end
	end)
end

local PATCH_MODEL = "WeedingPatchProp"

local function isSprout(child: Instance): boolean
	return child.Name:match("^WeedSprout_") ~= nil
end

function WeedService.init()
	task.spawn(function()
		WorldService.awaitDressed()

		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Model") and descendant.Name == PATCH_MODEL then
				WeedService.registerPatch(descendant, isSprout)
			end
		end
	end)
end

return WeedService

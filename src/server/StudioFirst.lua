local Workspace = game:GetService("Workspace")

local StudioFirst = {}

function StudioFirst.isEnabled(): boolean
	return Workspace:GetAttribute("StudioFirst") == true
end

function StudioFirst.shouldPreserve(instance: Instance?): boolean
	return StudioFirst.isEnabled()
		and instance ~= nil
		and instance:GetAttribute("RuntimeGenerated") ~= true
end

return StudioFirst

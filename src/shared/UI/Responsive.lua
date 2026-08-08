--!strict

local Workspace = game:GetService("Workspace")
local Responsive = {}

Responsive.COMPACT_WIDTH = 760
Responsive.COMPACT_HEIGHT = 420
Responsive.MIN_SUPPORTED = Vector2.new(568, 320)
Responsive.COMPACT_MARGIN = 8
Responsive.DESKTOP_MARGIN = 18

function Responsive.viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

function Responsive.isCompact(viewport: Vector2?): boolean
	local size = viewport or Responsive.viewport()
	return size.X < Responsive.COMPACT_WIDTH or size.Y < Responsive.COMPACT_HEIGHT
end

function Responsive.panelSize(preferred: UDim2, maxSize: Vector2?): (UDim2, boolean)
	local view = Responsive.viewport()
	local compact = Responsive.isCompact(view)
	local margin = if compact then Responsive.COMPACT_MARGIN else Responsive.DESKTOP_MARGIN
	if compact then
		return UDim2.fromOffset(math.max(0, view.X - margin * 2), math.max(0, view.Y - margin * 2)), true
	end
	local width = preferred.X.Scale * view.X + preferred.X.Offset
	local height = preferred.Y.Scale * view.Y + preferred.Y.Offset
	if maxSize then
		width = math.min(width, maxSize.X)
		height = math.min(height, maxSize.Y)
	end
	width = math.min(width, view.X - margin * 2)
	height = math.min(height, view.Y - margin * 2)
	return UDim2.fromOffset(math.floor(width), math.floor(height)), false
end

return Responsive

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponLook = require(Shared.Modules.WeaponLook)
local WeaponLooks = require(Shared.Modules.Config.WeaponLooks)
local WeaponSkins = require(Shared.Modules.Config.WeaponSkins)
local UI = require(Shared.UI)
local WeaponPreview = {}

export type Config = {
	spin: boolean?,
	tint: Color3?,
	backdrop: number?,
	pitch: number?,
	yaw: number?,
	zoom: number?,
	radius: number?,
	zIndex: number?,
}

type Entry = {
	viewport: ViewportFrame,
	camera: Camera,
	skinId: string,
	options: Config,
	spin: boolean,
	turn: number,
	aim: ((number) -> ())?,
	built: boolean,
}

local CACHE_LIMIT = 12
local BASE_PITCH = 8
local BASE_YAW = 24
local BASE_ZOOM = 1.2
local MIN_HALF_ANGLE = math.rad(4)
local SPIN_RATE = 32
local cache: { [string]: Model } = {}
local cacheOrder: { string } = {}
local pending: { [ViewportFrame]: Entry } = {}
local driver: RBXScriptConnection? = nil

local function forge(skinId: string): Model?
	local look = WeaponLooks.get(skinId)
	if not look then
		return nil
	end

	local model = WeaponLook.build(look, 1)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant:RemoveTag(WeaponLook.DECORATION_TAG)
		elseif descendant:IsA("Motor6D") or descendant:IsA("Highlight") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
			local effect = descendant :: any
			effect.Enabled = false
		end
	end

	return model
end

local function fromCache(skinId: string): Model?
	local hit = cache[skinId]
	if hit then
		local index = table.find(cacheOrder, skinId)
		if index then
			table.remove(cacheOrder, index)
		end
		table.insert(cacheOrder, skinId)
		return hit:Clone()
	end

	local built = forge(skinId)
	if not built then
		return nil
	end

	cache[skinId] = built
	table.insert(cacheOrder, skinId)
	while #cacheOrder > CACHE_LIMIT do
		local oldest = table.remove(cacheOrder, 1)
		if oldest then
			local stale = cache[oldest]
			cache[oldest] = nil
			if stale then
				stale:Destroy()
			end
		end
	end

	return built:Clone()
end

local function onScreen(viewport: ViewportFrame): boolean
	local node: Instance? = viewport
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	if node and node:IsA("LayerCollector") then
		return node.Enabled
	end
	return false
end

local function fitDistance(viewport: ViewportFrame, camera: Camera, radius: number, margin: number): number
	local extent = viewport.AbsoluteSize
	local vertical = math.rad(camera.FieldOfView) * 0.5
	local horizontal = vertical
	if extent.X > 0 and extent.Y > 0 then
		horizontal = math.atan(math.tan(vertical) * (extent.X / extent.Y))
	end
	local half = math.max(math.min(vertical, horizontal), MIN_HALF_ANGLE)
	return radius / math.sin(half) * margin
end

local function realize(entry: Entry)
	entry.built = true

	local model = fromCache(entry.skinId)
	if not model then
		return
	end
	model.Parent = entry.viewport

	local options = entry.options
	local viewport = entry.viewport
	local camera = entry.camera
	local pivot, size = model:GetBoundingBox()
	local radius = size.Magnitude * 0.5
	local margin = options.zoom or BASE_ZOOM
	local pitch = math.rad(options.pitch or BASE_PITCH)
	local facing = math.rad(options.yaw or BASE_YAW)
	local focus = pivot.Position
	local reach = fitDistance(viewport, camera, radius, margin)

	local function aim(spun: number)
		local turn = facing + spun
		local offset = CFrame.Angles(0, turn, 0) * CFrame.Angles(-pitch, 0, 0) * CFrame.new(0, 0, reach)
		camera.CFrame = CFrame.lookAt(focus + offset.Position, focus)
	end

	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		reach = fitDistance(viewport, camera, radius, margin)
		aim(entry.turn)
	end)

	entry.aim = aim
	aim(entry.turn)
end

local function step(delta: number)
	for viewport, entry in pending do
		if viewport.Parent == nil then
			pending[viewport] = nil
		elseif onScreen(viewport) then
			if not entry.built then
				realize(entry)
			end
			local aim = entry.aim
			if not entry.spin or not aim then
				pending[viewport] = nil
			else
				entry.turn = (entry.turn + math.rad(SPIN_RATE) * delta) % (math.pi * 2)
				aim(entry.turn)
			end
		end
	end

	if next(pending) == nil and driver then
		driver:Disconnect()
		driver = nil
	end
end

local function track(entry: Entry)
	pending[entry.viewport] = entry
	if not driver then
		driver = RunService.RenderStepped:Connect(step)
	end
end

function WeaponPreview.mount(parent: Instance, skinId: string, config: Config?): (ViewportFrame, () -> ())
	local options: Config = config or {}
	local skin = WeaponSkins.get(skinId)
	local rarity = if skin then WeaponSkins.RARITIES[skin.rarity] else nil
	local tint = options.tint or (if rarity then rarity.color else UI.color.paperDeep)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "WeaponPreview"
	viewport.Ambient = Color3.fromRGB(190, 186, 198)
	viewport.LightColor = Color3.fromRGB(255, 252, 246)
	viewport.LightDirection = Vector3.new(-0.4, -0.7, -0.6)
	viewport.BackgroundColor3 = tint:Lerp(Color3.fromRGB(28, 24, 38), 0.7)
	viewport.BackgroundTransparency = options.backdrop or 0
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = options.zIndex or 1
	viewport.Parent = parent
	UI.corner(viewport, options.radius or UI.radius.tile)

	UI.gradient(viewport, tint:Lerp(Color3.fromRGB(255, 255, 255), 0.35), tint:Lerp(Color3.fromRGB(0, 0, 0), 0.4), 90)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local entry: Entry = {
		viewport = viewport,
		camera = camera,
		skinId = skinId,
		options = options,
		spin = options.spin == true and not UI.motion.isReducedMotion(),
		turn = 0,
		aim = nil,
		built = false,
	}
	track(entry)

	viewport.Destroying:Connect(function()
		pending[viewport] = nil
	end)

	local function destroy()
		viewport:Destroy()
	end

	return viewport, destroy
end

return WeaponPreview

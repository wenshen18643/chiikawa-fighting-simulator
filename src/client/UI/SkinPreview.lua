--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Modules.Config.Assets)
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local SkinLook = require(Shared.Modules.SkinLook)
local SkinLooks = require(Shared.Modules.Config.SkinLooks)
local UI = require(Shared.UI)
local SkinPreview = {}

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

local FACING: { [string]: number } = {
	chiikawa = 0,
	hachiware = 0,
	usagi = 0,
}

local CACHE_LIMIT = 12
local BASE_PITCH = 14
local BASE_ZOOM = 1.55
local SPIN_RATE = 32
local templates: { [string]: Model } = {}
local cache: { [string]: Model } = {}
local cacheOrder: { string } = {}

local function templateFor(characterId: string): Model?
	local cached = templates[characterId]
	if cached then
		return cached
	end

	local spec = (Assets.MODELS :: any)[characterId]
	if not spec then
		return nil
	end

	local folder = ReplicatedStorage:FindFirstChild("Assets")
	local models = if folder then folder:FindFirstChild("Models") else nil
	local template = if models then models:FindFirstChild(spec.template) else nil
	if not template or not template:IsA("Model") then
		return nil
	end

	templates[characterId] = template
	return template
end

local function dress(skinId: string): Model?
	local skin = CompanionSkins.get(skinId)
	if not skin then
		return nil
	end

	local template = templateFor(skin.characterId)
	if not template then
		return nil
	end

	local wasArchivable = template.Archivable
	template.Archivable = true
	local model = template:Clone()
	template.Archivable = wasArchivable

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Humanoid") or descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end

	Skeleton.prepare(model, skin.characterId)
	SkinLook.apply(model, skin.characterId, SkinLooks.get(skinId))

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
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

	local built = dress(skinId)
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

function SkinPreview.mount(parent: Instance, skinId: string, config: Config?): (ViewportFrame, () -> ())
	local options: Config = config or {}
	local skin = CompanionSkins.get(skinId)
	local rarity = if skin then CompanionSkins.RARITIES[skin.rarity] else nil
	local tint = options.tint or (if rarity then rarity.color else UI.color.paperDeep)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "SkinPreview"
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

	local model = fromCache(skinId)
	local connection: RBXScriptConnection? = nil

	if model then
		model.Parent = viewport

		local pivot, size = model:GetBoundingBox()
		local reach = math.max(size.X, size.Y, size.Z) * (options.zoom or BASE_ZOOM)
		local pitch = math.rad(options.pitch or BASE_PITCH)
		local facing = math.rad(options.yaw or (if skin then FACING[skin.characterId] or 0 else 0))
		local focus = pivot.Position

		local function aim(spun: number)
			local turn = facing + spun
			local offset = CFrame.Angles(0, turn, 0) * CFrame.Angles(-pitch, 0, 0) * CFrame.new(0, 0, reach)
			camera.CFrame = CFrame.lookAt(focus + offset.Position, focus)
		end

		aim(0)

		if options.spin and not UI.motion.isReducedMotion() then
			local turn = 0
			connection = RunService.RenderStepped:Connect(function(delta)
				if not viewport.Visible or viewport.Parent == nil then
					return
				end
				turn = (turn + math.rad(SPIN_RATE) * delta) % (math.pi * 2)
				aim(turn)
			end)
		end
	end

	viewport.Destroying:Connect(function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)

	local function destroy()
		viewport:Destroy()
	end

	return viewport, destroy
end

return SkinPreview

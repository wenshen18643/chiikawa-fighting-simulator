local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Modules.Config.Assets)
local AssetService = {}
local cache: { [string]: Model } = {}
local failed: { [string]: string } = {}
local library: Folder

local function isContraband(descendant: Instance): boolean
	return descendant:IsA("LuaSourceContainer")
		or descendant:IsA("Sound")
		or descendant:IsA("Camera")
		or descendant:IsA("PostEffect")
end

local SHADOW_MIN_SIZE = 6

local function prepare(model: Model, spec: Assets.AssetSpec)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Tool") then
			local parent = descendant.Parent
			for _, child in descendant:GetChildren() do
				child.Parent = parent
			end
			descendant:Destroy()
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Accessory") then
			local parent = descendant.Parent
			for _, child in descendant:GetChildren() do
				if child:IsA("BasePart") then
					child.Parent = parent
				end
			end
			descendant:Destroy()
		end
	end

	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("WrapLayer")
			or descendant:IsA("WrapTarget")
			or (descendant:IsA("Vector3Value") and descendant.Name == "OriginalSize")
		then
			descendant:Destroy()
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local solid = spec.collide ~= false
			descendant.Anchored = true
			descendant.CanCollide = solid
			descendant.CanQuery = solid
			descendant.CanTouch = false

			if descendant:IsA("MeshPart") or descendant:IsA("UnionOperation") then
				pcall(function()
					(descendant :: any).CollisionFidelity = Enum.CollisionFidelity.Box
				end)
			end
			if math.max(descendant.Size.X, descendant.Size.Y, descendant.Size.Z) < SHADOW_MIN_SIZE then
				descendant.CastShadow = false
			end
		elseif isContraband(descendant) then
			descendant:Destroy()
		end
	end

	local scale = spec.scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
end

local function unwrap(container: Model): Model?
	local children = container:GetChildren()
	if #children == 1 and children[1]:IsA("Model") then
		return children[1] :: Model
	end
	return container
end

local function loadTemplate(key: string, spec: Assets.AssetSpec): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	if not models then
		failed[key] = `{key}: ReplicatedStorage.Assets.Models is missing (is assets/ mapped in default.project.json?)`
		return nil
	end

	local template = models:FindFirstChild(spec.template)
	if not template then
		failed[key] = `{key}: no template "{spec.template}" under assets/Models/`
		return nil
	end

	local container = Instance.new("Model")
	local clone = template:Clone()
	clone.Parent = container
	return container
end

local function load(key: string, spec: Assets.AssetSpec)
	local container = loadTemplate(key, spec)
	if not container then
		return
	end

	local model = unwrap(container)
	if not model then
		failed[key] = `{key} (template "{spec.template}"): loaded but contained no model`
		container:Destroy()
		return
	end

	model.Name = key
	prepare(model, spec)
	model.Parent = library
	cache[key] = model

	if container ~= model and container.Parent == nil then
		container:Destroy()
	end
end

function AssetService.clone(key: string): Model?
	local model = cache[key]
	if not model then
		return nil
	end
	return model:Clone()
end

function AssetService.isReady(key: string): boolean
	return cache[key] ~= nil
end

function AssetService.waitFor(key: string, timeout: number?): boolean
	if cache[key] then
		return true
	end
	if failed[key] then
		return false
	end

	local deadline = os.clock() + (timeout or 3)
	while os.clock() < deadline do
		task.wait(0.1)
		if cache[key] then
			return true
		end
		if failed[key] then
			return false
		end
	end
	return cache[key] ~= nil
end

function AssetService.place(model: Model, position: Vector3, rotationY: number?)
	local size = model:GetExtentsSize()
	local pivot = CFrame.new(position + Vector3.new(0, size.Y / 2, 0))
	if rotationY then
		pivot *= CFrame.Angles(0, rotationY, 0)
	end
	model:PivotTo(pivot)
end

function AssetService.describe(model: Model): string
	local parts, meshes, scripts, animations = 0, 0, 0, 0
	local humanoid = false

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			meshes += 1
			parts += 1
		elseif descendant:IsA("BasePart") then
			parts += 1
		elseif descendant:IsA("BaseScript") then
			scripts += 1
		elseif descendant:IsA("Animation") then
			animations += 1
		elseif descendant:IsA("Humanoid") then
			humanoid = true
		end
	end

	local size = model:GetExtentsSize()
	return string.format(
		"%.1f x %.1f x %.1f studs, %d part(s) (%d mesh), %d animation(s), humanoid: %s, scripts left: %d",
		size.X,
		size.Y,
		size.Z,
		parts,
		meshes,
		animations,
		tostring(humanoid),
		scripts
	)
end

function AssetService.init()
	library = Instance.new("Folder")
	library.Name = "AssetLibrary"
	library.Parent = ServerStorage

	local keys = Assets.keys()
	local loaded, broken = {}, {}

	for _, key in keys do
		local spec = Assets.get(key)
		if not spec then
			continue
		end

		load(key, spec)

		if cache[key] then
			table.insert(loaded, key)
		else
			table.insert(broken, failed[key] or `{key}: did not load`)
		end
	end

	print(
		`[AssetService] decor models: {#loaded} loaded from assets/Models/`
			.. (if #loaded > 0 then ` ({table.concat(loaded, ", ")})` else "")
			.. `, {#broken} failed`
	)

	if #broken > 0 then
		warn(
			`[AssetService] using the procedural fallback for {#broken} model(s): {table.concat(broken, "; ")}. `
				.. `Add the missing .rbxmx under assets/Models/ and match the template name in Config/Assets.lua.`
		)
	end
end

return AssetService

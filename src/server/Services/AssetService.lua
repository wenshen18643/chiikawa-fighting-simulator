local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Modules.Config.Assets)
local AssetService = {}
local cache: { [string]: Model } = {}
local packItems: { [string]: { Instance } } = {}
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

local function isExcluded(name: string, exclude: { string }?): boolean
	if not exclude then
		return false
	end
	local lowered = string.lower(name)
	for _, pattern in exclude do
		if string.find(lowered, string.lower(pattern), 1, true) then
			return true
		end
	end
	return false
end

local function collectItems(root: Instance, out: { Instance }, depth: number, exclude: { string }?)
	if depth > 6 then
		return
	end
	for _, child in root:GetChildren() do
		if child:IsA("Folder") then
			collectItems(child, out, depth + 1, exclude)
		elseif child:IsA("Model") or child:IsA("BasePart") then
			if not isExcluded(child.Name, exclude) then
				table.insert(out, child)
			end
		end
	end
end

local function unwrap(container: Model, spec: Assets.AssetSpec): Model?
	if spec.kind == "pack" then
		return container
	end

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

	local template = models:FindFirstChild(spec.template :: string)
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
	local container: Model

	if spec.template then
		local resolved = loadTemplate(key, spec)
		if not resolved then
			return
		end
		container = resolved
	else
		local ok, result = pcall(function()
			return InsertService:LoadAsset(spec.id)
		end)

		if not ok or typeof(result) ~= "Instance" then
			failed[key] = `{key} (id {spec.id}): {result}`
			return
		end

		container = result :: Model
	end

	local model = unwrap(container, spec)
	if not model then
		local source = if spec.template then `template "{spec.template}"` else `id {spec.id}`
		failed[key] = `{key} ({source}): loaded but contained no model`
		container:Destroy()
		return
	end

	model.Name = key
	prepare(model, spec)
	model.Parent = library
	cache[key] = model

	if spec.kind == "pack" then
		local items = {}
		collectItems(model, items, 0, spec.exclude)
		packItems[key] = items

		print(`[AssetService] pack "{key}" holds {#items} prop(s):`)
		for _, child in items do
			local detail = ""
			if child:IsA("Model") then
				local measured, size = pcall(function()
					return (child :: Model):GetExtentsSize()
				end)
				if measured then
					detail = string.format(" %.1f x %.1f x %.1f studs", size.X, size.Y, size.Z)
				end
			elseif child:IsA("BasePart") then
				local size = (child :: BasePart).Size
				detail = string.format(" %.1f x %.1f x %.1f studs", size.X, size.Y, size.Z)
			end
			print(`[AssetService]     {child.ClassName}  "{child.Name}"{detail}`)
		end

		if #items == 0 then
			warn(
				`[AssetService] pack "{key}" contained no Models or BaseParts at any depth. `
					.. `Callers will use their procedural fallback.`
			)
		end
	end

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

function AssetService.clonePackItem(key: string, rng: Random?, match: string?): Model?
	local usable = packItems[key]
	if not usable or #usable == 0 then
		return nil
	end

	local needle = match and string.lower(match) or nil
	local matched = {}
	if needle then
		for _, child in usable do
			if string.find(string.lower(child.Name), needle, 1, true) then
				table.insert(matched, child)
			end
		end
	end

	local pool = if #matched > 0 then matched else usable
	local index = if rng then rng:NextInteger(1, #pool) else math.random(1, #pool)
	local clone = pool[index]:Clone()

	if clone:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		wrapper.Name = clone.Name
		clone.Parent = wrapper
		wrapper.PrimaryPart = clone
		return wrapper
	end

	return clone :: any
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

	local configured = Assets.configured()
	local pending = 0

	for _, key in configured do
		local spec = Assets.get(key)
		if not spec then
			continue
		end

		if spec.template then
			load(key, spec)
			continue
		end

		pending += 1
		task.spawn(function()
			load(key, spec)
			pending -= 1
		end)
	end

	task.spawn(function()
		local deadline = os.clock() + 15
		while pending > 0 and os.clock() < deadline do
			task.wait(0.25)
		end

		local loaded, broken = {}, {}
		for _, key in configured do
			if cache[key] then
				table.insert(loaded, key)
			else
				table.insert(broken, failed[key] or `{key}: still loading`)
			end
		end

		local blank = Assets.blank()
		local fromRepo = Assets.local_()
		print(
			`[AssetService] decor models: {#loaded} loaded`
				.. (if #loaded > 0 then ` ({table.concat(loaded, ", ")})` else "")
				.. `, {#broken} failed, {#blank} with no id set`
				.. (
					if #fromRepo > 0 then `. Served locally from assets/Models/: {table.concat(fromRepo, ", ")}` else ""
				)
		)

		if #broken > 0 then
			warn(
				`[AssetService] using the procedural fallback for {#broken} model(s): {table.concat(broken, "; ")}. `
					.. `"not authorized" means the id is a PRIVATE model owned by another account. `
					.. `InsertService cannot fetch those no matter what is in Config/Assets.lua. `
					.. `Re-upload it to this place's owner, or use a genuinely free model, then swap the id.`
			)
		end
	end)
end

return AssetService

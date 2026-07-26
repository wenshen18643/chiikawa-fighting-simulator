--[[
	Loads the uploaded decor models in Config/Assets and hands out clones.

	--------------------------------------------------------------------------
	LOAD ONCE, CLONE MANY
	--------------------------------------------------------------------------

	InsertService:LoadAsset is a web call. The world scatters hundreds of props
	across six areas, so calling it per prop would turn world generation into a
	few hundred round trips. Everything is fetched once into ServerStorage at
	startup and every prop after that is a local clone.

	--------------------------------------------------------------------------
	FAILURE IS A FIRST-CLASS OUTCOME
	--------------------------------------------------------------------------

	`clone` returns nil rather than throwing when an asset is blank, still
	loading, or failed to load, and every caller in Areas/Area.lua falls back to
	the procedural version it used before. A private or moderated id therefore
	costs the nicer model and nothing else.

	This matters more than usual here: the ids come from docs/ASSETS.md and
	LoadAsset only succeeds for public assets or assets owned by the place
	owner. Whether a given id works is not knowable from this repo, so the code
	is written to be correct either way.

	--------------------------------------------------------------------------
	PREPARATION
	--------------------------------------------------------------------------

	Uploaded models arrive with whatever the author left on them, which for
	scenery is usually wrong for us: unanchored parts fall through the terrain,
	scripts run, and collision on every leaf makes a forest a wall. `prepare`
	normalises all of that once, on the cached copy, so clones are already
	correct and per-prop cost stays at "clone and pivot".
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Modules.Config.Assets)

local AssetService = {}

local cache: { [string]: Model } = {}
local failed: { [string]: boolean } = {}
local library: Folder

--[[
	Make an uploaded model safe to scatter.

	Anchoring is the load-bearing one. The world is built at a fixed terrain
	height and never simulated; a single unanchored part in a downloaded model
	falls forever and takes its welded neighbours with it.
]]
local function prepare(model: Model, spec: Assets.AssetSpec)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = spec.collide == true
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("BaseScript") then
			-- Free models are a well known way to import somebody else's code.
			descendant:Destroy()
		end
	end

	local scale = spec.scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
end

--[[
	LoadAsset returns a container Model holding the actual asset. For a single
	model that container is one level of indirection worth removing; for a pack
	it IS the thing, because its children are the point.
]]
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

local function load(key: string, spec: Assets.AssetSpec)
	local ok, result = pcall(function()
		return InsertService:LoadAsset(spec.id)
	end)

	if not ok or typeof(result) ~= "Instance" then
		failed[key] = true
		warn(
			`[AssetService] could not load "{key}" (id {spec.id}): {result}. `
				.. `Falling back to the procedural version. The id must be public or owned by this place's owner.`
		)
		return
	end

	local container = result :: Model
	local model = unwrap(container, spec)
	if not model then
		failed[key] = true
		container:Destroy()
		warn(`[AssetService] asset "{key}" (id {spec.id}) loaded but contained no model.`)
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

--[[
	A clone of `key`, or nil if it is blank, failed, or has not arrived yet.

	Nil is a normal answer. Callers are expected to have a fallback, not to
	treat this as an error path.
]]
function AssetService.clone(key: string): Model?
	local model = cache[key]
	if not model then
		return nil
	end
	return model:Clone()
end

--[[
	A clone of one random child of a pack, or nil.

	Chosen by index rather than by name because the contents of a downloaded
	pack are not known to this repo, and hardcoding child names would reproduce
	the guessed-id problem one level down.
]]
function AssetService.clonePackItem(key: string, rng: Random?): Model?
	local pack = cache[key]
	if not pack then
		return nil
	end

	local children = pack:GetChildren()
	if #children == 0 then
		return nil
	end

	local index = if rng then rng:NextInteger(1, #children) else math.random(1, #children)
	local pick = children[index]
	if not pick:IsA("Model") and not pick:IsA("BasePart") then
		return nil
	end
	return pick:Clone() :: any
end

function AssetService.isReady(key: string): boolean
	return cache[key] ~= nil
end

--[[
	Place a loaded model in the world.

	Uploaded models have no shared convention for where their origin sits, so
	this pivots by the model's own bounding box and lifts it to stand ON the
	given Y rather than centred through it, which is what every caller means.
]]
function AssetService.place(model: Model, position: Vector3, rotationY: number?)
	local size = model:GetExtentsSize()
	local pivot = CFrame.new(position + Vector3.new(0, size.Y / 2, 0))
	if rotationY then
		pivot *= CFrame.Angles(0, rotationY, 0)
	end
	model:PivotTo(pivot)
end

function AssetService.init()
	library = Instance.new("Folder")
	library.Name = "AssetLibrary"
	library.Parent = ServerStorage

	local blank = Assets.blank()
	if #blank > 0 then
		warn(
			`[AssetService] no id set for: {table.concat(blank, ", ")}. `
				.. `These use their procedural fallback. Add ids in Config/Assets.lua.`
		)
	end

	--[[
		Loaded in parallel and off the boot path. World generation is already
		progressive (Town synchronously, the rest on a background task), so
		blocking boot on a handful of web calls would delay the one area the
		player can actually reach. Anything that arrives late simply starts
		being used by the props built after it.
	]]
	for _, key in Assets.configured() do
		local spec = Assets.get(key)
		if spec then
			task.spawn(load, key, spec)
		end
	end
end

return AssetService

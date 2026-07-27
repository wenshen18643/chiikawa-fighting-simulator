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
-- Pack key -> its props, flattened once at load rather than re-walked per pick.
local packItems: { [string]: { Instance } } = {}
-- key -> the reason it failed, kept for the single consolidated report.
local failed: { [string]: string } = {}
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
		elseif descendant:IsA("LuaSourceContainer") then
			--[[
				Free models are a well known way to import somebody else's code.

				LuaSourceContainer, not BaseScript: BaseScript covers Script and
				LocalScript but NOT ModuleScript, and the require-backdoors found
				in this project's own character models kept their payload id on a
				ModuleScript. A module cannot start itself, so one left behind is
				inert -- but only for as long as nothing requires it, which is a
				property of the OTHER instances present rather than of the module.
				Take both and the question does not arise.
			]]
			descendant:Destroy()
		end
	end

	local scale = spec.scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
end

--[[
	Every prop inside a pack, at any depth.

	Packs are not laid out to a convention. This one arrives as
	LoadAsset container -> Folder "Nature Asset Pack - Studs Style" -> ...,
	and the next one may sort its contents into Trees/Bushes/Grass subfolders.
	Two earlier attempts at this both failed on the real file: taking the
	container's direct children handed out the entire pack as one prop, and
	descending a fixed number of wrapper levels stopped at a Folder and was
	then discarded for not being a Model.

	So: recurse through FOLDERS, and stop at the first Model or BasePart. That
	is the prop. Not descending into Models is the important half — otherwise a
	tree would be collected as a trunk, a canopy and four branches.
]]
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

--[[
	LoadAsset returns a container Model holding the actual asset. For a single
	model that is one level of indirection worth removing. For a pack the
	container is kept as-is and `collectItems` finds the props inside it,
	whatever shape the author left them in.
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

--[[
	Resolve a template out of ReplicatedStorage.Assets.Models.

	Returns a CLONE wrapped to look like what LoadAsset hands back -- a
	container holding the thing -- so the unwrap/prepare path below stays
	identical for local and fetched assets. The alternative was branching every
	step after this, for no gain.
]]
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

	--[[
		For a pack, say what arrived. What is inside a downloaded pack is not
		knowable from this repo, and "the nature props look wrong" is impossible
		to act on without knowing whether it holds 40 rocks or one 600-stud
		diorama. Printed once, at load.
	]]
	if spec.kind == "pack" then
		--[[
			Flatten once, then report every prop with its class and size. The
			names drive the substring filters in Areas/Area.lua ("tree", "bush",
			"grass"), and the sizes say whether anything will trip the size
			guard there. Neither is answerable from outside the running game,
			and getting this listing wrong is what hid two separate unwrapping
			bugs.
		]]
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
	A clone of one child of a pack, or nil.

	`match` is a case-insensitive substring of the child's name — "tree",
	"bush", "grass". The nature pack is titled "Trees Bush Grass Flower", so
	asking for the right kind of thing beats picking at random: a tree helper
	that returned a random flower would be worse than the procedural tree.

	Matching is deliberately loose and degrades in two steps: no child matches
	the filter -> any child; no children at all -> nil, and the caller's
	procedural fallback takes over. Exact child names are not known to this
	repo, so nothing here depends on guessing one (the startup print reports
	what actually arrived).
]]
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

	--[[
		Always hand back a Model.

		A pack may store a prop as a bare BasePart, but every caller places what
		it gets with GetExtentsSize/ScaleTo/PivotTo — Model methods that a Part
		does not have. Wrapping the odd loose part here means callers get one
		contract instead of two, and none of them need a type check.
	]]
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

--[[
	Block briefly for one asset.

	Loads are deliberately off the boot path, which is right for scenery
	scattered across six areas nobody has reached yet — but wrong for the
	cottage garden, which is built synchronously during boot and is the first
	thing every player looks at. Without this it would always lose the race and
	always draw its fallback.

	Bounded, and returns false rather than throwing on timeout, so a slow or
	failed load costs the nicer garden and not the boot.
]]
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

--[[
	One line describing what a loaded model actually is.

	"It loads" and "it is usable" are different questions, and the second one is
	only answerable inside a running server: a rig with a Humanoid needs
	different handling from a prop, extents decide whether `scale` is wrong by a
	factor of ten, and a non-zero script count would mean `prepare` had missed
	something and somebody else's code is in the place.
]]
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

	--[[
		Loaded in parallel and off the boot path. World generation is already
		progressive (Town synchronously, the rest on a background task), so
		blocking boot on a handful of web calls would delay the one area the
		player can actually reach. Anything that arrives late simply starts
		being used by the props built after it.
	]]
	local configured = Assets.configured()
	local pending = #configured

	for _, key in configured do
		local spec = Assets.get(key)
		if spec then
			task.spawn(function()
				load(key, spec)
				pending -= 1
			end)
		end
	end

	--[[
		ONE report, once, after the loads settle.

		Per-asset warnings meant a boot with four unauthorized ids printed four
		near-identical paragraphs, which buries the lines around them — and the
		lines around them are the world-generation timings somebody is usually
		reading the log for. The information is the same; it is one line now.
	]]
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
				-- Called out separately because these cannot fail the way the
				-- fetched ones can, so a reader chasing a load failure can rule
				-- them out without cross-referencing Config/Assets.lua.
				.. (
					if #fromRepo > 0 then `. Served locally from assets/Models/: {table.concat(fromRepo, ", ")}` else ""
				)
		)

		if #broken > 0 then
			warn(
				`[AssetService] using the procedural fallback for {#broken} model(s): {table.concat(broken, "; ")}. `
					.. `"not authorized" means the id is a PRIVATE model owned by another account -- `
					.. `InsertService cannot fetch those no matter what is in Config/Assets.lua. `
					.. `Re-upload it to this place's owner, or use a genuinely free model, then swap the id.`
			)
		end
	end)
end

return AssetService

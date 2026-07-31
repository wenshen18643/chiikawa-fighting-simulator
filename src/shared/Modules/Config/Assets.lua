--[[
	Where the world's models come from: local templates under assets/Models/
	for the character rigs, uploaded ids for the decor. This file is the list --
	docs/ASSETS.md used to mirror it for humans and no longer exists.

	--------------------------------------------------------------------------
	WHY THESE ARE OPTIONAL
	--------------------------------------------------------------------------

	Everything here has a procedural fallback in Areas/Area.lua. An id that is
	0, or that fails to load, costs nothing but the nicer model: the world still
	builds, in the same places, out of parts. That is deliberate — this project
	greyboxes from Config and a missing upload must never be the difference
	between a world and a hole in the ground.

	A blank id is therefore a valid state, not a bug. AssetService lists them at
	startup so they are discoverable rather than mysterious.

	--------------------------------------------------------------------------
	WHAT LOADS AND WHAT DOES NOT
	--------------------------------------------------------------------------

	InsertService:LoadAsset only succeeds for assets that are free/public OR
	owned by the account that owns the place. A private model belonging to
	somebody else fails no matter what the id says, and it fails at runtime on a
	live server rather than at build time — which is why every load is pcall'd
	and every failure is a warning plus a fallback, never an error.

	`kind` tells AssetService what it is holding:
		"model"  a single thing. Cloned as-is.
		"pack"   a container of many things. Cloned one random child at a time,
		         chosen by name at runtime, because nobody here knows what is
		         inside a given pack and guessing child names is the same
		         mistake as guessing ids.

	--------------------------------------------------------------------------
	LOCAL TEMPLATES BEAT IDS
	--------------------------------------------------------------------------

	A spec with `template` set is resolved from ReplicatedStorage.Assets.Models
	-- committed to this repo under assets/Models/ -- instead of being fetched
	over the network. Everything above stops applying to it: no web call, no
	"not authorized", no dependency on an uploader who can delete or edit the
	model out from under the game, and no per-server load latency.

	Prefer it. An `id` is what you use before somebody has done the work of
	pulling the model into the repo; a `template` is what you use afterwards.
	When both are present the template wins and the id is kept only as a note
	of where the geometry originally came from.
]]

local Assets = {}

export type AssetSpec = {
	id: number,
	kind: string,
	--[[
		Name of a child of ReplicatedStorage.Assets.Models, committed under
		assets/Models/ in this repo. Set it and the id is never fetched.
	]]
	template: string?,
	-- Multiplied onto the model after load. Uploaded models arrive at whatever
	-- scale their author chose, which is rarely this world's scale.
	scale: number?,
	--[[
		Whether the model is solid. DEFAULTS TO TRUE.

		It used to default to false, on the reasoning that scenery is cheaper
		without collision geometry. That is true and it was still the wrong
		default: a plot of props you walk through is a painting of a plot. If a
		thing is standing in the world at a size you can see, you should be able
		to bump into it and stand on it.

		So the exceptions are now written down instead. Set false for foliage --
		anything made of hundreds of thin blades or leaves, where the collision
		hulls cost real frame time and the only thing they buy you is tripping
		over grass.
	]]
	collide: boolean?,
	--[[
		True for models that are mostly air: a tree is a wide canopy over a thin
		trunk, so its bounding box is a poor description of the ground it
		occupies.

		Only the lawn cares. It reserves ground under solid props so grass does
		not grow up through a shop floor, and a 54-stud sakura would clear a
		54-stud circle of the lawn it is supposed to be standing in.
	]]
	canopy: boolean?,
	--[[
		Case-insensitive substrings. A pack child whose name contains any of
		them is not a prop and is dropped at load.

		Needed because packs ship their authoring tools alongside their content:
		this one includes "GrassWandSquare" and "GrassWandCylinder", 8-stud
		blocks meant to be dragged around in Studio to paint grass. They match a
		"grass" filter perfectly and are the wrong shape by a factor of eight.
	]]
	exclude: { string }?,
}

--[[
	----------------------------------------------------------------------------
	A NOTE ON `collide = false` BELOW
	----------------------------------------------------------------------------

	Every row down to `naturePack` is world scatter: Areas/Area.lua spreads these
	across six islands, hundreds at a time. They are pinned non-colliding
	deliberately, so flipping the default did not silently make six islands'
	worth of foliage solid and did not change how any area already plays.

	The safe zone's own props further down take the new default and are solid.
	If world scatter should become solid too, that is a separate decision about
	six areas, taken with their part counts in front of you -- not a side effect
	of dressing one garden.
]]
Assets.MODELS = {
	-- Still blank in docs/ASSETS.md. These fall back to their procedural
	-- versions; wiring is in place, so filling an id in here is the only step.
	tree = { id = 0, kind = "model", scale = 1, collide = false, canopy = true },
	grass = { id = 0, kind = "model", scale = 1, collide = false },
	stone = { id = 0, kind = "model", scale = 1, collide = false },

	log = { id = 9731248486, kind = "model", scale = 1, collide = false },
	bush = { id = 11337757315, kind = "model", scale = 1, collide = false },
	house = { id = 136868946197723, kind = "model", scale = 1, collide = true },
	terrain = { id = 97974769788038, kind = "model", scale = 1, collide = false },
	-- Replaced 71032774784968, which was private to another account and always
	-- failed with "User is not authorized to access Asset".
	--[[
		"Nature Pack Studs Trees Bush Grass Flower". Public domain, so unlike the
		four above it actually loads. Contents, as reported at startup:
		Tree 1/2/Tree, Bush 1/2, Grass 1-3, Flower 1-3, Rock 1-5, Mushroom 1/2,
		plus the two grass-painting wands excluded below.
	]]
	naturePack = { id = 82060619904561, kind = "pack", scale = 1, collide = false, exclude = { "wand" } },

	--[[
		----------------------------------------------------------------------
		CHARACTER RIGS -- the companion roster
		----------------------------------------------------------------------

		ALL THREE ARE LOCAL NOW. Each lives under assets/Models/ and is resolved
		by `template`, so the roster makes no web call at all: no "not
		authorized", no moderation risk, and no uploader who can edit the
		character out from under the game.

		They came out of the toolbox, and every one of them arrived carrying a
		require-backdoor. The pattern, twice, from two different uploaders:
		stash a Roblox asset id somewhere nobody reads -- a NumberPose's Value
		on chiikawa, a ModuleScript ATTRIBUTE on the other two -- then
		`require()` that number at runtime, which downloads and executes
		whatever its owner currently has published. Usagi additionally shipped a
		ScreenGui with a TextBox and buttons nested inside a LocalScript, which
		is what a command bar looks like. Every script was stripped before
		these were committed; the geometry is untouched.

		Do not take prepare() below as covering this. It deletes BaseScript,
		which is Script and LocalScript -- NOT ModuleScript. The backdoor's
		payload holder on two of these models was a ModuleScript and would have
		survived. It is inert with no Script left to require it, but "inert
		because the other half was removed" is not a defence worth relying on.

		They need no new `kind`. CompanionService unanchors its own clones --
		prepare() anchoring everything is right for decor and wrong for a pet --
		and normalises their height, so the authored scale below stays 1 and the
		size the author happened to export at does not matter.

		Sizes are worth watching: usagi is by far the heaviest at 70 parts and
		67 meshes, against chiikawa's 8 and hachiware's single MeshPart. One per
		player is fine; if companions ever become a crowd, usagi is the row to
		reconsider first.
	]]
	--[[
		Originally 126588941317056, "🌠 [New!] killer hachiware - chiikawa" by
		FeBypassguy9 -- a "killer" NPC whose scripts existed to damage whoever
		stood next to it, on top of the backdoor. 1 MeshPart, 1 Decal, a
		Humanoid and 5 Motor6Ds survive; the 9 Animations went with the Animate
		script that owned them, which costs nothing here because rig() deletes
		the Humanoid anyway and a companion never plays them.
	]]
	hachiware = { id = 126588941317056, kind = "model", template = "Hachiware", scale = 1 },
	--[[
		Originally 88154057398500, "🌠 [UPDATED] Chiikawa Thing" by FeBypassguy9.

		Titled "Chiikawa", reads as Usagi in game. Free models are named by
		whoever uploaded them and the titles here are not to be trusted over
		what is actually standing in front of you -- the key follows the model,
		not the title.
	]]
	usagi = { id = 88154057398500, kind = "model", template = "Usagi", scale = 1 },
	--[[
		LOCAL. Lives at assets/Models/Chiikawa.rbxmx, so this row makes no web
		call and cannot fail at runtime. 8 Parts, 8 SpecialMeshes, 1 Decal.

		It is a "model", not a "pack", because unlike the id it replaces this is
		exactly one character -- there is no shelf of plushies to pick a child
		out of, so CompanionService.rig can clone it directly.

		The id below is history, not a fallback: 103908480888538 ("🧸 Soft
		Plushie Roleplay Toy Bundle Collection Cut", XzVantalWBaconVzX154) was
		the pack this used to pull from, which itself replaced 136642940597969.
		Kept written down because knowing where geometry came from matters if it
		ever has to be re-sourced.

		Worth knowing why it is local: the toolbox copy shipped two scripts
		(`qPerfectionWeld`, `CoreSkyboxSystem`) that stashed an asset id in a
		NumberPose and `require`d it at runtime -- remote code execution owned by
		whoever controls that id, deliberately silent inside Studio. Both were
		stripped before the model was committed. prepare() below would have
		deleted them anyway, but that defence only ever fires for assets that go
		through AssetService, and it is not a reason to keep trusting the fetch.
	]]
	chiikawa = { id = 103908480888538, kind = "model", template = "Chiikawa", scale = 1 },

	-- Clean local geometry. MobService supplies the authoritative rig and AI.
	mushroomFrog = { id = 0, kind = "model", template = "MushroomFrog", scale = 1, collide = false },
	duck = { id = 0, kind = "model", template = "Duck", scale = 1, collide = false },
	wolf = { id = 0, kind = "model", template = "Wolf", scale = 1, collide = false },

	--[[
		----------------------------------------------------------------------
		SAFE ZONE -- the home plot dressing
		----------------------------------------------------------------------

		All local, all `template`, so none of them make a web call and the
		cottage cannot half-build because a download lost a race.

		Every one arrived from the toolbox and every one went through
		tools/model-hygiene before it was committed. Nine of them shipped
		scripts: four carried the same `require(<id parked in a NumberPose>)`
		backdoor documented above, and LaundryLine additionally shipped a
		ScreenGui holding a TextBox and two TextButtons nested under a
		LocalScript -- a command bar. All stripped; geometry untouched.

		`scale` stays 1 on every row. Nothing here is placed at its authored
		size: SafeZoneService sizes each prop to a target measured in studs
		(Config/SafeZone.lua), because a toolbox model's scale says only what
		its author was working at and these came from a dozen different authors.
	]]
	-- Canopy: grass grows under a tree, so the lawn ignores its footprint.
	sakuraTree = { id = 0, kind = "model", template = "SakuraTree", scale = 1, canopy = true },
	--[[
		The lawn, and the one prop here that stays walk-through. It is 105 unions
		of blade, laid on a grid across the whole plot -- solid, that is thousands
		of collision hulls whose only effect is that you trip on grass.
	]]
	grassPatch = { id = 0, kind = "model", template = "GrassPatch", scale = 1, collide = false },
	friendStand = { id = 0, kind = "model", template = "FriendStand", scale = 1 },
	strawberryDoor = { id = 0, kind = "model", template = "StrawberryDoor", scale = 1 },
	lantern = { id = 0, kind = "model", template = "Lantern", scale = 1 },
	lanternTall = { id = 0, kind = "model", template = "LanternTall", scale = 1 },
	mailBox = { id = 0, kind = "model", template = "MailBox", scale = 1 },
	laundryLine = { id = 0, kind = "model", template = "LaundryLine", scale = 1 },
	wateringCan = { id = 0, kind = "model", template = "WateringCan", scale = 1 },
	picnicTable = { id = 0, kind = "model", template = "PicnicTable", scale = 1 },
	lowTable = { id = 0, kind = "model", template = "LowTable", scale = 1 },
	tableCloth = { id = 0, kind = "model", template = "TableCloth", scale = 1 },
	floorCushion = { id = 0, kind = "model", template = "FloorCushion", scale = 1 },
	kettle = { id = 0, kind = "model", template = "Kettle", scale = 1 },
	teaPot = { id = 0, kind = "model", template = "TeaPot", scale = 1 },
	teaCup = { id = 0, kind = "model", template = "TeaCup", scale = 1 },

	-- The three market buildings. Solid, because a shop you can walk through
	-- reads as a poster of a shop.
	shopBlue = { id = 0, kind = "model", template = "ShopBlue", scale = 1 },
	shopRed = { id = 0, kind = "model", template = "ShopRed", scale = 1 },
	shopStall = { id = 0, kind = "model", template = "ShopStall", scale = 1 },

	--[[
		The town proper: three houses, flower beds, a bench and a bridge. Placed
		by height from the area file rather than by a scale here, so "a house is
		18 studs tall" is a decision about the scene.

		The fountain stays declared but is placed nowhere: it used to sit on the
		plaza centre, which is the doorstep the player spawns on.

		FlowerBed1 arrived from the toolbox carrying the same require-an-
		attribute backdoor as the three character models (id 129781504223456,
		parked on a ModuleScript attribute). It was quarantined and stripped
		before being committed. See docs/how_to_load_models.md.
	]]
	house1 = { id = 0, kind = "model", template = "House1", scale = 1 },
	house2 = { id = 0, kind = "model", template = "House2", scale = 1 },
	house3 = { id = 0, kind = "model", template = "House3", scale = 1 },
	fountain = { id = 0, kind = "model", template = "Fountain", scale = 1 },
	flowerBed1 = { id = 0, kind = "model", template = "FlowerBed1", scale = 1, collide = false },
	flowerBed2 = { id = 0, kind = "model", template = "FlowerBed2", scale = 1, collide = false },
	flowerBed3 = { id = 0, kind = "model", template = "FlowerBed3", scale = 1, collide = false },
	pinkBench = { id = 0, kind = "model", template = "PinkBench", scale = 1 },
	bridge = { id = 0, kind = "model", template = "Bridge", scale = 1 },

	--[[
		Food. Deliberately built oversized -- see SafeZone.FOOD. A bowl of ramen
		taller than the character eating it is the single most recognisable
		visual joke in the source material, and it only lands if the food is
		scaled against the CHARACTER rather than against the table.
	]]
	ramen = { id = 0, kind = "model", template = "Ramen", scale = 1 },
	onigiri = { id = 0, kind = "model", template = "Onigiri", scale = 1 },
	dango = { id = 0, kind = "model", template = "Dango", scale = 1 },
	dangoPlatter = { id = 0, kind = "model", template = "DangoPlatter", scale = 1 },
	pancakes = { id = 0, kind = "model", template = "Pancakes", scale = 1 },
	yogurtBerry = { id = 0, kind = "model", template = "YogurtBerry", scale = 1 },
	--[[
		The yogurt gag: §the house was won in a lottery run by a yogurt
		conglomerate, so a tub of it on the doorstep is the deed to the building.
	]]
	yogurtVanilla = { id = 0, kind = "model", template = "YogurtVanilla", scale = 1 },

	--[[
		The Yoroi-san pair. `yoroiKnight` is a legacy R6 rig -- Torso, Head, four
		limbs, joined by `Motor` and `Snap`, which are the pre-Motor6D joint
		classes and are NOT animatable. SafeZoneService.rigYoroi converts them
		and hangs a root joint off an invisible HumanoidRootPart, after which the
		ordinary Anim/Machine drives it like any companion.

		`yoroiBeast` is the four-legged one and is welded solid, so it is set
		dressing rather than a rig.
	]]
	yoroiKnight = { id = 0, kind = "model", template = "YoroiKnight", scale = 1 },
	yoroiBeast = { id = 0, kind = "model", template = "YoroiBeast", scale = 1 },

	--[[
		----------------------------------------------------------------------
		FORAGE & KITCHEN -- interactive nodes and the cooking station
		----------------------------------------------------------------------

		All local templates. These are props the player walks up to and works,
		not scatter: the bushes, mushrooms, sausage trees and vegetables are
		forage nodes that regrow after a pluck (Config/Ingredients.lua), and the
		CookingPot is the kitchen station (Config/Recipes.lua).

		Bushes, mushrooms and the vegetables stay walk-through. They are thin
		foliage at ground level, and solid hulls there cost real frame time only
		to trip the player over a carrot. The sausage trees and the pot are
		solid -- a tree you walk through reads as a painting of a tree.
	]]
	blackBerryBush = { id = 0, kind = "model", template = "BlackBerryBush", scale = 1, collide = false },
	blueBerryBush = { id = 0, kind = "model", template = "BlueBerryBush", scale = 1, collide = false },
	whiteBerryBush = { id = 0, kind = "model", template = "WhiteBerryBush", scale = 1, collide = false },
	purpleBerryBush = { id = 0, kind = "model", template = "PurpleBerryBush", scale = 1, collide = false },
	brownMushroom = { id = 0, kind = "model", template = "BrownMushroom", scale = 1, collide = false },
	whiteMushroom = { id = 0, kind = "model", template = "WhiteMushroom", scale = 1, collide = false },
	pinkSausageTree = { id = 0, kind = "model", template = "PinkSausageTree", scale = 1, collide = true },
	yellowSausageTree = { id = 0, kind = "model", template = "YellowSausageTree", scale = 1, collide = true },
	riceCookerSprout = { id = 0, kind = "model", template = "RiceCookerSprout", scale = 1, collide = false },
	carrot = { id = 0, kind = "model", template = "Carrot", scale = 1, collide = false },
	potato = { id = 0, kind = "model", template = "Potato", scale = 1, collide = false },
	cookingPot = { id = 0, kind = "model", template = "CookingPot", scale = 1, collide = true },
} :: { [string]: AssetSpec }

function Assets.get(key: string): AssetSpec?
	return Assets.MODELS[key]
end

-- Whether a spec resolves at all: from the repo, or failing that, from an id.
local function isResolvable(spec: AssetSpec): boolean
	return spec.template ~= nil or (spec.id ~= nil and spec.id > 0)
end

-- Keys worth attempting a load for, whether local or uploaded.
function Assets.configured(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if isResolvable(spec) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

-- Keys still waiting on an id, for the startup report.
function Assets.blank(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if not isResolvable(spec) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

-- Keys served from assets/Models/ rather than fetched, for the startup report.
function Assets.local_(): { string }
	local keys = {}
	for key, spec in Assets.MODELS do
		if spec.template then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

return Assets

--[[
	Makes each skill look like itself.

	Four skills that all resolve to "click, number goes up" are one skill wearing
	four colours. A weed gets yanked, a fork comes down, a page turns — the
	gesture is what separates them, and it costs one table row per skill
	(Config/PlayerAnims) rather than an art budget.

	--------------------------------------------------------------------------
	NO UPLOADED ASSETS
	--------------------------------------------------------------------------

	A Roblox animation normally means an uploaded Animation instance and an asset
	id. This drives the body joints directly from keyframes in config instead,
	which keeps the same promise the rest of the project makes: icons are
	geometry (UI/Glyphs), characters are parts (NpcService), and none of it can
	break because an upload went missing or was moderated.

	It also makes the gestures recolourable, retimeable and diffable, which an
	uploaded animation is not.

	--------------------------------------------------------------------------
	HOW THIS COOPERATES WITH THE DEFAULT ANIMATE SCRIPT
	--------------------------------------------------------------------------

	The Animator writes joint `Transform` every frame. So does this. The trick is
	ordering and blending, not ownership:

	  * Motor6D rigs are written on BindToRenderStep at Character + 1, which is
	    after the legacy animation step has posed the frame.
	  * AnimationConstraint rigs (the Avatar Joint Upgrade default for R15
	    players) are written on PreSimulation instead. Their Transforms are
	    collected in a batch job that runs after PreSimulation and before physics,
	    and the Animator refills them between PreAnimation and PreSimulation --
	    so a render-step write on those rigs is discarded before it is ever read.
	  * Either way we read what the Animator just wrote and LERP from it toward
	    the gesture pose by a weight that ramps 0 -> 1 -> 0.

	At weight 0 the arm is exactly the walk cycle; at weight 1 it is exactly the
	gesture; in between it is a real blend. When a gesture ends we stop writing
	and the Animator's pose is already what is on screen, so there is nothing to
	restore and nothing to pop.

	This replaces an older approach that faded the Animator's tracks out with
	AdjustWeight(0) on every click and back in afterwards. At click speed that
	was a cross-fade starting several times a second, which is most of what
	"the animations are not smooth" was.

	--------------------------------------------------------------------------
	WHY THE WHOLE BODY
	--------------------------------------------------------------------------

	An earlier version drove the arms alone, which is why every gesture read as
	stiff: a swing with no waist behind it and no weight on the legs is a stick
	on a pivot. Clips now key the waist, neck, hips and knees as well, masked
	low on the legs so the walk cycle still shows through underneath.

	Clips are authored once in the character's own root frame and mapped onto
	each rig's real joint axes, so the same data drives R15 and R6. A joint a
	rig does not have is simply skipped -- R6 loses the elbows, wrists, waist
	and knees, and keeps the rest.

	--------------------------------------------------------------------------
	LOCAL vs. REMOTE
	--------------------------------------------------------------------------

	The local player gets a crisp gesture per click, fired from WorkController
	before the server has answered, because waiting for a round trip is what
	makes a click feel dead.

	Other players get a looping version driven by a character attribute the
	server sets while they are working. That is deliberate: replicating a
	gesture per click per player would be a remote storm to animate something
	nobody is looking at closely.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clip = require(Shared.Modules.Anim.Clip)
local Feedback = require(Shared.Modules.Config.Feedback)
local PlayerAnims = require(Shared.Modules.Config.PlayerAnims)
local Skeleton = require(Shared.Modules.Anim.Skeleton)

local WorkController = require(script.Parent.WorkController)

local GestureController = {}

-- Set by the server on a working character; drives the looping remote version.
local WORKING_ATTRIBUTE = "WorkingSkill"
-- Set by the server per forage pluck: ForageClipAt (an os.clock stamp) changing
-- fires the clip named in ForageClip once, rather than looping it.
local FORAGE_CLIP_ATTRIBUTE = "ForageClip"
local FORAGE_STAMP_ATTRIBUTE = "ForageClipAt"
-- Held true by the server while a character stirs at the kitchen.
local COOKING_ATTRIBUTE = "Cooking"
local COOKING_CLIP = "cook_stir"

-- Weight envelope, in seconds. Short enough to feel immediate, long enough that
-- neither end of a gesture is a step change.
local BLEND_IN = 0.07
local BLEND_OUT = 0.13

-- How long to wait for a character's joints before saying so. The watcher stays
-- live past this, so it is a reporting deadline and not a give-up.
local BIND_TIMEOUT = 15

--[[
	Book prop timing, in seconds and independent of the gesture clock.

	The book used to open and shut once per click, which at click speed is a
	trapdoor rather than a book. It now opens when studying starts, STAYS open for
	as long as clicks keep arriving, turns one page per click, and only closes
	once the player has stopped.
]]
local BOOK_OPEN_TIME = 0.28
local BOOK_CLOSE_TIME = 0.4
local BOOK_HOLD = 1.1
local BOOK_FLIP_TIME = 0.22

local SASUMATA_SKILLS = { tobatsu = true, subjugation = true, strength = true }
local BOOK_SKILLS = { examprep = true, special = true, craft = true }
local KUSATORI_SKILLS = { kusatori = true, weeding = true, agility = true }

local PROP_NAMES = { "EquippedSasumata", "EquippedOpenBook", "EquippedWeedTuft" }

local TUFT_SHOW_T = 0.55
local TUFT_HIDE_T = 0.98

type Rig = {
	joints: Skeleton.Joints,
	basis: { [string]: CFrame },
	inverse: { [string]: CFrame },
	animator: Animator?,
}

type Playing = {
	skillId: string,
	startedAt: number,
	duration: number,
}

type ForageShot = {
	clipId: string,
	startedAt: number,
	duration: number,
}

type BookState = {
	open: number,
	flipFrom: number,
	flipTo: number,
	flipAt: number,
	touchedAt: number,
}

local localRig: Rig? = nil
local localCharacter: Model? = nil
local playing: Playing? = nil

local remoteRigs: { [Model]: Rig } = {}
local remotePhase: { [Model]: number } = {}

local forageStamps: { [Model]: number? } = {}
local forageShots: { [Model]: ForageShot } = {}

local books: { [Model]: BookState } = {}
local tuftShown: { [Model]: boolean } = {}

local function bookState(character: Model): BookState
	local state = books[character]
	if not state then
		state = { open = 0, flipFrom = 0, flipTo = 0, flipAt = -math.huge, touchedAt = -math.huge }
		books[character] = state
	end
	return state
end

local function turnPage(character: Model, now: number)
	local state = bookState(character)
	state.touchedAt = now
	if now - state.flipAt >= BOOK_FLIP_TIME then
		state.flipFrom = state.flipTo
		state.flipTo = 1 - state.flipTo
		state.flipAt = now
	end
end

--------------------------------------------------------------------------------
-- Joints
--------------------------------------------------------------------------------

local function buildRig(character: Model): Rig?
	local joints = Skeleton.resolveCharacter(character)
	if not joints then
		return nil
	end
	if not joints.shoulderR and not joints.shoulderL then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	local basis, inverse = Skeleton.basisFor(character, joints, root)
	return { joints = joints, basis = basis, inverse = inverse, animator = animator }
end

--[[
	Bind as soon as the joints exist, whenever that turns out to be.

	Polling for five seconds and then giving up forever was wrong: joints can
	arrive much later than the character does -- an avatar still downloading, a
	HumanoidDescription swap rebuilding the rig, a body part streamed in late --
	and once the poll expired gestures stayed dead for the rest of the session.
	Watching DescendantAdded is what makes that self-heal.
]]
local function bindRig(character: Model, assign: (Rig) -> ())
	local bound = false

	local function attempt(): boolean
		if bound or character.Parent == nil then
			return bound
		end
		local rig = buildRig(character)
		if not rig then
			return false
		end
		bound = true
		assign(rig)
		return true
	end

	local watcher = character.DescendantAdded:Connect(function(descendant)
		if Skeleton.isJoint(descendant) or descendant:IsA("Attachment") then
			attempt()
		end
	end)

	task.spawn(function()
		local started = os.clock()
		while not bound and os.clock() - started < BIND_TIMEOUT do
			if character.Parent == nil then
				watcher:Disconnect()
				return
			end
			if attempt() then
				watcher:Disconnect()
				return
			end
			task.wait(0.25)
		end

		if bound then
			watcher:Disconnect()
			return
		end
		if character.Parent == nil then
			watcher:Disconnect()
			return
		end

		--[[
			Say exactly what the rig DOES have. "No animation" with a silent log
			is indistinguishable from a logic bug, and the usual cause is a rig
			shape this code does not expect rather than a timing miss -- the
			watcher above is still live, so a late rig will still bind.
		]]
		local found, bones = {}, {}
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("Motor6D") then
				table.insert(found, `Motor6D:{descendant.Name}`)
			elseif descendant:IsA("AnimationConstraint") then
				local wired = if descendant.Attachment0 and descendant.Attachment1 then "" else " (unwired)"
				table.insert(found, `AnimationConstraint:{descendant.Name}{wired}`)
			elseif descendant:IsA("Bone") then
				table.insert(bones, descendant.Name)
			end
		end

		warn(
			`[GestureController] no drivable joints in {character.Name} after {BIND_TIMEOUT}s. `
				.. `RigType={Skeleton.rigKind(character)}. `
				.. `Joints: {if #found > 0 then table.concat(found, ", ") else "none"}. `
				.. `Bones: {if #bones > 0 then table.concat(bones, ", ") else "none"}. `
				.. `Still watching for joints to appear.`
		)
	end)
end

--------------------------------------------------------------------------------
-- Applying a clip
--------------------------------------------------------------------------------

local function smoothstep(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local scratch: Clip.Pose = {}

--[[
	Blend a clip pose onto whatever the Animator wrote this frame.

	`joint.Transform` is read, not assumed: at this point in the frame it holds
	the locomotion pose, so lerping from it is what makes weight mean "how much
	of this is the gesture". At weight 0 the joint is exactly the walk cycle.

	Rotations are authored in the character's own root frame and mapped onto the
	rig's real joint axes by `inverse * pose * basis`, so one clip drives R6 and
	R15 without the per-rig sign flips this used to need.

	`constraints` selects which half of a rig this pass owns. AnimationConstraints
	are only read pre-physics and Motor6Ds are only read post-animation-step, so
	the two are written from different events and each pass skips the other's
	joints rather than writing a value that will be thrown away.
]]
local function applyRig(rig: Rig, definition: any, t: number, weight: number, constraints: boolean)
	if rig.animator and rig.animator.EvaluationThrottled then
		return
	end

	table.clear(scratch)
	Clip.pose(definition, t, scratch)

	local mask = definition.mask

	for name, target in scratch do
		local motor = rig.joints[name]
		if motor and motor.Parent and motor:IsA("AnimationConstraint") == constraints then
			local jointWeight = weight
			if mask then
				jointWeight *= mask[name] or 1
			end

			if jointWeight > 0.001 then
				local inverse = rig.inverse[name]
				local final = if inverse then inverse * target * rig.basis[name] else target
				motor.Transform = motor.Transform:Lerp(final, math.min(jointWeight, 1))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Held props
--------------------------------------------------------------------------------

local function findHand(character: Model, side: string): BasePart?
	local exact = character:FindFirstChild(side .. "Hand") -- R15
	if exact and exact:IsA("BasePart") then
		return exact
	end
	local arm = character:FindFirstChild(side .. " Arm") -- R6
	if arm and arm:IsA("BasePart") then
		return arm
	end
	local upper = character:FindFirstChild(side .. "LowerArm")
	if upper and upper:IsA("BasePart") then
		return upper
	end
	return nil
end

local function decorate(part: BasePart, parent: Instance)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

--[[
	The Sasumata, built around a root at the identity CFrame so the whole model
	can be pivoted into the hand as one piece afterwards. Parts are welded to the
	shaft, and only then positioned, which is the order that makes the offsets in
	here mean what they say.
]]
local function buildSasumata(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "EquippedSasumata"

	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.22, 3.4, 0.22) * scale
	shaft.Color = Color3.fromRGB(126, 92, 62)
	shaft.Material = Enum.Material.Wood
	shaft.CFrame = CFrame.new()
	decorate(shaft, model)
	model.PrimaryPart = shaft

	local function attach(part: BasePart, offset: CFrame)
		part.CFrame = shaft.CFrame * offset
		decorate(part, model)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = shaft
		weld.Part1 = part
		weld.Parent = shaft
	end

	local bar = Instance.new("Part")
	bar.Name = "ForkBar"
	bar.Size = Vector3.new(1.25, 0.2, 0.2) * scale
	bar.Color = Color3.fromRGB(226, 232, 240)
	bar.Material = Enum.Material.Metal
	attach(bar, CFrame.new(0, 1.7 * scale, 0))

	for _, side in { -1, 1 } do
		local prong = Instance.new("Part")
		prong.Name = if side < 0 then "LeftProng" else "RightProng"
		prong.Size = Vector3.new(0.18, 1.15, 0.2) * scale
		prong.Color = Color3.fromRGB(226, 232, 240)
		prong.Material = Enum.Material.Metal
		attach(prong, CFrame.new(0.55 * side * scale, (1.7 + 0.62) * scale, 0))
	end

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.28, 0.7, 0.28) * scale
	grip.Color = Color3.fromRGB(72, 54, 40)
	grip.Material = Enum.Material.SmoothPlastic
	attach(grip, CFrame.new(0, -0.9 * scale, 0))

	return model
end

local function buildWeedTuft(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "EquippedWeedTuft"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.45, 0.35, 0.45) * scale
	root.Color = Color3.fromRGB(72, 54, 40)
	root.Material = Enum.Material.Ground
	root.CFrame = CFrame.new()
	decorate(root, model)
	model.PrimaryPart = root

	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		local blade = Instance.new("Part")
		blade.Name = `Blade_{i}`
		blade.Size = Vector3.new(0.14, 1.1, 0.14) * scale
		blade.Color = if i % 2 == 0 then Color3.fromRGB(126, 190, 104) else Color3.fromRGB(96, 162, 78)
		blade.Material = Enum.Material.Grass
		blade.CFrame = root.CFrame
			* CFrame.new(math.cos(angle) * 0.14 * scale, 0.65 * scale, math.sin(angle) * 0.14 * scale)
			* CFrame.Angles(math.rad(14 * math.cos(angle)), 0, math.rad(14 * math.sin(angle)))
		decorate(blade, model)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = blade
		weld.Parent = root
	end

	return model
end

--[[
	The open book. Ruled lines are thin parts rather than a texture: the project
	does not commit guessed asset ids, and a page needs about six of them.

	EVERY MOVING PART IS WELDED, and the animation drives `Weld.C0` rather than
	`BasePart.CFrame`. That is not a style preference. Setting CFrame on an
	unanchored, unwelded part inside a Character means physics owns it the
	moment you stop writing to it every frame — so the covers fell out of the
	book the instant a gesture ended, and loose dynamic parts inside a character
	interfere with the Humanoid. Welded, they cannot fall, cannot fight physics,
	and cost nothing between gestures.
]]
local function weldTo(root: BasePart, part: BasePart, offset: CFrame): Weld
	local weld = Instance.new("Weld")
	weld.Name = "BookWeld"
	weld.Part0 = root
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	return weld
end

local function buildOpenBook(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "EquippedOpenBook"

	local spine = Instance.new("Part")
	spine.Name = "Spine"
	spine.Size = Vector3.new(0.12, 0.14, 1.4) * scale
	spine.Color = Color3.fromRGB(160, 40, 60)
	spine.Material = Enum.Material.SmoothPlastic
	spine.CFrame = CFrame.new()
	decorate(spine, model)
	model.PrimaryPart = spine

	local function page(name: string, cover: boolean): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Size = if cover then Vector3.new(1.0, 0.04, 1.4) * scale else Vector3.new(0.95, 0.06, 1.35) * scale
		part.Color = if cover then Color3.fromRGB(240, 90, 150) else Color3.fromRGB(252, 250, 242)
		part.Material = Enum.Material.SmoothPlastic
		decorate(part, model)
		return part
	end

	local coverRight = page("CoverRight", true)
	local coverLeft = page("CoverLeft", true)
	local rightPage = page("RightPage", false)
	local leftPage = page("LeftPage", false)

	local middlePage = Instance.new("Part")
	middlePage.Name = "MiddlePage"
	middlePage.Size = Vector3.new(0.94, 0.01, 1.34) * scale
	middlePage.Color = Color3.fromRGB(252, 250, 242)
	middlePage.Material = Enum.Material.SmoothPlastic
	decorate(middlePage, model)

	-- Welded to the spine at their closed-book offsets. animateBook rewrites
	-- these C0s; nothing here is ever positioned by CFrame again.
	weldTo(spine, coverRight, CFrame.new(0.5 * scale, -0.02 * scale, 0))
	weldTo(spine, coverLeft, CFrame.new(0, 0.04 * scale, 0) * CFrame.new(0.5 * scale, 0.02 * scale, 0))
	weldTo(spine, rightPage, CFrame.new(0.475 * scale, 0.015 * scale, 0))
	weldTo(spine, leftPage, CFrame.new(0, 0.04 * scale, 0) * CFrame.new(0.475 * scale, -0.02 * scale, 0))
	weldTo(spine, middlePage, CFrame.new(0, 0.04 * scale, 0) * CFrame.new(0.5 * scale, 0.03 * scale, 0))

	--[[
		Ruled lines hang off their page with a WeldConstraint, giving a chain of
		spine -> page -> rule. Moving the page's Weld.C0 carries them along, so
		the lines never need touching.
	]]
	for _, host in { rightPage, leftPage } do
		for line = 1, 5 do
			local rule = Instance.new("Part")
			rule.Name = "Rule"
			rule.Size = Vector3.new(0.62, 0.01, 0.05) * scale
			rule.Color = Color3.fromRGB(176, 186, 200)
			rule.Material = Enum.Material.SmoothPlastic
			rule.CFrame = host.CFrame * CFrame.new(0, 0.04 * scale, (line - 3) * 0.2 * scale)
			decorate(rule, model)

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = host
			weld.Part1 = rule
			weld.Parent = host
		end
	end

	local ribbon = Instance.new("Part")
	ribbon.Name = "BookmarkRibbon"
	ribbon.Size = Vector3.new(0.06, 0.01, 0.6) * scale
	ribbon.Color = Color3.fromRGB(255, 215, 0)
	ribbon.Material = Enum.Material.SmoothPlastic
	decorate(ribbon, model)
	weldTo(spine, ribbon, CFrame.new(0, -0.05 * scale, 0.7 * scale))

	model:SetAttribute("Scale", scale)
	return model
end

--[[
	Pose the book's covers. Driven every frame rather than welded, because the
	open/close IS the animation -- there is no rigid transform that reads as
	"reading a book".
]]
local function bookWeld(book: Instance, partName: string): Weld?
	local part = book:FindFirstChild(partName)
	return part and part:FindFirstChild("BookWeld") :: Weld? or nil
end

local function animateBook(character: Model, openAmount: number, flipAmount: number)
	local book = character:FindFirstChild("EquippedOpenBook")
	if not book then
		return
	end

	local coverLeft = bookWeld(book, "CoverLeft")
	local coverRight = bookWeld(book, "CoverRight")
	local leftPage = bookWeld(book, "LeftPage")
	local rightPage = bookWeld(book, "RightPage")
	local middlePage = bookWeld(book, "MiddlePage")
	if not (coverLeft and coverRight and leftPage and rightPage) then
		return
	end

	local scale = book:GetAttribute("Scale") or 1
	local open = smoothstep(openAmount)

	-- All offsets are relative to the spine, which is the welded root, so these
	-- compose exactly as the old world-space CFrame chain did.
	local rightAngle = math.rad(-15 * open)
	local rightCover = CFrame.Angles(0, 0, rightAngle) * CFrame.new(0.5 * scale, -0.02 * scale, 0)
	coverRight.C0 = rightCover
	rightPage.C0 = rightCover * CFrame.new(-0.025 * scale, 0.035 * scale, 0)

	local hinge = CFrame.new(0, 0.04 * scale, 0)
	local leftAngle = math.rad(145 * open)
	local leftCover = hinge * CFrame.Angles(0, 0, leftAngle) * CFrame.new(0.5 * scale, 0.02 * scale, 0)
	coverLeft.C0 = leftCover
	leftPage.C0 = leftCover * CFrame.new(-0.025 * scale, -0.04 * scale, 0)

	if middlePage then
		local midAngle = rightAngle + (leftAngle - rightAngle) * math.clamp(flipAmount, 0, 1)
		middlePage.C0 = hinge * CFrame.Angles(0, 0, midAngle) * CFrame.new(0.5 * scale, 0.03 * scale, 0)
	end
end

--[[
	Advance the book toward open-while-studying and run whichever page turn is in
	flight, then draw it. Returns nothing; the state lives in `books` so a book
	that has been left alone still closes on its own.
]]
local function stepBook(character: Model, dt: number, wanted: boolean)
	if not character:FindFirstChild("EquippedOpenBook") then
		return
	end

	local state = bookState(character)
	local now = os.clock()
	if wanted then
		state.touchedAt = now
	end

	local target = if now - state.touchedAt < BOOK_HOLD then 1 else 0
	local rate = if target > state.open then dt / BOOK_OPEN_TIME else dt / BOOK_CLOSE_TIME
	state.open += math.clamp(target - state.open, -rate, rate)

	local flip = state.flipTo
	local since = now - state.flipAt
	if since < BOOK_FLIP_TIME then
		flip = state.flipFrom + (state.flipTo - state.flipFrom) * smoothstep(since / BOOK_FLIP_TIME)
	end

	animateBook(character, state.open, flip)
end


local function removeProps(character: Model)
	for _, name in PROP_NAMES do
		local prop = character:FindFirstChild(name)
		if prop then
			prop:Destroy()
		end
	end
	tuftShown[character] = nil
end

local function setTuftVisible(character: Model, visible: boolean)
	if tuftShown[character] == visible then
		return
	end
	tuftShown[character] = visible

	local tuft = character:FindFirstChild("EquippedWeedTuft")
	if not tuft then
		return
	end
	for _, part in tuft:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
		end
	end
end

local function attachSkillProp(character: Model, skillId: string)
	local targetName: string? = nil
	if SASUMATA_SKILLS[skillId] then
		targetName = "EquippedSasumata"
	elseif BOOK_SKILLS[skillId] then
		targetName = "EquippedOpenBook"
	elseif KUSATORI_SKILLS[skillId] then
		targetName = "EquippedWeedTuft"
	end
	if not targetName then
		return
	end

	for _, name in PROP_NAMES do
		if name ~= targetName then
			local other = character:FindFirstChild(name)
			if other then
				other:Destroy()
			end
		end
	end

	--[[
		Every tool is one size now.

		It used to scale with the worksite tier being worked, so a tier-7 fork
		was visibly bigger than a tier-1 one. The pads that carried the tier are
		gone; the scale is kept as a value rather than inlined because the
		builders below take it, and a future upgrade tier can put a real number
		back here without touching them.
	]]
	local scale = 1
	if character:FindFirstChild(targetName) then
		return
	end

	local hand = findHand(character, "Right")
	if not hand then
		return
	end

	local model: Model
	local grip: CFrame
	if targetName == "EquippedSasumata" then
		model = buildSasumata(scale)
		grip = CFrame.new(0, -0.35, -0.3) * CFrame.Angles(math.rad(-100), 0, 0)
	elseif targetName == "EquippedOpenBook" then
		model = buildOpenBook(scale)
		grip = CFrame.new(0, -0.25, -0.45) * CFrame.Angles(math.rad(-70), math.rad(90), 0)
	else
		model = buildWeedTuft(scale)
		grip = CFrame.new(0, -0.3, -0.25) * CFrame.Angles(math.rad(-80), 0, 0)
	end

	model:SetAttribute("Scale", scale)
	model.Parent = character

	if targetName == "EquippedWeedTuft" then
		tuftShown[character] = false
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end
	end

	--[[
		A Weld with an explicit C0, not PivotTo plus a WeldConstraint. The
		constraint captures whatever offset happens to exist when it is created,
		which races the physics step that runs between the pivot and the weld.
		C0 states the grip outright and cannot drift.
	]]
	local weld = Instance.new("Weld")
	weld.Name = "GripWeld"
	weld.Part0 = hand
	weld.Part1 = model.PrimaryPart
	weld.C0 = grip
	weld.Parent = hand
end

--------------------------------------------------------------------------------
-- Local player
--------------------------------------------------------------------------------

--[[
	`duration` is the gap WorkController measured between the last two clicks,
	and the clip is fitted to it rather than played at its authored length.

	A clip that outruns the click rate always loses: kusatori's authored rip
	lands at 0.65s, so a player clicking twice a second restarted it before its
	one distinctive frame and only ever saw the crouch. Compressing it to the
	cadence is what makes every gesture reach its payoff between two clicks.
]]
function GestureController.play(skillId: string?, duration: number?)
	if not skillId then
		return
	end

	local definition = PlayerAnims.get(skillId)
	if not definition then
		warn(`[GestureController] no PlayerAnims clip for "{skillId}"; nothing to play`)
		return
	end

	local character = Players.LocalPlayer.Character
	if character then
		attachSkillProp(character, skillId)
		if BOOK_SKILLS[skillId] then
			turnPage(character, os.clock())
		end
	end

	-- Restarting mid-gesture is fine: BLEND_IN ramps from whatever is on screen,
	-- so there is no snap back to the first keyframe.
	playing = {
		skillId = skillId,
		startedAt = os.clock(),
		duration = math.max(duration or definition.length, 0.1),
	}
end

local function tuftPhase(skillId: string?, t: number): boolean
	return skillId ~= nil and KUSATORI_SKILLS[skillId] == true and t >= TUFT_SHOW_T and t <= TUFT_HIDE_T
end

local function stepLocalProps(dt: number)
	local character = localCharacter
	if not character then
		return
	end

	local visible = false
	if playing then
		local t = math.clamp((os.clock() - playing.startedAt) / playing.duration, 0, 1)
		visible = tuftPhase(playing.skillId, t)
	end
	setTuftVisible(character, visible)

	stepBook(character, dt, playing ~= nil and BOOK_SKILLS[playing.skillId] == true)
end

local function stepLocal(constraints: boolean)
	local rig = localRig
	if not rig or not playing then
		return
	end

	local definition = PlayerAnims.get(playing.skillId)
	if not definition then
		playing = nil
		return
	end

	local duration = playing.duration
	local elapsed = os.clock() - playing.startedAt
	local t = math.clamp(elapsed / duration, 0, 1)

	local weight: number
	if elapsed < duration then
		weight = smoothstep(elapsed / BLEND_IN)
	else
		-- Hold the final pose and fade our influence out, so the walk cycle
		-- takes the arm back rather than the arm being dropped into it.
		local releasing = elapsed - duration
		if releasing >= BLEND_OUT then
			playing = nil
			return
		end
		weight = smoothstep(1 - releasing / BLEND_OUT)
	end

	applyRig(rig, definition, t, weight, constraints)
end

--------------------------------------------------------------------------------
-- Other players
--------------------------------------------------------------------------------

local function stepRemoteProps(dt: number)
	for character in remoteRigs do
		if not character.Parent then
			continue
		end

		local skillId = character:GetAttribute(WORKING_ATTRIBUTE)
		local studying = type(skillId) == "string" and BOOK_SKILLS[skillId] == true

		if type(skillId) == "string" then
			attachSkillProp(character, skillId)

			if KUSATORI_SKILLS[skillId] then
				local phase = remotePhase[character] or 0
				local definition = PlayerAnims.get(skillId)
				local length = if definition then definition.length else 1
				setTuftVisible(character, tuftPhase(skillId, ((os.clock() + phase) % length) / length))
			else
				setTuftVisible(character, false)
			end
		end

		if studying then
			local phase = remotePhase[character] or 0
			local definition = PlayerAnims.get(skillId :: string)
			local length = if definition then definition.length else 1
			local turns = math.floor((os.clock() + phase) / length)
			local state = bookState(character)
			if state.flipTo ~= turns % 2 then
				turnPage(character, os.clock())
			end
		end

		stepBook(character, dt, studying)
	end
end

local function stepRemote(constraints: boolean)
	for character, rig in remoteRigs do
		if not character.Parent then
			remoteRigs[character] = nil
			remotePhase[character] = nil
			books[character] = nil
			tuftShown[character] = nil
			forageStamps[character] = nil
			forageShots[character] = nil
			continue
		end

		local phase = remotePhase[character] or 0

		-- The looping work gesture the server says this character is doing.
		local skillId = character:GetAttribute(WORKING_ATTRIBUTE)
		if type(skillId) == "string" then
			local definition = PlayerAnims.get(skillId)
			if definition then
				local t = ((os.clock() + phase) % definition.length) / definition.length
				applyRig(rig, definition, t, 1, constraints)
			end
		end

		-- Stirring cycles while the server holds Cooking = true; releasing the
		-- attribute simply stops the writes and the walk cycle takes back over.
		if character:GetAttribute(COOKING_ATTRIBUTE) == true then
			local definition = PlayerAnims.get(COOKING_CLIP)
			if definition then
				local t = ((os.clock() + phase) % definition.length) / definition.length
				applyRig(rig, definition, t, 1, constraints)
			end
		end

		--[[
			One shot per pluck. ForageClipAt is a stamp the server bumps every
			time; seeing a new one fires the clip named in ForageClip once, with
			the same blend envelope as a local gesture. Applied last so the pluck
			reads over any loop already running. The stamp is only consumed once
			the clip name is readable, so a stamp that replicates a frame ahead
			of its clip retries rather than dropping the pluck.
		]]
		local stamp = character:GetAttribute(FORAGE_STAMP_ATTRIBUTE)
		if type(stamp) == "number" and forageStamps[character] ~= stamp then
			local clipId = character:GetAttribute(FORAGE_CLIP_ATTRIBUTE)
			local definition = if type(clipId) == "string" then PlayerAnims.get(clipId) else nil
			if definition and clipId then
				forageStamps[character] = stamp
				local entry = Feedback.get(clipId :: string)
				forageShots[character] = {
					clipId = clipId :: string,
					startedAt = os.clock(),
					duration = if entry and entry.gesture then entry.gesture.duration else definition.length,
				}
			end
		end

		local shot = forageShots[character]
		if shot then
			local definition = PlayerAnims.get(shot.clipId)
			if not definition then
				forageShots[character] = nil
			else
				local elapsed = os.clock() - shot.startedAt
				if elapsed >= shot.duration + BLEND_OUT then
					forageShots[character] = nil
				else
					local t = math.clamp(elapsed / shot.duration, 0, 1)
					local weight: number
					if elapsed < shot.duration then
						weight = smoothstep(elapsed / BLEND_IN)
					else
						weight = smoothstep(1 - (elapsed - shot.duration) / BLEND_OUT)
					end
					applyRig(rig, definition, t, weight, constraints)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function GestureController.init()
	local localPlayer = Players.LocalPlayer

	local function bindLocal(character: Model)
		if localCharacter then
			books[localCharacter] = nil
			tuftShown[localCharacter] = nil
		end
		localCharacter = character
		localRig = nil
		playing = nil
		bindRig(character, function(rig)
			localRig = rig
		end)
	end

	if localPlayer.Character then
		bindLocal(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(bindLocal)

	-- clipId overrides the skill when the click is aimed at something specific:
	-- a carrot is dug, not weeded. See WorkController.kusatoriClip.
	WorkController.onStart(function(skillId, duration, clipId)
		GestureController.play(clipId or skillId or WorkController.getTrainingSkill() or "tobatsu", duration)
	end)

	local function watch(player: Player)
		if player == localPlayer then
			return
		end
		local function bindRemote(character: Model)
			-- Seed the stamp so a pluck from before this client arrived (or
			-- before the character streamed in) is not replayed as new.
			local stamp = character:GetAttribute(FORAGE_STAMP_ATTRIBUTE)
			forageStamps[character] = if type(stamp) == "number" then stamp else nil
			forageShots[character] = nil
			bindRig(character, function(rig)
				remoteRigs[character] = rig
				remotePhase[character] = math.random() * 1000
			end)
		end
		if player.Character then
			bindRemote(player.Character)
		end
		player.CharacterAdded:Connect(bindRemote)
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	--[[
		Two events, because the two joint types are read at different points.

		AnimationConstraints -- what an R15 player rig is made of since the Avatar
		Joint Upgrade -- are gathered in a batch job that runs after PreSimulation
		and before physics, and the Animator refills their Transform earlier in
		the same frame. Writing them from the render step, as this used to, put
		the pose somewhere nothing would ever read it: the gestures were running
		correctly and were simply never applied, which is why only the held props
		appeared to animate.

		Motor6D rigs (R6 players, and any rig on a place with the upgrade turned
		off) still take their pose from the legacy animation step during render,
		so those joints keep the Character + 1 binding. Props are welds and are
		stepped once, on the earlier of the two.
	]]
	local lastTrainingSkill: string? = nil

	RunService.PreSimulation:Connect(function(dt)
		local trainingSkill = WorkController.getTrainingSkill()
		if trainingSkill ~= lastTrainingSkill then
			lastTrainingSkill = trainingSkill
			if localCharacter then
				removeProps(localCharacter)
			end
		end

		stepLocal(true)
		stepRemote(true)
		stepLocalProps(dt)
		stepRemoteProps(dt)
	end)

	RunService:BindToRenderStep("Gesture", Enum.RenderPriority.Character.Value + 1, function()
		stepLocal(false)
		stepRemote(false)
	end)
end

return GestureController

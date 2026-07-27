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

	The Animator writes `Motor6D.Transform` every frame during the internal
	animation step. So does this. The trick is ordering and blending, not
	ownership:

	  * We run on BindToRenderStep at Character + 1, which is AFTER the animation
	    step has written its pose for the frame.
	  * We then read what the Animator just wrote and LERP from it toward the
	    gesture pose by a weight that ramps 0 -> 1 -> 0.

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
local PlayerAnims = require(Shared.Modules.Config.PlayerAnims)
local Skeleton = require(Shared.Modules.Anim.Skeleton)

local WorkController = require(script.Parent.WorkController)

local GestureController = {}

-- Set by the server on a working character; drives the looping remote version.
local WORKING_ATTRIBUTE = "WorkingSkill"
-- Set alongside it; scales the held prop so higher tiers swing bigger tools.
local TIER_ATTRIBUTE = "WorkTier"

-- Weight envelope, in seconds. Short enough to feel immediate, long enough that
-- neither end of a gesture is a step change.
local BLEND_IN = 0.07
local BLEND_OUT = 0.13

-- How long to wait for a character's joints before saying so. The watcher stays
-- live past this, so it is a reporting deadline and not a give-up.
local BIND_TIMEOUT = 15

-- Book prop timing, as fractions of the examprep gesture. The flip window is
-- the one Config/PlayerAnims keys for the left hand's page sweep.
local BOOK_OPEN_START, BOOK_OPEN_END = 0.10, 0.30
local BOOK_CLOSE_START, BOOK_CLOSE_END = 0.86, 1.00
local BOOK_FLIP_START, BOOK_FLIP_END = 0.52, 0.68

local SASUMATA_SKILLS = { tobatsu = true, subjugation = true, strength = true }
local BOOK_SKILLS = { examprep = true, special = true, craft = true }

type Rig = {
	joints: Skeleton.Joints,
	basis: { [string]: CFrame },
	inverse: { [string]: CFrame },
}

type Playing = {
	skillId: string,
	startedAt: number,
	releasingAt: number?,
}

local localRig: Rig? = nil
local localCharacter: Model? = nil
local playing: Playing? = nil

local remoteRigs: { [Model]: Rig } = {}
local remotePhase: { [Model]: number } = {}

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

	local basis, inverse = Skeleton.basisFor(character, joints, root)
	return { joints = joints, basis = basis, inverse = inverse }
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
		if descendant:IsA("Motor6D") then
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
		local motors, bones = {}, {}
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("Motor6D") then
				table.insert(motors, descendant.Name)
			elseif descendant:IsA("Bone") or descendant:IsA("AnimationConstraint") then
				table.insert(bones, `{descendant.ClassName}:{descendant.Name}`)
			end
		end

		warn(
			`[GestureController] no drivable joints in {character.Name} after {BIND_TIMEOUT}s. `
				.. `RigType={Skeleton.rigKind(character)}. `
				.. `Motor6Ds: {if #motors > 0 then table.concat(motors, ", ") else "none"}. `
				.. `Bones/constraints: {if #bones > 0 then table.concat(bones, ", ") else "none"}. `
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

	`motor.Transform` is read, not assumed: at this point in the frame it holds
	the locomotion pose, so lerping from it is what makes weight mean "how much
	of this is the gesture". At weight 0 the joint is exactly the walk cycle.

	Rotations are authored in the character's own root frame and mapped onto the
	rig's real joint axes by `inverse * pose * basis`, so one clip drives R6 and
	R15 without the per-rig sign flips this used to need.
]]
local function applyRig(rig: Rig, definition: any, t: number, weight: number)
	table.clear(scratch)
	Clip.pose(definition, t, scratch)

	local mask = definition.mask

	for name, target in scratch do
		local motor = rig.joints[name]
		if motor and motor.Parent then
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
		part.Size = if cover
			then Vector3.new(1.0, 0.04, 1.4) * scale
			else Vector3.new(0.95, 0.06, 1.35) * scale
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

local function animateBook(character: Model, openAmount: number, t: number)
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
		local flip = 0
		if t >= BOOK_FLIP_START then
			if t <= BOOK_FLIP_END then
				flip = smoothstep((t - BOOK_FLIP_START) / (BOOK_FLIP_END - BOOK_FLIP_START))
			else
				flip = 1
			end
		end
		local midAngle = rightAngle + (leftAngle - rightAngle) * flip
		middlePage.C0 = hinge * CFrame.Angles(0, 0, midAngle) * CFrame.new(0.5 * scale, 0.03 * scale, 0)
	end
end

local function bookOpenAmount(t: number): number
	if t < BOOK_OPEN_START then
		return 0
	elseif t < BOOK_OPEN_END then
		return (t - BOOK_OPEN_START) / (BOOK_OPEN_END - BOOK_OPEN_START)
	elseif t < BOOK_CLOSE_START then
		return 1
	elseif t < BOOK_CLOSE_END then
		return 1 - (t - BOOK_CLOSE_START) / (BOOK_CLOSE_END - BOOK_CLOSE_START)
	end
	return 0
end

--[[
	Tier scales the tool. §17's ladder runs seven tiers, and a tier-7 fork being
	visibly bigger than a tier-1 one is the cheapest possible read on progress.
	Kept sublinear so the top of the ladder is impressive rather than absurd.
]]
local function tierScale(tier: number): number
	return 1 + math.clamp(tier - 1, 0, 6) * 0.14
end

local function propScaleFor(character: Model): number
	local tier = character:GetAttribute(TIER_ATTRIBUTE)
	return tierScale(if type(tier) == "number" then tier else 1)
end

local function attachSkillProp(character: Model, skillId: string)
	local wantsSasumata = SASUMATA_SKILLS[skillId] == true
	local wantsBook = BOOK_SKILLS[skillId] == true
	if not wantsSasumata and not wantsBook then
		return
	end

	local targetName = if wantsSasumata then "EquippedSasumata" else "EquippedOpenBook"
	local otherName = if wantsSasumata then "EquippedOpenBook" else "EquippedSasumata"

	local other = character:FindFirstChild(otherName)
	if other then
		other:Destroy()
	end

	local scale = propScaleFor(character)
	local existing = character:FindFirstChild(targetName)
	if existing then
		-- Rebuild only when the tier actually moved.
		if math.abs((existing:GetAttribute("Scale") or 1) - scale) < 0.001 then
			return
		end
		existing:Destroy()
	end

	local hand = findHand(character, "Right")
	if not hand then
		return
	end

	local model: Model
	local grip: CFrame
	if wantsSasumata then
		model = buildSasumata(scale)
		grip = CFrame.new(0, -0.35, -0.3) * CFrame.Angles(math.rad(-100), 0, 0)
	else
		model = buildOpenBook(scale)
		grip = CFrame.new(0, -0.25, -0.45) * CFrame.Angles(math.rad(-70), math.rad(90), 0)
	end

	model:SetAttribute("Scale", scale)
	model.Parent = character

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

function GestureController.play(skillId: string?)
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
	end

	-- Restarting mid-gesture is fine: BLEND_IN ramps from whatever is on screen,
	-- so there is no snap back to the first keyframe.
	playing = { skillId = skillId, startedAt = os.clock() }
end

local function stepLocal()
	local rig = localRig
	local character = localCharacter
	if not rig or not character then
		return
	end

	if not playing then
		return
	end

	local definition = PlayerAnims.get(playing.skillId)
	if not definition then
		playing = nil
		return
	end

	local duration = definition.length
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

	if BOOK_SKILLS[playing.skillId] then
		animateBook(character, bookOpenAmount(t), t)
	end

	applyRig(rig, definition, t, weight)
end

--------------------------------------------------------------------------------
-- Other players
--------------------------------------------------------------------------------

local function stepRemote()
	for character, rig in remoteRigs do
		if not character.Parent then
			remoteRigs[character] = nil
			remotePhase[character] = nil
			continue
		end

		local skillId = character:GetAttribute(WORKING_ATTRIBUTE)
		if type(skillId) ~= "string" then
			continue
		end

		local definition = PlayerAnims.get(skillId)
		if not definition then
			continue
		end

		attachSkillProp(character, skillId)

		local phase = remotePhase[character] or 0
		local t = ((os.clock() + phase) % definition.length) / definition.length

		if BOOK_SKILLS[skillId] then
			animateBook(character, bookOpenAmount(t), t)
		end

		applyRig(rig, definition, t, 1)
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function GestureController.init()
	local localPlayer = Players.LocalPlayer

	local function bindLocal(character: Model)
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

	WorkController.onClick(function(skillId)
		GestureController.play(skillId or WorkController.getTrainingSkill() or "tobatsu")
	end)

	local function watch(player: Player)
		if player == localPlayer then
			return
		end
		local function bindRemote(character: Model)
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
		Character + 1, not RenderStepped.

		RenderStepped fires before the animation step, so anything written there
		is overwritten by the Animator in the same frame -- which is why the old
		version had to silence the Animator to be seen at all. One priority above
		Character puts us after it, where reading Transform gives the pose to
		blend against.
	]]
	RunService:BindToRenderStep("Gesture", Enum.RenderPriority.Character.Value + 1, function()
		stepLocal()
		stepRemote()
	end)
end

return GestureController

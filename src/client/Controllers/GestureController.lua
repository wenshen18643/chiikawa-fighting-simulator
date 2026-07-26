--[[
	Makes each skill look like itself.

	Four skills that all resolve to "click, number goes up" are one skill wearing
	four colours. A weed gets yanked, a fork comes down, a page turns — the
	gesture is what separates them, and it costs one table row per skill
	(Config/Feedback) rather than an art budget.

	--------------------------------------------------------------------------
	NO UPLOADED ASSETS
	--------------------------------------------------------------------------

	A Roblox animation normally means an uploaded Animation instance and an asset
	id. This drives the arm joints directly from keyframes in config instead,
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
	WHY THE WHOLE ARM
	--------------------------------------------------------------------------

	An earlier version bound the shoulder and explicitly rejected the elbow and
	wrist. That makes the arm a rigid stick on a pivot: it cannot fold to bring a
	book to a face, and it cannot coil before a swing. Both of the gestures that
	read worst were the two that need an elbow most. This binds the whole chain
	on R15 and degrades to the shoulder alone on R6, which genuinely has no
	elbow joint to drive.

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
local Feedback = require(Shared.Modules.Config.Feedback)

local WorkController = require(script.Parent.WorkController)

local GestureController = {}

-- Set by the server on a working character; drives the looping remote version.
local WORKING_ATTRIBUTE = "WorkingSkill"
-- Set alongside it; scales the held prop so higher tiers swing bigger tools.
local TIER_ATTRIBUTE = "WorkTier"

--[[
	Axis conventions. Every joint rotates about its local X.

	Shoulder: NEGATIVE pitch lifts the arm up and back.
	Elbow:    POSITIVE flexes, bringing the hand toward the shoulder.

	These are deltas from the rig's rest pose, captured per joint, so they hold
	for R6 and R15 alike. If a rig ever reads inverted, flip the sign HERE, once
	-- never in Config/Feedback, which is shared with the remote path.
]]
local ELBOW_DIRECTION = 1
local WRIST_DIRECTION = 1

-- Weight envelope, in seconds. Short enough to feel immediate, long enough that
-- neither end of a gesture is a step change.
local BLEND_IN = 0.07
local BLEND_OUT = 0.13

-- Book prop timing, as fractions of the examprep gesture. The flip window is
-- the one Config/Feedback documents for the left hand's page sweep.
local BOOK_OPEN_START, BOOK_OPEN_END = 0.10, 0.30
local BOOK_CLOSE_START, BOOK_CLOSE_END = 0.86, 1.00
local BOOK_FLIP_START, BOOK_FLIP_END = 0.52, 0.68

local SASUMATA_SKILLS = { tobatsu = true, subjugation = true, strength = true }
local BOOK_SKILLS = { examprep = true, special = true, craft = true }

type Chain = {
	shoulder: Motor6D?,
	elbow: Motor6D?,
	wrist: Motor6D?,
}

type Rig = {
	Right: Chain,
	Left: Chain,
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

--[[
	R15 and R6 name their arm joints exactly and differently, so match on the
	name rather than guessing from substrings. The old heuristic accepted any
	joint whose name merely started with "r", which is a wide net to cast at a
	rig you do not control.
]]
local JOINT_NAMES = {
	R15 = {
		Right = { shoulder = "RightShoulder", elbow = "RightElbow", wrist = "RightWrist" },
		Left = { shoulder = "LeftShoulder", elbow = "LeftElbow", wrist = "LeftWrist" },
	},
	R6 = {
		Right = { shoulder = "Right Shoulder" },
		Left = { shoulder = "Left Shoulder" },
	},
}

local function rigKind(character: Model): string
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		return "R6"
	end
	return "R15"
end

local function findMotor(character: Model, name: string): Motor6D?
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function buildChain(character: Model, names: { [string]: string }): Chain
	local chain: Chain = {}
	chain.shoulder = names.shoulder and findMotor(character, names.shoulder) or nil
	chain.elbow = names.elbow and findMotor(character, names.elbow) or nil
	chain.wrist = names.wrist and findMotor(character, names.wrist) or nil
	return chain
end

local function buildRig(character: Model): Rig?
	local names = JOINT_NAMES[rigKind(character)]
	local rig: Rig = {
		Right = buildChain(character, names.Right),
		Left = buildChain(character, names.Left),
	}
	if not rig.Right.shoulder and not rig.Left.shoulder then
		return nil
	end
	return rig
end

-- Rigs stream in a frame or two after the character does, so poll briefly.
local function bindRig(character: Model, assign: (Rig) -> ())
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < 5 do
			if character.Parent == nil then
				return
			end
			local rig = buildRig(character)
			if rig then
				assign(rig)
				return
			end
			task.wait(0.2)
		end
		--[[
			Nothing to drive. Say exactly what the rig DOES have, because the
			usual cause is a rig this code does not expect -- an
			AnimationConstraint rig has no Motor6Ds at all, and "no animation"
			with a silent log is indistinguishable from a logic bug.
		]]
		local found = {}
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("Motor6D") then
				table.insert(found, descendant.Name)
			end
		end
		warn(
			`[GestureController] no arm joints found in {character.Name} after 5s; gestures disabled. `
				.. `RigType={rigKind(character)}. Motor6Ds present: `
				.. (if #found > 0 then table.concat(found, ", ") else "NONE (AnimationConstraint rig?)")
		)
	end)
end

--------------------------------------------------------------------------------
-- Keyframe evaluation
--------------------------------------------------------------------------------

--[[
	Catmull-Rom, not per-segment smoothstep.

	Smoothstep eases into AND out of every interior key, which drives the
	angular velocity to zero at each one. A six-key gesture then reads as six
	small separate movements — the "steppy" quality. A Catmull-Rom spline is C1
	continuous, so the pose carries its velocity through a key and the whole
	gesture flows as one motion. It also overshoots slightly on direction
	changes, which is free follow-through.
]]
local function catmullRom(p0: number, p1: number, p2: number, p3: number, a: number): number
	local a2 = a * a
	local a3 = a2 * a
	return 0.5
		* ((2 * p1) + (-p0 + p2) * a + (2 * p0 - 5 * p1 + 4 * p2 - p3) * a2 + (-p0 + 3 * p1 - 3 * p2 + p3) * a3)
end

type Pose = { pitch: number, yaw: number, roll: number, elbow: number, wrist: number }

local CHANNELS = { "pitch", "yaw", "roll", "elbow", "wrist" }

-- A key's pose for one side. `left` overrides the mirror when present.
local function sideOf(key: Feedback.GestureKey, side: string, mirror: boolean): Pose
	if side == "Left" then
		local override = key.left
		if override then
			return {
				pitch = override.pitch,
				yaw = override.yaw or 0,
				roll = override.roll or 0,
				elbow = override.elbow or 0,
				wrist = override.wrist or 0,
			}
		end
		if mirror then
			return {
				pitch = key.pitch,
				yaw = -(key.yaw or 0),
				roll = -(key.roll or 0),
				elbow = key.elbow or 0,
				wrist = key.wrist or 0,
			}
		end
	end
	return {
		pitch = key.pitch,
		yaw = key.yaw or 0,
		roll = key.roll or 0,
		elbow = key.elbow or 0,
		wrist = key.wrist or 0,
	}
end

local function poseAt(gesture: Feedback.Gesture, t: number, side: string): Pose
	local keys = gesture.keys
	local count = #keys
	local mirror = gesture.arms == "both"

	if count == 0 then
		return { pitch = 0, yaw = 0, roll = 0, elbow = 0, wrist = 0 }
	end
	if count == 1 or t <= keys[1].t then
		return sideOf(keys[1], side, mirror)
	end
	if t >= keys[count].t then
		return sideOf(keys[count], side, mirror)
	end

	for index = 1, count - 1 do
		local a, b = keys[index], keys[index + 1]
		if t <= b.t then
			local span = b.t - a.t
			local alpha = if span > 0 then (t - a.t) / span else 1

			-- Clamped endpoints: duplicate the edge key so the spline does not
			-- need a neighbour that does not exist.
			local p0 = sideOf(keys[math.max(index - 1, 1)], side, mirror)
			local p1 = sideOf(a, side, mirror)
			local p2 = sideOf(b, side, mirror)
			local p3 = sideOf(keys[math.min(index + 2, count)], side, mirror)

			local out = {} :: any
			for _, channel in CHANNELS do
				out[channel] = catmullRom(p0[channel], p1[channel], p2[channel], p3[channel], alpha)
			end
			return out :: Pose
		end
	end

	return sideOf(keys[count], side, mirror)
end

--------------------------------------------------------------------------------
-- Applying a pose
--------------------------------------------------------------------------------

local function smoothstep(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

--[[
	Blend one joint toward a target rotation.

	`motor.Transform` is read, not assumed: at this point in the frame it holds
	whatever the Animator wrote, so lerping from it is what makes weight mean
	"how much of this is the gesture".
]]
local function blendJoint(motor: Motor6D?, target: CFrame, weight: number)
	if not motor or not motor.Parent then
		return
	end
	if weight >= 0.999 then
		motor.Transform = target
	else
		motor.Transform = motor.Transform:Lerp(target, weight)
	end
end

local function applyChain(chain: Chain, pose: Pose, weight: number)
	blendJoint(
		chain.shoulder,
		CFrame.Angles(math.rad(pose.pitch), math.rad(pose.yaw), math.rad(pose.roll)),
		weight
	)
	blendJoint(chain.elbow, CFrame.Angles(math.rad(pose.elbow * ELBOW_DIRECTION), 0, 0), weight)
	blendJoint(chain.wrist, CFrame.Angles(math.rad(pose.wrist * WRIST_DIRECTION), 0, 0), weight)
end

local function applyRig(rig: Rig, gesture: Feedback.Gesture, t: number, weight: number)
	applyChain(rig.Right, poseAt(gesture, t, "Right"), weight)

	-- A "right" gesture leaves the left arm entirely to the walk cycle.
	if gesture.arms == "both" then
		applyChain(rig.Left, poseAt(gesture, t, "Left"), weight)
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

	local entry = Feedback.get(skillId)
	if not entry then
		warn(`[GestureController] no Feedback entry for "{skillId}"; nothing to play`)
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

	local entry = Feedback.get(playing.skillId)
	if not entry then
		playing = nil
		return
	end

	local gesture = entry.gesture
	local elapsed = os.clock() - playing.startedAt
	local t = math.clamp(elapsed / gesture.duration, 0, 1)

	local weight: number
	if elapsed < gesture.duration then
		weight = smoothstep(elapsed / BLEND_IN)
	else
		-- Hold the final pose and fade our influence out, so the walk cycle
		-- takes the arm back rather than the arm being dropped into it.
		local releasing = elapsed - gesture.duration
		if releasing >= BLEND_OUT then
			playing = nil
			return
		end
		weight = smoothstep(1 - releasing / BLEND_OUT)
	end

	if BOOK_SKILLS[playing.skillId] then
		animateBook(character, bookOpenAmount(t), t)
	end

	applyRig(rig, gesture, t, weight)
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

		local entry = Feedback.get(skillId)
		if not entry then
			continue
		end

		attachSkillProp(character, skillId)

		local phase = remotePhase[character] or 0
		local t = ((os.clock() + phase) % entry.gesture.duration) / entry.gesture.duration

		if BOOK_SKILLS[skillId] then
			animateBook(character, bookOpenAmount(t), t)
		end

		applyRig(rig, entry.gesture, t, 1)
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

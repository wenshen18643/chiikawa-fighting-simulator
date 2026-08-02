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
local WORKING_ATTRIBUTE = "WorkingSkill"
local FORAGE_CLIP_ATTRIBUTE = "ForageClip"
local FORAGE_STAMP_ATTRIBUTE = "ForageClipAt"
local COOKING_ATTRIBUTE = "Cooking"
local COOKING_CLIP = "cook_stir"
local BLEND_IN = 0.07
local BLEND_OUT = 0.13
local BIND_TIMEOUT = 15
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

local function smoothstep(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local scratch: Clip.Pose = {}

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

local function findHand(character: Model, side: string): BasePart?
	local exact = character:FindFirstChild(side .. "Hand")
	if exact and exact:IsA("BasePart") then
		return exact
	end
	local arm = character:FindFirstChild(side .. " Arm")
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

local SASUMATA_PINK = Color3.fromRGB(243, 167, 193)
local SASUMATA_BARB = Color3.fromRGB(226, 124, 158)
local SASUMATA_CREAM = Color3.fromRGB(252, 247, 240)
local PRONG_SPLAY = 13
local BARBS_PER_PRONG = 3

local function buildSasumata(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "EquippedSasumata"

	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.2, 3.4, 0.2) * scale
	shaft.Color = SASUMATA_PINK
	shaft.Material = Enum.Material.SmoothPlastic
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

	local neck = Instance.new("Part")
	neck.Name = "ForkNeck"
	neck.Size = Vector3.new(0.86, 0.2, 0.2) * scale
	neck.Color = SASUMATA_PINK
	neck.Material = Enum.Material.SmoothPlastic
	attach(neck, CFrame.new(0, 1.66 * scale, 0))

	local prongLength = 1.3
	local splay = math.rad(PRONG_SPLAY)

	for _, side in { -1, 1 } do
		local lean = splay * side
		local baseX = 0.43 * side * scale
		local baseY = 1.66 * scale
		local prong = Instance.new("Part")
		prong.Name = if side < 0 then "LeftProng" else "RightProng"
		prong.Size = Vector3.new(0.18 * scale, prongLength * scale, 0.2 * scale)
		prong.Color = SASUMATA_PINK
		prong.Material = Enum.Material.SmoothPlastic
		attach(
			prong,
			CFrame.new(
				baseX + math.sin(lean) * prongLength * scale / 2,
				baseY + math.cos(lean) * prongLength * scale / 2,
				0
			) * CFrame.Angles(0, 0, -lean)
		)

		local tip = Instance.new("Part")
		tip.Name = if side < 0 then "LeftTip" else "RightTip"
		tip.Shape = Enum.PartType.Ball
		tip.Size = Vector3.new(0.22, 0.22, 0.22) * scale
		tip.Color = SASUMATA_PINK
		tip.Material = Enum.Material.SmoothPlastic
		attach(
			tip,
			CFrame.new(baseX + math.sin(lean) * prongLength * scale, baseY + math.cos(lean) * prongLength * scale, 0)
		)

		for index = 1, BARBS_PER_PRONG do
			local along = (index - 0.35) / BARBS_PER_PRONG * prongLength * scale
			local barb = Instance.new("Part")
			barb.Name = "Barb"
			barb.Shape = Enum.PartType.Wedge
			barb.Size = Vector3.new(0.14, 0.26, 0.3) * scale
			barb.Color = SASUMATA_BARB
			barb.Material = Enum.Material.SmoothPlastic
			attach(
				barb,
				CFrame.new(baseX + math.sin(lean) * along - 0.16 * side * scale, baseY + math.cos(lean) * along, 0)
					* CFrame.Angles(0, math.rad(90) * side, -lean)
			)
		end
	end

	local band = Instance.new("Part")
	band.Name = "GripBand"
	band.Size = Vector3.new(0.26, 0.8, 0.26) * scale
	band.Color = SASUMATA_CREAM
	band.Material = Enum.Material.SmoothPlastic
	attach(band, CFrame.new(0, -0.85 * scale, 0))

	local butt = Instance.new("Part")
	butt.Name = "ButtCap"
	butt.Shape = Enum.PartType.Ball
	butt.Size = Vector3.new(0.26, 0.26, 0.26) * scale
	butt.Color = SASUMATA_BARB
	butt.Material = Enum.Material.SmoothPlastic
	attach(butt, CFrame.new(0, -1.7 * scale, 0))

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

	weldTo(spine, coverRight, CFrame.new(0.5 * scale, -0.02 * scale, 0))
	weldTo(spine, coverLeft, CFrame.new(0, 0.04 * scale, 0) * CFrame.new(0.5 * scale, 0.02 * scale, 0))
	weldTo(spine, rightPage, CFrame.new(0.475 * scale, 0.015 * scale, 0))
	weldTo(spine, leftPage, CFrame.new(0, 0.04 * scale, 0) * CFrame.new(0.475 * scale, -0.02 * scale, 0))
	weldTo(spine, middlePage, CFrame.new(0, 0.04 * scale, 0) * CFrame.new(0.5 * scale, 0.03 * scale, 0))

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

	local weld = Instance.new("Weld")
	weld.Name = "GripWeld"
	weld.Part0 = hand
	weld.Part1 = model.PrimaryPart
	weld.C0 = grip
	weld.Parent = hand
end

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
		local releasing = elapsed - duration
		if releasing >= BLEND_OUT then
			playing = nil
			return
		end
		weight = smoothstep(1 - releasing / BLEND_OUT)
	end

	applyRig(rig, definition, t, weight, constraints)
end

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
		local skillId = character:GetAttribute(WORKING_ATTRIBUTE)
		if type(skillId) == "string" then
			local definition = PlayerAnims.get(skillId)
			if definition then
				local t = ((os.clock() + phase) % definition.length) / definition.length
				applyRig(rig, definition, t, 1, constraints)
			end
		end

		if character:GetAttribute(COOKING_ATTRIBUTE) == true then
			local definition = PlayerAnims.get(COOKING_CLIP)
			if definition then
				local t = ((os.clock() + phase) % definition.length) / definition.length
				applyRig(rig, definition, t, 1, constraints)
			end
		end

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

	WorkController.onStart(function(skillId, duration, clipId)
		GestureController.play(clipId or skillId or WorkController.getTrainingSkill() or "tobatsu", duration)
	end)

	local function watch(player: Player)
		if player == localPlayer then
			return
		end

		local function bindRemote(character: Model)
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

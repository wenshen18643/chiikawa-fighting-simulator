local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clip = require(Shared.Modules.Anim.Clip)
local Props = require(Shared.Modules.Anim.Props)
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local Skills = require(Shared.Modules.Config.Skills)

local Machine = {}
Machine.__index = Machine

local SPEED_SMOOTHING = 9
local TRANSFORM_RESPONSE = 26
local MOVE_THRESHOLD = 0.6
local LOCO_MIN_RATE = 0.45
local LOCO_MAX_RATE = 2.1
local ACTION_BLEND_IN = 0.09
local ACTION_BLEND_OUT = 0.2
local BREAK_HOLD_AFTER_MOVE = 2.5

local function smoothstep(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function hashName(name: string): number
	local total = 0
	for index = 1, #name do
		total += string.byte(name, index) * index
	end
	return total % 512
end

function Machine.new(model: Model, joints: { [string]: Motor6D }, set: any)
	local self = setmetatable({}, Machine)

	self.model = model
	self.joints = joints
	self.set = set
	self.root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	self.basis = {} :: { [string]: CFrame }
	self.basisInverse = {} :: { [string]: CFrame }
	self.jointSeed = {} :: { [string]: number }

	self.speed = 0
	self.idlePhase = math.random()
	self.locoPhase = math.random()
	self.seed = math.random() * 500
	self.action = nil
	self.prop = nil
	self.propOffset = nil
	self.flashed = false

	self.pose = {} :: Clip.Pose
	self.locoScratch = {} :: Clip.Pose
	self.runScratch = {} :: Clip.Pose
	self.actionScratch = {} :: Clip.Pose

	local extents = model:GetExtentsSize()
	self.scale = math.max(extents.X, extents.Y, extents.Z)
	self.propScale = self.scale * 0.3

	local rootJoint = joints.root
	self.propAnchor = (rootJoint and rootJoint.Part1) or self.root

	--[[
		Measured HERE, once, and never again -- because this is the only moment
		the model holds nothing but the companion.

		propPlacement reads self.model:GetBoundingBox(), and play() used to call
		it one line after parenting the new prop into that same model. Props are
		built at the origin (Props.build positions everything relative to a
		PrimaryPart whose CFrame it never sets), so the box being measured ran
		from the companion all the way back to (0, 0, 0) and `reach` came out as
		half the distance to the middle of the map. The prop landed there.

		A live flash burst does the same thing more quietly, since Props.flash
		parents into the model too and lingers for its Debris window.

		Nothing is lost by taking it early: the offset is returned in the
		anchor's own space, so it tracks the body wherever the animation puts it,
		and self.propScale one line above is already measured once this way.
	]]
	self.propBase = self:propPlacement()

	for name in joints do
		self.jointSeed[name] = hashName(name)
	end

	self:computeBasis()
	self:scheduleBreak(os.clock())

	return self
end

function Machine:computeBasis()
	if not self.root then
		return
	end
	self.basis, self.basisInverse = Skeleton.basisFor(self.model, self.joints, self.root)
end

function Machine:scheduleBreak(now: number)
	local range = self.set.breakDelay
	if not range then
		self.nextBreak = math.huge
		return
	end
	self.nextBreak = now + range[1] + math.random() * math.max(range[2] - range[1], 0)
end

--[[
	Where a held prop sits, in the anchor part's own space.

	Measured off the model's bounding box rather than off the anchor joint. The
	joint a companion hangs from is not where its body looks like it is -- on the
	R6 roster entry the root joint drives an invisible standard torso while the
	whole visible character is one oversized mesh welded to it, so anchoring the
	prop at the joint puts it inside the face.
]]
function Machine:propPlacement(): CFrame
	local anchor = self.propAnchor
	if not anchor then
		return CFrame.identity
	end

	local boxCFrame, boxSize = self.model:GetBoundingBox()
	local reach = boxSize.Z * 0.5 + self.propScale * 0.55
	local desired = CFrame.new(boxCFrame.Position) * anchor.CFrame.Rotation * CFrame.new(0, boxSize.Y * 0.06, -reach)

	return anchor.CFrame:Inverse() * desired
end

function Machine:clearProp()
	if self.prop then
		self.prop:Destroy()
		self.prop = nil
		self.propOffset = nil
	end
end

function Machine:play(clipName: string, now: number)
	local definition = self.set.clips[clipName]
	if not definition then
		return false
	end

	local current = self.action
	if current and current.name == clipName and now - current.startedAt < definition.length then
		return false
	end

	self:clearProp()

	self.action = {
		name = clipName,
		definition = definition,
		startedAt = now,
	}
	self.flashed = false

	local prop = definition.prop
	if prop and self.propAnchor then
		local model, rotation = Props.build(prop.builder, self.propScale)
		if model and rotation then
			local offset = self.propBase * rotation
			-- Placed before it is parented. Props.build leaves everything at the
			-- origin and update() does not run until the next render step, which
			-- is one frame of a camera sitting on the middle of the map.
			if model.PrimaryPart then
				model:PivotTo(self.propAnchor.CFrame * offset)
			end
			model.Parent = self.model
			self.prop = model
			self.propOffset = offset
		end
	end

	return true
end

function Machine:playAction(skillId: string?, now: number): boolean
	if type(skillId) == "string" then
		local named = `action_{Skills.canonicalize(skillId)}`
		if self.set.clips[named] then
			return self:play(named, now)
		end
	end
	return self:play("action", now)
end

function Machine:playBreak(now: number)
	self:scheduleBreak(now)

	local breaks = self.set.breaks
	if not breaks or #breaks == 0 then
		return
	end

	local total = 0
	for _, entry in breaks do
		total += entry.weight
	end

	local roll = math.random() * total
	for _, entry in breaks do
		roll -= entry.weight
		if roll <= 0 then
			self:play(entry.clip, now)
			return
		end
	end
end

function Machine:destroy()
	self:clearProp()
	self.action = nil
end

function Machine:update(dt: number, now: number)
	local root = self.root
	if not root or not root.Parent then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local planar = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	self.speed += (planar - self.speed) * (1 - math.exp(-dt * SPEED_SMOOTHING))

	local set = self.set
	local clips = set.clips
	local speed = self.speed

	local locoWeight = smoothstep(math.clamp((speed - MOVE_THRESHOLD) / (set.walkSpeed * 0.55), 0, 1))
	local runFloor = set.walkSpeed * 0.82
	local runBlend = smoothstep(math.clamp((speed - runFloor) / math.max(set.runSpeed - runFloor, 1), 0, 1))

	self.idlePhase += dt / clips.idle.length

	local cycle = clips.walk.length + (clips.run.length - clips.walk.length) * runBlend
	local stride = set.walkSpeed + (set.runSpeed - set.walkSpeed) * runBlend
	local rate = math.clamp(speed / math.max(stride, 1), LOCO_MIN_RATE, LOCO_MAX_RATE)
	self.locoPhase += dt * rate / math.max(cycle, 0.05)

	local pose = self.pose
	table.clear(pose)
	Clip.pose(clips.idle, self.idlePhase, pose)

	if locoWeight > 0.001 then
		local loco = self.locoScratch
		table.clear(loco)
		Clip.pose(clips.walk, self.locoPhase, loco)

		if runBlend > 0.001 then
			local run = self.runScratch
			table.clear(run)
			Clip.pose(clips.run, self.locoPhase, run)
			Clip.blend(loco, run, runBlend)
		end

		Clip.blend(pose, loco, locoWeight)
	end

	local action = self.action
	if action then
		local definition = action.definition
		local duration = definition.length
		local elapsed = now - action.startedAt

		if elapsed >= duration then
			self.action = nil
			self:clearProp()
			self:scheduleBreak(now)
		else
			local weight
			if elapsed < ACTION_BLEND_IN then
				weight = elapsed / ACTION_BLEND_IN
			elseif elapsed > duration - ACTION_BLEND_OUT then
				weight = (duration - elapsed) / ACTION_BLEND_OUT
			else
				weight = 1
			end

			local phase = elapsed / duration
			local scratch = self.actionScratch
			table.clear(scratch)
			Clip.pose(definition, phase, scratch)
			Clip.blend(pose, scratch, smoothstep(weight), definition.mask)

			local prop = definition.prop
			if prop and prop.flashAt and not self.flashed and phase >= prop.flashAt then
				self.flashed = true
				local anchor = self.propAnchor
				if anchor then
					local offset = self.propOffset or self.propBase
					Props.flash(anchor.CFrame * offset, self.propScale, self.model)
				end
			end
		end
	end

	local tremble = set.tremble
	if tremble then
		local restWeight = 1 - locoWeight * 0.55
		local t = now * tremble.frequency
		for joint, amount in tremble.joints do
			if self.joints[joint] then
				local offset = self.seed + (self.jointSeed[joint] or 0)
				local pitch = math.noise(t, offset) * 2 * tremble.amplitude * amount
				local roll = math.noise(t + 31.7, offset) * 2 * tremble.amplitude * amount
				Clip.add(pose, joint, CFrame.Angles(math.rad(pitch), 0, math.rad(roll)), restWeight)
			end
		end
	end

	if locoWeight > 0.08 then
		self.nextBreak = math.max(self.nextBreak, now + BREAK_HOLD_AFTER_MOVE)
	elseif not self.action and now >= self.nextBreak then
		self:playBreak(now)
	end

	local response = 1 - math.exp(-dt * TRANSFORM_RESPONSE)
	for name, motor in self.joints do
		local target = pose[name]
		if target and motor.Parent then
			local inverse = self.basisInverse[name]
			local final = if inverse then inverse * target * self.basis[name] else target
			motor.Transform = motor.Transform:Lerp(final, response)
		end
	end

	local prop = self.prop
	if prop and self.propOffset and self.propAnchor and prop.PrimaryPart then
		prop:PivotTo(self.propAnchor.CFrame * self.propOffset)
	end
end

return Machine

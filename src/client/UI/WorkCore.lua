--[[
	The work core: the bottom-centre control, and the thing the player actually
	looks at while playing.

	It replaces three separate panels that used to live down here — the stamina
	bar, the worksite prompt, and the guide card — and which could all be visible
	simultaneously, giving the most important corner of the screen three voices
	and no hierarchy.

	One control, two states:

	  ON A PAD      the stamina ring wraps the worksite you are working, its
	                multiplier, and what one click is worth.
	  OFF A PAD     the same ring wraps the pad you should walk to, with a live
	                bearing arrow and a distance.

	The ring is the stamina meter (Primitives.ring — a real dial, drawn from
	frames, no image assets). Putting the rate limiter AROUND the thing it limits
	is the whole design: you never have to look somewhere else to know why the
	clicks stopped counting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)
local UI = require(Shared.UI)

local GuideController = require(script.Parent.Parent.Controllers.GuideController)
local WorkController = require(script.Parent.Parent.Controllers.WorkController)

local WorkCore = {}

-- Fits the shorter card: 108 tall less 12 padding top and bottom.
local RING_SIZE = 84

local root: Frame
local setRing: (number) -> ()
local ringGlyph: Frame
local ringValue: TextLabel
local ringCaption: TextLabel

local titleLabel: TextLabel
local detailLabel: TextLabel
local actionPill: Frame
local actionLabel: TextLabel
local arrowGlyph: Frame

local currentTarget: GuideController.Target? = nil
local currentSkill: string? = nil
local ringGlyphSkill: string? = nil
local lastRatio = 0

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function WorkCore.build(parent: Instance): Frame
	root = UI.card(parent, "WorkCore")
	--[[
		Bottom RIGHT, not centre.

		Centred and 392x132 it sat directly over the character and the ground
		ahead of them — the two things the player is actually looking at. It is
		a status readout, not the focus, so it belongs in a corner. The skill
		bar keeps centre because that one IS the focus.
	]]
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -18, 1, -18)
	root.Size = UDim2.fromOffset(320, 108)
	UI.padding(root, 12)
	UI.shadow(root)

	local ring
	ring, setRing = UI.ring(root, "Stamina", {
		extent = UDim2.fromOffset(RING_SIZE, RING_SIZE),
		position = UDim2.fromOffset(0, 0),
		thickness = 9,
		color = UI.color.leaf,
		zIndex = 3,
	})
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.new(0, 0, 0.5, 0)

	-- Inside the ring: the skill's glyph and the stamina reading.
	ringGlyph = UI.glyph(ring, "leaf", {
		color = UI.color.leafDeep,
		extent = UDim2.fromOffset(24, 24),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.34),
		zIndex = 6,
	})

	ringValue = UI.label(ring, "Value", {
		text = "100",
		font = UI.font.display,
		size = 19,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 0.2),
		position = UDim2.fromScale(0, 0.46),
		zIndex = 6,
	})

	ringCaption = UI.label(ring, "Caption", {
		text = "STAMINA",
		font = UI.font.bold,
		size = 9,
		color = UI.color.inkFaint,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 0.16),
		position = UDim2.fromScale(0, 0.63),
		zIndex = 6,
	})

	-- Right-hand column: what you are doing, or where to go.
	local column = Instance.new("Frame")
	column.Name = "Detail"
	column.Position = UDim2.fromOffset(RING_SIZE + 16, 4)
	column.Size = UDim2.new(1, -(RING_SIZE + 16), 1, -8)
	column.BackgroundTransparency = 1
	column.ZIndex = 3
	column.Parent = root

	arrowGlyph = UI.glyph(column, "arrow", {
		color = UI.color.leafDeep,
		extent = UDim2.fromOffset(22, 22),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, 0, 0, 15),
		zIndex = 5,
	})

	titleLabel = UI.label(column, "Title", {
		text = "",
		font = UI.font.display,
		size = 20,
		extent = UDim2.new(1, -30, 0, 26),
		position = UDim2.fromOffset(30, 2),
	})

	detailLabel = UI.label(column, "Detail", {
		text = "",
		font = UI.font.body,
		size = 13,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 30),
	})

	actionPill = Instance.new("Frame")
	actionPill.Name = "ActionPill"
	actionPill.AnchorPoint = Vector2.new(0, 1)
	actionPill.Position = UDim2.new(0, 0, 1, 0)
	actionPill.Size = UDim2.new(1, 0, 0, 30)
	actionPill.BackgroundColor3 = UI.color.leaf
	actionPill.BorderSizePixel = 0
	actionPill.ZIndex = 4
	actionPill.Parent = column
	UI.corner(actionPill, UI.radius.pill)

	actionLabel = UI.label(actionPill, "Action", {
		text = "",
		font = UI.font.bold,
		size = 13,
		color = UI.color.white,
		align = Enum.TextXAlignment.Center,
		extent = UDim2.fromScale(1, 1),
		zIndex = 5,
	})

	-- The arrow tracks the camera, which moves every frame even when nothing
	-- else does. Refreshing the whole panel that often would be waste; this is
	-- one property write.
	RunService.RenderStepped:Connect(function()
		if currentTarget and arrowGlyph.Visible then
			-- Negated so a target to the player's right swings the arrow
			-- clockwise, which is the direction they will turn.
			arrowGlyph.Rotation = -GuideController.bearingToTarget(currentTarget)
		end
	end)

	return root
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local function showWorking(snapshot: any)
	local worksite = Worksites.get(snapshot.currentWorksite)
	if not worksite then
		return
	end

	local skill = Skills.get(worksite.skill)
	currentTarget = nil
	currentSkill = worksite.skill

	arrowGlyph.Visible = false
	titleLabel.Position = UDim2.fromOffset(0, 2)
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.Text = worksite.name

	local gain = snapshot.gainPerAction
	detailLabel.Text = if Skills.canonicalize(worksite.skill) == "examprep"
		then `TIER {worksite.tier}  ·  x{worksite.multiplier}  ·  +{gain and BigNumber.toString(gain) or "0"} a page`
		else `TIER {worksite.tier}  ·  x{worksite.multiplier}  ·  +{gain and BigNumber.toString(gain) or "0"} a click`
	detailLabel.TextColor3 = UI.color.inkSoft

	actionPill.BackgroundColor3 = if skill and skill.color then skill.color else (UI.color.leaf or Color3.fromRGB(126, 190, 104))
	actionLabel.Text = string.upper(WorkController.getPromptText() or "Click to work")
end

--[[
	Not on a pad. Two different situations that need different words:

	  - standing on a pad you have not earned. The server told us which one, so
	    say what it needs rather than pretending there is nothing there.
	  - standing on grass. Point at the nearest thing worth walking to.
]]
local function showIdle(snapshot: any)
	currentSkill = nil

	--[[
		Standing on a pad you have not earned. It still trains — at base rate,
		into that pad's own skill — so this says what the pad WANTS rather than
		refusing outright, which is what it used to do.
	]]
	local blockedId = snapshot.blockedWorksite
	if blockedId then
		local worksite = Worksites.get(blockedId)
		if worksite then
			local skill = Skills.get(worksite.skill)
			currentSkill = worksite.skill
			currentTarget = nil
			arrowGlyph.Visible = false
			titleLabel.Position = UDim2.fromOffset(0, 2)
			titleLabel.Size = UDim2.new(1, 0, 0, 26)
			titleLabel.Text = worksite.name
			detailLabel.Text =
				`practising at base rate · pad needs {BigNumber.toString(BigNumber.coerce(worksite.requirement))}`
			detailLabel.TextColor3 = UI.color.inkFaint
			actionPill.BackgroundColor3 = if skill and skill.color then skill.color:Lerp(UI.color.paper or Color3.fromRGB(253, 251, 246), 0.35) else (UI.color.inkFaint or Color3.fromRGB(190, 182, 170))
			actionLabel.Text = if Skills.canonicalize(worksite.skill) == "examprep"
				then string.upper(if UserInputService.TouchEnabled then "tap skill 4 to open book" else "press 4 to open book")
				else string.upper(`click to {skill and skill.verb or "work"}`)
			return
		end
	end

	--[[
		Open ground. You can still train here — a pad is a multiplier, not a
		gate — so this leads with what you ARE training, and treats the nearest
		pad as an upgrade to walk to rather than as a prerequisite.

		The old copy said "NOTHING NEARBY", which was discouraging and is now
		simply untrue.
	]]
	local selected = snapshot.selectedSkill
	local selectedDefinition = selected and Skills.get(selected)
	currentSkill = selected

	local target = GuideController.getTarget()
	currentTarget = target

	titleLabel.Position = UDim2.fromOffset(0, 2)
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.Text = if selectedDefinition then `Training {selectedDefinition.name}` else "Training"
	actionPill.BackgroundColor3 = if selectedDefinition and selectedDefinition.color
		then selectedDefinition.color:Lerp(UI.color.paper or Color3.fromRGB(253, 251, 246), 0.3)
		else (UI.color.paperDeep or Color3.fromRGB(244, 239, 230))
	actionLabel.Text = if selected and Skills.canonicalize(selected) == "examprep"
		then string.upper(if UserInputService.TouchEnabled then "tap skill 4 to open book" else "press 4 to open book")
		else string.upper(
			`{if UserInputService.TouchEnabled then "tap" else "click"} to {selectedDefinition and selectedDefinition.verb or "work"}`
		)

	if not target then
		arrowGlyph.Visible = false
		detailLabel.Text = "base rate · press 1-4 to switch skill"
		detailLabel.TextColor3 = UI.color.inkSoft
		return
	end

	-- There is a better place to do this. Say where, and by how much.
	arrowGlyph.Visible = true
	titleLabel.Position = UDim2.fromOffset(30, 2)
	titleLabel.Size = UDim2.new(1, -30, 0, 26)
	detailLabel.Text =
		`base rate · {target.worksite.name} is x{target.worksite.multiplier}, {math.floor(target.distance)}m away`
	detailLabel.TextColor3 = UI.color.inkSoft
end

function WorkCore.update(snapshot: any)
	if not root then
		return
	end

	--------------------------------------------------------------------------
	-- The ring: stamina, always, whichever state the panel is in.
	--------------------------------------------------------------------------
	local stamina = snapshot.stamina
	local ratio = if stamina.max > 0 then math.clamp(stamina.current / stamina.max, 0, 1) else 0

	-- Stepped toward the new value rather than snapped, but without a tween per
	-- snapshot: at 2.5 snapshots a second, overlapping tweens on the same
	-- property visibly stutter.
	lastRatio += (ratio - lastRatio) * 0.5
	setRing(lastRatio)

	ringValue.Text = tostring(math.floor(stamina.current))
	ringCaption.Text = if snapshot.resting then "RESTING" else "STAMINA"
	ringCaption.TextColor3 = if snapshot.resting then UI.color.rest else UI.color.inkFaint

	--------------------------------------------------------------------------
	-- The panel body.
	--------------------------------------------------------------------------
	if snapshot.currentWorksite then
		showWorking(snapshot)
	else
		showIdle(snapshot)
	end

	actionLabel.TextColor3 = if snapshot.currentWorksite then UI.color.white else UI.color.inkSoft

	-- The glyph inside the ring follows whatever the panel is about, so the
	-- ring is never a generic meter floating next to unrelated text.
	--
	-- Rebuilt only when the skill CHANGES. Snapshots arrive 2.5 times a second
	-- and a glyph is five instances; tearing it down and rebuilding it on every
	-- one would churn a few hundred instances a minute to draw the same picture.
	local glyphSkill = currentSkill or (currentTarget and currentTarget.worksite.skill)
	if glyphSkill and glyphSkill ~= ringGlyphSkill then
		ringGlyphSkill = glyphSkill
		local skill = Skills.get(glyphSkill)
		local host = ringGlyph.Parent :: Instance
		ringGlyph:Destroy()
		ringGlyph = UI.skillGlyph(host, glyphSkill, {
			color = skill and skill.color or UI.color.leafDeep,
			extent = UDim2.fromOffset(24, 24),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.34),
			zIndex = 6,
		})
	end
end

function WorkCore.setVisible(visible: boolean)
	if root then
		root.Visible = visible
	end
end

return WorkCore

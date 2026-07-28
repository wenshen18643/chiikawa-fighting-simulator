--[[
	The HUD. Built in code so it lives in version control rather than in a
	.rbxlx nobody can diff. Visual tokens live in Theme.lua.

	Reads StateController only — every number shown here came from the server
	(docs/GAME.md §13). Nothing is computed locally and then trusted.

	    ┌ identity ─────┐                        ┌ minimap ──┐
	    │ bust · purse  │                        │ local     │
	    └───────────────┘                        │ world     │
	    (o) atlas                                └───────────┘
	    (o) help
	                  ┌ work core ─────────┐
	                  │ ring · what · how  │          (UI/WorkCore)
	                  └────────────────────┘
	              ( 1 )  ( 2 )  ( 3 )  ( 4 )          (UI/SkillBar)

	This file owns the identity block, the side rail and the toasts, and hosts
	the panels that own themselves: SkillBar, WorkCore, Minimap and Atlas.

	The skills moved out of a card down the left and into the round bottom-centre
	bar — see UI/SkillBar for why. What is left here is the wiring: this file
	still decides what ACTIVE and SELECTED mean and tells the bar, because that
	distinction is a rule about the game rather than about a button.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNumber = require(Shared.Modules.BigNumber)
local Certifications = require(Shared.Modules.Config.Certifications)
local Remotes = require(Shared.Modules.Remotes)
local Skills = require(Shared.Modules.Config.Skills)
local Worksites = require(Shared.Modules.Config.Worksites)
local UI = require(Shared.UI)

-- Skill selection moved to UI/SkillBar, which talks to WorkController itself.
local StateController = require(script.Parent.Parent.Controllers.StateController)
local Atlas = require(script.Parent.Atlas)
local ControlsPanel = require(script.Parent.ControlsPanel)
local InventoryMenu = require(script.Parent.InventoryMenu)
local Minimap = require(script.Parent.Minimap)
local SkillBar = require(script.Parent.SkillBar)
local WorkCore = require(script.Parent.WorkCore)

local HUD = {}

-- Below this the side panels come off. A phone cannot carry three of them, and
-- shrinking everything into illegibility is worse than showing less. The skill
-- bar is NOT one of them: it is the primary control and stays at every width.
local COMPACT_WIDTH = 760

local skillEntries: { [string]: SkillBar.SkillEntry } = {}

local screen: ScreenGui
local identityCard: Frame
local skillBarHolder: Frame
local yenSet: (string, number?) -> ()
local wageLabel: TextLabel
local stampLabel: TextLabel
local seasonChip: Frame
local toastHolder: Frame
local buffHolder: Frame

local activeSkill: string? = nil
local selectedSkill: string? = nil
local buffChips: { TextLabel } = {}
local buffKey = ""

--------------------------------------------------------------------------------
-- Identity
--------------------------------------------------------------------------------

--[[
	A live portrait of the player's own character, rendered in a ViewportFrame
	from a clone of their model.

	No asset, no thumbnail API, no upload: the character already exists on the
	client, so a copy of it in a little box costs one clone and a camera. It is
	the cheapest way to make a HUD feel like it belongs to a person.
]]
local function buildBust(parent: Frame)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Bust"
	viewport.Size = UDim2.fromOffset(52, 52)
	viewport.BackgroundColor3 = UI.color.paperDeep
	viewport.BackgroundTransparency = 0
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 3
	viewport.Parent = parent
	UI.corner(viewport, UI.radius.chip)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	viewport.CurrentCamera = camera
	camera.Parent = viewport

	local function mount(character: Model)
		for _, child in viewport:GetChildren() do
			if child:IsA("Model") then
				child:Destroy()
			end
		end

		-- Archivable is false on live characters, so a straight Clone returns
		-- nil. Flip it for the duration of the copy and put it back.
		local wasArchivable = character.Archivable
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = wasArchivable
		if not clone then
			return
		end

		for _, descendant in clone:GetDescendants() do
			-- A cloned Humanoid in a viewport will try to simulate and will
			-- spam state-change errors; scripts would run for real.
			if descendant:IsA("Humanoid") or descendant:IsA("BaseScript") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
		clone.Parent = viewport

		local head = clone:FindFirstChild("Head") :: BasePart?
		local pivot = if head then head.CFrame else clone:GetPivot()
		camera.CFrame =
			CFrame.lookAt(pivot.Position + Vector3.new(0, 0.25, 4.2), pivot.Position + Vector3.new(0, 0.1, 0))
	end

	local player = Players.LocalPlayer
	if player.Character then
		task.defer(mount, player.Character)
	end
	player.CharacterAppearanceLoaded:Connect(mount)

	return viewport
end

local function buildIdentity(parent: Instance)
	identityCard = UI.card(parent, "Identity")
	identityCard.Position = UDim2.fromOffset(18, 18)
	identityCard.Size = UDim2.fromOffset(268, 116)
	UI.padding(identityCard, 14)
	UI.shadow(identityCard)

	buildBust(identityCard)

	UI.label(identityCard, "Name", {
		text = Players.LocalPlayer.DisplayName,
		font = UI.font.bold,
		size = 14,
		extent = UDim2.new(1, -62, 0, 17),
		position = UDim2.fromOffset(62, 0),
	})

	seasonChip = UI.chip(identityCard, "Season", {
		text = "SEASON 1",
		textSize = 9,
		extent = UDim2.fromOffset(74, 16),
		position = UDim2.fromOffset(62, 19),
		zIndex = 3,
	})

	UI.glyph(identityCard, "coin", {
		color = UI.color.gold,
		extent = UDim2.fromOffset(19, 19),
		position = UDim2.fromOffset(62, 42),
		zIndex = 4,
	})

	local yenLabel
	yenLabel, yenSet = UI.ticker(identityCard, "Yen", {
		text = "0",
		font = UI.font.display,
		size = 25,
		extent = UDim2.new(1, -86, 0, 30),
		position = UDim2.fromOffset(86, 38),
	})
	yenLabel.TextTruncate = Enum.TextTruncate.AtEnd

	wageLabel = UI.label(identityCard, "Wage", {
		text = "0 / min",
		font = UI.font.light,
		size = 12,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -62, 0, 15),
		position = UDim2.fromOffset(62, 68),
	})

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.fromOffset(0, 86)
	divider.BackgroundColor3 = UI.color.line
	divider.BorderSizePixel = 0
	divider.ZIndex = 3
	divider.Parent = identityCard

	UI.glyph(identityCard, "stamp", {
		color = UI.color.inkSoft,
		extent = UDim2.fromOffset(14, 14),
		position = UDim2.fromOffset(0, 92),
		zIndex = 4,
	})

	stampLabel = UI.label(identityCard, "Stamps", {
		text = "0 stamps",
		font = UI.font.body,
		size = 12,
		color = UI.color.inkSoft,
		extent = UDim2.new(1, -20, 0, 16),
		position = UDim2.fromOffset(20, 91),
	})
end

--------------------------------------------------------------------------------
-- Active buffs
--------------------------------------------------------------------------------

local function buffLabel(boost: any): string
	if boost.skill then
		local skill = Skills.get(boost.skill)
		return if skill then string.upper(string.sub(skill.name, 1, 3)) else "ALL"
	end
	if boost.stat == "yen" then
		return "YEN"
	end
	if boost.stat == "staminaRegen" then
		return "STA"
	end
	return "ALL"
end

local function buffColor(boost: any): Color3
	return (boost.skill and UI.color[boost.skill]) or UI.color.gold
end

local function buildBuffs(parent: Instance)
	buffHolder = Instance.new("Frame")
	buffHolder.Name = "Buffs"
	buffHolder.Position = UDim2.fromOffset(18, 140)
	buffHolder.Size = UDim2.fromOffset(300, 24)
	buffHolder.BackgroundTransparency = 1
	buffHolder.Visible = false
	buffHolder.ZIndex = 4
	buffHolder.Parent = parent

	UI.list(buffHolder, UI.space.tight).FillDirection = Enum.FillDirection.Horizontal
end

local function updateBuffs(boosts: { any }?)
	local now = os.time()
	local active = {}
	local key = ""

	local all: { any } = boosts or {}
	for _, boost in all do
		if (boost.expiresAt or 0) - now > 0 then
			table.insert(active, boost)
			key ..= `{boost.id};`
		end
	end

	-- Chips are rebuilt only when the set changes; the countdown is text.
	if key ~= buffKey then
		buffKey = key
		buffChips = {}
		for _, child in buffHolder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		for index, boost in active do
			local chip = UI.chip(buffHolder, boost.id, {
				text = "",
				textSize = 11,
				color = buffColor(boost),
				textColor = UI.color.paperDeep,
				extent = UDim2.fromOffset(96, 24),
				zIndex = 5,
			})
			chip.LayoutOrder = index
			table.insert(buffChips, chip:FindFirstChild("Text") :: TextLabel)
		end
	end

	-- Same key means the same boosts in the same order, so index matches.
	for index, label in buffChips do
		local boost = active[index]
		label.Text = `x{boost.multiplier} {buffLabel(boost)} {boost.expiresAt - now}s`
	end

	buffHolder.Visible = #active > 0
end

--------------------------------------------------------------------------------
-- Side rail
--------------------------------------------------------------------------------

--[[
	Round buttons down the left edge, under the identity card.

	One shape, stacked, rather than a labelled pill in whichever corner each
	panel's author picked — the Atlas button used to sit alone in the bottom
	right, which is now where the skill bar's fourth button lives.
]]
local function buildSideRail(parent: Instance, buttons: { { glyph: string, hint: string, activated: () -> () } })
	local rail = Instance.new("Frame")
	rail.Name = "SideRail"
	rail.Position = UDim2.fromOffset(18, 174)
	rail.Size = UDim2.fromOffset(52, #buttons * 60)
	rail.BackgroundTransparency = 1
	rail.ZIndex = 4
	rail.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = rail

	for index, spec in buttons do
		local button = Instance.new("TextButton")
		button.Name = spec.glyph
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(52, 52)
		button.BackgroundColor3 = UI.color.paper
		button.AutoButtonColor = false
		button.Text = ""
		button.ZIndex = 5
		button.Parent = rail
		UI.corner(button, UI.radius.pill)
		UI.stroke(button, UI.color.line, UI.Theme.stroke.heavy)

		UI.glyph(button, spec.glyph, {
			color = UI.color.ink,
			extent = UDim2.fromOffset(22, 22),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			zIndex = 6,
		})

		-- The keyboard shortcut on the button, same trick as the skill badges.
		local hint = Instance.new("Frame")
		hint.Name = "Hint"
		hint.AnchorPoint = Vector2.new(0.5, 0.5)
		hint.Position = UDim2.fromScale(0.92, 0.9)
		hint.Size = UDim2.fromOffset(18, 18)
		hint.BackgroundColor3 = UI.color.paperDeep
		hint.BorderSizePixel = 0
		hint.ZIndex = 7
		hint.Parent = button
		UI.corner(hint, UI.radius.pill)
		UI.stroke(hint, UI.color.line, UI.Theme.stroke.base)

		UI.label(hint, "Key", {
			text = spec.hint,
			font = UI.font.bold,
			size = 10,
			color = UI.color.inkSoft,
			align = Enum.TextXAlignment.Center,
			extent = UDim2.fromScale(1, 1),
			zIndex = 8,
		})

		button.Activated:Connect(spec.activated)
	end
end

--------------------------------------------------------------------------------
-- Toasts
--------------------------------------------------------------------------------

local TOAST_GLYPH = {
	unlock = "home",
	locked = "lock",
	travel = "pin",
	info = "leaf",
}

local function buildToasts(parent: Instance)
	toastHolder = Instance.new("Frame")
	toastHolder.Name = "Toasts"
	toastHolder.AnchorPoint = Vector2.new(0.5, 0)
	toastHolder.Position = UDim2.new(0.5, 0, 0, 18)
	toastHolder.Size = UDim2.fromOffset(420, 260)
	toastHolder.BackgroundTransparency = 1
	toastHolder.ZIndex = 10
	toastHolder.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = toastHolder
end

local function showToast(message: string, kind: string)
	local isUnlock = kind == "unlock"

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 44)
	card.BackgroundColor3 = if isUnlock then UI.color.leaf else UI.color.paper
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ZIndex = 11
	card.Parent = toastHolder
	UI.corner(card, UI.radius.card)
	local stroke = UI.stroke(card, if isUnlock then UI.color.leafDeep else UI.color.line)
	stroke.Transparency = 1

	local glyph = UI.glyph(card, TOAST_GLYPH[kind] or "leaf", {
		color = if isUnlock then UI.color.white else UI.color.inkSoft,
		extent = UDim2.fromOffset(16, 16),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, 14, 0.5, 0),
		zIndex = 12,
	})

	local text = UI.label(card, "Text", {
		text = message,
		font = if isUnlock then UI.font.bold else UI.font.body,
		size = 13,
		color = if isUnlock then UI.color.white else UI.color.ink,
		align = Enum.TextXAlignment.Left,
		wrapped = true,
		extent = UDim2.new(1, -50, 1, 0),
		position = UDim2.fromOffset(38, 0),
		zIndex = 12,
	})
	text.TextTransparency = 1

	UI.motion.to(card, UI.motion.settle, { BackgroundTransparency = 0.02 })
	UI.motion.to(stroke, UI.motion.settle, { Transparency = 0.35 })
	UI.motion.to(text, UI.motion.settle, { TextTransparency = 0 })

	task.delay(3.6, function()
		UI.motion.to(text, UI.motion.wipe, { TextTransparency = 1 })
		UI.motion.to(glyph, UI.motion.wipe, { BackgroundTransparency = 1 })
		UI.motion.to(stroke, UI.motion.wipe, { Transparency = 1 })
		local out = UI.motion.play(card, UI.motion.wipe, { BackgroundTransparency = 1 })
		out.Completed:Wait()
		card:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Behaviour
--------------------------------------------------------------------------------

--[[
	Fraction of the way from the current worksite tier's requirement to the next
	one. Computed in log space because the ladder is geometric — a linear bar
	over 1e5..1e6 would sit pinned at zero for most of the climb.

	Also returns how many tiers are already met, which is what the pips show.
]]
local function tierProgress(skillId: string, value: any): (number, number)
	local ladder = Worksites.getLadder(skillId)
	if #ladder == 0 then
		return 0, 0
	end

	local current = BigNumber.log10(value)
	if current < 0 then
		current = 0
	end

	local lower = 0
	local met = 0

	for _, worksite in ladder do
		local requirement = BigNumber.log10(BigNumber.coerce(worksite.requirement))
		if current < requirement then
			local span = requirement - lower
			if span <= 0 then
				return 1, met
			end
			return math.clamp((current - lower) / span, 0, 1), met
		end
		met += 1
		lower = requirement
	end

	return 1, met -- past the top of the ladder
end

local function update(snapshot: any)
	yenSet(BigNumber.toString(snapshot.yen), BigNumber.toNumber(snapshot.yen))
	wageLabel.Text = `{BigNumber.toString(snapshot.yenPerMinute)} / min`
	stampLabel.Text = `{BigNumber.toString(snapshot.stamps)} stamps`

	updateBuffs(snapshot.boosts)

	local season = (snapshot.seasons or 0) + 1
	local seasonText = seasonChip:FindFirstChild("Text") :: TextLabel?
	if seasonText then
		seasonText.Text = `SEASON {season}`
	end

	--[[
		Two different states share this stack, and they are not the same thing:

		  ACTIVE   the skill a click would raise right now — the pad under your
		           feet if there is one, otherwise your selection.
		  SELECTED what free-form clicking raises when you are not on a pad.

		Standing on a Cooking pad with Weeding selected, Cooking is active and
		Weeding is still selected; step off and Weeding takes over. Showing only
		one of the two would make the other one's behaviour look like a bug.
	]]
	local working = snapshot.currentWorksite and Worksites.get(snapshot.currentWorksite)
	local nowActive = working and working.skill or snapshot.selectedSkill
	local activeChanged = nowActive ~= activeSkill or snapshot.selectedSkill ~= selectedSkill
	activeSkill = nowActive
	selectedSkill = snapshot.selectedSkill

	for skillId, entry in skillEntries do
		local value = snapshot.skills[skillId]
		local text = if value then BigNumber.toString(value) else "0"
		entry.setValue(text, if value then BigNumber.toNumber(value) else nil)

		-- Written long rather than as a conditional expression: `if ... then f()
		-- else 0, 0` only ever binds one value, so `met` would silently be nil
		-- and every pip strip would read empty.
		local progress, met = 0, 0
		if value then
			progress, met = tierProgress(skillId, value)
		end
		entry.setProgress(progress)
		entry.setPips(met)

		local order = snapshot.certifications[skillId] or 0
		entry.setGrade(if order > 0 then Certifications.describe(order) else nil)

		if activeChanged then
			entry.setState(skillId == activeSkill, skillId == selectedSkill)
		end
	end

	WorkCore.update(snapshot)
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

--[[
	Phone screens cannot carry three side panels. Drop the secondary ones rather
	than shrinking everything into illegibility — the work core stays, because it
	is the only one you cannot play without.
]]
local function applyResponsiveLayout()
	local compact = screen.AbsoluteSize.X < COMPACT_WIDTH

	-- The minimap is NOT touched here any more. It is hidden by default and
	-- owned by its own M toggle, so forcing Visible from the layout pass would
	-- reopen it every time the window resized.

	-- The skill bar stays at every width — it is the primary control, not a
	-- side panel. It only shrinks, so four buttons still fit on a phone.
	if skillBarHolder then
		skillBarHolder.Size = UDim2.fromOffset(if compact then 300 else 4 * 82 + 3 * 10, if compact then 92 else 106)
	end

	-- On a narrow screen the identity card sheds its lower half rather than
	-- disappearing: the purse is the one number a player checks constantly.
	identityCard.Size = if compact then UDim2.fromOffset(212, 78) else UDim2.fromOffset(268, 116)
end

function HUD.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "HUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	buildIdentity(screen)
	buildBuffs(screen)
	buildToasts(screen)

	skillEntries, skillBarHolder = SkillBar.build(screen, function()
		showToast("Resilience grows from cooking, running and jumping.", "info")
	end)
	Minimap.build(screen)
	WorkCore.build(screen)

	-- The Atlas gets its own ScreenGui at a higher DisplayOrder: it is a modal
	-- and must cover the HUD rather than fight it for ZIndex.
	local atlasScreen = Instance.new("ScreenGui")
	atlasScreen.Name = "Atlas"
	atlasScreen.ResetOnSpawn = false
	atlasScreen.DisplayOrder = 10
	atlasScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	atlasScreen.Parent = playerGui
	Atlas.build(atlasScreen)

	-- A permanent way in, since not every player will try the M key. The bottom
	-- right is the skill bar's now, so these live on the left rail instead.
	buildSideRail(screen, {
		{
			glyph = "pin",
			hint = "M",
			activated = function()
				Minimap.toggle()
			end,
		},
		{
			glyph = "map",
			hint = "N",
			activated = function()
				Atlas.toggle()
			end,
		},
		{
			glyph = "platter",
			hint = "I",
			activated = function()
				InventoryMenu.toggle()
			end,
		},
		{
			glyph = "help",
			hint = "H",
			activated = function()
				ControlsPanel.setOpen(true)
			end,
		},
	})

	applyResponsiveLayout()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout)
	UserInputService.LastInputTypeChanged:Connect(applyResponsiveLayout)

	StateController.onChanged(update)

	-- Work.Feedback is NOT wired here any more — FeedbackController owns the
	-- "+N" and everything else that happens when a click lands.
	Remotes.event("Notify", "Message").OnClientEvent:Connect(showToast)
end

return HUD

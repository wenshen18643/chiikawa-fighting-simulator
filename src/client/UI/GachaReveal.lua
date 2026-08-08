--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared.UI)
local InputMode = require(script.Parent.InputMode)

export type PullResult = {
	skinId: string,
	rarity: string,
	isNew: boolean,
}

export type Presentation = {
	name: string,
	subtitle: string,
	rarityName: string,
	rarityColor: Color3,
	rarityOrder: number,
	mountPreview: ((parent: Instance, hero: boolean) -> GuiObject?)?,
}

export type Presenter = (result: PullResult) -> Presentation?

local GachaReveal = {}
local BACKDROP = Color3.fromRGB(8, 12, 30)
local SKY_TOP = Color3.fromRGB(32, 50, 92)
local WHITE = Color3.fromRGB(255, 250, 235)
local GOLD = Color3.fromRGB(255, 214, 122)

GachaReveal.CINEMATIC_ORDER = 5

local CHARMS = { "💖", "⭐", "✨", "🌸", "🎀", "💫", "🍬" }
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 176, 208),
	Color3.fromRGB(255, 226, 150),
	Color3.fromRGB(168, 226, 255),
	Color3.fromRGB(196, 246, 202),
	Color3.fromRGB(214, 190, 255),
}

local PACE = 1.6
local CINEMATIC_BEATS = 3
local CINEMATIC_BEAT = 0.26
local CINEMATIC_CHARGE = CINEMATIC_BEATS * CINEMATIC_BEAT
local CINEMATIC_BURST = CINEMATIC_CHARGE + 0.34
local CINEMATIC_HOLD = CINEMATIC_BURST + 2.1

local function corner(parent: GuiObject, radius: UDim)
	local item = Instance.new("UICorner")
	item.CornerRadius = radius
	item.Parent = parent
end

local function tween(instance: Instance, duration: number, style: Enum.EasingStyle, goal: { [string]: any }): Tween
	return UI.motion.play(instance, TweenInfo.new(duration * PACE, style, Enum.EasingDirection.Out), goal)
end

local function after(seconds: number, callback: () -> ())
	task.delay(if UI.motion.isReducedMotion() then seconds else seconds * PACE, callback)
end

local function spin(instance: GuiObject, seconds: number, clockwise: boolean)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	TweenService:Create(instance, info, { Rotation = if clockwise then 360 else -360 }):Play()
end

local function makeStar(parent: Instance, rng: Random): Frame
	local size = rng:NextInteger(2, 6)
	local star = Instance.new("Frame")
	star.Name = "Star"
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.BackgroundColor3 = WHITE
	star.BackgroundTransparency = rng:NextNumber(0.15, 0.65)
	star.BorderSizePixel = 0
	star.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
	star.Size = UDim2.fromOffset(size, size)
	star.ZIndex = 102
	star.Parent = parent
	corner(star, UDim.new(1, 0))
	return star
end

local function makeStreak(parent: Instance, rng: Random, color: Color3)
	local length = rng:NextInteger(90, 260)
	local streak = Instance.new("Frame")
	streak.Name = "WishTrail"
	streak.AnchorPoint = Vector2.new(0.5, 0.5)
	streak.BackgroundColor3 = color:Lerp(WHITE, rng:NextNumber(0.15, 0.65))
	streak.BackgroundTransparency = rng:NextNumber(0.25, 0.65)
	streak.BorderSizePixel = 0
	streak.Position = UDim2.new(rng:NextNumber(-0.2, 0.8), 0, rng:NextNumber(0.35, 1.2), 0)
	streak.Rotation = -32
	streak.Size = UDim2.fromOffset(length, rng:NextInteger(2, 5))
	streak.ZIndex = 104
	streak.Parent = parent
	corner(streak, UDim.new(1, 0))

	local flight = tween(streak, rng:NextNumber(0.38, 0.68), Enum.EasingStyle.Quad, {
		Position = streak.Position + UDim2.fromScale(0.55, -0.7),
		BackgroundTransparency = 1,
	})
	flight.Completed:Connect(function()
		streak:Destroy()
	end)
end

local function makeRing(parent: Instance, color: Color3, span: number, thickness: number, life: number): Frame
	local ring = Instance.new("Frame")
	ring.Name = "ImpactRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.fromScale(0.5, 0.43)
	ring.Size = UDim2.fromOffset(24, 24)
	ring.ZIndex = 106
	ring.Parent = parent
	corner(ring, UDim.new(1, 0))

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.05
	stroke.Parent = ring

	tween(ring, life, Enum.EasingStyle.Quint, { Size = UDim2.fromScale(span, span) })
	tween(stroke, life * 0.92, Enum.EasingStyle.Quad, { Thickness = 1, Transparency = 1 })
	return ring
end

local function makeSunburst(parent: Instance, color: Color3): Frame
	local hub = Instance.new("Frame")
	hub.Name = "Sunburst"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.BackgroundTransparency = 1
	hub.Position = UDim2.fromScale(0.5, 0.36)
	hub.Size = UDim2.fromScale(1.6, 1.6)
	hub.SizeConstraint = Enum.SizeConstraint.RelativeYY
	hub.ZIndex = 105
	hub.Parent = parent

	local group = Instance.new("UIScale")
	group.Scale = 0.1
	group.Parent = hub

	for index = 1, 12 do
		local ray = Instance.new("Frame")
		ray.Name = `Ray_{index}`
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.BackgroundColor3 = if index % 2 == 0 then color else color:Lerp(WHITE, 0.55)
		ray.BackgroundTransparency = 0.62
		ray.BorderSizePixel = 0
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Rotation = index * 15
		ray.Size = UDim2.fromScale(0.055, 1)
		ray.ZIndex = 105
		ray.Parent = hub

		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
	end

	tween(group, 0.7, Enum.EasingStyle.Quint, { Scale = 1 })
	spin(hub, 26, true)
	return hub
end

local function makeCharm(parent: Instance, rng: Random, size: number): TextLabel
	local charm = Instance.new("TextLabel")
	charm.Name = "Charm"
	charm.AnchorPoint = Vector2.new(0.5, 0.5)
	charm.BackgroundTransparency = 1
	charm.Font = UI.font.bold
	charm.Size = UDim2.fromOffset(size, size)
	charm.Text = CHARMS[rng:NextInteger(1, #CHARMS)]
	charm.TextSize = size
	charm.ZIndex = 118
	charm.Parent = parent
	return charm
end

local function burstConfetti(parent: Instance, rng: Random)
	for index = 1, 26 do
		local angle = (index / 26) * math.pi * 2 + rng:NextNumber(-0.16, 0.16)
		local reach = rng:NextNumber(0.24, 0.52)
		local piece: GuiObject
		if index % 3 == 0 then
			piece = makeCharm(parent, rng, rng:NextInteger(20, 34))
		else
			local flake = Instance.new("Frame")
			flake.Name = "Confetti"
			flake.AnchorPoint = Vector2.new(0.5, 0.5)
			flake.BackgroundColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
			flake.BorderSizePixel = 0
			flake.Rotation = rng:NextInteger(0, 180)
			flake.Size = UDim2.fromOffset(rng:NextInteger(8, 16), rng:NextInteger(8, 16))
			flake.ZIndex = 118
			flake.Parent = parent
			corner(flake, UDim.new(0.35, 0))
			piece = flake
		end

		piece.Position = UDim2.fromScale(0.5, 0.4)
		local flight = tween(piece, rng:NextNumber(0.7, 1.15), Enum.EasingStyle.Quint, {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * reach, 0.4 + math.sin(angle) * reach * 0.86),
			Rotation = piece.Rotation + rng:NextInteger(-220, 220),
		})
		if piece:IsA("TextLabel") then
			tween(piece, 1.4, Enum.EasingStyle.Quad, { TextTransparency = 1 })
		else
			tween(piece, 1.4, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
		end
		flight.Completed:Connect(function()
			piece:Destroy()
		end)
	end
end

local function floatCharm(parent: Instance, rng: Random)
	local charm = makeCharm(parent, rng, rng:NextInteger(18, 30))
	charm.Position = UDim2.fromScale(rng:NextNumber(0.12, 0.88), 1.08)
	charm.TextTransparency = 0.15
	local rise = tween(charm, rng:NextNumber(1.6, 2.6), Enum.EasingStyle.Sine, {
		Position = charm.Position - UDim2.fromScale(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0.75, 1.2)),
		TextTransparency = 1,
		Rotation = rng:NextInteger(-40, 40),
	})
	rise.Completed:Connect(function()
		charm:Destroy()
	end)
end

local function makeBanner(parent: Instance, presentation: Presentation)
	local banner = Instance.new("Frame")
	banner.Name = "LegendaryBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.BackgroundColor3 = Color3.fromRGB(26, 20, 44)
	banner.BackgroundTransparency = 0.12
	banner.BorderSizePixel = 0
	banner.Position = UDim2.fromScale(-0.6, 0.5)
	banner.Size = UDim2.new(1.25, 0, 0, 46)
	banner.ZIndex = 112
	banner.Parent = parent

	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 20, 44)),
		ColorSequenceKeypoint.new(0.5, presentation.rarityColor:Lerp(Color3.fromRGB(26, 20, 44), 0.45)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 20, 44)),
	})
	sheen.Parent = banner

	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 2
	edge.Transparency = 0.25
	edge.Parent = banner

	local ribbon = Instance.new("TextLabel")
	ribbon.Name = "Ribbon"
	ribbon.BackgroundTransparency = 1
	ribbon.Font = UI.font.bold
	ribbon.Size = UDim2.fromScale(1, 1)
	ribbon.Text = `✨  {string.upper(presentation.rarityName)}  ·  {presentation.subtitle}  ✨`
	ribbon.TextColor3 = GOLD
	ribbon.TextSize = 20
	ribbon.ZIndex = 113
	ribbon.Parent = banner

	tween(banner, 0.42, Enum.EasingStyle.Back, { Position = UDim2.fromScale(0.5, 0.5) })
end

local function makeContinuePrompt(parent: Instance, onContinue: () -> ())
	local gate = Instance.new("TextButton")
	gate.Name = "ContinueGate"
	gate.AutoButtonColor = false
	gate.BackgroundTransparency = 1
	gate.Size = UDim2.fromScale(1, 1)
	gate.Text = ""
	gate.ZIndex = 119
	gate.Parent = parent

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0.5)
	hint.BackgroundTransparency = 1
	hint.Font = UI.font.bold
	hint.Position = UDim2.fromScale(0.5, 0.9)
	hint.Size = UDim2.fromOffset(340, 32)
	hint.Text = "♡  tap anywhere to continue  ♡"
	hint.TextColor3 = WHITE
	hint.TextSize = 20
	hint.TextStrokeColor3 = BACKDROP
	hint.TextStrokeTransparency = 0.35
	hint.TextTransparency = 0.1
	hint.ZIndex = 119
	hint.Parent = gate

	if not UI.motion.isReducedMotion() then
		local breathe = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(hint, breathe, { TextTransparency = 0.6 }):Play()
	end

	gate.Activated:Connect(onContinue)
end

local function makeResultLabels(
	parent: Instance,
	result: PullResult,
	presentation: Presentation,
	index: number,
	total: number,
	hero: boolean
)
	local mountPreview = presentation.mountPreview
	local stage: Frame? = nil
	local stageSize = UDim2.fromOffset(0, 0)

	if mountPreview then
		local host = Instance.new("Frame")
		host.Name = "PreviewStage"
		host.AnchorPoint = Vector2.new(0.5, 0.5)
		host.BackgroundTransparency = 1
		host.Position = UDim2.fromScale(0.5, 0.36)
		host.Size = UDim2.fromOffset(0, 0)
		host.ZIndex = 117
		host.Parent = parent

		local preview = mountPreview(host, true)
		if preview then
			preview.Size = UDim2.fromScale(1, 1)
			stage = host
			local span = (216 + presentation.rarityOrder * 26) * (if hero then 1.12 else 1)
			stageSize = UDim2.fromOffset(span, span)
		else
			host:Destroy()
		end
	end

	local counter = Instance.new("TextLabel")
	counter.Name = "Counter"
	counter.AnchorPoint = Vector2.new(0.5, 0.5)
	counter.BackgroundTransparency = 1
	counter.Font = UI.font.bold
	counter.Position = UDim2.fromScale(0.5, 0.16)
	counter.Size = UDim2.fromOffset(220, 30)
	counter.Text = `PULL {index} / {total}`
	counter.TextColor3 = WHITE
	counter.TextSize = UI.text.small
	counter.TextTransparency = 0.15
	counter.ZIndex = 116
	counter.Parent = parent

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = UI.font.bold
	rarityLabel.Position = UDim2.fromScale(0.5, if hero then 0.6 else 0.57)
	rarityLabel.Size = UDim2.fromScale(0.8, 0.07)
	rarityLabel.Text = if hero then `★ {string.upper(presentation.rarityName)} ★` else string.upper(presentation.rarityName)
	rarityLabel.TextColor3 = if hero then GOLD else presentation.rarityColor
	rarityLabel.TextSize = 18
	rarityLabel.TextStrokeColor3 = BACKDROP
	rarityLabel.TextStrokeTransparency = 0.25
	rarityLabel.TextTransparency = 1
	rarityLabel.ZIndex = 116
	rarityLabel.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "SkinName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = UI.font.display
	nameLabel.Position = if stage then UDim2.fromScale(0.5, 0.68) else UDim2.fromScale(0.5, 0.64)
	nameLabel.Size = if stage then UDim2.fromScale(0.82, 0.08) else UDim2.fromScale(0.82, 0.1)
	nameLabel.Text = presentation.name
	nameLabel.TextColor3 = WHITE
	nameLabel.TextSize = if stage then 16 else 26
	nameLabel.TextStrokeColor3 = BACKDROP
	nameLabel.TextStrokeTransparency = 0.15
	nameLabel.TextTransparency = 1
	nameLabel.ZIndex = 116
	nameLabel.Parent = parent

	local copyLabel = Instance.new("TextLabel")
	copyLabel.Name = "CopyState"
	copyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	copyLabel.BackgroundTransparency = 1
	copyLabel.Font = UI.font.bold
	copyLabel.Position = UDim2.fromScale(0.5, if hero then 0.76 else 0.72)
	copyLabel.Size = UDim2.fromOffset(240, 30)
	copyLabel.Text = if result.isNew then "NEW!" else "EXTRA COPY"
	copyLabel.TextColor3 = if result.isNew then Color3.fromRGB(138, 244, 192) else Color3.fromRGB(196, 202, 220)
	copyLabel.TextSize = UI.text.small
	copyLabel.TextTransparency = 1
	copyLabel.ZIndex = 116
	copyLabel.Parent = parent

	local nameTarget = if stage then (if hero then 30 else 24) else 42

	if UI.motion.isReducedMotion() then
		if stage then
			stage.Size = stageSize
		end
		rarityLabel.TextTransparency = 0
		nameLabel.TextTransparency = 0
		copyLabel.TextTransparency = 0
		return
	end

	if stage then
		tween(stage, if hero then 0.5 else 0.34, Enum.EasingStyle.Back, { Size = stageSize })
	end
	tween(rarityLabel, if hero then 0.4 else 0.28, Enum.EasingStyle.Back, {
		TextSize = if hero then 46 else 34,
		TextTransparency = 0,
	})
	tween(nameLabel, 0.32, Enum.EasingStyle.Back, { TextSize = nameTarget, TextTransparency = 0 })
	tween(copyLabel, 0.25, Enum.EasingStyle.Quad, { TextTransparency = 0 })
end

function GachaReveal.play(
	parent: PlayerGui,
	results: { PullResult },
	present: Presenter,
	onComplete: () -> ()
): () -> ()
	local rng = Random.new()
	local previousSelection = GuiService.SelectedObject
	local finished = false
	local skipping = false
	local sceneGeneration = 0
	local activeScene: Frame? = nil
	local nextIndex = 1
	local screen = Instance.new("ScreenGui")
	screen.Name = "GachaWishReveal"
	screen.DisplayOrder = 80
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = parent

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Active = true
	overlay.BackgroundColor3 = BACKDROP
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 100
	overlay.Parent = screen

	local sky = Instance.new("UIGradient")
	sky.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, SKY_TOP),
		ColorSequenceKeypoint.new(0.58, BACKDROP),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 5, 15)),
	})
	sky.Rotation = 90
	sky.Parent = overlay

	for _ = 1, 38 do
		local star = makeStar(overlay, rng)
		tween(star, rng:NextNumber(1.1, 2.2), Enum.EasingStyle.Sine, {
			BackgroundTransparency = 0.8,
			Size = star.Size + UDim2.fromOffset(3, 3),
		})
	end

	local skipButton = Instance.new("TextButton")
	skipButton.Name = "Skip"
	skipButton.AnchorPoint = Vector2.new(1, 1)
	skipButton.AutoButtonColor = false
	skipButton.BackgroundColor3 = Color3.fromRGB(20, 27, 50)
	skipButton.BackgroundTransparency = 0.2
	skipButton.BorderSizePixel = 0
	skipButton.Font = UI.font.bold
	skipButton.Position = UDim2.new(1, -24, 1, -22)
	skipButton.Size = UDim2.fromOffset(128, 44)
	skipButton.Text = "Skip all"
	skipButton.TextColor3 = WHITE
	skipButton.TextSize = UI.text.small
	skipButton.ZIndex = 120
	skipButton.Parent = overlay
	corner(skipButton, UDim.new(1, 0))

	local function isCinematic(presentation: Presentation): boolean
		return presentation.rarityOrder >= GachaReveal.CINEMATIC_ORDER
	end

	local function close(completed: boolean)
		if finished then
			return
		end
		finished = true
		sceneGeneration += 1
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screen) then
			GuiService.SelectedObject = if previousSelection and previousSelection:IsDescendantOf(game)
				then previousSelection
				else nil
		end
		screen:Destroy()
		if completed then
			onComplete()
		end
	end

	local function resolve(result: PullResult): Presentation
		return present(result)
			or {
				name = "Mystery Skin",
				subtitle = "Unknown item",
				rarityName = "Unknown",
				rarityColor = Color3.fromRGB(178, 158, 152),
				rarityOrder = 1,
				mountPreview = nil,
			}
	end

	local playNext: () -> ()

	playNext = function()
		if finished then
			return
		end

		local presentation: Presentation? = nil
		while nextIndex <= #results do
			local candidate = resolve(results[nextIndex])
			if not skipping or isCinematic(candidate) then
				presentation = candidate
				break
			end
			nextIndex += 1
		end
		if not presentation then
			close(true)
			return
		end

		if activeScene then
			activeScene:Destroy()
		end
		sceneGeneration += 1
		local generation = sceneGeneration
		local index = nextIndex
		nextIndex += 1
		local result = results[index]
		local hero = isCinematic(presentation)
		skipButton.Visible = not hero

		local scene = Instance.new("Frame")
		scene.Name = `Pull{index}`
		scene.BackgroundTransparency = 1
		scene.Size = UDim2.fromScale(1, 1)
		scene.ZIndex = 103
		scene.Parent = overlay
		activeScene = scene

		local function isCurrent(): boolean
			return not finished and sceneGeneration == generation and scene.Parent ~= nil
		end

		local function advance()
			if isCurrent() then
				playNext()
			end
		end

		if UI.motion.isReducedMotion() then
			makeResultLabels(scene, result, presentation, index, #results, hero)
			if hero then
				makeContinuePrompt(scene, advance)
			else
				task.delay(0.55, advance)
			end
			return
		end

		if hero then
			local charge = Instance.new("Frame")
			charge.Name = "WishHeart"
			charge.AnchorPoint = Vector2.new(0.5, 0.5)
			charge.BackgroundColor3 = WHITE
			charge.BorderSizePixel = 0
			charge.Position = UDim2.fromScale(0.5, 0.36)
			charge.Size = UDim2.fromOffset(18, 18)
			charge.ZIndex = 110
			charge.Parent = scene
			corner(charge, UDim.new(1, 0))

			local halo = Instance.new("UIStroke")
			halo.Color = presentation.rarityColor
			halo.Thickness = 3
			halo.Transparency = 0.2
			halo.Parent = charge

			for beat = 1, CINEMATIC_BEATS do
				after((beat - 1) * CINEMATIC_BEAT, function()
					if not isCurrent() then
						return
					end
					local span = 22 + beat * 16
					tween(charge, CINEMATIC_BEAT * 0.44, Enum.EasingStyle.Back, {
						Size = UDim2.fromOffset(span, span),
					})
					makeRing(scene, presentation.rarityColor, 0.24 + beat * 0.12, 3, CINEMATIC_BEAT * 0.9)
					floatCharm(scene, rng)
					floatCharm(scene, rng)
				end)
			end

			after(CINEMATIC_CHARGE, function()
				if not isCurrent() then
					return
				end
				makeSunburst(scene, presentation.rarityColor)
				tween(charge, 0.3, Enum.EasingStyle.Quint, {
					Size = UDim2.fromOffset(260, 260),
					BackgroundTransparency = 1,
				})
				tween(halo, 0.3, Enum.EasingStyle.Quad, { Transparency = 1, Thickness = 1 })
			end)

			after(CINEMATIC_BURST, function()
				if not isCurrent() then
					return
				end

				local flash = Instance.new("Frame")
				flash.Name = "LegendaryFlash"
				flash.BackgroundColor3 = WHITE
				flash.BackgroundTransparency = 1
				flash.BorderSizePixel = 0
				flash.Size = UDim2.fromScale(1, 1)
				flash.ZIndex = 115
				flash.Parent = scene
				tween(flash, 0.08, Enum.EasingStyle.Quad, { BackgroundTransparency = 0 })
				after(0.09, function()
					if flash.Parent then
						tween(flash, 0.45, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
					end
				end)

				for wave = 1, 3 do
					after(wave * 0.09, function()
						if isCurrent() then
							makeRing(scene, if wave % 2 == 0 then GOLD else presentation.rarityColor, 1.5, 6, 0.85)
						end
					end)
				end

				burstConfetti(scene, rng)
				makeBanner(scene, presentation)
				makeResultLabels(scene, result, presentation, index, #results, true)
			end)

			for wave = 1, 14 do
				after(CINEMATIC_BURST + wave * 0.17, function()
					if isCurrent() then
						floatCharm(scene, rng)
					end
				end)
			end

			after(CINEMATIC_HOLD, function()
				if not isCurrent() then
					return
				end
				makeContinuePrompt(scene, advance)
				task.spawn(function()
					while isCurrent() do
						floatCharm(scene, rng)
						task.wait(0.45)
					end
				end)
			end)
			return
		end

		local flare = Instance.new("Frame")
		flare.Name = "WishCoreGlow"
		flare.AnchorPoint = Vector2.new(0.5, 0.5)
		flare.BackgroundColor3 = presentation.rarityColor
		flare.BackgroundTransparency = 0.55
		flare.BorderSizePixel = 0
		flare.Position = UDim2.fromScale(-0.08, 0.95)
		flare.Size = UDim2.fromOffset(100, 100)
		flare.ZIndex = 108
		flare.Parent = scene
		corner(flare, UDim.new(1, 0))

		local core = Instance.new("Frame")
		core.Name = "WishCore"
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.BackgroundColor3 = WHITE
		core.BorderSizePixel = 0
		core.Position = UDim2.fromScale(0.5, 0.5)
		core.Rotation = 45
		core.Size = UDim2.fromOffset(32, 32)
		core.ZIndex = 109
		core.Parent = flare
		corner(core, UDim.new(0.22, 0))

		local travelTime = 0.5 + presentation.rarityOrder * 0.025
		local hasPreview = presentation.mountPreview ~= nil
		tween(flare, travelTime, Enum.EasingStyle.Quint, {
			Position = if hasPreview then UDim2.fromScale(0.5, 0.36) else UDim2.fromScale(0.5, 0.43),
			Size = UDim2.fromOffset(
				140 + presentation.rarityOrder * 10,
				140 + presentation.rarityOrder * 10
			),
		})
		tween(core, travelTime, Enum.EasingStyle.Quint, {
			Rotation = 225,
			Size = UDim2.fromOffset(40 + presentation.rarityOrder * 4, 40 + presentation.rarityOrder * 4),
		})

		for streakIndex = 1, 10 + presentation.rarityOrder * 4 do
			after(streakIndex * 0.012, function()
				if isCurrent() then
					makeStreak(scene, rng, presentation.rarityColor)
				end
			end)
		end

		after(travelTime * 0.72, function()
			if not isCurrent() then
				return
			end
			for _ = 1, math.max(1, presentation.rarityOrder - 1) do
				makeRing(scene, presentation.rarityColor, 0.82, 5, 0.55)
			end
		end)

		after(travelTime, function()
			if not isCurrent() then
				return
			end

			local flash = Instance.new("Frame")
			flash.Name = "RarityFlash"
			flash.BackgroundColor3 = presentation.rarityColor:Lerp(WHITE, 0.55)
			flash.BackgroundTransparency = 1
			flash.BorderSizePixel = 0
			flash.Size = UDim2.fromScale(1, 1)
			flash.ZIndex = 115
			flash.Parent = scene
			tween(flash, 0.1, Enum.EasingStyle.Quad, { BackgroundTransparency = 0.04 })
			after(0.09, function()
				if flash.Parent then
					tween(flash, 0.28, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
				end
			end)

			if hasPreview then
				tween(core, 0.26, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
				tween(flare, 0.4, Enum.EasingStyle.Quad, {
					BackgroundTransparency = 0.78,
					Size = UDim2.fromOffset(
						230 + presentation.rarityOrder * 30,
						230 + presentation.rarityOrder * 30
					),
				})
			end

			makeResultLabels(scene, result, presentation, index, #results, false)
		end)

		after(travelTime + 0.72, advance)
	end

	skipButton.Activated:Connect(function()
		if finished or skipping then
			return
		end
		skipping = true
		skipButton.Visible = false
		playNext()
	end)
	if InputMode.current() == "gamepad" then
		task.defer(function()
			if not finished then
				GuiService.SelectedObject = skipButton
			end
		end)
	end
	tween(overlay, 0.18, Enum.EasingStyle.Quad, { BackgroundTransparency = 0 })
	task.defer(playNext)

	return function()
		close(false)
	end
end

return GachaReveal

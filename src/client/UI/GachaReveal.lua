--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
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

local function corner(parent: GuiObject, radius: UDim)
	local item = Instance.new("UICorner")
	item.CornerRadius = radius
	item.Parent = parent
end

local function tween(instance: Instance, duration: number, style: Enum.EasingStyle, goal: { [string]: any }): Tween
	return UI.motion.play(instance, TweenInfo.new(duration, style, Enum.EasingDirection.Out), goal)
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

local function makeRing(parent: Instance, color: Color3): Frame
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
	stroke.Thickness = 5
	stroke.Transparency = 0.05
	stroke.Parent = ring

	tween(ring, 0.55, Enum.EasingStyle.Quint, { Size = UDim2.fromScale(0.82, 0.82) })
	tween(stroke, 0.5, Enum.EasingStyle.Quad, { Thickness = 1, Transparency = 1 })
	return ring
end

local function makeResultLabels(
	parent: Instance,
	result: PullResult,
	presentation: Presentation,
	index: number,
	total: number
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
			local span = 216 + presentation.rarityOrder * 26
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
	rarityLabel.Position = UDim2.fromScale(0.5, 0.57)
	rarityLabel.Size = UDim2.fromScale(0.8, 0.07)
	rarityLabel.Text = string.upper(presentation.rarityName)
	rarityLabel.TextColor3 = presentation.rarityColor
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
	nameLabel.Position = if stage then UDim2.fromScale(0.5, 0.65) else UDim2.fromScale(0.5, 0.64)
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
	copyLabel.Position = UDim2.fromScale(0.5, 0.72)
	copyLabel.Size = UDim2.fromOffset(240, 30)
	copyLabel.Text = if result.isNew then "NEW!" else "EXTRA COPY"
	copyLabel.TextColor3 = if result.isNew then Color3.fromRGB(138, 244, 192) else Color3.fromRGB(196, 202, 220)
	copyLabel.TextSize = UI.text.small
	copyLabel.TextTransparency = 1
	copyLabel.ZIndex = 116
	copyLabel.Parent = parent

	local nameTarget = if stage then 24 else 42

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
		tween(stage, 0.34, Enum.EasingStyle.Back, { Size = stageSize })
	end
	tween(rarityLabel, 0.28, Enum.EasingStyle.Back, { TextSize = 34, TextTransparency = 0 })
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

	local playNext: () -> ()

	playNext = function()
		if finished then
			return
		end
		if nextIndex > #results then
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
		local presentation: Presentation = present(result) or {
			name = "Mystery Skin",
			subtitle = "Unknown item",
			rarityName = "Unknown",
			rarityColor = Color3.fromRGB(178, 158, 152),
			rarityOrder = 1,
			mountPreview = nil,
		}
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

		if UI.motion.isReducedMotion() then
			makeResultLabels(scene, result, presentation, index, #results)
			task.delay(0.55, function()
				if isCurrent() then
					playNext()
				end
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
			task.delay(streakIndex * 0.012, function()
				if isCurrent() then
					makeStreak(scene, rng, presentation.rarityColor)
				end
			end)
		end

		task.delay(travelTime * 0.72, function()
			if not isCurrent() then
				return
			end
			for _ = 1, math.max(1, presentation.rarityOrder - 1) do
				makeRing(scene, presentation.rarityColor)
			end
		end)

		task.delay(travelTime, function()
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
			task.delay(0.09, function()
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

			makeResultLabels(scene, result, presentation, index, #results)
		end)

		task.delay(travelTime + 0.72, function()
			if isCurrent() then
				playNext()
			end
		end)
	end

	skipButton.Activated:Connect(function()
		close(true)
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

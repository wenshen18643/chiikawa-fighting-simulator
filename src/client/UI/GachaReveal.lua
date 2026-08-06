--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local UI = require(Shared.UI)

type PullResult = {
	skinId: string,
	rarity: CompanionSkins.RarityId,
	isNew: boolean,
}

local GachaReveal = {}
local BACKDROP = Color3.fromRGB(8, 12, 30)
local SKY_TOP = Color3.fromRGB(32, 50, 92)
local WHITE = Color3.fromRGB(255, 250, 235)

local function corner(parent: GuiObject, radius: UDim)
	local item = Instance.new("UICorner")
	item.CornerRadius = radius
	item.Parent = parent
end

local function highestRarity(results: { PullResult }): CompanionSkins.RarityDefinition
	local highest = CompanionSkins.RARITIES.common
	for _, result in results do
		local rarity = CompanionSkins.RARITIES[result.rarity]
		if rarity and rarity.order > highest.order then
			highest = rarity
		end
	end
	return highest
end

local function tween(instance: Instance, duration: number, style: Enum.EasingStyle, goal: { [string]: any }): Tween
	local info = TweenInfo.new(
		if UI.motion.isReducedMotion() then 0.01 else duration,
		style,
		Enum.EasingDirection.Out
	)
	local animation = TweenService:Create(instance, info, goal)
	animation:Play()
	return animation
end

local function makeStar(parent: Instance, rng: Random, zIndex: number): Frame
	local size = rng:NextInteger(2, 6)
	local star = Instance.new("Frame")
	star.Name = "Star"
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.BackgroundColor3 = WHITE
	star.BackgroundTransparency = rng:NextNumber(0.15, 0.65)
	star.BorderSizePixel = 0
	star.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
	star.Size = UDim2.fromOffset(size, size)
	star.ZIndex = zIndex
	star.Parent = parent
	corner(star, UDim.new(1, 0))
	return star
end

local function makeStreak(parent: Instance, rng: Random, color: Color3, zIndex: number)
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
	streak.ZIndex = zIndex
	streak.Parent = parent
	corner(streak, UDim.new(1, 0))

	local destination = streak.Position + UDim2.fromScale(0.55, -0.7)
	local flight = tween(streak, rng:NextNumber(0.45, 0.9), Enum.EasingStyle.Quad, {
		Position = destination,
		BackgroundTransparency = 1,
	})
	flight.Completed:Connect(function()
		streak:Destroy()
	end)
end

local function makeRing(parent: Instance, color: Color3, zIndex: number): Frame
	local ring = Instance.new("Frame")
	ring.Name = "ImpactRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.fromScale(0.5, 0.45)
	ring.Size = UDim2.fromOffset(24, 24)
	ring.ZIndex = zIndex
	ring.Parent = parent
	corner(ring, UDim.new(1, 0))

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 5
	stroke.Transparency = 0.05
	stroke.Parent = ring

	tween(ring, 0.7, Enum.EasingStyle.Quint, { Size = UDim2.fromScale(0.82, 0.82) })
	tween(stroke, 0.62, Enum.EasingStyle.Quad, { Thickness = 1, Transparency = 1 })
	return ring
end

function GachaReveal.play(parent: PlayerGui, results: { PullResult }, onComplete: () -> ()): () -> ()
	local rarity = highestRarity(results)
	local rng = Random.new()
	local finished = false
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
		ColorSequenceKeypoint.new(0, SKY_TOP:Lerp(rarity.color, 0.3)),
		ColorSequenceKeypoint.new(0.58, BACKDROP),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 5, 15)),
	})
	sky.Rotation = 90
	sky.Parent = overlay

	local finishButton = Instance.new("TextButton")
	finishButton.Name = "Skip"
	finishButton.AnchorPoint = Vector2.new(1, 1)
	finishButton.AutoButtonColor = false
	finishButton.BackgroundColor3 = Color3.fromRGB(20, 27, 50)
	finishButton.BackgroundTransparency = 0.2
	finishButton.BorderSizePixel = 0
	finishButton.Font = UI.font.bold
	finishButton.Position = UDim2.new(1, -24, 1, -22)
	finishButton.Size = UDim2.fromOffset(116, 38)
	finishButton.Text = "Skip reveal"
	finishButton.TextColor3 = WHITE
	finishButton.TextSize = UI.text.small
	finishButton.ZIndex = 120
	finishButton.Parent = overlay
	corner(finishButton, UDim.new(1, 0))

	local function finish()
		if finished then
			return
		end
		finished = true
		screen:Destroy()
		onComplete()
	end

	finishButton.Activated:Connect(finish)
	tween(overlay, 0.22, Enum.EasingStyle.Quad, { BackgroundTransparency = 0 })

	if UI.motion.isReducedMotion() then
		local simpleLabel = Instance.new("TextLabel")
		simpleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		simpleLabel.BackgroundTransparency = 1
		simpleLabel.Font = UI.font.display
		simpleLabel.Position = UDim2.fromScale(0.5, 0.47)
		simpleLabel.Size = UDim2.fromScale(0.8, 0.12)
		simpleLabel.Text = string.upper(rarity.name)
		simpleLabel.TextColor3 = rarity.color
		simpleLabel.TextSize = 34
		simpleLabel.ZIndex = 110
		simpleLabel.Parent = overlay
		task.delay(0.28, finish)
		return finish
	end

	for _ = 1, 34 do
		local star = makeStar(overlay, rng, 102)
		tween(star, rng:NextNumber(0.8, 1.6), Enum.EasingStyle.Sine, {
			BackgroundTransparency = 1,
			Size = star.Size + UDim2.fromOffset(3, 3),
		})
	end

	local flare = Instance.new("Frame")
	flare.Name = "WishCoreGlow"
	flare.AnchorPoint = Vector2.new(0.5, 0.5)
	flare.BackgroundColor3 = rarity.color
	flare.BackgroundTransparency = 0.55
	flare.BorderSizePixel = 0
	flare.Position = UDim2.fromScale(-0.08, 0.95)
	flare.Size = UDim2.fromOffset(110, 110)
	flare.ZIndex = 108
	flare.Parent = overlay
	corner(flare, UDim.new(1, 0))

	local core = Instance.new("Frame")
	core.Name = "WishCore"
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.BackgroundColor3 = WHITE
	core.BorderSizePixel = 0
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Rotation = 45
	core.Size = UDim2.fromOffset(34, 34)
	core.ZIndex = 109
	core.Parent = flare
	corner(core, UDim.new(0.22, 0))

	local travelTime = 0.78 + rarity.order * 0.055
	tween(flare, travelTime, Enum.EasingStyle.Quint, {
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(155 + rarity.order * 12, 155 + rarity.order * 12),
	})
	tween(core, travelTime, Enum.EasingStyle.Quint, {
		Rotation = 225,
		Size = UDim2.fromOffset(44 + rarity.order * 4, 44 + rarity.order * 4),
	})

	local streakCount = 13 + rarity.order * 5
	for index = 1, streakCount do
		task.delay(index * 0.018, function()
			if not finished and overlay.Parent then
				makeStreak(overlay, rng, rarity.color, 104)
			end
		end)
	end

	task.delay(travelTime * 0.72, function()
		if finished or not overlay.Parent then
			return
		end
		for _ = 1, math.max(1, rarity.order - 1) do
			makeRing(overlay, rarity.color, 106)
		end
	end)

	task.delay(travelTime, function()
		if finished or not overlay.Parent then
			return
		end

		local flash = Instance.new("Frame")
		flash.Name = "RarityFlash"
		flash.BackgroundColor3 = rarity.color:Lerp(WHITE, 0.55)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 115
		flash.Parent = overlay
		tween(flash, 0.12, Enum.EasingStyle.Quad, { BackgroundTransparency = 0.04 })
		task.delay(0.11, function()
			if flash.Parent then
				tween(flash, 0.36, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
			end
		end)

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Name = "Rarity"
		rarityLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Font = UI.font.display
		rarityLabel.Position = UDim2.fromScale(0.5, 0.57)
		rarityLabel.Size = UDim2.fromScale(0.8, 0.12)
		rarityLabel.Text = string.upper(rarity.name)
		rarityLabel.TextColor3 = rarity.color
		rarityLabel.TextSize = 22
		rarityLabel.TextStrokeColor3 = BACKDROP
		rarityLabel.TextStrokeTransparency = 0.25
		rarityLabel.TextTransparency = 1
		rarityLabel.ZIndex = 116
		rarityLabel.Parent = overlay
		tween(rarityLabel, 0.38, Enum.EasingStyle.Back, { TextSize = 42, TextTransparency = 0 })
	end)

	task.delay(travelTime + 0.82 + rarity.order * 0.05, finish)
	return finish
end

return GachaReveal

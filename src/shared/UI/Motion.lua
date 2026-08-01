local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Motion = {}

local reducedMotion = false

function Motion.setReducedMotion(enabled: boolean)
	reducedMotion = enabled
end

function Motion.isReducedMotion(): boolean
	return reducedMotion
end

Motion.snap = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.settle = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Motion.pop = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Motion.riseOut = TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.wipe = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
Motion.slow = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

Motion.hover = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
Motion.press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.release = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Motion.spring = TweenInfo.new(0.46, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
Motion.drift = TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local INSTANT = TweenInfo.new(0.01, Enum.EasingStyle.Linear)

function Motion.play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, if reducedMotion then INSTANT else info, goal)
	tween:Play()
	return tween
end

function Motion.to(instance: Instance, info: TweenInfo, goal: { [string]: any })
	Motion.play(instance, info, goal)
end

function Motion.loop(instance: Instance, duration: number, goal: { [string]: any }): Tween?
	if reducedMotion then
		return nil
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		goal
	)
	tween:Play()
	return tween
end

function Motion.popIn(gui: GuiObject, finalSize: UDim2, after: (() -> ())?)
	local target = finalSize
	gui.Size = UDim2.fromOffset(0, 0)

	local tween = Motion.play(gui, Motion.pop, { Size = target })
	if after then
		tween.Completed:Connect(after)
	end
	return tween
end

function Motion.stagger(items: { GuiObject }, info: TweenInfo, goal: { [string]: any }, gap: number?)
	local delay = gap or 0.045
	for index, item in items do
		if reducedMotion then
			Motion.play(item, info, goal)
		else
			task.delay((index - 1) * delay, function()
				if item.Parent then
					Motion.play(item, info, goal)
				end
			end)
		end
	end
end

function Motion.shimmer(gradient: UIGradient, period: number?): thread?
	if reducedMotion then
		return nil
	end
	local span = period or 1.9
	return task.spawn(function()
		while gradient.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			local tween = TweenService:Create(
				gradient,
				TweenInfo.new(span * 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Offset = Vector2.new(1, 0) }
			)
			tween:Play()
			tween.Completed:Wait()
			task.wait(span * 0.55)
		end
	end)
end

function Motion.countUp(setter: (value: number) -> (), from: number, to: number, duration: number?): thread
	local span = if reducedMotion then 0 else (duration or 0.4)
	return task.spawn(function()
		if span <= 0 then
			setter(to)
			return
		end
		local elapsed = 0
		while elapsed < span do
			elapsed += RunService.Heartbeat:Wait()
			local alpha = math.clamp(elapsed / span, 0, 1)
			setter(from + (to - from) * (1 - (1 - alpha) ^ 3))
		end
		setter(to)
	end)
end

function Motion.nudge(gui: GuiObject, offset: UDim2)
	if reducedMotion then
		return
	end
	local home = gui.Position
	local tween = Motion.play(gui, Motion.press, { Position = home + offset })
	tween.Completed:Connect(function()
		Motion.play(gui, Motion.release, { Position = home })
	end)
end

return Motion

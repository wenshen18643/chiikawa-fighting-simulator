local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Motion = {}
local reducedMotion = GuiService.ReducedMotionEnabled
local activeTweens: { [Tween]: { instance: Instance, goal: { [string]: any } } } = {}
local loopingTweens: { Tween } = {}

GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
	reducedMotion = GuiService.ReducedMotionEnabled
	if reducedMotion then
		for tween, record in activeTweens do
			tween:Cancel()
			for property, value in record.goal do
				(record.instance :: any)[property] = value
			end
		end
		table.clear(activeTweens)

		for _, tween in loopingTweens do
			tween:Cancel()
		end
		table.clear(loopingTweens)
	end
end)

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
	activeTweens[tween] = { instance = instance, goal = goal }
	tween.Completed:Once(function()
		activeTweens[tween] = nil
	end)
	tween:Play()
	return tween
end

function Motion.to(instance: Instance, info: TweenInfo, goal: { [string]: any })
	Motion.play(instance, info, goal)
end

function Motion.loop(instance: Instance, seconds: number, goal: { [string]: any }): Tween?
	if reducedMotion then
		return nil
	end

	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(instance, info, goal)
	table.insert(loopingTweens, tween)
	tween:Play()
	return tween
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

return Motion

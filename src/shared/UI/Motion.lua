--[[
	Named motion. Every animation in the game picks a curve from here rather
	than inventing its own TweenInfo at the call site.

	The reason is consistency of FEEL, which is a real thing and not a tidiness
	argument: a HUD where the currency counter, the toast and the panel all ease
	differently reads as several interfaces glued together. One vocabulary of
	four or five motions, used everywhere, reads as one product.

	The vocabulary:
	  snap    — state changed, acknowledge it and get out of the way
	  settle  — a value moved to a new resting place
	  pop     — something appeared and wants to be noticed (overshoots)
	  riseOut — something is leaving upward as it fades
	  wipe    — a full-screen transition

	REDUCED MOTION is honoured here rather than at every call site. When a player
	turns it off, `Motion.play` collapses the tween to a near-instant one; the
	end state is identical, so nothing has to branch.
]]

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

-- A near-zero tween rather than a direct property write: callers still get a
-- Tween back, so `:Play()`, `.Completed` and the rest keep working unchanged.
local INSTANT = TweenInfo.new(0.01, Enum.EasingStyle.Linear)

function Motion.play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, if reducedMotion then INSTANT else info, goal)
	tween:Play()
	return tween
end

-- Fire and forget, for the common case where nothing waits on completion.
function Motion.to(instance: Instance, info: TweenInfo, goal: { [string]: any })
	Motion.play(instance, info, goal)
end

--[[
	A looping there-and-back, for idle motion: a pulsing glow, a bobbing arrow.
	Returns the tween so the caller can stop it.

	Under reduced motion this returns nil and does nothing at all — an infinite
	loop is exactly what somebody enabling that setting is trying to stop, and
	collapsing it to a fast loop would be worse than no loop.
]]
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

--[[
	Scale in from nothing with an overshoot, then run `after`.

	The two-stage shape is what makes a click feel like it landed: appearing at
	final size reads as a value being reported, appearing small and springing
	past reads as an impact.
]]
function Motion.popIn(gui: GuiObject, finalSize: UDim2, after: (() -> ())?)
	local target = finalSize
	gui.Size = UDim2.fromOffset(0, 0)

	local tween = Motion.play(gui, Motion.pop, { Size = target })
	if after then
		tween.Completed:Connect(after)
	end
	return tween
end

return Motion

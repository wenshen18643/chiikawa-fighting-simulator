local Clip = {}

export type Key = {
	t: number,
	pitch: number?,
	yaw: number?,
	roll: number?,
	x: number?,
	y: number?,
	z: number?,
}

export type Track = { Key }

export type Definition = {
	length: number,
	looped: boolean?,
	tracks: { [string]: Track },
	mask: { [string]: number }?,
	prop: string?,
}

export type Pose = { [string]: CFrame }

local CHANNELS = { "pitch", "yaw", "roll", "x", "y", "z" }

local IDENTITY = CFrame.new()

local function catmullRom(p0: number, p1: number, p2: number, p3: number, a: number): number
	local a2 = a * a
	local a3 = a2 * a
	return 0.5 * ((2 * p1) + (-p0 + p2) * a + (2 * p0 - 5 * p1 + 4 * p2 - p3) * a2 + (-p0 + 3 * p1 - 3 * p2 + p3) * a3)
end

local function channel(key: Key, name: string): number
	return (key :: any)[name] or 0
end

local function neighbour(track: Track, index: number, looped: boolean): Key
	local count = #track
	if looped then
		return track[((index - 1) % count) + 1]
	end
	return track[math.clamp(index, 1, count)]
end

local function toCFrame(values: { [string]: number }): CFrame
	return CFrame.new(values.x, values.y, values.z)
		* CFrame.Angles(math.rad(values.pitch), math.rad(values.yaw), math.rad(values.roll))
end

local function keyToCFrame(key: Key): CFrame
	local values = {}
	for _, name in CHANNELS do
		values[name] = channel(key, name)
	end
	return toCFrame(values)
end

function Clip.sample(track: Track, phase: number, looped: boolean): CFrame
	local count = #track
	if count == 0 then
		return CFrame.identity
	end
	if count == 1 then
		return keyToCFrame(track[1])
	end

	local first, last = track[1], track[count]

	if not looped then
		if phase <= first.t then
			return keyToCFrame(first)
		end
		if phase >= last.t then
			return keyToCFrame(last)
		end
	end

	local index, alpha

	if looped and phase >= last.t then
		local span = (1 - last.t) + first.t
		index = count
		alpha = if span > 0 then (phase - last.t) / span else 0
	elseif looped and phase < first.t then
		local span = (1 - last.t) + first.t
		index = count
		alpha = if span > 0 then ((1 - last.t) + phase) / span else 0
	else
		index = count - 1
		for i = 1, count - 1 do
			if phase <= track[i + 1].t then
				index = i
				break
			end
		end
		local a, b = track[index], track[index + 1]
		local span = b.t - a.t
		alpha = if span > 0 then (phase - a.t) / span else 0
	end

	local p0 = neighbour(track, index - 1, looped)
	local p1 = neighbour(track, index, looped)
	local p2 = neighbour(track, index + 1, looped)
	local p3 = neighbour(track, index + 2, looped)

	local values = {}
	for _, name in CHANNELS do
		values[name] = catmullRom(channel(p0, name), channel(p1, name), channel(p2, name), channel(p3, name), alpha)
	end
	return toCFrame(values)
end

function Clip.pose(definition: Definition, phase: number, out: Pose): Pose
	local looped = definition.looped == true
	local clamped = if looped then phase % 1 else math.clamp(phase, 0, 1)

	for joint, track in definition.tracks do
		out[joint] = Clip.sample(track, clamped, looped)
	end
	return out
end

function Clip.blend(target: Pose, source: Pose, weight: number, mask: { [string]: number }?)
	if weight <= 0 then
		return
	end

	for joint, cframe in source do
		local jointWeight = weight
		if mask then
			jointWeight *= mask[joint] or 1
		end
		if jointWeight > 0 then
			local current = target[joint]
			if current then
				target[joint] = current:Lerp(cframe, math.min(jointWeight, 1))
			elseif jointWeight >= 0.999 then
				target[joint] = cframe
			else
				target[joint] = IDENTITY:Lerp(cframe, jointWeight)
			end
		end
	end
end

function Clip.add(target: Pose, joint: string, delta: CFrame, weight: number)
	if weight <= 0 then
		return
	end
	local current = target[joint] or CFrame.identity
	target[joint] = current * IDENTITY:Lerp(delta, math.min(weight, 1))
end

return Clip

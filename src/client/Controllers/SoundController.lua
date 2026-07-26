--[[
	Per-skill work sounds.

	--------------------------------------------------------------------------
	THE IDS ARE DELIBERATELY BLANK
	--------------------------------------------------------------------------

	A Roblox sound is an uploaded asset id, and unlike every other asset in this
	project there is no way to synthesise one — icons can be drawn from frames
	and characters built from parts, but audio cannot be generated in-engine.

	Inventing an id would be worse than leaving it empty: a made-up number is
	either nothing at all or somebody else's audio playing in your game, and
	both fail silently at exactly the moment you stop looking for them.

	So the machinery here is complete and the ids in Config/Feedback are "". A
	blank id plays nothing, and `init` warns ONCE naming every skill still
	waiting on audio, so silence is a message rather than a mystery. Filling one
	in is a single line in Config/Feedback.lua.

	--------------------------------------------------------------------------
	POOLING
	--------------------------------------------------------------------------

	At the click cap a naive implementation creates fourteen Sound instances a
	second and leaves the garbage collector to notice. Each skill gets a small
	ring of reusable voices instead, so overlapping clicks layer without
	allocating and a held-down autoclicker cannot grow the instance count.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feedback = require(Shared.Modules.Config.Feedback)
local Skills = require(Shared.Modules.Config.Skills)

local WorkController = require(script.Parent.WorkController)

local SoundController = {}

-- Enough to layer a fast click without ever cutting a sound off mid-play.
local VOICES_PER_SKILL = 4

local container: Folder
local voices: { [string]: { Sound } } = {}
local nextVoice: { [string]: number } = {}

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function buildVoices(skillId: string, spec: Feedback.SoundSpec)
	if spec.id == "" then
		return
	end

	local ring: { Sound } = {}
	for index = 1, VOICES_PER_SKILL do
		local sound = Instance.new("Sound")
		sound.Name = `{skillId}_{index}`
		sound.SoundId = spec.id
		sound.Volume = spec.volume
		-- Not spatial: this is the player's own action, and a 3D sound emitted
		-- from their own character is quieter when they look away from
		-- themselves, which is a strange thing for a click to do.
		sound.RollOffMaxDistance = 0
		sound.Parent = container
		ring[index] = sound
	end

	voices[skillId] = ring
	nextVoice[skillId] = 1
end

--------------------------------------------------------------------------------
-- Playback
--------------------------------------------------------------------------------

local function play(skillId: string?)
	if not skillId then
		return
	end

	local ring = voices[skillId]
	if not ring then
		-- No id configured for this skill. Silent by design, already warned
		-- about once at startup — never warn per click.
		return
	end

	local entry = Feedback.get(skillId)
	if not entry then
		return
	end

	local index = nextVoice[skillId] or 1
	nextVoice[skillId] = index % #ring + 1

	local sound = ring[index]
	-- Randomised per play so six clicks a second do not machine-gun one
	-- identical waveform, which is what makes repeated SFX grating.
	sound.PlaybackSpeed = entry.sound.pitchMin + math.random() * (entry.sound.pitchMax - entry.sound.pitchMin)
	sound.TimePosition = 0
	sound:Play()
end

SoundController.play = play

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function SoundController.init()
	container = Instance.new("Folder")
	container.Name = "WorkSounds"
	container.Parent = SoundService

	for _, skillId in Skills.ORDER do
		local entry = Feedback.get(skillId)
		if entry then
			buildVoices(skillId, entry.sound)
		end
	end

	local missing = Feedback.missingSounds()
	if #missing > 0 then
		warn(
			`[SoundController] no sound id set for: {table.concat(missing, ", ")}. `
				.. "Those skills are silent. Add ids in Shared/Modules/Config/Feedback.lua "
				.. '(sound = { id = "rbxassetid://..." }).'
		)
	end

	WorkController.onClick(play)
end

return SoundController

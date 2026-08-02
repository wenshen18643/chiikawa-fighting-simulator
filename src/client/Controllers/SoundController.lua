local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feedback = require(Shared.Modules.Config.Feedback)
local Skills = require(Shared.Modules.Config.Skills)
local WorkController = require(script.Parent.WorkController)
local SoundController = {}
local VOICES_PER_SKILL = 4
local container: Folder
local voices: { [string]: { Sound } } = {}
local nextVoice: { [string]: number } = {}

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
		sound.RollOffMaxDistance = 0
		sound.Parent = container
		ring[index] = sound
	end

	voices[skillId] = ring
	nextVoice[skillId] = 1
end

local function play(skillId: string?)
	if not skillId then
		return
	end

	local ring = voices[skillId]
	if not ring then
		return
	end

	local entry = Feedback.get(skillId)
	if not entry then
		return
	end

	local index = nextVoice[skillId] or 1
	nextVoice[skillId] = index % #ring + 1

	local sound = ring[index]
	sound.PlaybackSpeed = entry.sound.pitchMin + math.random() * (entry.sound.pitchMax - entry.sound.pitchMin)
	sound.TimePosition = 0
	sound:Play()
end

SoundController.play = play

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

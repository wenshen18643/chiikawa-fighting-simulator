--!strict

local UserInputService = game:GetService("UserInputService")
local InputMode = {}

export type Kind = "keyboard" | "touch" | "gamepad"

local initialized = false
local currentKind: Kind = "keyboard"
local listeners: { (Kind) -> () } = {}

local GAMEPAD_TYPES = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true,
}

local function fallback(): Kind
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "gamepad"
	end
	return "keyboard"
end

local function classify(inputType: Enum.UserInputType): Kind
	if inputType == Enum.UserInputType.Touch then
		return "touch"
	end
	if GAMEPAD_TYPES[inputType] then
		return "gamepad"
	end
	if inputType == Enum.UserInputType.None then
		return fallback()
	end
	return "keyboard"
end

local function apply(kind: Kind)
	if kind == currentKind then
		return
	end
	currentKind = kind
	for _, listener in listeners do
		task.spawn(listener, kind)
	end
end

function InputMode.init()
	if initialized then
		return
	end
	initialized = true
	currentKind = classify(UserInputService:GetLastInputType())
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		apply(classify(inputType))
	end)
end

function InputMode.current(): Kind
	InputMode.init()
	return currentKind
end

function InputMode.onChanged(callback: (Kind) -> ()): () -> ()
	InputMode.init()
	table.insert(listeners, callback)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

return InputMode

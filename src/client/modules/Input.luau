--!nonstrict
--[[
	Input.luau
	Единая точка ввода. Держит состояние кнопок и раздаёт события
	подписчикам (PlayerController/WeaponController).

	Мышь 1 = огонь, мышь 2 = прицел, Shift = бег, C = присед,
	R = перезарядка, 1..9 = слоты, X = убрать оружие.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("HardOut"):WaitForChild("Config"))

local Input = {}

Input.State = {
	Fire = false,
	Aim = false,
	Sprint = false,
	Crouch = false,
}

Input._handlers = {}

--[[ Подписка на действие. Возвращает объект с Disconnect. ]]
function Input.on(action, callback, phase)
	local handlers = Input._handlers[action]
	if not handlers then
		handlers = {}
		Input._handlers[action] = handlers
	end
	if not handlers[phase] then
		handlers[phase] = {}
	end
	local list = handlers[phase]
	table.insert(list, callback)
	return {
		Disconnect = function()
			local index = table.find(list, callback)
			if index then
				table.remove(list, index)
			end
		end,
	}
end

local function emit(action, phase, ...)
	Input.State[action] = (phase == "Began")
	local handlers = Input._handlers[action]
	if not handlers then
		return
	end
	local list = handlers[phase]
	if not list then
		return
	end
	for _, callback in ipairs(list) do
		task.spawn(callback, ...)
	end
end

local ACTION_BY_KEY = {
	[Config.Keys.Sprint] = "Sprint",
	[Config.Keys.Crouch] = "Crouch",
	[Config.Keys.Reload] = "Reload",
	[Config.Keys.Unequip] = "Unequip",
}

function Input.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
			emit("Jump", "Began")
			return
		end
		if kind == Enum.UserInputType.MouseButton1 then
			emit("Fire", "Began")
		elseif kind == Enum.UserInputType.MouseButton2 then
			emit("Aim", "Began")
			Input.State.Aim = true
		elseif kind == Enum.UserInputType.Keyboard then
			local slot = tostring(input.KeyCode):match("^Enum%.KeyCode%.(%d)$")
			if slot then
				emit("Slot", "Began", tonumber(slot))
				return
			end
			local action = ACTION_BY_KEY[input.KeyCode]
			if action then
				emit(action, "Began")
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 then
			emit("Fire", "Ended")
		elseif kind == Enum.UserInputType.MouseButton2 then
			emit("Aim", "Ended")
		elseif kind == Enum.UserInputType.Keyboard then
			local action = ACTION_BY_KEY[input.KeyCode]
			if action then
				emit(action, "Ended")
			end
		end
	end)

	-- Минимум магии от Roblox: отключаем стандартный зум и смену камеры.
	UserInputService.WindowFocused:Connect(function()
		Input.State.Fire = false
		Input.State.Aim = false
	end)
end

return Input

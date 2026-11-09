--!nonstrict
--[[
	CharacterTransparency.luau
	Отвечает за ВИДИМОСТЬ ТЕЛА своего персонажа от первого лица.

	Проблема, которую решает:
	  Дефолтный PlayerModule Roblox в первом лице сам делает части тела локально
	  прозрачными (через LocalTransparencyModifier) — и руки, и ноги, и торс
	  «исчезают». Поэтому изнутри видно только оружие, а тела нет.

	Решение:
	  * отключаем локальную прозрачность (Transparency = 0 у всех частей);
	  * глушим дефолтный скрипт, который её ставит (см. CharacterSetup);
	  * каждый кадр ПОДДЕРЖИВАЕМ видимость — на случай, если кто-то (движок,
	    другая система) снова выставит модификатор;
	  * прячем только голову и головные аксессуары, чтобы не загораживали обзор;
	  * вернуть штатное поведение: Config.ViewModel.HideBodyInFirstPerson = true.

	Почему LocalTransparencyModifier, а не Transparency:
	  модификатор виден только локально и не ломает вид персонажа для других
	  игроков/сервера.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Config = require(HardOut:WaitForChild("Config"))

local CharacterTransparency = {}

local player = Players.LocalPlayer

-- Части, которые нельзя прятать: в них камера и по ним стреляют.
local NEVER_HIDE = {
	HumanoidRootPart = true,
}

local function isHeadPart(instance: Instance): boolean
	if instance.Name == "Head" then
		return true
	end
	-- Шляпы, маски, очки: их части лежат внутри Accessory.
	return instance:FindFirstAncestorOfClass("Accessory") ~= nil
end

local function shouldHide(instance: BasePart): boolean
	if NEVER_HIDE[instance.Name] then
		return false
	end
	if not Config.ViewModel.HideHead then
		return false
	end
	return isHeadPart(instance)
end

local function applyTo(character: Instance)
	if not Config.ViewModel.ShowBody then
		return -- пользователь хочет штатное поведение Roblox (тело скрыто)
	end

	local function update(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		if shouldHide(instance) then
			instance.LocalTransparencyModifier = 1
		else
			-- Ключевая строка: возвращаем тело в кадр.
			instance.LocalTransparencyModifier = 0
		end
	end

	for _, descendant in character:GetDescendants() do
		update(descendant)
	end

	return update
end

function CharacterTransparency.initialize()
	local activeCharacter = nil
	local updatePart = nil
	local connections = {}

	local function clearConnections()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function bind(character: Instance)
		clearConnections()
		activeCharacter = character
		updatePart = applyTo(character)
		if not updatePart then
			return
		end

		-- Новые части (загрузка аксессуаров, смена аватара, респавн частей).
		table.insert(
			connections,
			character.DescendantAdded:Connect(function(descendant)
				task.defer(updatePart, descendant)
			end)
		)
	end

	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		-- Ждём Humanoid: части появляются не мгновенно.
		character:WaitForChild("Humanoid", 10)
		task.wait(0.1)
		bind(character)
	end)

	-- Страховка: если движок снова спрятал тело — возвращаем видимость.
	-- (дешёвая проверка раз в кадр, только по нескольким ключевым частям)
	RunService.Heartbeat:Connect(function()
		if not updatePart or not activeCharacter or not activeCharacter.Parent then
			return
		end
		if not Config.ViewModel.ShowBody then
			return
		end
		for _, partName in
			{
				"Torso",
				"UpperTorso",
				"LowerTorso",
				"Left Arm",
				"Right Arm",
				"Left Leg",
				"Right Leg",
				"LeftUpperArm",
				"RightUpperArm",
				"LeftUpperLeg",
				"RightUpperLeg",
				"LeftLowerArm",
				"RightLowerArm",
				"LeftLowerLeg",
				"RightLowerLeg",
				"LeftFoot",
				"RightFoot",
				"LeftHand",
				"RightHand",
			}
		do
			local part = activeCharacter:FindFirstChild(partName)
			if part and part:IsA("BasePart") and part.LocalTransparencyModifier > 0.05 and not shouldHide(part) then
				part.LocalTransparencyModifier = 0
			end
		end
	end)
end

return CharacterTransparency

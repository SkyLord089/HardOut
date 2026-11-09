--!nonstrict
--[[
	CharacterSetup.luau
	Приводит стандартный персонаж в состояние, нужное для FPS-стенда:

	  * отключает дефолтные контроллы Roblox (они перехватывают мышь,
	    зумят камеру и двигают персонажа так, как нам не надо);
	  * гасит авто-поворот персонажа (у нас своя камера);
	  * НЕ выключает анимации персонажа: они нужны, чтобы руки/ноги в кадре
	    двигались как у живого персонажа;
	  * убирает прыжок по умолчанию с пробела и ставит свой (с задержкой).

	Здесь же — заготовка под будущий сетевой вид рук других игроков.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local CharacterSetup = {}

local function disableDefaultControls()
	-- Эти скрипты создаются движком в PlayerScripts. Отключаем, а не удаляем:
	-- так меньше шансов сломать что-то в будущем.
	local playerScripts = player:WaitForChild("PlayerScripts")
	local names = {
		"PlayerModule",
		"ControlModule",
		"CameraModule",
	}

	local function disable(instance)
		if instance:IsA("LuaSourceContainer") then
			instance.Disabled = true
		end
	end

	for _, name in names do
		local existing = playerScripts:FindFirstChild(name)
		if existing then
			disable(existing)
		end
	end

	playerScripts.ChildAdded:Connect(function(child)
		if table.find(names, child.Name) then
			task.defer(disable, child)
		end
	end)
end

local function prepareCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.AutoRotate = false
	humanoid.UseJumpPower = true
	-- Камера смотрит из головы: не даём роблоксу крутить персонажа за камерой.
	humanoid.CameraOffset = Vector3.new(0, 0, 0)

	-- Анимации НЕ отключаем: именно они двигают руки и ноги в кадре.
	-- (Если когда-нибудь понадобится "мёртвая" поза — Config.ViewModel.Mode = "Procedural".)

	-- Стандартные "прыжки" от Roblox ControlModule отключены вместе с модулем,
	-- поэтому прыжок обрабатывается в PlayerController.
	humanoid.WalkSpeed = 0 -- скоростью управляет PlayerController
end

function CharacterSetup.start()
	disableDefaultControls()

	local function ensureAnimations(character)
		local animate = character:WaitForChild("Animate", 5)
		if animate and animate:IsA("LocalScript") then
			animate.Disabled = false
		end
	end

	if player.Character then
		task.spawn(prepareCharacter, player.Character)
		task.spawn(ensureAnimations, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(prepareCharacter, character)
		task.spawn(ensureAnimations, character)
	end)
end

return CharacterSetup

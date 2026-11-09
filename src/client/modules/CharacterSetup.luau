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
	-- Эти скрипты созданы движком в PlayerScripts. Важно: PlayerModule —
	-- это ModuleScript, у него НЕТ свойства Disabled (попытка его выставить
	-- падает с ошибкой). Поэтому PlayerModule мы НЕ отключаем: он нужен для
	-- работы камеры/контроллов, а его "скрытие тела в первом лице" мы
	-- перебиваем каждый кадр в CharacterTransparency.
	local playerScripts = player:WaitForChild("PlayerScripts")

	local function disable(instance)
		-- Отключаем только то, что реально имеет Disabled (LocalScript/Script).
		if instance:IsA("LocalScript") or instance:IsA("Script") then
			pcall(function()
				instance.Disabled = true
			end)
		end
	end

	-- ControlModule/CameraModule лежат внутри PlayerModule и обычно тоже
	-- ModuleScript'ы — их не трогаем (см. комментарий выше).
	for _, name in { "ControlModule", "CameraModule" } do
		local existing = playerScripts:FindFirstChild(name)
		if existing then
			disable(existing)
		end
	end
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

	-- Тело должно быть видно: включаем (выключается в Config.ViewModel.ShowBody).
	local bodyParts = {
		"Head",
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
		"LeftHand",
		"RightHand",
		"LeftFoot",
		"RightFoot",
	}
	for _, partName in bodyParts do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			-- LocalTransparencyModifier — то, чем движок прячет тело в 1-м лице.
			part.LocalTransparencyModifier = part.Name == "Head" and 1 or 0
		end
	end
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

--!nonstrict
--[[
	CharacterSetup.luau
	Приводит стандартный персонаж в состояние, нужное для FPS-стенда:

	  * отключает дефолтные контроллы Roblox (они перехватывают мышь,
	    зумят камеру и двигают персонажа так, как нам не надо);
	  * гасит авто-поворот персонажа (у нас своя камера);
	  * выключает анимации персонажа: в кадре всё равно только ViewModel,
	    но чужие анимации дёргают Humanoid и «пружинят» позицию головы;
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

	-- Отключаем анимации персонажа (R6/R15). ViewModel свой, они не нужны.
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end

	-- Стандартные "прыжки" от Roblox ControlModule отключены вместе с модулем,
	-- поэтому прыжок обрабатывается в PlayerController.
	humanoid.WalkSpeed = 0 -- скоростью управляет PlayerController
end

function CharacterSetup.start()
	disableDefaultControls()

	if player.Character then
		task.spawn(prepareCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(prepareCharacter, character)
	end)
end

return CharacterSetup

--!nonstrict
--[[
	HardOut — клиентская точка входа.
	Запускает HUD, контроллер игрока (камера + руки/ноги) и оружие.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("HardOut"):WaitForChild("Config"))

-- Курсор: без системной стрелки в центре экрана и без "свободной" мыши.
if Config.Camera.HideCursor then
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

-- Камера от первого лица (скриптовая, наша).
player.CameraMode = Enum.CameraMode.LockFirstPerson

-- Папка Modules — рядом с ClientBoot (внутри StarterPlayerScripts).
-- ВАЖНО: используем WaitForChild, а не FindFirstChild. Studio загружает объекты
-- по одному, и ClientBoot может запуститься РАНЬШЕ, чем появится соседняя
-- папка Modules. С FindFirstChild это давало nil -> return, и весь клиент
-- молча не работал (ни вида, ни покачивания, ни тела).
local parent = script.Parent
local Modules = parent and parent:WaitForChild("Modules", 10)
if not Modules then
	warn(
		"[HardOut] НЕ НАЙДЕНА папка Modules рядом с ClientBoot (ожидается внутри StarterPlayerScripts)."
	)
	-- Диагностика: что вообще есть рядом со скриптом.
	if parent then
		local found = {}
		for _, child in parent:GetChildren() do
			table.insert(found, child.Name .. " (" .. child.ClassName .. ")")
		end
		warn("[HardOut] Рядом с ClientBoot: " .. (#found > 0 and table.concat(found, ", ") or "ничего"))
	end
	return
end
local CharacterSetup = require(Modules:WaitForChild("CharacterSetup"))
local CharacterTransparency = require(Modules:WaitForChild("CharacterTransparency"))
local DebugPanel = require(Modules:WaitForChild("DebugPanel"))
local SmokeTest = require(Modules:WaitForChild("SmokeTest"))
local Hud = require(Modules:WaitForChild("Hud"))
local PlayerController = require(Modules:WaitForChild("PlayerController"))
local WeaponController = require(Modules:WaitForChild("WeaponController"))
local Tracers = require(Modules:WaitForChild("Tracers"))

--[[
	Запуск по шагам, каждый в pcall.

	Зачем: раньше одна ошибка в середине (например, nil из конструктора)
	обрывала весь клиент, и снаружи это выглядело как "ничего не работает,
	кроме мыши". Теперь падение одного шага не убивает остальные, а в Output
	печатается точное место.
]]
local function step(label: string, callback: () -> ()): boolean
	local ok, err = pcall(callback)
	if not ok then
		warn(string.format('[HardOut] Шаг "%s" упал: %s', label, tostring(err)))
	end
	return ok
end

local hud = nil
local controller = nil

step("тело (видимость)", function()
	CharacterSetup.start()
	CharacterTransparency.initialize()
end)

step("HUD", function()
	hud = Hud.new()
	if Config.Camera.ShowCrosshair == false then
		hud:setCrosshairVisible(false)
	end
end)

step("контроллер игрока", function()
	controller = PlayerController.new()
	if not controller then
		error("PlayerController.new() вернул nil")
	end
	controller.hud = hud
	controller:start()
end)

if controller then
	step("оружие", function()
		WeaponController.new(controller)
	end)
end

step("трассеры", function()
	Tracers.initialize()
end)

-- Диагностика: F2 — панель, /ho — статус в чат.
step("диагностика", function()
	DebugPanel.initialize()
end)

-- Самопроверка: реально ли крутится кадровый цикл (FPS, камера).
step("пульс", function()
	SmokeTest.start()
end)

if controller then
	print("[HardOut] Клиент готов: вид от первого лица, руки/ноги, HUD.")
else
	warn(
		"[HardOut] Клиент запустился НЕ полностью: контроллер игрока не поднялся, см. ошибки выше."
	)
end

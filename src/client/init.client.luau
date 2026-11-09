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

CharacterSetup.start()

-- Тело (руки/ноги/живот) должно быть видно от первого лица.
CharacterTransparency.initialize()

local hud = Hud.new()
if Config.Camera.ShowCrosshair == false then
	hud:setCrosshairVisible(false)
end

local controller = PlayerController.new()
controller.hud = hud
controller:start()

local weaponController = WeaponController.new(controller)

Tracers.initialize()

-- Диагностика: F2 — панель, /ho — статус в чат. Помогает понять, работает ли скрипт.
DebugPanel.initialize()

-- Самопроверка: реально ли крутится наш кадровый цикл (FPS, работает ли камера).
SmokeTest.start()

print("[HardOut] Клиент готов: вид от первого лица, руки/ноги, HUD.")

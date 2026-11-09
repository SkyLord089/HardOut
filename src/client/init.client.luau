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
local Modules = script.Parent and script.Parent:FindFirstChild("Modules")
if not Modules then
	warn(
		"[HardOut] НЕ НАЙДЕНА папка Modules рядом с ClientBoot (ожидается внутри StarterPlayerScripts)."
	)
	return
end
local CharacterSetup = require(Modules:WaitForChild("CharacterSetup"))
local CharacterTransparency = require(Modules:WaitForChild("CharacterTransparency"))
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

print("[HardOut] Клиент готов: вид от первого лица, руки/ноги, HUD.")

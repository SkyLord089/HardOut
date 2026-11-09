--!nonstrict
--[[
	HardOut — клиентская точка входа.
	Запускает HUD, контроллер игрока (камера + руки/ноги) и оружие.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Папка Modules — рядом с ClientBoot (внутри StarterPlayerScripts).
local Modules = script.Parent and script.Parent:FindFirstChild("Modules")
if not Modules then
	warn(
		"[HardOut] НЕ НАЙДЕНА папка Modules рядом с ClientBoot (ожидается внутри StarterPlayerScripts)."
	)
	return
end
local CharacterSetup = require(Modules:WaitForChild("CharacterSetup"))
local Hud = require(Modules:WaitForChild("Hud"))
local PlayerController = require(Modules:WaitForChild("PlayerController"))
local WeaponController = require(Modules:WaitForChild("WeaponController"))
local Tracers = require(Modules:WaitForChild("Tracers"))

CharacterSetup.start()

local hud = Hud.new()

local controller = PlayerController.new()
controller.hud = hud
controller:start()

local weaponController = WeaponController.new(controller)

Tracers.initialize()

print("[HardOut] Клиент готов: вид от первого лица, руки/ноги, HUD.")

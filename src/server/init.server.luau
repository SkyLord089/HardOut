--!nonstrict
--[[
	HardOut — серверная точка входа.
	Поднимает сеть, полигон и (опционально) модели оружия для теста.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HardOut = ReplicatedStorage:WaitForChild("HardOut", 10)
if not HardOut then
	warn("[HardOut] Не найдена ReplicatedStorage.HardOut — проверь Rojo-синк.")
	return
end
local Config = require(HardOut:WaitForChild("Config"))
local Net = require(HardOut:WaitForChild("Net"):WaitForChild("Remotes"))

local Modules = script:WaitForChild("Modules")
local CombatService = require(Modules:WaitForChild("CombatService"))
local TestRange = require(Modules:WaitForChild("TestRange"))
local RaidSandbox = require(Modules:WaitForChild("RaidSandbox"))
local SampleWeapon = require(Modules:WaitForChild("SampleWeapon"))

-- Все RemoteEvent'ы должны существовать до первого выстрела клиента.
for _, name in Net.Names do
	Net.get(name)
end

-- Папка под модели оружия: создаём, чтобы было куда класть.
local weaponFolder = ReplicatedStorage:FindFirstChild("WeaponModels")
if not weaponFolder then
	weaponFolder = Instance.new("Folder")
	weaponFolder.Name = "WeaponModels"
	weaponFolder.Parent = ReplicatedStorage
end

-- Демо-оружие, чтобы стенд можно было пощупать до появления своей модели.
local sample = SampleWeapon.install(weaponFolder)
if sample and Config.Debug.Verbose then
	print(
		"[HardOut] Папка WeaponModels была пуста — подложил демо-оружие '"
			.. sample.Name
			.. "'."
	)
	print(
		"[HardOut] Когда положишь свою модель, демо можно удалить из папки."
	)
end

-- Полигон.
if Config.Debug.Verbose then
	print("[HardOut] Строю тестовый полигон...")
end
TestRange.build()

CombatService.initialize()
RaidSandbox.initialize()

if Config.Debug.Verbose then
	print("[HardOut] Сервер готов. Оружие кладётся в ReplicatedStorage.WeaponModels.")
end

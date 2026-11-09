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

-- Папка Modules лежит РЯДОМ со скриптом (сиблинг), а не внутри него.
-- Важно: не block-им поток навсегда — иначе полигон не построится и будет "пусто".
local Modules = script.Parent and script.Parent:WaitForChild("Modules", 10)
if not Modules then
	warn(
		"[HardOut] НЕ НАЙДЕНА папка Modules рядом с ServerBoot. "
			.. "Скрипт должен лежать в ServerScriptService вместе с папкой Modules."
	)
	if script.Parent then
		local found = {}
		for _, child in script.Parent:GetChildren() do
			table.insert(found, child.Name .. " (" .. child.ClassName .. ")")
		end
		warn("[HardOut] Рядом с ServerBoot: " .. (#found > 0 and table.concat(found, ", ") or "ничего"))
	end
	return
end

local CombatService = require(Modules:WaitForChild("CombatService"))
local TestRange = require(Modules:WaitForChild("TestRange"))
local RaidSandbox = require(Modules:WaitForChild("RaidSandbox"))
local SampleWeapon = require(Modules:WaitForChild("SampleWeapon"))

-- Все RemoteEvent'ы должны существовать до первого выстрела клиента.
for _, name in Net.Names do
	Net.get(name)
end

-- Папка под модели оружия: создаём, чтобы было куда класть.
-- Здесь FindFirstChild уместен: папки может не быть в файле по замыслу,
-- и мы её создаём (в отличие от папок проекта, которые обязаны быть).
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

--!nonstrict
--[[
	WeaponController.luau
	Оружие в руках на клиенте: слоты, экипировка, стрельба, перезарядка, эффекты.

	Роли:
	  * WeaponState  — чистая логика патронов/темпа (та же, что на сервере);
	  * WeaponHolder — визуал и сокеты модели оружия;
	  * сервер       — единственный, кто наносит урон.

	Стенд: оружие берётся из ReplicatedStorage.WeaponModels. Положил модель —
	она автоматически попадает в слот 1 (и далее по алфавиту).
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Config = require(HardOut:WaitForChild("Config"))
local Net = require(HardOut:WaitForChild("Net"):WaitForChild("Remotes"))
local WeaponFolder = HardOut:WaitForChild("Weapon")
local Ballistics = require(WeaponFolder:WaitForChild("Ballistics"))
local WeaponState = require(WeaponFolder:WaitForChild("WeaponState"))

local WeaponHolder = require(script.Parent.WeaponHolder)
local Input = require(script.Parent.Input)

local rng = Random.new()

local WeaponController = {}
WeaponController.__index = WeaponController

--[[ controller — PlayerController (камера, риг, HUD). ]]
function WeaponController.new(controller)
	local self = setmetatable({}, WeaponController)
	self.controller = controller
	self.rig = controller.rig

	self.slots = {}
	self.activeSlot = nil
	self.holder = nil
	self.state = nil
	self.triggerHeld = false
	self.shotIndex = 0

	self.fireRemote = Net.waitFor(Net.Names.Fire)
	self.reloadRemote = Net.waitFor(Net.Names.Reload)

	self:bindInput()
	self:refreshInventory()

	-- Персонаж мог появиться ДО создания контроллера оружия: надеваем сразу.
	if controller.rig and self.slots[Config.Inventory.FirstSlot] then
		self:equip(Config.Inventory.FirstSlot)
	end

	-- Если риг пересоздали (респавн) — перевешиваем оружие.
	controller.onRigReady = function(rig)
		self.rig = rig
		local slot = self.activeSlot
		self:unequip()
		if slot and self.slots[slot] then
			self:equip(slot)
		elseif self.slots[1] then
			self:equip(Config.Inventory.FirstSlot)
		end
	end

	-- Подхватываем модели, добавленные позже (удобно при разработке).
	task.spawn(function()
		local folder = WeaponHolder.resolveWeaponFolder()
		if folder then
			folder.ChildAdded:Connect(function()
				task.wait(0.2)
				self:refreshInventory()
			end)
			folder.ChildRemoved:Connect(function()
				self:refreshInventory()
			end)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		self:update(dt)
	end)
	return self
end

function WeaponController:bindInput()
	Input.on("Fire", function()
		self.triggerHeld = true
		self:tryFire()
	end, "Began")

	Input.on("Fire", function()
		self.triggerHeld = false
		if self.state then
			self.state:releaseTrigger()
		end
		self.shotIndex = 0
	end, "Ended")

	Input.on("Reload", function()
		self:reload()
	end, "Began")

	Input.on("Unequip", function()
		if self.activeSlot then
			self:unequip()
		elseif self.slots[1] then
			self:equip(1)
		end
	end, "Began")

	Input.on("Slot", function(slot)
		self:equip(slot)
	end, "Began")
end

--[[ Перечитывает папку оружия. ]]
function WeaponController:refreshInventory()
	local weapons = WeaponHolder.listWeapons()
	self.slots = {}
	for index, weapon in weapons do
		self.slots[index] = weapon
	end

	if Config.Debug.Verbose then
		if #weapons == 0 then
			warn(
				"[HardOut] ReplicatedStorage.WeaponModels пуста. "
					.. "Положи туда модель оружия (Model) — стенд подхватит её сам."
			)
		else
			for _, weapon in weapons do
				WeaponHolder.report(weapon)
			end
		end
	end

	if self.controller.hud then
		self.controller.hud:setSlots(self.slots)
	end

	if not self.activeSlot and self.slots[Config.Inventory.FirstSlot] then
		self:equip(Config.Inventory.FirstSlot)
	end
end

function WeaponController:equip(slot)
	local weapon = self.slots[slot]
	if not weapon or self.activeSlot == slot then
		return
	end

	self:unequip()
	self.activeSlot = slot
	self.rig = self.controller.rig
	if not self.rig then
		warn(
			"[HardOut] Нет ViewModel (персонаж ещё не появился) — оружие не надеть."
		)
		self.activeSlot = nil
		return
	end

	self.holder = WeaponHolder.new(self.rig, weapon)
	self.state = WeaponState.new(self.holder.stats)
	self.shotIndex = 0

	self.controller:setAdsFov(self.holder.stats.AdsFov)
	if self.controller.hud then
		self.controller.hud:setSlots(self.slots)
		self.controller.hud:setWeapon(self.holder, slot)
		self:pushState()
	end
end

function WeaponController:unequip()
	if self.holder then
		self.holder:destroy()
		self.holder = nil
	end
	self.state = nil
	self.activeSlot = nil
	if self.controller.hud then
		self.controller.hud:setWeapon(nil)
	end
end

function WeaponController:reload()
	if not self.state then
		return
	end
	if self.state:startReload(os.clock()) then
		self.shotIndex = 0
		self.reloadRemote:FireServer()
	end
end

function WeaponController:tryFire()
	if not (self.state and self.holder) then
		return
	end
	local now = os.clock()
	local canFire = self.state:canFire(now)
	if not canFire then
		if self.state.magazine <= 0 and not self.state.reloading then
			self:reload()
		end
		return
	end

	local stats = self.state.stats
	self.state:fire(now)
	self.shotIndex = math.min(self.shotIndex + 1, 40)

	-- Отдача: паттерн + визуальный импульс камеры.
	local yaw, pitch = Ballistics.recoilOffset(stats, self.shotIndex - 1, function()
		return rng:NextNumber()
	end)
	self.controller.camera:addRecoil(yaw, pitch, stats.RecoilVisual)

	self:spawnMuzzleFlash()
	self:playShotSound()

	local origin, direction = self.controller.camera:getLookRay()
	self.fireRemote:FireServer({
		weaponName = self.holder.sourceName,
		origin = origin,
		direction = direction,
		shotIndex = self.shotIndex,
		aiming = self.controller.isAiming,
		speed = self.controller.speed,
	})

	self:pushState()
end

function WeaponController:spawnMuzzleFlash()
	local muzzle = self.holder:getMuzzleCFrame()

	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.3, 0.3, 0.3)
	flash.Color = Color3.fromRGB(255, 205, 130)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.CFrame = muzzle
	flash.Parent = workspace
	Debris:AddItem(flash, 0.04)

	local light = Instance.new("PointLight")
	light.Brightness = 5
	light.Range = 14
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Parent = flash
end

function WeaponController:playShotSound()
	-- Ассетов нет специально: подставь свой rbxassetid в Config.Weapons.ShotSoundId.
	local soundId = Config.Weapons.ShotSoundId
	if not soundId or soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.6
	sound.RollOffMaxDistance = 250
	sound.Parent = self.holder.root
	sound:Play()
	Debris:AddItem(sound, 3)
end

function WeaponController:pushState()
	if not self.state or not self.controller.hud then
		return
	end
	self.controller.hud:setAmmo(self.state.magazine, self.state.stats.MagazineSize)
	self.controller.hud:setReload(self.state.reloading, self.state:reloadProgress(os.clock()))
end

function WeaponController:update(dt)
	if not self.state then
		return
	end

	-- Оружие плавно подъезжает к центру в прицеле.
	if self.holder and self.holder.setAim then
		self.holder:setAim(self.controller.camera:getAimFactor(), dt)
	end

	if self.triggerHeld then
		self:tryFire()
	end

	if self.state:update(os.clock()) then
		self:pushState()
	end

	if self.controller.hud then
		self.controller.hud:setAim(self.controller.camera:getAimFactor())
		self.controller.hud:setReload(self.state.reloading, self.state:reloadProgress(os.clock()))
	end
end

return WeaponController

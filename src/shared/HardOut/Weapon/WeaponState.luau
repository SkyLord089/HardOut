--!strict
--[[
	WeaponState.luau
	Состояние одного оружия: патроны, магазин, перезарядка, режим огня.
	Чистая логика без Roblox API -> тестируется в юнит-тестах.

	Один экземпляр на слот инвентаря. Клиент и сервер держат свои экземпляры;
	сервер — источник истины, клиент предсказывает для отзывчивости.
]]

local WeaponState = {}
WeaponState.__index = WeaponState

export type Mode = "Semi" | "Auto" | "Burst"

function WeaponState.new(stats, ammoInMagazine: number?)
	local self = setmetatable({}, WeaponState)
	self.stats = stats
	self.magazine = ammoInMagazine or stats.MagazineSize
	self.reserve = stats.ReserveAmmo or stats.MagazineSize * 4
	self.reloading = false
	self.reloadEndsAt = 0
	self.lastShotAt = -math.huge
	self.shotIndex = 0
	self.triggerHeld = false
	self.boltReady = true
	return self
end

function WeaponState:isEmpty(): boolean
	return self.magazine <= 0
end

function WeaponState:isFull(): boolean
	return self.magazine >= self.stats.MagazineSize
end

function WeaponState:canFire(now: number): (boolean, string?)
	if self.reloading then
		return false, "Reloading"
	end
	if self.magazine <= 0 then
		return false, "Empty"
	end
	local interval = 60 / math.max(self.stats.RoundsPerMinute, 1)
	if now - self.lastShotAt < interval then
		return false, "FireRate"
	end
	-- Полуавтомат: нужен отпущенный и снова нажатый курок.
	if not self.stats.Auto and self.triggerHeld then
		return false, "SemiAuto"
	end
	return true, nil
end

function WeaponState:fire(now: number)
	self.magazine -= 1
	self.lastShotAt = now
	self.triggerHeld = true
	self.shotIndex += 1
end

function WeaponState:releaseTrigger()
	self.triggerHeld = false
	-- Сброс паттерна отдачи после паузы (решается снаружи по времени).
end

function WeaponState:resetShotPattern()
	self.shotIndex = 0
end

function WeaponState:startReload(now: number): boolean
	if self.reloading or self:isFull() or self.reserve <= 0 then
		return false
	end
	self.reloading = true
	self.reloadEndsAt = now + self.stats.ReloadTime
	return true
end

--[[ Вызывается каждый кадр. Возвращает true, если перезарядка только что завершилась. ]]
function WeaponState:update(now: number): boolean
	if self.reloading and now >= self.reloadEndsAt then
		local needed = self.stats.MagazineSize - self.magazine
		local taken = math.min(needed, self.reserve)
		self.magazine += taken
		self.reserve -= taken
		self.reloading = false
		self.reloadEndsAt = 0
		return true
	end
	return false
end

function WeaponState:reloadProgress(now: number): number
	if not self.reloading then
		return 1
	end
	local total = self.stats.ReloadTime
	if total <= 0 then
		return 1
	end
	return math.clamp(1 - (self.reloadEndsAt - now) / total, 0, 1)
end

return WeaponState

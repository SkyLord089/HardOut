--!strict
--[[
	Recoil.luau
	Отдача как состояние во времени, а не как разовый нокбек.
	Используется камерой каждый кадр: camera:Step(dt), camera:AddShot(stats, shotIndex).

	Модель intentionally простая:
	  - kick: импульс вверх (затухает пружиной),
	  - recoilOffset: накопленное смещение прицела (возвращается к нулю само),
	  - sway: инерция от вращения мышью (задел под "тяжёлое" ощущение Таркова).
]]

local Recoil = {}
Recoil.__index = Recoil

function Recoil.new()
	local self = setmetatable({}, Recoil)
	self.kickPitch = 0
	self.kickYaw = 0
	self.offsetPitch = 0
	self.offsetYaw = 0
	self.swayYaw = 0
	self.swayPitch = 0
	self.time = 0
	self.enabled = true
	return self
end

--[[ Импульс от одного выстрела. yaw/pitch в градусах (обычно из Ballistics.recoilOffset). ]]
function Recoil:AddShot(yawDegrees, pitchDegrees, visualMult)
	local visual = visualMult or 1
	self.kickPitch += pitchDegrees * 0.05 * visual
	self.kickYaw += yawDegrees * 0.05 * visual
	self.offsetPitch += pitchDegrees * visual
	self.offsetYaw += yawDegrees * visual
end

--[[ Инерция от движения мышью (вызывать при InputChanged). ]]
function Recoil:AddLook(deltaX, deltaY)
	local influence = 0.01
	self.swayYaw = math.clamp(self.swayYaw - deltaX * influence, -4, 4)
	self.swayPitch = math.clamp(self.swayPitch - deltaY * influence, -4, 4)
end

--[[ Кадровое обновление. Возвращает смещение камеры (yaw, pitch) в градусах. ]]
function Recoil:Step(dt, recoveryRate)
	if not self.enabled then
		return 0, 0
	end
	self.time += dt
	local rate = recoveryRate or 9

	-- Пружина для kick (визуальная тряска).
	local damping = math.exp(-dt * 14)
	self.kickPitch *= damping
	self.kickYaw *= damping

	-- Возврат накопленного увода прицела (медленнее, чем тряска).
	local offsetDamping = math.exp(-dt * (rate * 0.35))
	self.offsetPitch *= offsetDamping
	self.offsetYaw *= offsetDamping

	-- Sway возвращается к нулю.
	local swayDamping = math.exp(-dt * 6)
	self.swayYaw *= swayDamping
	self.swayPitch *= swayDamping

	return self.offsetYaw + self.swayYaw + self.kickYaw, self.offsetPitch + self.swayPitch + self.kickPitch
end

--[[ Сброс (например, при смене оружия). ]]
function Recoil:Reset()
	self.kickPitch = 0
	self.kickYaw = 0
	self.offsetPitch = 0
	self.offsetYaw = 0
	self.swayYaw = 0
	self.swayPitch = 0
end

return Recoil

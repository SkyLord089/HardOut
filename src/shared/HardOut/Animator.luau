--!strict
--[[
	Animator.luau
	Процедурная анимация верхней части тела от первого лица.
	Не требует ни одного ассета: всё считается кодом, поэтому стенд
	запускается сразу после Rojo-синка, без загрузки анимаций.

	Даёт: покачивание рук от шагов, инерцию от поворота камеры,
	наклон в стрейфе, дыхание в покое и в прицеле.
]]

local Animator = {}
Animator.__index = Animator

function Animator.new(camera)
	local self = setmetatable({}, Animator)
	self.camera = camera
	self.time = 0
	self.bobPhase = 0
	self.lookDelta = Vector2.zero
	self.smoothedLook = Vector2.zero
	self.lean = 0
	self.leanTarget = 0
	self.breathPhase = 0
	return self
end

function Animator:AddLookDelta(delta: Vector2)
	self.lookDelta += delta
end

function Animator:SetLeanTarget(value: number)
	self.leanTarget = value
end

--[[
	stepFlags:
		speed       number  — горизонтальная скорость (studs/s)
		isAiming    boolean
		isCrouching boolean
		dt          number

	Возвращает таблицу смещений для модели от первого лица:
		position  Vector3
		rotation  Vector3 (в градусах: pitch, yaw, roll)
]]
function Animator:Step(dt: number, flags)
	self.time += dt
	local speed = flags.speed or 0
	local isAiming = flags.isAiming or false

	-- Частота шага зависит от скорости.
	local frequency = 2.2 * math.sqrt(math.max(speed, 0.001) / 8)
	self.bobPhase += dt * frequency * math.pi * 2

	local moveAmount = math.clamp(speed / 8, 0, 1.6)
	local bobScale = 1
	if isAiming then
		bobScale = 0.35
	end
	local crouchScale = flags.isCrouching and 0.7 or 1

	local bobX = math.cos(self.bobPhase) * 0.35 * moveAmount * bobScale
	local bobY = math.abs(math.sin(self.bobPhase)) * 0.5 * moveAmount * bobScale
	local bobRoll = math.sin(self.bobPhase) * 0.8 * moveAmount * bobScale

	-- Инерция от движения мышью (затухает).
	self.lookDelta = self.lookDelta * math.exp(-dt * 10)
	self.smoothedLook = self.smoothedLook:Lerp(self.lookDelta, math.clamp(dt * 12, 0, 1))
	local lookYaw = math.clamp(self.smoothedLook.X * 0.02, -2.5, 2.5)
	local lookPitch = math.clamp(self.smoothedLook.Y * 0.02, -2.5, 2.5)

	-- Наклон (lean) в стрейфе.
	self.lean += (self.leanTarget - self.lean) * math.clamp(dt * 8, 0, 1)

	-- Дыхание.
	local breathRate = isAiming and 1.4 or 0.8
	self.breathPhase += dt * breathRate * math.pi * 2
	local breath = math.sin(self.breathPhase) * (isAiming and 0.12 or 0.2)

	local position = Vector3.new(bobX * 0.12, bobY * 0.12 + breath * 0.1, 0) * crouchScale

	local rotation = Vector3.new(lookPitch - breath * 0.3, lookYaw, bobRoll + self.lean * 1.2)

	return { position = position, rotation = rotation }
end

--[[ Сброс инерции при телепорте/респавне. ]]
function Animator:Reset()
	self.smoothedLook = Vector2.zero
	self.lookDelta = Vector2.zero
	self.lean = 0
	self.leanTarget = 0
end

return Animator

--!strict
--[[
	Ballistics.luau
	Чистая математика стрельбы: разброс, паттерн отдачи, падение пули.
	Модуль намеренно не трогает Roblox API (кроме Vector3/CFrame),
	поэтому его можно прогонять юнит-тестами вне движка (см. tests/).
]]

local Ballistics = {}

--[[ Случайный единичный вектор внутри конуса с полууглом coneDegrees. ]]
function Ballistics.applySpread(direction, coneDegrees, rng)
	if coneDegrees <= 0 then
		return direction.Unit
	end

	local dir = direction.Unit
	local cosLimit = math.cos(math.rad(math.clamp(coneDegrees, 0, 89)))

	-- Ортонормированный базис вокруг направления.
	local reference = math.abs(dir.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right = dir:Cross(reference).Unit
	local trueUp = right:Cross(dir).Unit

	-- Равномерно по площади конуса (sqrt по косинусу).
	local u1 = rng()
	local u2 = rng()
	local cosTheta = 1 - u1 * (1 - cosLimit)
	local sinTheta = math.sqrt(math.max(0, 1 - cosTheta * cosTheta))
	local phi = u2 * math.pi * 2

	local result = dir * cosTheta + right * (math.cos(phi) * sinTheta) + trueUp * (math.sin(phi) * sinTheta)
	return result.Unit
end

--[[
	Паттерн отдачи: возвращает {yaw, pitch} в градусах для выстрела shotIndex (0-based).
	Первые выстрелы почти в точку, дальше уводит вверх-вправо, потом рандом,
	чтобы паттерн нельзя было выучить наизусть.
]]
function Ballistics.recoilOffset(stats, shotIndex, rng)
	local scale = stats.Recoil or 1
	local climb = math.min(shotIndex, 12) * 0.55
	local drift = math.min(shotIndex, 12) * 0.18
	local jitterX = (rng() - 0.5) * 0.5 * math.min(shotIndex, 8)
	local jitterY = (rng() - 0.5) * 0.5

	local pitch = (climb + jitterY) * scale
	local yaw = (drift + jitterX) * scale
	return yaw, pitch
end

--[[
	Интегрирует падение пули: возвращает новое направление через dt секунд
	и пройденную этим шагом дистанцию.
]]
function Ballistics.integrate(direction, speed, dt, gravity)
	local g = gravity or 196.2
	local velocity = direction.Unit * speed
	local delta = velocity * dt + Vector3.new(0, -0.5 * g * dt * dt, 0)
	return delta.Unit, delta.Magnitude
end

--[[ Время полёта пули на дистанцию (для задержки урона на больших расстояниях). ]]
function Ballistics.travelTime(distance, speed)
	return distance / math.max(speed, 1)
end

--[[ На какой угол (в градусах) задрать ствол, чтобы попасть в точку на distance. ]]
function Ballistics.dropCompensation(distance, speed, gravity)
	local g = gravity or 196.2
	if speed <= 0 or distance <= 0 then
		return 0
	end
	local t = distance / speed
	local drop = 0.5 * g * t * t
	return math.deg(math.atan(drop / distance))
end

--[[ Куда целиться, чтобы пуля прилетела в target (поправка на падение). ]]
function Ballistics.aimAdjust(origin, target, speed, gravity)
	local flat = Vector3.new(target.X, 0, target.Z) - Vector3.new(origin.X, 0, origin.Z)
	local horizontalDistance = flat.Magnitude
	if horizontalDistance < 0.01 then
		return target
	end
	local correction = Ballistics.dropCompensation(horizontalDistance, speed, gravity)
	local axis = Vector3.new(flat.X, 0, flat.Z).Unit:Cross(Vector3.new(0, 1, 0))
	-- Вращаем "вверх" относительно горизонтали: поднимаем точку прицеливания.
	local offset = (target - origin)
	local rotated = CFrame.fromAxisAngle(axis, math.rad(-correction)) * offset
	return origin + rotated
end

return Ballistics

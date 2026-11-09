--!strict
--[[
	ArmSolver.luau
	Двухкостная IK-математика для рук и ног.
	Чистые функции над Vector3 — без Roblox-специфики, тестируется вне движка.

	Зачем: руки, построенные как "одна палка от плеча до кисти", выглядят деревянно.
	С локтём/коленом модель от первого лица сразу читается как в шутере.
]]

local ArmSolver = {}

--[[
	Решает положение локтя (колена).
		root   — плечо (бедро)
		target — кисть (стопа)
		l1     — длина первого сегмента
		l2     — длина второго сегмента
		hint   — направление, куда выгибать сустав (обычно вниз/в сторону)

	Возвращает позицию сустава и признак "достаёт ли" (false = цель дальше вытянутой руки).
]]
function ArmSolver.solve(root: Vector3, target: Vector3, l1: number, l2: number, hint: Vector3): (Vector3, boolean)
	local toTarget = target - root
	local distance = toTarget.Magnitude

	if distance < 0.0001 then
		return root + hint.Unit * l1, true
	end

	local direction = toTarget / distance
	local reachable = distance <= (l1 + l2) - 0.0001
	local clampedDistance = math.min(distance, l1 + l2 - 0.0001)

	-- Недостижимая цель: рука/нога полностью выпрямляется, сустав строго на оси.
	-- (Иначе на границе радикал даёт микроскопический "излом", который видно как дёрганье.)
	if not reachable then
		local joint = root + direction * (l1 / (l1 + l2)) * (l1 + l2)
		return joint, false
	end

	-- Проекция сустава на ось root->target.
	local a = (l1 * l1 - l2 * l2 + clampedDistance * clampedDistance) / (2 * clampedDistance)
	local hSquared = l1 * l1 - a * a
	local h = hSquared > 0 and math.sqrt(hSquared) or 0

	-- Ортогональная составляющая hint относительно оси.
	local hintPerp = hint - direction * hint:Dot(direction)
	if hintPerp.Magnitude < 0.0001 then
		-- hint параллелен оси: берём любую перпендикулярную ось.
		local fallback = math.abs(direction.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
		hintPerp = fallback - direction * fallback:Dot(direction)
	end
	local side = hintPerp.Unit

	local joint = root + direction * a + side * h
	return joint, reachable
end

--[[
	Возвращает CFrames двух сегментов (плечо->локоть, локоть->кисть),
	чтобы части нужного размера вставали между точками.

	Сегмент — это Part с Size = (толщина, толщина, длина), у которого
	ось Z смотрит от start к finish.
]]
function ArmSolver.segmentCFrame(start: Vector3, finish: Vector3): CFrame
	local delta = finish - start
	local length = delta.Magnitude
	if length < 0.0001 then
		return CFrame.new(start)
	end
	local midpoint = start + delta * 0.5
	return CFrame.lookAt(midpoint, finish)
end

--[[ Длина сегмента между точками. ]]
function ArmSolver.segmentLength(start: Vector3, finish: Vector3): number
	return (finish - start).Magnitude
end

--[[
	Сгибание конечности по фазе шага.
	Возвращает смещение стопы относительно бедра для бегущего цикла.
	phase — фаза в радианах, stride — амплитуда.
]]
function ArmSolver.strideOffset(phase: number, stride: number, lift: number): Vector3
	local z = math.sin(phase) * stride
	local y = -math.max(0, math.cos(phase)) * lift
	return Vector3.new(0, y, z)
end

return ArmSolver

--!strict
--[[
	AimSolver.luau
	Мозг стрельбы: решает, куда попала пуля и сколько урона нанести.
	Специально отделён от Roblox-специфики: физика попадания приходит
	через resolver (origin, direction, range) -> результат raycast или nil.

	Чистую часть можно гонять в юнит-тестах без движка.
]]

local Ballistics = require(script.Parent.Ballistics)

local AimSolver = {}

local HEAD_PARTS = {
	Head = true,
	head = true,
}

local LIMB_PARTS = {
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

--[[ Имя части -> множитель урона. ]]
function AimSolver.zoneMultiplier(partName, stats)
	if HEAD_PARTS[partName] then
		return stats.HeadshotMult
	end
	if LIMB_PARTS[partName] then
		return 0.7
	end
	if partName == "HumanoidRootPart" then
		return 1.0
	end
	return 1.0
end

--[[
	Основной расчёт выстрела.
	origin/direction — из камеры, spreadDegrees — уже посчитанный разброс,
	rng — функция 0..1 (детерминированная в тестах).
]]
function AimSolver.solve(params)
	local stats = params.stats
	local direction = Ballistics.applySpread(params.direction, params.spreadDegrees, params.rng)
	local result = params.resolver(params.origin, direction, stats.Range)

	if not result then
		return {
			Hit = false,
			Position = params.origin + direction * stats.Range,
			Normal = Vector3.new(0, 1, 0),
			Distance = stats.Range,
			Direction = direction,
			PartName = "",
			Damage = 0,
			IsHead = false,
		}
	end

	local part = result.Instance
	local partName = part and part.Name or tostring(result.PartName or "")
	local isHead = HEAD_PARTS[partName] == true
	local damage = stats.Damage * AimSolver.zoneMultiplier(partName, stats)

	return {
		Hit = true,
		Position = result.Position,
		Normal = result.Normal or Vector3.new(0, 1, 0),
		Distance = (result.Position - params.origin).Magnitude,
		Direction = direction,
		PartName = partName,
		Instance = part,
		Damage = damage,
		IsHead = isHead,
		Material = result.Material,
	}
end

--[[ Разброс: стойка / прицел / движение. ]]
function AimSolver.computeSpread(stats, isAiming, speedRatio)
	local spread = isAiming and stats.SpreadAim or stats.Spread
	local ratio = math.clamp(speedRatio or 0, 0, 2)
	spread *= 1 + ratio * 0.8
	if isAiming then
		spread *= 0.6
	end
	return spread
end

return AimSolver

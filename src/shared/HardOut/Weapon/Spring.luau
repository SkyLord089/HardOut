--!strict
--[[
	Spring.luau
	Маленькая пружина (критически задемпфированная) для сглаживания:
	прицеливания, FOV, покачивания рук, смещений. Без Roblox API.
]]

local Spring = {}
Spring.__index = Spring

function Spring.new(initial: number, stiffness: number?, damping: number?)
	local self = setmetatable({}, Spring)
	self.value = initial or 0
	self.target = initial or 0
	self.velocity = 0
	self.stiffness = stiffness or 180
	self.damping = damping or 14
	return self
end

function Spring:SetTarget(target: number)
	self.target = target
end

--[[ Возвращает текущее значение. ]]
function Spring:Step(dt: number): number
	dt = math.min(dt, 1 / 15) -- защита от лагов
	local delta = self.target - self.value
	self.velocity += delta * self.stiffness * dt
	self.velocity *= math.exp(-self.damping * dt)
	self.value += self.velocity * dt
	return self.value
end

function Spring:Snap(value: number)
	self.value = value
	self.target = value
	self.velocity = 0
end

return Spring

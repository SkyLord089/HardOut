--[[
	roblox_mocks.luau
	Минимальные моки Roblox API (Vector3/Vector2/CFrame), чтобы прогонять
	чистую математику стенда в обычном Luau вне Roblox Studio.
	Это тестовая обвязка, а не часть игры.
]]

local Mocks = {}

Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	if type(x) == "table" then
		return Vector3.new(x.X or 0, x.Y or 0, x.Z or 0)
	end
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)
function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function Vector3.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function Vector3.__unm(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
function Vector3.__mul(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	end
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function Vector3.__div(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
function Vector3.__eq(a, b)
	return math.abs(a.X - b.X) < 1e-5 and math.abs(a.Y - b.Y) < 1e-5 and math.abs(a.Z - b.Z) < 1e-5
end
function Vector3.__tostring(a)
	return string.format("(%.3f, %.3f, %.3f)", a.X, a.Y, a.Z)
end
function Vector3.__index(t, key)
	if key == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif key == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(t.X / m, t.Y / m, t.Z / m)
	elseif key == "Dot" then
		return function(self, other)
			return self.X * other.X + self.Y * other.Y + self.Z * other.Z
		end
	elseif key == "Cross" then
		return function(self, o)
			return Vector3.new(self.Y * o.Z - self.Z * o.Y, self.Z * o.X - self.X * o.Z, self.X * o.Y - self.Y * o.X)
		end
	elseif key == "Lerp" then
		return function(self, o, alpha)
			return Vector3.new(
				self.X + (o.X - self.X) * alpha,
				self.Y + (o.Y - self.Y) * alpha,
				self.Z + (o.Z - self.Z) * alpha
			)
		end
	elseif key == "Abs" then
		return function(self)
			return Vector3.new(math.abs(self.X), math.abs(self.Y), math.abs(self.Z))
		end
	end
	return nil
end

Vector2 = {}
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
end
Vector2.zero = Vector2.new(0, 0)
Vector2.__index = Vector2
function Vector2.__add(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
function Vector2.__mul(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
function Vector2.__index(t, key)
	if key == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y)
	end
	if key == "Lerp" then
		return function(self, o, a)
			return Vector2.new(self.X + (o.X - self.X) * a, self.Y + (o.Y - self.Y) * a)
		end
	end
	return nil
end

CFrame = {}
CFrame.__index = CFrame
local function makeRotation(m)
	return setmetatable({ p = Vector3.new(0, 0, 0), m = m }, CFrame)
end
function CFrame.new(x, y, z)
	if type(x) == "table" and x.X then
		return setmetatable({ p = Vector3.new(x.X, x.Y, x.Z), m = nil }, CFrame)
	end
	return setmetatable({ p = Vector3.new(x or 0, y or 0, z or 0), m = nil }, CFrame)
end
CFrame.identity = CFrame.new(0, 0, 0)
function CFrame.fromOrientation(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local m = {
		{ cy * cz, -cy * sz, sy },
		{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
		{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
	}
	return makeRotation(m)
end
CFrame.Angles = CFrame.fromOrientation
function CFrame.fromAxisAngle(axis, angle)
	local a = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	return makeRotation({
		{ c + a.X * a.X * t, a.X * a.Y * t - a.Z * s, a.X * a.Z * t + a.Y * s },
		{ a.Y * a.X * t + a.Z * s, c + a.Y * a.Y * t, a.Y * a.Z * t - a.X * s },
		{ a.Z * a.X * t - a.Y * s, a.Z * a.Y * t + a.X * s, c + a.Z * a.Z * t },
	})
end
function CFrame.lookAt(from, to)
	local delta = (to - from)
	local dir = delta.Unit
	local up = Vector3.new(0, 1, 0)
	local right = dir:Cross(up)
	if right.Magnitude < 1e-5 then
		right = Vector3.new(1, 0, 0)
	end
	right = right.Unit
	local trueUp = right:Cross(dir).Unit
	return makeRotation({
		{ right.X, trueUp.X, -dir.X },
		{ right.Y, trueUp.Y, -dir.Y },
		{ right.Z, trueUp.Z, -dir.Z },
	})
end
function CFrame.__mul(a, b)
	if getmetatable(b) == CFrame then
		local p = a:PointToWorldSpace(b.p)
		if not a.m then
			return CFrame.new(p)
		end
		if not b.m then
			return CFrame.new(p)
		end
		local m = {}
		for i = 1, 3 do
			m[i] = {}
			for j = 1, 3 do
				local sum = 0
				for k = 1, 3 do
					sum = sum + a.m[i][k] * b.m[k][j]
				end
				m[i][j] = sum
			end
		end
		local result = makeRotation(m)
		result.p = p
		return result
	end
	return a:PointToWorldSpace(b)
end
function CFrame.__index(t, key)
	if key == "Position" then
		return rawget(t, "p")
	end
	if key == "LookVector" then
		local m = rawget(t, "m")
		if not m then
			return Vector3.new(0, 0, -1)
		end
		return Vector3.new(-m[1][3], -m[2][3], -m[3][3])
	end
	if key == "RightVector" then
		local m = rawget(t, "m")
		if not m then
			return Vector3.new(1, 0, 0)
		end
		return Vector3.new(m[1][1], m[2][1], m[3][1])
	end
	if key == "UpVector" then
		local m = rawget(t, "m")
		if not m then
			return Vector3.new(0, 1, 0)
		end
		return Vector3.new(m[1][2], m[2][2], m[3][2])
	end
	if key == "PointToWorldSpace" then
		return function(self, v)
			local m = rawget(self, "m")
			local p = rawget(self, "p")
			if not m then
				return p + v
			end
			return Vector3.new(
				m[1][1] * v.X + m[1][2] * v.Y + m[1][3] * v.Z + p.X,
				m[2][1] * v.X + m[2][2] * v.Y + m[2][3] * v.Z + p.Y,
				m[3][1] * v.X + m[3][2] * v.Y + m[3][3] * v.Z + p.Z
			)
		end
	end
	return nil
end

-- Enum: нужен Config (клавиши).
Enum = {
	KeyCode = setmetatable({}, {
		__index = function(t, key)
			local value = { Name = key, EnumType = "KeyCode", Value = 0 }
			rawset(t, key, value)
			return value
		end,
	}),
	Material = setmetatable({}, {
		__index = function(t, key)
			local value = { Name = key }
			rawset(t, key, value)
			return value
		end,
	}),
}

-- Заглушки, чтобы модули не падали на обращении к сервисам.
MockInstance = {}
MockInstance.__index = MockInstance
function MockInstance.new(name, attributes)
	return setmetatable({ Name = name or "Mock", _attributes = attributes or {} }, MockInstance)
end
function MockInstance:GetAttribute(name)
	return self._attributes[name]
end

return Mocks

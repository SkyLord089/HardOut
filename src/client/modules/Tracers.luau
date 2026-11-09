--!nonstrict
--[[
	Tracers.luau
	Визуал выстрелов: трассер (линия от ствола до попадания), вспышка в точке удара.
	Слушает ShotResult с сервера, поэтому видно ВСЕ выстрелы, включая чужие.

	Ассеты не используются: трассер — тонкая Part с Neon, искры — ParticleEmitter.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Net = require(HardOut:WaitForChild("Net"):WaitForChild("Remotes"))
local Config = require(HardOut:WaitForChild("Config"))

local Tracers = {}

local tracerFolder

local function getFolder()
	if not tracerFolder or not tracerFolder.Parent then
		tracerFolder = Instance.new("Folder")
		tracerFolder.Name = "HardOutTracers"
		tracerFolder.Parent = workspace
	end
	return tracerFolder
end

local function spawnTracer(from, to)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Size = Vector3.new(0.06, 0.06, length)
	tracer.CFrame = CFrame.lookAt(from + delta * 0.5, to)
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 214, 150)
	tracer.Transparency = 0.25
	tracer.Parent = getFolder()
	Debris:AddItem(tracer, Config.Debug.TraceLifetime)
end

local function spawnImpact(position, normal)
	local impact = Instance.new("Part")
	impact.Name = "Impact"
	impact.Size = Vector3.new(0.1, 0.1, 0.1)
	impact.CFrame = CFrame.new(position)
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanQuery = false
	impact.CanTouch = false
	impact.CastShadow = false
	impact.Transparency = 1
	impact.Parent = getFolder()

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparks"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160), Color3.fromRGB(120, 110, 100))
	emitter.Lifetime = NumberRange.new(0.12, 0.3)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Enabled = true
	emitter.Parent = impact
	emitter:Emit(8)
	Debris:AddItem(impact, 0.6)

	local decal = Instance.new("Part")
	decal.Name = "BulletHole"
	decal.Size = Vector3.new(0.22, 0.22, 0.02)
	decal.CFrame = CFrame.lookAt(position + normal * 0.01, position + normal)
	decal.Anchored = true
	decal.CanCollide = false
	decal.CanQuery = false
	decal.CanTouch = false
	decal.CastShadow = false
	decal.Color = Color3.fromRGB(16, 16, 16)
	decal.Material = Enum.Material.SmoothPlastic
	decal.Parent = getFolder()
	Debris:AddItem(decal, 12)
end

function Tracers.initialize()
	local remote = Net.waitFor(Net.Names.ShotResult)
	remote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local origin = payload.origin
		local position = payload.position
		if typeof(origin) ~= "Vector3" or typeof(position) ~= "Vector3" then
			return
		end
		spawnTracer(origin, position)
		if payload.hit then
			local normal = typeof(payload.normal) == "Vector3" and payload.normal or Vector3.new(0, 1, 0)
			spawnImpact(position, normal)
		end
	end)
end

return Tracers

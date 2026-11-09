--!nonstrict
--[[
	Camera.luau
	Камера от первого лица, полностью управляемая скриптом.

	Почему своя камера, а не дефолтная:
	  * отдача идёт в прицел и возвращается плавно, а не дёргает персонажа;
	  * ADS плавно меняет FOV и приближает оружие;
	  * наклон в стрейфе и покачивание головы.

	Важно: углы обзора (lookAngles) хранятся здесь и НЕ зависят от Humanoid,
	поэтому не возникает петли "камера -> поворот персонажа -> камера".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Config = require(HardOut:WaitForChild("Config"))
local Spring = require(HardOut:WaitForChild("Weapon"):WaitForChild("Spring"))
local Recoil = require(HardOut:WaitForChild("Weapon"):WaitForChild("Recoil"))

local Camera = {}
Camera.__index = Camera

-- Чувствительность: чуть ниже роблоксовой, как в "медленных" шутерах.
local LOOK_SENSITIVITY = 0.0026

function Camera.new(player)
	local self = setmetatable({}, Camera)
	self.player = player
	self.recoil = Recoil.new()
	self.fovSpring = Spring.new(Config.Camera.BaseFov, 160, 18)
	self.aimSpring = Spring.new(0, 200, 22)
	self.lookAngles = Vector2.new(0, 0) -- yaw/pitch в градусах
	self.speed = 0
	self.leanTarget = 0
	self.leanAngle = 0
	self.bobPhase = 0
	self.shake = 0
	self.aimed = false
	self.aimFactor = 0
	self.lastDelta = Vector2.zero
	self.lastCFrame = CFrame.new(0, 0, 0)
	self.smoothedAngles = Vector2.new(0, 0)
	self.shakePhase = 0
	return self
end

--[[ Чтение мыши + инерция для оружия. ]]
function Camera:readMouse()
	local delta = UserInputService:GetMouseDelta()
	self.lastDelta = delta
	local sensitivity = LOOK_SENSITIVITY * 57.2958
	self.lookAngles = Vector2.new(
		self.lookAngles.X - delta.X * sensitivity,
		math.clamp(self.lookAngles.Y - delta.Y * sensitivity, -85, 85)
	)
	self.recoil:AddLook(delta.X, delta.Y)
end

function Camera:addRecoil(yaw, pitch, visualMult)
	self.recoil:AddShot(yaw, pitch, visualMult)
	local strength = Config.Camera.ShakeScale or 0.35
	self.shake = math.min(self.shake + 0.35 * (visualMult or 1) * strength, 1.6 * strength)
end

function Camera:setAiming(isAiming, adsFov)
	self.aimed = isAiming
	self.aimSpring:SetTarget(isAiming and 1 or 0)
	self.fovSpring:SetTarget(isAiming and (adsFov or Config.Camera.BaseFov) or Config.Camera.BaseFov)
end

function Camera:setMovement(speed, isCrouching)
	self.speed = speed
	self.isCrouching = isCrouching
end

function Camera:setLean(lean)
	self.leanTarget = lean
end

--[[ Сброс в начальное положение (респавн). ]]
function Camera:reset()
	self.recoil:Reset()
	self.shake = 0
	self.leanAngle = 0
	self.bobPhase = 0
end

--[[ Возвращает актуальный CFrame и FOV. ]]
function Camera:update(dt)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local character = self.player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return self.lastCFrame, camera.FieldOfView
	end

	local recoilYaw, recoilPitch = self.recoil:Step(dt)
	self.shake *= math.exp(-dt * 10)
	self.shakePhase = (self.shakePhase or 0) + dt * 60
	local shakePitch = math.sin(self.shakePhase) * self.shake * 0.4
	local shakeRoll = math.cos(self.shakePhase * 0.63) * self.shake * 0.25

	local bob = Config.Camera.HeadBob
	local bobY, bobRoll, bobX = 0, 0, 0
	if bob.Enabled and self.speed > 0.5 then
		self.bobPhase += dt * (bob.Frequency * math.sqrt(self.speed / Config.Movement.WalkSpeed)) * math.pi * 2
		local amount = math.clamp(self.speed / Config.Movement.WalkSpeed, 0, 1.6)
		bobY = math.abs(math.sin(self.bobPhase)) * bob.Amplitude * amount
		bobRoll = math.sin(self.bobPhase) * 0.5 * amount
		bobX = math.cos(self.bobPhase) * bob.Amplitude * 0.5 * amount
	end

	self.leanAngle += (self.leanTarget * Config.Camera.LeanAngle - self.leanAngle) * math.clamp(dt * 10, 0, 1)

	local crouchOffset = self.isCrouching and -0.5 or 0
	-- Камера чуть впереди головы: иначе она окажется внутри тела, и торс/живот
	-- не будут видны при взгляде вниз (а near-plane срежет шею).
	local forward = Config.Camera.EyeForward or 0.6
	local ahead = Vector3.new(-math.sin(math.rad(self.smoothedAngles.X)), 0, -math.cos(math.rad(self.smoothedAngles.X)))
	local origin = head.Position + Config.Camera.EyeOffset + ahead * forward + Vector3.new(bobX, bobY + crouchOffset, 0)

	-- Мягкое сглаживание: камера чуть "догоняет" мышь (не резкие рывки).
	local smooth = Config.Camera.Smoothing or 0.35
	local targetAngles = Vector2.new(self.lookAngles.X - recoilYaw, self.lookAngles.Y - recoilPitch)
	if smooth > 0 then
		self.smoothedAngles =
			self.smoothedAngles:Lerp(targetAngles, math.clamp(dt * (1 / math.max(smooth, 0.02)), 0, 1))
	else
		self.smoothedAngles = targetAngles
	end

	local rotation = CFrame.fromOrientation(
		math.rad(self.smoothedAngles.Y + shakePitch),
		math.rad(self.smoothedAngles.X),
		math.rad(self.leanAngle + bobRoll + shakeRoll)
	)

	local cameraCFrame = CFrame.new(origin) * rotation
	camera.CFrame = cameraCFrame
	camera.FieldOfView = self.fovSpring:Step(dt)
	self.aimFactor = self.aimSpring:Step(dt)
	self.lastCFrame = cameraCFrame
	return cameraCFrame, camera.FieldOfView
end

--[[ Куда сейчас смотрит игрок (для стрельбы и привязок). ]]
function Camera:getLookRay()
	return self.lastCFrame.Position, self.lastCFrame.LookVector
end

function Camera:getAimFactor()
	return self.aimFactor
end

return Camera

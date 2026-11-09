--!nonstrict
--[[
	PlayerController.luau
	Связывает всё воедино: камера, ViewModel, ввод, движение, обновления по кадрам.

	Порядок кадра:
	  1. RenderStepped: чтение мыши + движение персонажа + поза рук.
	  2. После этого камера уже стоит там, куда смотрит игрок.

	Движение своё (не Humanoid:MoveTo), потому что камера тоже своя:
	персонаж поворачивается строго по камере, без "петли" между ними.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Config = require(HardOut:WaitForChild("Config"))

local CameraModule = require(script.Parent.Camera)
local FirstPersonRig = require(script.Parent.FirstPersonRig)
local Input = require(script.Parent.Input)

local PlayerController = {}
PlayerController.__index = PlayerController

local player = Players.LocalPlayer

function PlayerController.new()
	local self = setmetatable({}, PlayerController)
	self.player = player
	self.camera = CameraModule.new(player)

	self.speed = 0
	self.isAiming = false
	self.isCrouching = false
	self.isSprinting = false
	self.walkSpeed = Config.Movement.WalkSpeed
	self.lean = 0
	self.rig = nil
	self.humanoid = nil
	self.character = nil
	self.adsFov = Config.Camera.BaseFov
	self.hud = nil
end

function PlayerController:start()
	Input.start()

	-- Камера и курсор.
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	Input.on("Aim", function()
		self.isAiming = true
		self.camera:setAiming(true, self.adsFov)
	end, "Began")
	Input.on("Aim", function()
		self.isAiming = false
		self.camera:setAiming(false, self.adsFov)
	end, "Ended")

	Input.on("Sprint", function()
		self.isSprinting = true
	end, "Began")
	Input.on("Sprint", function()
		self.isSprinting = false
	end, "Ended")

	Input.on("Crouch", function()
		self.isCrouching = not self.isCrouching
	end, "Began")

	Input.on("Jump", function()
		self:tryJump()
	end, "Began")

	self:bindCharacter()
	player.CharacterAdded:Connect(function(character)
		self:bindCharacter(character)
	end)

	-- Поза рук/ног — раз в кадр, прямо перед рендером.
	RunService.RenderStepped:Connect(function(dt)
		self:readInput()
		self:updateMovement(dt)
		self:updateCamera(dt)
		self:updateRig(dt)
	end)

	RunService.PostSimulation:Connect(function(dt)
		self:updateCharacterRotation(dt)
	end)
end

--[[ Прыжок свой: у дефолтного ControlModule он отключён вместе с модулем. ]]
function PlayerController:tryJump()
	local humanoid = self.humanoid
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - (self.lastJumpAt or 0) < 0.35 then
		return
	end
	local state = humanoid:GetState()
	if
		state == Enum.HumanoidStateType.Landed
		or state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics
	then
		self.lastJumpAt = now
		humanoid.Jump = true
	end
end

function PlayerController:bindCharacter(character)
	local current = character or player.Character
	if not current then
		return
	end
	self.character = current
	self.humanoid = current:WaitForChild("Humanoid")
	self.speed = 0

	-- Пересоздаём ViewModel под нового персонажа.
	if self.rig then
		self.rig:destroy()
	end
	self.rig = FirstPersonRig.new(self.camera)
	if self.onRigReady then
		self.onRigReady(self.rig)
	end
end

--[[ Читаем мышь (камера) и запоминаем инерцию для рук. ]]
function PlayerController:readInput()
	self.camera:readMouse()
end

--[[ Поворот персонажа строго по камере (иначе руки/коллизии разъедутся). ]]
function PlayerController:updateCharacterRotation(dt)
	local character = self.character
	local humanoid = self.humanoid
	if not (character and humanoid and humanoid.RootPart) then
		return
	end
	local flatLook = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flatLook.Magnitude < 0.01 then
		return
	end
	local targetCFrame = CFrame.lookAt(humanoid.RootPart.Position, humanoid.RootPart.Position + flatLook.Unit)
	-- Человекообразные поворачиваются мгновенно, как в шутерах от первого лица.
	humanoid.RootPart.CFrame = humanoid.RootPart.CFrame:Lerp(targetCFrame, math.clamp(dt * 25, 0, 1))
end

function PlayerController:updateMovement(dt)
	local humanoid = self.humanoid
	if not humanoid or humanoid.Health <= 0 then
		self.speed = 0
		return
	end

	local moveX, moveZ = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveZ -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveZ += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveX -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveX += 1
	end

	local camera = workspace.CurrentCamera
	local flatLook = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end
	local flatRight = flatLook:Cross(Vector3.new(0, 1, 0))

	local worldMove = flatLook * -moveZ + flatRight * moveX
	if worldMove.Magnitude > 0 then
		worldMove = worldMove.Unit
	end

	-- Тарковские скорости: медленно, весомо.
	local targetSpeed = Config.Movement.WalkSpeed
	if self.isCrouching then
		targetSpeed = Config.Movement.CrouchSpeed
	elseif self.isAiming then
		targetSpeed = Config.Movement.AimWalkSpeed
	elseif self.isSprinting and moveZ < 0 then
		targetSpeed = Config.Movement.SprintSpeed
	end

	-- Вес снаряжения и состояния (RaidSandbox на сервере) режут скорость.
	targetSpeed *= player:GetAttribute("HardOutSpeedMult") or 1

	-- Разгон/торможение, чтобы не было "роблоксовой" липкости.
	local rate = 1 / math.max(Config.Movement.AccelerationTime or 0.16, 0.01)
	self.walkSpeed += (targetSpeed - self.walkSpeed) * math.clamp(dt * rate, 0, 1)

	humanoid.WalkSpeed = self.walkSpeed
	humanoid:Move(worldMove * (worldMove.Magnitude > 0 and 1 or 0), false)

	-- Присед: уменьшаем HipHeight, чтобы модель реально опускалась.
	local targetHip = self.isCrouching and 1.2 or 2
	humanoid.HipHeight += (targetHip - humanoid.HipHeight) * math.clamp(dt * 10, 0, 1)

	local velocity = humanoid.RootPart and humanoid.RootPart.AssemblyLinearVelocity or Vector3.zero
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	self.speed = horizontal
	self.camera:setMovement(horizontal, self.isCrouching)
	self.camera:setLean(moveX)
	self.lean = moveX
end

function PlayerController:updateCamera(dt)
	self.camera:update(dt)
end

function PlayerController:updateRig(dt)
	if not self.rig then
		return
	end
	self.rig:addLook(self.camera.lastDelta.X, self.camera.lastDelta.Y)
	self.rig:setState({
		speed = self.speed,
		isAiming = self.isAiming,
		isSprinting = self.isSprinting,
		isCrouching = self.isCrouching,
		lean = self.lean,
	})
	self.rig:update(dt)
end

function PlayerController:setAdsFov(fov)
	self.adsFov = fov
	self.camera:setAiming(self.isAiming, fov)
end

return PlayerController

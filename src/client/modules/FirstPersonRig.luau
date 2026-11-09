--!nonstrict
--[[
	FirstPersonRig.luau
	Руки и ноги от первого лица.

	Как устроено:
	  * Модель живёт в workspace.Camera (не в персонаже) — её нельзя сломать
	    физикой или чужими анимациями.
	  * Каждая рука = два сегмента (плечо-локоть, локоть-кисть), поза считается
	    через IK (shared/HardOut/ArmSolver). Отсюда живая поза вместо "палки".
	  * Правая кисть — точка хвата оружия (Attachment HandAnchor), к ней
	    привязывается модель оружия через Grip (см. WeaponHolder).
	  * Ноги идут в такт шагу и видны, если посмотреть вниз.

	Контракт замены на свои модели: docs/HANDS_AND_GUN.md.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Config = require(HardOut:WaitForChild("Config"))
local Animator = require(HardOut:WaitForChild("Animator"))
local ArmSolver = require(HardOut:WaitForChild("ArmSolver"))

local FirstPersonRig = {}
FirstPersonRig.__index = FirstPersonRig

local SKIN = Color3.fromRGB(226, 180, 145)
local SLEEVE = Color3.fromRGB(58, 62, 54)
local CLOTH = Color3.fromRGB(54, 58, 52)
local CLOTH_DARK = Color3.fromRGB(38, 40, 36)
local BOOT = Color3.fromRGB(26, 26, 26)

local LENGTHS = {
	UpperArm = 1.15,
	LowerArm = 1.15,
	UpperLeg = 1.35,
	LowerLeg = 1.35,
}

local THICKNESS = {
	Arm = 0.5,
	Leg = 0.62,
}

local CHEST_SIZE = Vector3.new(1.5, 1.0, 0.9)

local function newPart(name, size, color, parent, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[ Ставит сегмент между двумя точками (ось Z = длина). ]]
local function placeSegment(part, from, to)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.001 then
		part.CFrame = CFrame.lookAt(from + delta * 0.5, to) * CFrame.Angles(0, 0, 0)
		return
	end
	part.Size = Vector3.new(part.Size.X, part.Size.Y, length)
	part.CFrame = CFrame.lookAt(from + delta * 0.5, to)
end

function FirstPersonRig.new(camera)
	local self = setmetatable({}, FirstPersonRig)
	self.camera = camera
	self.animator = Animator.new(camera)
	self.enabled = Config.ViewModel.Enabled

	self.speed = 0
	self.isAiming = false
	self.isSprinting = false
	self.isCrouching = false
	self.lean = 0
	self.aimFactor = 0
	self.legPhase = 0
	self.equipped = false

	self:build()
	self:hideCharacterLimbs()
	return self
end

function FirstPersonRig:build()
	local model = Instance.new("Model")
	model.Name = "HardOutViewModel"

	local chest = newPart("Chest", CHEST_SIZE, CLOTH, model)
	local rightUpperArm =
		newPart("RightUpperArm", Vector3.new(THICKNESS.Arm, THICKNESS.Arm, LENGTHS.UpperArm), SLEEVE, model)
	local rightLowerArm =
		newPart("RightLowerArm", Vector3.new(THICKNESS.Arm * 0.92, THICKNESS.Arm * 0.92, LENGTHS.LowerArm), SKIN, model)
	local leftUpperArm =
		newPart("LeftUpperArm", Vector3.new(THICKNESS.Arm, THICKNESS.Arm, LENGTHS.UpperArm), SLEEVE, model)
	local leftLowerArm =
		newPart("LeftLowerArm", Vector3.new(THICKNESS.Arm * 0.92, THICKNESS.Arm * 0.92, LENGTHS.LowerArm), SKIN, model)

	local rightUpperLeg =
		newPart("RightUpperLeg", Vector3.new(THICKNESS.Leg, THICKNESS.Leg, LENGTHS.UpperLeg), CLOTH_DARK, model)
	local rightLowerLeg =
		newPart("RightLowerLeg", Vector3.new(THICKNESS.Leg, THICKNESS.Leg, LENGTHS.LowerLeg), CLOTH_DARK, model)
	local leftUpperLeg =
		newPart("LeftUpperLeg", Vector3.new(THICKNESS.Leg, THICKNESS.Leg, LENGTHS.UpperLeg), CLOTH_DARK, model)
	local leftLowerLeg =
		newPart("LeftLowerLeg", Vector3.new(THICKNESS.Leg, THICKNESS.Leg, LENGTHS.LowerLeg), CLOTH_DARK, model)

	local rightBoot = newPart("RightBoot", Vector3.new(0.62, 0.3, 0.95), BOOT, model, Enum.Material.Leather)
	local leftBoot = newPart("LeftBoot", Vector3.new(0.62, 0.3, 0.95), BOOT, model, Enum.Material.Leather)

	-- Кисть правой руки — точка хвата оружия.
	local handAnchor = Instance.new("Attachment")
	handAnchor.Name = "HandAnchor"
	handAnchor.Parent = rightLowerArm

	local supportAnchor = Instance.new("Attachment")
	supportAnchor.Name = "SupportAnchor"
	supportAnchor.Parent = leftLowerArm

	model.Parent = workspace.Camera

	self.model = model
	self.chest = chest
	self.rightUpperArm = rightUpperArm
	self.rightLowerArm = rightLowerArm
	self.leftUpperArm = leftUpperArm
	self.leftLowerArm = leftLowerArm
	self.rightUpperLeg = rightUpperLeg
	self.rightLowerLeg = rightLowerLeg
	self.leftUpperLeg = leftUpperLeg
	self.leftLowerLeg = leftLowerLeg
	self.rightBoot = rightBoot
	self.leftBoot = leftBoot
	self.handAnchor = handAnchor
	self.supportAnchor = supportAnchor
	self.handPart = rightLowerArm
	return model
end

--[[ Прячет руки/ноги настоящего персонажа, чтобы не торчали в кадре. ]]
function FirstPersonRig:hideCharacterLimbs()
	if not Config.ViewModel.HideCharacterLimbs then
		return
	end
	local HIDE = { ["Right Arm"] = true, ["Left Arm"] = true, ["Right Leg"] = true, ["Left Leg"] = true }

	local function apply(character)
		local function hide(instance)
			if instance:IsA("BasePart") and HIDE[instance.Name] then
				instance.LocalTransparencyModifier = 1
			end
		end
		for _, descendant in character:GetDescendants() do
			hide(descendant)
		end
		character.DescendantAdded:Connect(function(descendant)
			task.defer(hide, descendant)
		end)
	end

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		task.defer(apply, character)
	end)
	if player.Character then
		task.defer(apply, player.Character)
	end
end

function FirstPersonRig:setState(state)
	self.speed = state.speed or 0
	self.isAiming = state.isAiming == true
	self.isSprinting = state.isSprinting == true
	self.isCrouching = state.isCrouching == true
	self.lean = state.lean or 0
	self.equipped = state.equipped ~= false
end

function FirstPersonRig:addLook(deltaX, deltaY)
	self.animator:AddLookDelta(Vector2.new(deltaX, deltaY))
end

--[[ Главный апдейт: ставит модель по камере и раскладывает конечности. ]]
function FirstPersonRig:update(dt)
	if not self.model or not self.enabled then
		return
	end

	local animation = self.animator:Step(dt, {
		speed = self.speed,
		isAiming = self.isAiming,
		isCrouching = self.isCrouching,
	})

	local cameraCFrame = self.camera.lastCFrame or workspace.CurrentCamera.CFrame
	local origin = cameraCFrame * Config.ViewModel.Offset * CFrame.new(0, -0.15, -0.15)

	local targetAim = self.isAiming and 1 or 0
	self.aimFactor += (targetAim - self.aimFactor) * math.clamp(dt * 12, 0, 1)

	-- Корпус: чуть повёрнут, покачивается вместе с камерой.
	self.chest.CFrame = origin
		* CFrame.new(animation.position)
		* CFrame.Angles(math.rad(animation.rotation.X), math.rad(animation.rotation.Y), math.rad(animation.rotation.Z))

	self:poseArms(dt, animation)
	self:poseLegs(dt)
end

--[[ Руки: IK от плеч к кистям. Правая кисть = место оружия. ]]
function FirstPersonRig:poseArms(dt, animation)
	local chestCFrame = self.chest.CFrame

	local aim = self.aimFactor
	local sprint = self.isSprinting and not self.isAiming
	local sprintFactor = 0
	if sprint then
		sprintFactor = 1
	end
	self.sprintFactor = (self.sprintFactor or 0) + (sprintFactor - (self.sprintFactor or 0)) * math.clamp(dt * 6, 0, 1)
	local sprintAmount = self.sprintFactor

	-- Плечи.
	local rightShoulder = chestCFrame * CFrame.new(0.45, 0.3, 0.1)
	local leftShoulder = chestCFrame * CFrame.new(-0.45, 0.3, 0.05)

	-- Кисти: при ADS подтягиваются к центру кадра, на бегу опускаются.
	local handForward = 0.95 - aim * 0.12 + sprintAmount * 0.35
	local handHeight = -0.12 + aim * 0.05 - sprintAmount * 0.5
	local handSpread = 0.22 - aim * 0.2

	local bobDown = math.min(animation.position.Y * 0.5, 0.15)

	-- Правая кисть — точка оружия. Левая тянется дальше вперёд (цевьё).
	local rightHand = chestCFrame * CFrame.new(handSpread, handHeight + bobDown, -handForward)
	local leftHand = chestCFrame * CFrame.new(-handSpread + 0.28, handHeight + bobDown - 0.04, -handForward - 0.42)

	-- IK правой руки.
	local rightJoint = ArmSolver.solve(
		rightShoulder.Position,
		rightHand.Position,
		LENGTHS.UpperArm,
		LENGTHS.LowerArm,
		Vector3.new(0.7, -1, -0.15)
	)
	placeSegment(self.rightUpperArm, rightShoulder.Position, rightJoint)
	placeSegment(self.rightLowerArm, rightJoint, rightHand.Position)

	-- Кисть на конце нижнего сегмента.
	self.handAnchor.CFrame = CFrame.new(0, 0, -LENGTHS.LowerArm * 0.5)

	-- IK левой руки (тянется к цевью).
	local leftJoint = ArmSolver.solve(
		leftShoulder.Position,
		leftHand.Position,
		LENGTHS.UpperArm,
		LENGTHS.LowerArm,
		Vector3.new(-0.7, -1, -0.15)
	)
	placeSegment(self.leftUpperArm, leftShoulder.Position, leftJoint)
	placeSegment(self.leftLowerArm, leftJoint, leftHand.Position)
	self.supportAnchor.CFrame = CFrame.new(0, 0, -LENGTHS.LowerArm * 0.5)
end

--[[ Ноги: бедра от корпуса, стопы по фазе шага. ]]
function FirstPersonRig:poseLegs(dt)
	local showLegs = Config.ViewModel.ShowLegs
	local parts = {
		self.rightUpperLeg,
		self.rightLowerLeg,
		self.leftUpperLeg,
		self.leftLowerLeg,
		self.rightBoot,
		self.leftBoot,
	}
	for _, part in parts do
		part.Transparency = showLegs and 0 or 1
	end
	if not showLegs then
		return
	end

	local chest = self.chest.CFrame
	local hipY = -CHEST_SIZE.Y * 0.5 - 0.05
	local hipRight = chest * CFrame.new(0.38, hipY, 0)
	local hipLeft = chest * CFrame.new(-0.38, hipY, 0)

	local walkRatio = math.clamp(self.speed / Config.Movement.WalkSpeed, 0, 1.8)
	self.legPhase += dt * walkRatio * 7.5
	local stride = 0.72 * math.min(walkRatio, 1.3)
	local lift = 0.42 * math.min(walkRatio, 1.2)

	local legLength = LENGTHS.UpperLeg + LENGTHS.LowerLeg

	-- Смещение стопы относительно бедра: вперёд/назад + подъём.
	local function footOffset(phase)
		local z = math.sin(phase) * stride
		local liftY = math.max(0, math.cos(phase)) * lift
		return Vector3.new(0, -legLength + 0.35 + liftY, z)
	end

	local footRight = hipRight * footOffset(self.legPhase)
	local footLeft = hipLeft * footOffset(self.legPhase + math.pi)

	local function placeLeg(hip, foot, upperPart, lowerPart, bootPart)
		local joint = ArmSolver.solve(
			hip.Position,
			foot.Position,
			LENGTHS.UpperLeg,
			LENGTHS.LowerLeg,
			Vector3.new(0, 0, -1) -- колено вперёд
		)
		placeSegment(upperPart, hip.Position, joint)
		placeSegment(lowerPart, joint, foot.Position)
		bootPart.CFrame =
			CFrame.lookAt(foot.Position + Vector3.new(0, 0.05, -0.18), foot.Position + Vector3.new(0, 0.05, -1))
	end

	placeLeg(hipRight, footRight, self.rightUpperLeg, self.rightLowerLeg, self.rightBoot)
	placeLeg(hipLeft, footLeft, self.leftUpperLeg, self.leftLowerLeg, self.leftBoot)
end

--[[ Интерфейс как у CharacterRig: часть-кисть и CFrame хвата. ]]
function FirstPersonRig:getGripCFrame(): CFrame
	return self.handAnchor.CFrame
end

function FirstPersonRig:getHandPart()
	return self.handAnchor.Parent
end

--[[ Мировая точка правой кисти. ]]
function FirstPersonRig:getHandCFrame()
	return self.rightLowerArm.CFrame * self.handAnchor.CFrame
end

function FirstPersonRig:setVisible(isVisible)
	if self.model then
		self.model.Parent = isVisible and workspace.Camera or nil
	end
end

function FirstPersonRig:destroy()
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

return FirstPersonRig

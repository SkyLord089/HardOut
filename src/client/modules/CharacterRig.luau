--!nonstrict
--[[
	CharacterRig.luau
	"Руки и ноги от первого лица" через НАСТОЯЩЕГО персонажа.

	Почему так лучше процедурных частей:
	  * руки и ноги — это твои аватары/скины, а не серые бруски;
	  * работают штатные анимации Roblox (idle / walk / run / jump) — «анимации
	    персонажа», как ты и просил;
	  * оружие цепляется к настоящей кисти (RightHand в R15, Right Arm в R6),
	    поэтому оно честно ездит вместе с анимацией рук.

	Что делает модуль:
	  1. Прячет голову и головные аксессуары (иначе они закрывают обзор изнутри).
	  2. Включает штатные анимации (в CharacterSetup они больше не отключаются).
	  3. Даёт стабильный интерфейс для WeaponHolder/WeaponController:
	         rig.handPart   — часть-кисть (BasePart)
	         rig:getGripCFrame() — CFrame хвата оружия в системе кисти
	         rig:setState / update / destroy
	4. Подстраховывает "провал камеры в голову": голова невидима локально,
	     поэтому near-plane не режет кадр.

	Переключить на процедурные руки: Config.ViewModel.Mode = "Procedural".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Config = require(HardOut:WaitForChild("Config"))

local CharacterRig = {}
CharacterRig.__index = CharacterRig

local HEAD_NAMES = {
	Head = true,
	["head"] = true,
}

local function isAccessory(instance: Instance): boolean
	-- Шляпы/маски/очки — это Accessory с рукой-обёрткой; прячем целиком.
	return instance:IsA("Accessory") or instance:IsA("Hat")
end

local function findHand(character: Instance): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	for _, handName in Config.Weapons.HandNames do
		local part = character:FindFirstChild(handName)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	-- На всякий случай: первая рука, которую найдём.
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and string.find(part.Name, "Arm") then
			return part
		end
	end
	return nil
end

function CharacterRig.new(character: Instance)
	local self = setmetatable({}, CharacterRig)
	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
	self.enabled = Config.ViewModel.Mode == "Character"

	self.hidden = {}
	self:prepare()
	return self
end

--[[ Видимостью тела управляет CharacterTransparency: она показывает руки/ноги/торс
     и прячет только голову. Здесь ничего не трогаем, чтобы не спорить с ней. ]]
function CharacterRig:hideHead()
	-- намеренно пусто: см. CharacterTransparency.luau
end

--[[ Штатные анимации должны играть: это и есть "анимации персонажа". ]]
function CharacterRig:prepare()
	self.handPart = findHand(self.character)

	local animate = self.character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = false
	end

	if self.humanoid then
		self.humanoid.AutoRotate = false -- поворотом управляет PlayerController
	end

	if not self.handPart then
		warn(
			"[HardOut] Не нашёл кисть персонажа (RightHand / Right Arm) — оружие не надеть."
		)
	end
end

--[[ CFrame, к которому цепляется оружие (в системе координат кисти). ]]
function CharacterRig:getGripCFrame(): CFrame
	return Config.Weapons.HandGripCFrame
end

--[[ Совместимость с PlayerController: состояние движения не нужно, но пусть будет. ]]
function CharacterRig:setState(_state: any)
	-- Настоящий персонаж анимируется собственными треками, руками управлять не надо.
end

function CharacterRig:addLook(_deltaX: number, _deltaY: number)
	-- Инерция рук от мыши: у штатных анимаций её нет. При желании можно добавить
	-- сюда лёгкий поворот Motor6D "Right Shoulder", но это ломает R15-анимации.
end

--[[ Вызывается каждый кадр. Пока делать нечего — позу ведёт Animator персонажа. ]]
function CharacterRig:update(_dt: number)
	if not self.enabled then
		return
	end
	-- Кисть могла пересоздаться (например, после смены аватара).
	if not self.handPart or not self.handPart.Parent then
		self.handPart = findHand(self.character)
	end
end

function CharacterRig:destroy()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	-- Возвращаем прозрачность (на случай смены режима на процедурный).
	for part in pairs(self.hidden) do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	table.clear(self.hidden)
end

return CharacterRig

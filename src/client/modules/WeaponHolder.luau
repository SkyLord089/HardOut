--!nonstrict
--[[
	WeaponHolder.luau
	ЗАГОТОВКА ПОД ОРУЖИЕ — здесь модель пушки превращается в "оружие в руках".

	Что делает по шагам:
	  1. Клонирует модель из ReplicatedStorage.WeaponModels.
	  2. Ищет сокеты Grip / Support / Muzzle / Sight (см. docs/HANDS_AND_GUN.md).
	  3. Мягко чинит проблемы: нет Grip -> цепляем по центру + warn.
	  4. Опционально масштабирует под эталон (Config.Weapons.AutoScale).
	  5. Жёстко привязывает модель к правой кисти через Weld
	     (обе части неанкоренные, поэтому оружие честно едет за рукой).
	  6. Отдаёт наружу статы и сокеты: Muzzle для вспышки/трассера, Sight для ADS.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local WeaponFolder = HardOut:WaitForChild("Weapon")

local Config = require(HardOut:WaitForChild("Config"))
local GunPreset = require(WeaponFolder:WaitForChild("GunPreset"))
local WeaponConfig = require(WeaponFolder:WaitForChild("WeaponConfig"))

local WeaponHolder = {}
WeaponHolder.__index = WeaponHolder

--[[ Путь "ReplicatedStorage.WeaponModels" -> Instance. ]]
function WeaponHolder.resolveWeaponFolder()
	local current = game :: any
	for segment in string.gmatch(Config.Weapons.FolderPath, "[^%.]+") do
		local nextInstance = current:FindFirstChild(segment)
		if not nextInstance then
			return nil
		end
		current = nextInstance
	end
	return current
end

--[[ Модели оружия из папки, отсортированные по имени. ]]
function WeaponHolder.listWeapons()
	local folder = WeaponHolder.resolveWeaponFolder()
	if not folder then
		return {}
	end
	local weapons = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(weapons, child)
		end
	end
	table.sort(weapons, function(a, b)
		return a.Name < b.Name
	end)
	return weapons
end

--[[ Печатает в консоль результат проверки модели. ]]
function WeaponHolder.report(weapon)
	local issue, sockets = GunPreset.diagnose(weapon)
	local names = {}
	for key in sockets do
		table.insert(names, key)
	end
	table.sort(names)

	if issue then
		warn(string.format("[HardOut] Модель '%s': %s", weapon.Name, issue))
	else
		print(
			string.format(
				"[HardOut] Модель '%s' OK. Сокеты: %s",
				weapon.Name,
				#names > 0 and table.concat(names, ", ") or "нет"
			)
		)
	end
	return issue, sockets
end

function WeaponHolder.new(rig, weapon)
	local self = setmetatable({}, WeaponHolder)
	self.rig = rig
	self.sourceName = weapon.Name
	self.stats = WeaponConfig.fromModel(weapon)

	self.cloned = weapon:Clone()

	if Config.Weapons.AutoScale then
		GunPreset.applyScale(self.cloned, GunPreset.computeScale(self.cloned))
	end

	self.cloned.Name = "HardOutWeapon_" .. weapon.Name
	self:prepareParts()
	self.cloned.Parent = workspace.Camera

	self.sockets = {}
	self:resolveSockets()
	self:attach()
	return self
end

--[[ Части: без коллизий/рейкастов и неанкоренные (иначе Weld не потащит). ]]
function WeaponHolder:prepareParts()
	local primary = self.cloned.PrimaryPart
	if not primary then
		primary = self.cloned:FindFirstChildWhichIsA("BasePart", true)
		self.cloned.PrimaryPart = primary
	end

	for _, descendant in self.cloned:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
			-- Свет/эффекты из исходной модели могут мигать — гасим, стенд добавит свои.
			descendant.Enabled = false
		end
	end
	self.root = primary
end

function WeaponHolder:resolveSockets()
	for key, name in GunPreset.AttachmentNames do
		local attachment = GunPreset.getAttachment(self.cloned, name)
		if attachment then
			self.sockets[key] = attachment
		end
	end
end

--[[ Привязка к правой кисти: Weld c C0 = кисть, C1 = точка Grip. ]]
function WeaponHolder:attach()
	local root = self.root
	if not root then
		warn(
			string.format(
				"[HardOut] В модели '%s' нет ни одной BasePart — держать нечего.",
				self.sourceName
			)
		)
		return
	end

	local grip = self.sockets.Grip
	if not grip then
		warn(
			string.format(
				"[HardOut] '%s': нет Attachment 'Grip'. Оружие встанет по центру модели; "
					.. "добавь Attachments.Grip, чтобы настроить хват (docs/HANDS_AND_GUN.md).",
				self.sourceName
			)
		)
		local fallback = Instance.new("Attachment")
		fallback.Name = "Grip"
		fallback.Parent = root
		grip = fallback
		self.sockets.Grip = fallback
	end

	-- C1 — CFrame.Grip в системе координат корневой части оружия.
	local gripWorld = (grip.Parent :: BasePart).CFrame * grip.CFrame
	local gripRelative = root.CFrame:ToObjectSpace(gripWorld)

	-- Кисть берём у рига: у настоящего персонажа это RightHand/Right Arm,
	-- у процедурного — конец правой руки. Так оружие работает в обоих режимах.
	local handPart = self.rig.handPart or (self.rig.handAnchor and self.rig.handAnchor.Parent)
	if not handPart or not handPart:IsA("BasePart") then
		warn("[HardOut] Не найдена кисть для крепления оружия.")
		return
	end
	self.handPart = handPart

	local gripCFrame = Config.Weapons.HandGripCFrame
	if self.rig.getGripCFrame then
		gripCFrame = self.rig:getGripCFrame()
	elseif self.rig.handAnchor then
		gripCFrame = self.rig.handAnchor.CFrame
	end

	local weld = Instance.new("Weld")
	weld.Name = "WeaponWeld"
	weld.Part0 = handPart
	weld.Part1 = root
	weld.C0 = gripCFrame
	weld.C1 = gripRelative
	weld.Parent = handPart
	self.weld = weld
	self.baseGrip = gripCFrame
	self.aimAlpha = 0
end

--[[
	Прицеливание (ADS) для настоящей руки: позу руки мы не трогаем (её ведёт
	аниматор персонажа), поэтому оружие само плавно подъезжает к центру кадра.
	Для процедурного рига рука и так поднимается — там сдвиг меньше.
]]
function WeaponHolder:setAim(alpha: number, dt: number)
	if not self.weld or not self.baseGrip then
		return
	end
	local target = math.clamp(alpha or 0, 0, 1)
	self.aimAlpha += (target - self.aimAlpha) * math.clamp(dt * 12, 0, 1)

	local offset = Config.Weapons.AimOffset or CFrame.new()
	self.weld.C0 = self.baseGrip * CFrame.new(offset.Position * self.aimAlpha)
end

function WeaponHolder:getMuzzleCFrame(): CFrame
	local muzzle = self.sockets.Muzzle
	if muzzle then
		return muzzle.WorldCFrame
	end
	if self.root then
		return self.root.CFrame * CFrame.new(0, 0, -self.root.Size.Z * 0.5)
	end
	return CFrame.new(0, 0, 0)
end

function WeaponHolder:getSightCFrame(): CFrame?
	local sight = self.sockets.Sight
	if sight then
		return sight.WorldCFrame
	end
	return nil
end

function WeaponHolder:destroy()
	if self.weld then
		self.weld:Destroy()
		self.weld = nil
	end
	if self.cloned then
		self.cloned:Destroy()
		self.cloned = nil
	end
end

return WeaponHolder

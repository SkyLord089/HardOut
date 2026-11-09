--!nonstrict
--[[
	SampleWeapon.luau
	Демо-оружие "HYBRID-9": процедурная заготовка из Parts, повторяющая ровно тот
	контракт, который ждёт стенд:

		Model "HYBRID-9"
		  ├─ Body, Slide, Barrel, Grip, Magazine, SightRear...  (MeshPart/Part)
		  └─ Attachments (Folder)
		       ├─ Grip    Attachment  — точка хвата правой рукой
		       ├─ Support Attachment  — точка поддержки левой рукой
		       ├─ Muzzle  Attachment  — срез ствола (вспышка/трассер)
		       └─ Sight   Attachment  — точка прицеливания (ADS)

	Зачем нужен: проверить стенд ДО того, как появится твоя модель, и увидеть,
	как правильно расставлены сокеты и оси. Удалить можно одной строкой в
	init.server.luau (HardOut создаст его только если папка пустая).

	Когда положишь свою модель — демо можно убрать: Config.Weapons.AutoSpawnSample = false.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SampleWeapon = {}

local function part(name, size, cframe, color, material, parent)
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Material = material or Enum.Material.Metal
	instance.Anchored = false
	instance.CanCollide = false
	instance.CanQuery = false
	instance.CanTouch = false
	instance.Massless = true
	instance.Parent = parent
	return instance
end

local function attachment(name, cframe, parent)
	local instance = Instance.new("Attachment")
	instance.Name = name
	instance.CFrame = cframe
	instance.Parent = parent
	return instance
end

--[[ Собирает модель демо-оружия. Оси: ствол = -Z, верх = +Y. ]]
function SampleWeapon.build()
	local model = Instance.new("Model")
	model.Name = "HYBRID-9"

	local METAL = Color3.fromRGB(52, 54, 56)
	local DARK = Color3.fromRGB(30, 31, 33)
	local POLYMER = Color3.fromRGB(43, 45, 42)
	local ACCENT = Color3.fromRGB(120, 96, 60)

	-- Корпус (ресивер). Ось Z = длина оружия (ствол смотрит в -Z), ось Y = верх.
	local body = part("Body", Vector3.new(0.34, 0.42, 1.9), CFrame.new(0, 0, 0), METAL, nil, model)

	-- Ствол.
	part("Barrel", Vector3.new(0.16, 0.16, 1.15), CFrame.new(0, 0.06, -1.45), DARK, nil, model)

	-- Цевьё (сюда встаёт левая рука).
	part("Handguard", Vector3.new(0.3, 0.3, 0.85), CFrame.new(0, -0.02, -1.0), POLYMER, nil, model)

	-- Затвор/кожух сверху.
	part("Slide", Vector3.new(0.3, 0.16, 1.3), CFrame.new(0, 0.28, -0.2), METAL, nil, model)

	-- Пистолетная рукоять, наклонена назад.
	part(
		"GripPart",
		Vector3.new(0.28, 0.75, 0.38),
		CFrame.new(0, -0.5, 0.62) * CFrame.Angles(math.rad(-15), 0, 0),
		POLYMER,
		nil,
		model
	)

	-- Магазин.
	part(
		"MagazinePart",
		Vector3.new(0.24, 0.62, 0.3),
		CFrame.new(0, -0.75, 0.68) * CFrame.Angles(math.rad(-10), 0, 0),
		DARK,
		nil,
		model
	)

	-- Приклад.
	part("Stock", Vector3.new(0.22, 0.34, 0.9), CFrame.new(0, -0.06, 1.35), POLYMER, nil, model)
	part("StockPad", Vector3.new(0.26, 0.46, 0.12), CFrame.new(0, -0.08, 1.82), DARK, nil, model)

	-- Прицельные: задний + мушка.
	part("RearSight", Vector3.new(0.2, 0.12, 0.1), CFrame.new(0, 0.42, 0.24), ACCENT, nil, model)
	part("FrontSight", Vector3.new(0.09, 0.16, 0.08), CFrame.new(0, 0.32, -1.86), ACCENT, nil, model)

	-- Спусковая скоба.
	part("TriggerGuard", Vector3.new(0.2, 0.1, 0.42), CFrame.new(0, -0.3, 0.26), DARK, nil, model)

	model.PrimaryPart = body

	-- ВАЖНО: сокеты. Это единственное, что обязательно для стенда.
	local sockets = Instance.new("Folder")
	sockets.Name = "Attachments"
	sockets.Parent = model

	-- Grip: где находится правая ладонь. Оружие смотрит в -Z, верх +Y.
	attachment("Grip", CFrame.new(0, -0.38, 0.62) * CFrame.Angles(math.rad(-8), 0, 0), sockets)

	-- Support: куда встаёт левая рука (цевьё).
	attachment("Support", CFrame.new(0, -0.12, -1.02), sockets)

	-- Muzzle: срез ствола, ось -Z смотрит вперёд. Отсюда вспышка и трассер.
	attachment("Muzzle", CFrame.new(0, 0.06, -2.06), sockets)

	-- Sight: точка, куда "смотрит" глаз в ADS.
	attachment("Sight", CFrame.new(0, 0.42, 0.24), sockets)

	-- Статы прямо на модели (перекрывают пресет WeaponConfig).
	model:SetAttribute("RoundsPerMinute", 700)
	model:SetAttribute("Damage", 36)
	model:SetAttribute("MagazineSize", 30)
	model:SetAttribute("ReloadTime", 2.4)
	model:SetAttribute("Auto", true)
	model:SetAttribute("AmmoType", "9x19")
	model:SetAttribute("AdsFov", 48)
	model:SetAttribute("Spread", 1.5)
	model:SetAttribute("SpreadAim", 0.2)
	model:SetAttribute("Recoil", 1.0)
	model:SetAttribute("RecoilVisual", 1.0)
	model:SetAttribute("Range", 300)

	return model
end

--[[ Кладёт демо-оружие в папку, если она пуста. ]]
function SampleWeapon.install(folder)
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") or child:IsA("Tool") then
			return nil -- у пользователя уже есть своё оружие, не мешаем
		end
	end

	local model = SampleWeapon.build()
	model.Parent = folder
	return model
end

return SampleWeapon

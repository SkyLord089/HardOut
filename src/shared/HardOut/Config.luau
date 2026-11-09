--!strict
--[[
	Config.luau
	Все настройки тестового стенда в одном месте.
	Начинать правки стоит отсюда — почти всё поведение крутится здесь.
]]

local Config = {}

--[[ Инвентарь ]]
Config.Inventory = {
	-- Сколько слотов рисуется в хотбаре (максимум 9 — по числу клавиш).
	Slots = 9,
	FirstSlot = 1,
}

--[[ Камера / вид от первого лица ]]
Config.Camera = {
	BaseFov = 75,
	FovLerpSpeed = 10,

	-- Наклон камеры при стрейфе (градусы). Мягко: 1.0-1.5, "тарковее": 2.5+.
	LeanAngle = 1.2,

	-- Покачивание головы при ходьбе.
	-- 0.045 — почти незаметно; 0.15-0.25 — явно чувствуется.
	HeadBob = {
		Enabled = true,
		Amplitude = 0.16, -- studs
		Frequency = 1.8, -- множитель к частоте шага
	},

	-- Сила "тряски" от выстрела. 0 = совсем без тряски.
	ShakeScale = 0.35,

	-- Сглаживание поворота: 0 = 1:1 с мышью, 0.3-0.4 = мягко (не "дёргает").
	Smoothing = 0.3,

	-- Прятать системный курсор и запирать его в центре экрана.
	HideCursor = true,

	-- Рисовать свой прицел в центре. false = чистая картинка без точки.
	ShowCrosshair = false,

	-- Смещение глаз относительно головы персонажа.
	EyeOffset = Vector3.new(0, 0.35, 0),

	-- Насколько камера выдвинута вперёд из головы (studs).
	-- 0 = камера внутри головы (видно только ноги), 0.4-0.5 = видно торс и живот.
	-- Подбирай командой /eye 0.45 прямо в игре.
	EyeForward = 0.45,
}

--[[ Руки и ноги от первого лица ]]
Config.ViewModel = {
	-- Как показывать тело:
	--   "Character"   — НАСТОЯЩИЙ персонаж: его руки, ноги и штатные анимации
	--                   (рекомендуется: живые анимации Roblox, видны руки и ноги).
	--   "Procedural"  — процедурные руки/ноги из кода (без ассетов, свои позы).
	Mode = "Character",

	-- Для Mode = "Procedural".
	Enabled = true,
	ShowLegs = true,
	HideCharacterLimbs = true,
	Offset = CFrame.new(0, 0, 0),

	-- Прятать голову и головные аксессуары (шляпы/маски), чтобы не закрывали обзор.
	HideHead = true,

	-- ВИДЕТЬ СВОЁ ТЕЛО от первого лица (руки, ноги, живот/торс).
	-- false -> штатное поведение Roblox: тело локально прозрачное.
	ShowBody = true,
}

--[[ Оружие в руках ]]
Config.Weapons = {
	-- Папка в ReplicatedStorage с моделями оружия (Model).
	FolderPath = "ReplicatedStorage.WeaponModels",

	-- Подгонять размер модели под эталон.
	AutoScale = false,

	-- Звук выстрела: свой rbxassetid, пусто = без звука.
	ShotSoundId = "",

	-- Куда крепится оружие ОТНОСИТЕЛЬНО кисти (RightHand / Right Arm).
	-- Если пушка смотрит вверх/вбок — крути именно это, а не модель:
	--   CFrame.Angles(math.rad(-90), 0, 0) разворачивает ствол вдоль руки.
	HandGripCFrame = CFrame.new(0, -0.35, 0) * CFrame.Angles(math.rad(-90), 0, 0),

	-- Имя части-кисти для разных ригов (R15 / R6).
	HandNames = { "RightHand", "Right Arm" },

	-- Сдвиг модели оружия в прицеле (ADS): придвигаем к центру экрана.
	AimOffset = CFrame.new(0, 0.12, -0.15),
}

--[[ Движение — намеренно медленнее роблоксового, в духе Таркова ]]
Config.Movement = {
	WalkSpeed = 8,
	AimWalkSpeed = 4.5,
	SprintSpeed = 15,
	CrouchSpeed = 3.5,
	JumpPower = 42,
	-- Время разгона/торможения (сек).
	AccelerationTime = 0.16,
}

--[[ Тестовый полигон ]]
Config.TestRange = {
	-- false -> полигон не строится (если хочешь свой уровень).
	Enabled = true,
}

--[[ Отладка ]]
Config.Debug = {
	-- Печатать в консоль, что найдено/создано (модели, сокеты, полигон).
	Verbose = true,
	-- Время жизни трассера (сек).
	TraceLifetime = 0.12,
}

--[[ Клавиши (используются в client/modules/Input.luau) ]]
Config.Keys = {
	Sprint = Enum.KeyCode.LeftShift,
	Crouch = Enum.KeyCode.C,
	Reload = Enum.KeyCode.R,
	Unequip = Enum.KeyCode.X,
}

return Config

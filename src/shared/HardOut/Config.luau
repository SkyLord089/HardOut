--!strict
--[[
	Config.luau
	Все настройки тестового стенда в одном месте.
	Начинать правки стоит отсюда — почти всё поведение крутится здесь.
]]

local Config = {}

--[[ Оружие ]]
Config.Weapons = {
	-- Папка в ReplicatedStorage, куда кладутся модели оружия (Model или Tool).
	-- Положил модель -> стенд сам выдаст её в руки (слот 1, дальше по алфавиту).
	FolderPath = "ReplicatedStorage.WeaponModels",

	-- Подгонять размер модели под эталон (GunPreset.ReferenceSize).
	-- Полезно, если модель сделана "не в масштабе" персонажа.
	AutoScale = false,

	-- Звук выстрела: вставь свой rbxassetid, например "rbxassetid://123456789".
	-- Пусто -> без звука (стенд не тянет сторонние ассеты).
	ShotSoundId = "",
}

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

	-- Наклон камеры при стрейфе (градусы) — тарковская "масса" при движении.
	LeanAngle = 2.5,

	-- Покачивание головы при ходьбе.
	HeadBob = {
		Enabled = true,
		Amplitude = 0.1, -- studs
		Frequency = 2.0, -- множитель к частоте шага
	},

	-- Смещение глаз относительно головы персонажа.
	EyeOffset = Vector3.new(0, 0.35, 0),
}

--[[ Модель от первого лица (руки/ноги) ]]
Config.ViewModel = {
	-- Включить процедурные руки/ноги.
	Enabled = true,

	-- Показывать ноги (видны при взгляде вниз).
	ShowLegs = true,

	-- Скрывать настоящие руки/ноги персонажа, чтобы не торчали в кадре.
	HideCharacterLimbs = true,

	-- Общий сдвиг ViewModel относительно камеры (если нужно "посадить" руки ниже).
	Offset = CFrame.new(0, 0, 0),
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

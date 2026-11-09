--!nonstrict
--[[
	run.luau
	Раннер юнит-тестов исходников стенда.

	Как работает:
	  1. Загружает моки Roblox API (Vector3/CFrame/Enum).
	  2. Загружает модули стенда ЧЕРЕЗ loadstring, подменяя `require`,
	     чтобы пути вида script.Parent работали без Filesystem Roblox.
	  3. Прогоняет набор проверок чистой логики (математика, патроны, отдача, IK).

	Запуск (см. tools/test.sh):
		lune run tests/run.luau
	или через @luau-rs/luau (node) — tools/run-tests.mjs.
]]

local ROOT = "src/shared/HardOut/"

local moduleCache = {}
local moduleSources = {
	Config = "Config.luau",
	Animator = "Animator.luau",
	ArmSolver = "ArmSolver.luau",
	Ballistics = "Weapon/Ballistics.luau",
	Recoil = "Weapon/Recoil.luau",
	Spring = "Weapon/Spring.luau",
	WeaponConfig = "Weapon/WeaponConfig.luau",
	WeaponState = "Weapon/WeaponState.luau",
	AimSolver = "Weapon/AimSolver.luau",
}

local currentPath = nil

local function loadModule(name)
	if moduleCache[name] then
		return moduleCache[name]
	end
	local file = ROOT .. moduleSources[name]
	local source = io.open(file, "r")
	if not source then
		error("Не найден модуль: " .. file)
	end
	local code = source:read("*a")
	source:close()

	local previousPath = currentPath
	currentPath = name

	local fn, err = loadstring(code, "@" .. file)
	if not fn then
		error("Синтаксическая ошибка в " .. file .. ": " .. tostring(err))
	end
	local result = fn()
	moduleCache[name] = result

	currentPath = previousPath
	return result
end

-- Мок `script`: модуль AimSolver делает require(script.Parent.Ballistics),
-- поэтому подсовываем таблицу-«иерархию» с именами модулей.
script = {
	Parent = {
		Ballistics = "Ballistics",
	},
	Name = "AimSolver",
}

-- Специальный require, который понимает имена модулей стенда.
require = function(target)
	if type(target) == "string" then
		return loadModule(target)
	end
	error("Тестовый require поддерживает только строковые имена модулей")
end

-- Моки лежат рядом с тестами: ищем и в tests/, и в корне проекта.
local MOCK_PATHS = { "tests/roblox_mocks.luau", "roblox_mocks.luau" }

local function loadMocks()
	for _, path in MOCK_PATHS do
		local handle = io.open(path)
		if handle then
			local chunk = assert(loadstring(handle:read("*a"), "@" .. path))
			handle:close()
			chunk()
			return
		end
	end
	error("Не найден файл моков roblox_mocks.luau")
end

loadMocks()

-- Мок game: RaidSandbox в initialize() трогает сервисы, но чистые формулы — нет.
game = {
	GetService = function(_, name)
		return {
			GetPlayers = function()
				return {}
			end,
			PlayerAdded = { Connect = function() end },
			PlayerRemoving = { Connect = function() end },
			FindFirstChild = function()
				return nil
			end,
		}
	end,
}

moduleSources.RaidSandbox = nil

--[[ Мини-фреймворк ]]
local tests = {}
local failures = 0
local passes = 0

local function test(name, callback)
	table.insert(tests, { name = name, callback = callback })
end

local function assertTrue(value, message)
	if not value then
		error(message or "ожидалось true, получено false", 2)
	end
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(
			string.format(
				"%s: ожидалось %s, получено %s",
				message or "неравенство",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

local function assertNear(actual, expected, tolerance, message)
	if math.abs(actual - expected) > (tolerance or 1e-4) then
		error(
			string.format(
				"%s: ожидалось ~%f, получено %f",
				message or "не в допуске",
				expected,
				actual
			),
			2
		)
	end
end

local function assertVectorNear(actual, expected, tolerance, message)
	assertNear(actual.X, expected.X, tolerance, (message or "") .. " X")
	assertNear(actual.Y, expected.Y, tolerance, (message or "") .. " Y")
	assertNear(actual.Z, expected.Z, tolerance, (message or "") .. " Z")
end

local function fixedRng(value)
	return function()
		return value
	end
end

local function sequenceRng(values)
	local index = 0
	return function()
		index += 1
		return values[((index - 1) % #values) + 1]
	end
end

------------------------------------------------------------------------
-- Ballistics
------------------------------------------------------------------------

local Ballistics = loadModule("Ballistics")

test("applySpread(0) не меняет направление", function()
	local direction = Vector3.new(0, 0, -1)
	local result = Ballistics.applySpread(direction, 0, fixedRng(0.5))
	assertVectorNear(result, direction, 1e-6)
end)

test("applySpread остаётся внутри конуса", function()
	local direction = Vector3.new(0, 0, -1)
	local cone = 5
	local cosCone = math.cos(math.rad(cone))
	local rng = sequenceRng({ 0.13, 0.77, 0.42, 0.91, 0.05, 0.63 })
	for index = 1, 200 do
		local result = Ballistics.applySpread(direction, cone, rng)
		assertNear(result.Magnitude, 1, 1e-4, "спред сломал нормализацию")
		local dot = result:Dot(direction)
		assertTrue(dot >= cosCone - 1e-6, "выстрел вышел за конус разброса")
	end
end)

test("applySpread не даёт NaN при выстреле строго вверх", function()
	local direction = Vector3.new(0, 1, 0)
	local rng = sequenceRng({ 0.5, 0.5 })
	local result = Ballistics.applySpread(direction, 12, rng)
	assertTrue(result.X == result.X, "NaN по X")
	assertNear(result.Magnitude, 1, 1e-4)
end)

test("dropCompensation растёт с дистанцией", function()
	local near = Ballistics.dropCompensation(50, 800)
	local far = Ballistics.dropCompensation(300, 800)
	assertTrue(far > near, "поправка на падение не растёт")
	assertNear(Ballistics.dropCompensation(0, 800), 0, 1e-9, "на нуле поправка должна быть 0")
end)

test("travelTime пропорционально дистанции", function()
	assertNear(Ballistics.travelTime(100, 1000), 0.1, 1e-9)
	assertNear(Ballistics.travelTime(0, 1000), 0, 1e-9)
end)

test("integrate увело пулю вниз", function()
	local direction = Vector3.new(0, 0, -1)
	local newDirection = Ballistics.integrate(direction, 100, 0.5)
	assertTrue(newDirection.Y < 0, "гравитация не применилась")
end)

test("recoilOffset: первый выстрел точнее десятого", function()
	local stats = { Recoil = 1 }
	local rng = fixedRng(0.5)
	local _, firstPitch = Ballistics.recoilOffset(stats, 0, rng)
	local _, pitch = Ballistics.recoilOffset(stats, 8, rng)
	assertTrue(pitch > firstPitch, "отдача не нарастает к середине магазина")
end)

------------------------------------------------------------------------
-- Spring / Recoil
------------------------------------------------------------------------

local Spring = loadModule("Spring")

test("Spring приходит к цели и не перелетает бесконечно", function()
	local spring = Spring.new(0, 180, 16)
	spring:SetTarget(1)
	for _ = 1, 240 do
		spring:Step(1 / 60)
	end
	assertNear(spring.value, 1, 0.01, "пружина не дошла до цели")
end)

local Recoil = loadModule("Recoil")

test("Recoil возвращается к нулю после выстрелов", function()
	local recoil = Recoil.new()
	recoil:AddShot(3, 4, 1)
	recoil:Step(1 / 60)
	for _ = 1, 600 do
		recoil:Step(1 / 60)
	end
	local yaw, pitch = recoil:Step(1 / 60)
	assertNear(yaw, 0, 0.05, "yaw не вернулся")
	assertNear(pitch, 0, 0.05, "pitch не вернулся")
end)

------------------------------------------------------------------------
-- WeaponState
------------------------------------------------------------------------

local WeaponState = loadModule("WeaponState")

local pistolStats = {
	RoundsPerMinute = 320,
	MagazineSize = 17,
	ReloadTime = 2,
	Auto = false,
	ReserveAmmo = 51,
	Spread = 2,
	SpreadAim = 0.5,
	Recoil = 1,
	Damage = 30,
	HeadshotMult = 2,
	Range = 150,
}

test("полуавтомат не стреляет второй раз с зажатым курком", function()
	local state = WeaponState.new(pistolStats)
	local now = 0
	assertTrue(state:canFire(now))
	state:fire(now)
	assertTrue(not state:canFire(now + 0.5), "полуавтомат дал очередь")
	state:releaseTrigger()
	assertTrue(state:canFire(now + 0.5), "после отпускания курка выстрела нет")
end)

test("автомат стреляет очередью с ограничением темпа", function()
	local stats = table.clone(pistolStats)
	stats.Auto = true
	stats.RoundsPerMinute = 600
	local state = WeaponState.new(stats)
	state:fire(0)
	assertTrue(not state:canFire(0.01), "темп не соблюдён")
	assertTrue(state:canFire(0.11), "очередь не стреляет после интервала")
end)

test("перезарядка добивает магазин из запаса", function()
	local state = WeaponState.new(pistolStats)
	for _ = 1, 5 do
		state.magazine -= 1
	end
	local started = state:startReload(0)
	assertTrue(started, "перезарядка не началась")
	assertTrue(not state:canFire(0.5), "во время перезарядки можно стрелять")
	local finished = state:update(2.1)
	assertTrue(finished, "перезарядка не закончилась")
	assertEqual(state.magazine, 17, "магазин не полный")
	assertEqual(state.reserve, 51 - 5, "неверный расход запаса")
end)

test("нельзя перезарядиться с пустым запасом", function()
	local state = WeaponState.new(pistolStats)
	state.reserve = 0
	state.magazine = 3
	assertTrue(not state:startReload(0))
end)

test("reloadProgress идёт от 0 к 1", function()
	local state = WeaponState.new(pistolStats)
	state.magazine -= 5
	assertTrue(
		state:startReload(10),
		"перезарядка должна начаться при неполном магазине"
	)
	assertNear(state:reloadProgress(10), 0, 1e-6)
	assertNear(state:reloadProgress(11), 0.5, 1e-6)
	assertNear(state:reloadProgress(12.5), 1, 1e-6)
end)

------------------------------------------------------------------------
-- WeaponConfig
------------------------------------------------------------------------

local WeaponConfig = loadModule("WeaponConfig")

test("пресет PM подхватывается по имени", function()
	local stats = WeaponConfig.fromName("PM")
	assertEqual(stats.Auto, false)
	assertEqual(stats.MagazineSize, 17)
	assertEqual(stats.AmmoType, "9x18")
end)

test("пресет AK автоматический", function()
	local stats = WeaponConfig.fromName("AK74_my_model")
	assertEqual(stats.Auto, true)
	assertEqual(stats.MagazineSize, 30)
end)

test("неизвестное имя получает дефолт", function()
	local stats = WeaponConfig.fromName("Безымянный_бластер")
	assertEqual(stats.Damage, WeaponConfig.Defaults.Damage)
	assertEqual(stats.MagazineSize, WeaponConfig.Defaults.MagazineSize)
end)

test("атрибуты модели перекрывают пресет", function()
	local model = MockInstance.new("PM", { Damage = 99, MagazineSize = 8, Auto = true })
	local stats = WeaponConfig.fromModel(model)
	assertEqual(stats.Damage, 99)
	assertEqual(stats.MagazineSize, 8)
	assertEqual(stats.Auto, true)
end)

test("secondsPerShot считает темп", function()
	local stats = table.clone(pistolStats)
	assertNear(WeaponConfig.secondsPerShot(stats), 60 / 320, 1e-9)
end)

------------------------------------------------------------------------
-- AimSolver
------------------------------------------------------------------------

local AimSolver = loadModule("AimSolver")

local aimStats = {
	Damage = 40,
	HeadshotMult = 2.5,
	Range = 200,
	Spread = 0,
	SpreadAim = 0,
	Recoil = 1,
}

test("попадание в голову даёт множитель", function()
	local result = AimSolver.solve({
		origin = Vector3.new(0, 0, 0),
		direction = Vector3.new(0, 0, -1),
		stats = aimStats,
		spreadDegrees = 0,
		rng = fixedRng(0.5),
		resolver = function()
			return {
				Instance = MockInstance.new("Head"),
				Position = Vector3.new(0, 0, -10),
				Normal = Vector3.new(0, 0, 1),
			}
		end,
	})
	assertTrue(result.Hit)
	assertTrue(result.IsHead)
	assertNear(result.Damage, 100, 1e-6, "урон в голову")
	assertNear(result.Distance, 10, 1e-6, "дистанция")
end)

test("попадание в конечность снижает урон", function()
	local result = AimSolver.solve({
		origin = Vector3.new(0, 0, 0),
		direction = Vector3.new(0, 0, -1),
		stats = aimStats,
		spreadDegrees = 0,
		rng = fixedRng(0.5),
		resolver = function()
			return {
				Instance = MockInstance.new("LeftArm"),
				Position = Vector3.new(0, 0, -5),
				Normal = Vector3.new(0, 0, 1),
			}
		end,
	})
	assertNear(result.Damage, 28, 1e-6, "урон в руку")
end)

test("промах возвращает дистанцию = Range и нулевой урон", function()
	local result = AimSolver.solve({
		origin = Vector3.new(0, 0, 0),
		direction = Vector3.new(0, 0, -1),
		stats = aimStats,
		spreadDegrees = 0,
		rng = fixedRng(0.5),
		resolver = function()
			return nil
		end,
	})
	assertTrue(not result.Hit)
	assertEqual(result.Damage, 0)
	assertNear(result.Distance, 200, 1e-6)
end)

test("computeSpread: прицел точнее, движение шире", function()
	local stats = table.clone(aimStats)
	stats.Spread = 2
	stats.SpreadAim = 0.5

	local standing = AimSolver.computeSpread(stats, false, 0)
	local aiming = AimSolver.computeSpread(stats, true, 0)
	assertTrue(aiming < standing, "прицел не снизил разброс")

	local moving = AimSolver.computeSpread(stats, false, 1)
	assertTrue(moving > standing, "движение не расширило разброс")
end)

------------------------------------------------------------------------
-- ArmSolver (IK)
------------------------------------------------------------------------

local ArmSolver = loadModule("ArmSolver")

test("IK: рука достаёт до цели на вытянутую длину", function()
	local root = Vector3.new(0, 0, 0)
	local target = Vector3.new(0, 0, -2)
	local joint, reachable = ArmSolver.solve(root, target, 1.15, 1.15, Vector3.new(0, -1, 0))
	assertTrue(reachable, "цель должна быть достижима")
	assertNear((joint - root).Magnitude, 1.15, 1e-4, "длина первого сегмента")
	assertNear((target - joint).Magnitude, 1.15, 1e-4, "длина второго сегмента")
end)

test("IK: недостижимая цель -> рука выпрямлена, reachable=false", function()
	local root = Vector3.new(0, 0, 0)
	local target = Vector3.new(0, 0, -10)
	local joint, reachable = ArmSolver.solve(root, target, 1.15, 1.15, Vector3.new(0, -1, 0))
	assertTrue(not reachable)
	-- Локоть лежит на прямой между плечом и целью.
	local cross = (joint - root):Cross(target - root)
	assertNear(cross.Magnitude, 0, 1e-4, "локоть ушёл с оси")
end)

test("IK: локоть выгибается в сторону hint", function()
	local root = Vector3.new(0, 0, 0)
	local target = Vector3.new(0, 0, -1.5)
	local joint = ArmSolver.solve(root, target, 1.15, 1.15, Vector3.new(0, -1, 0))
	assertTrue(joint.Y < -0.1, "локоть не выгнулся вниз")
end)

test("segmentLength считает расстояние", function()
	assertNear(ArmSolver.segmentLength(Vector3.new(0, 0, 0), Vector3.new(0, 3, 4)), 5, 1e-6)
end)

------------------------------------------------------------------------
-- RaidSandbox (вес и состояния) — загружаем напрямую из server/modules
------------------------------------------------------------------------

local RaidSandbox
do
	local handle = io.open("src/server/modules/RaidSandbox.luau")
	assert(handle, "не найден RaidSandbox.luau")
	local chunk = assert(loadstring(handle:read("*a"), "@RaidSandbox"))
	handle:close()
	RaidSandbox = chunk()
end

test("вес снаряжения замедляет, но не останавливает", function()
	local light = RaidSandbox.speedMultiplier(0)
	local heavy = RaidSandbox.speedMultiplier(40)
	assertNear(light, 1, 1e-6, "без веса скорость не меняется")
	assertTrue(heavy < light, "вес не замедлил")
	assertTrue(heavy > 0.4, "вес остановил игрока совсем")
end)

test("перегруз ограничен снизу", function()
	assertTrue(RaidSandbox.speedMultiplier(500) >= 0.45, "перегруз пробил нижнюю границу")
end)

test("вес увеличивает разброс", function()
	assertNear(RaidSandbox.spreadMultiplier(0), 1, 1e-6)
	assertTrue(RaidSandbox.spreadMultiplier(50) > 1.3, "разброс не вырос от веса")
end)

test("перелом и кровотечение режут скорость", function()
	assertNear(RaidSandbox.conditionMultiplier(nil), 1, 1e-6)
	local fractured = RaidSandbox.conditionMultiplier({ fractured = true })
	assertTrue(fractured <= 0.56, "перелом не замедлил")
	local combined = RaidSandbox.conditionMultiplier({ fractured = true, bleeding = true })
	assertTrue(combined < fractured, "кровотечение не добавило эффекта")
end)

test("низкая выносливость тоже мешает", function()
	local fresh = RaidSandbox.conditionMultiplier({ stamina = 100 })
	local tired = RaidSandbox.conditionMultiplier({ stamina = 10 })
	assertTrue(tired < fresh, "усталость не повлияла")
end)

------------------------------------------------------------------------
-- Config (санити-проверки, чтобы стенд не развалился от правок)
------------------------------------------------------------------------

local Config = loadModule("Config")

test("Config: режим вида и прятанье курсора заданы", function()
	assertTrue(
		Config.ViewModel.Mode == "Character" or Config.ViewModel.Mode == "Procedural",
		"неизвестный режим вида"
	)
	assertTrue(Config.Camera.HideCursor == true, "курсор не спрятан")
	assertTrue(Config.Camera.Smoothing >= 0, "сглаживание отрицательное")
	-- Анимации камеры не должны быть "сильными".
	assertTrue(
		Config.Camera.HeadBob.Amplitude <= 0.1,
		"покачивание головы слишком большое"
	)
	assertTrue(Config.Camera.LeanAngle <= 2, "наклон в стрейфе слишком сильный")
	assertTrue(Config.Camera.ShakeScale <= 0.5, "тряска от выстрела слишком сильная")
end)

test("Config: тело видно от первого лица", function()
	assertTrue(
		Config.ViewModel.ShowBody == true,
		"тело спрятано — руки/ноги/живот не будут видны"
	)
	assertTrue(
		Config.ViewModel.HideHead == true,
		"голова должна быть спрятана, иначе закрывает обзор"
	)
	assertTrue(Config.Camera.EyeForward > 0, "камера внутри головы — торс не виден")
end)

test("Config: у оружия задан хват для кисти", function()
	assertTrue(Config.Weapons.HandGripCFrame ~= nil, "нет HandGripCFrame — оружие встанет криво")
	assertTrue(#Config.Weapons.HandNames >= 1, "не заданы имена кистей")
end)

test("Config: скорости и слоты в разумных пределах", function()
	assertTrue(Config.Movement.WalkSpeed > 0 and Config.Movement.WalkSpeed < 30)
	assertTrue(Config.Movement.SprintSpeed > Config.Movement.WalkSpeed)
	assertTrue(Config.Inventory.Slots >= 1 and Config.Inventory.Slots <= 9)
	assertTrue(Config.Camera.BaseFov >= 50 and Config.Camera.BaseFov <= 120)
	assertTrue(#Config.Weapons.FolderPath > 0)
end)

------------------------------------------------------------------------
-- Итог
------------------------------------------------------------------------

for _, entry in tests do
	local ok, err = pcall(entry.callback)
	if ok then
		passes += 1
		print(string.format("  ok   %s", entry.name))
	else
		failures += 1
		print(string.format("  FAIL %s\n       %s", entry.name, tostring(err)))
	end
end

print(string.format("\n%d прошло, %d упало, всего %d", passes, failures, passes + failures))
if failures > 0 then
	error("Есть упавшие тесты")
end

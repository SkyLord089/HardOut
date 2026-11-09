--!nonstrict
--[[
	CombatService.luau
	Серверная сторона стрельбы: единственное место, где считается урон.

	Клиент присылает только намерение (куда смотрел, из чего стрелял).
	Сервер сам:
	  - находит модель оружия и берёт её статы,
	  - проверяет темп и "нельзя стрелять чаще, чем оружие позволяет",
	  - проверяет, что origin рядом с головой игрока (античит на телепорт пули),
	  - считает raycast и урон (AimSolver: голова/конечности/броня),
	  - рассылает результат всем (трассеры видны всем игрокам).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local WeaponFolder = HardOut:WaitForChild("Weapon")
local Net = require(HardOut:WaitForChild("Net"):WaitForChild("Remotes"))
local AimSolver = require(WeaponFolder:WaitForChild("AimSolver"))
local WeaponConfig = require(WeaponFolder:WaitForChild("WeaponConfig"))

local CombatService = {}

local ORIGIN_TOLERANCE = 14 -- studs от головы
local FIRE_RATE_GRACE = 0.9 -- 10% запас на джиттер сети
local MAX_SHOTS_PER_SECOND = 25

type PlayerState = {
	lastShotAt: number,
	shotCount: number,
	minuteStartedAt: number,
}

local states: { [Player]: PlayerState } = {}

local function getState(player)
	local state = states[player]
	if not state then
		state = { lastShotAt = -math.huge, shotCount = 0, minuteStartedAt = os.clock() }
		states[player] = state
	end
	return state
end

--[[ Находит модель оружия по имени в ReplicatedStorage.WeaponModels. ]]
local function findWeaponModel(name)
	if type(name) ~= "string" then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	if not folder then
		return nil
	end
	local model = folder:FindFirstChild(name, true)
	if model and (model:IsA("Model") or model:IsA("Tool")) then
		return model
	end
	return nil
end

function CombatService.handleFire(player, payload)
	if type(payload) ~= "table" then
		return
	end
	if typeof(payload.origin) ~= "Vector3" or typeof(payload.direction) ~= "Vector3" then
		return
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (head and humanoid and humanoid.Health > 0) then
		return
	end

	-- Статы оружия: ищем модель, если её нет — берём дефолт (стенд не падает).
	local model = findWeaponModel(payload.weaponName)
	local stats = model and WeaponConfig.fromModel(model) or WeaponConfig.fromName(tostring(payload.weaponName or ""))

	-- 1. Темп стрельбы.
	local state = getState(player)
	local now = os.clock()
	local interval = (60 / math.max(stats.RoundsPerMinute, 1)) * FIRE_RATE_GRACE
	if now - state.lastShotAt < interval then
		return
	end
	state.lastShotAt = now

	-- 2. Грубый лимит выстрелов в минуту (защита от "спидрана").
	if now - state.minuteStartedAt > 1 then
		state.minuteStartedAt = now
		state.shotCount = 0
	end
	state.shotCount += 1
	if state.shotCount > MAX_SHOTS_PER_SECOND then
		return
	end

	-- 3. Origin должен быть у головы (нельзя стрелять из-за стены с другого конца карты).
	if (payload.origin - head.Position).Magnitude > ORIGIN_TOLERANCE then
		return
	end

	-- 4. Направление нормируем сами (клиент не может "продлить" пулю).
	local direction = payload.direction
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit

	-- 5. Разброс считаем на сервере: клиентский шум не даёт преимущества.
	local speedRatio = math.clamp((tonumber(payload.speed) or 0) / 8, 0, 2)
	local spread = AimSolver.computeSpread(stats, payload.aiming == true, speedRatio)

	local rng = Random.new()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.Camera }
	params.IgnoreWater = true

	local origin = head.Position
		+ (payload.origin - head.Position).Unit * math.min((payload.origin - head.Position).Magnitude, 2)

	local result = AimSolver.solve({
		origin = origin,
		direction = direction,
		stats = stats,
		spreadDegrees = spread,
		rng = function()
			return rng:NextNumber()
		end,
		resolver = function(rayOrigin, rayDirection, range)
			return workspace:Raycast(rayOrigin, rayDirection * range, params)
		end,
	})

	-- 6. Урон только через Humanoid.
	if result.Hit and result.Instance then
		local victimModel = result.Instance:FindFirstAncestorOfClass("Model")
		local victimHumanoid = victimModel and victimModel:FindFirstChildOfClass("Humanoid")
		if victimHumanoid and victimHumanoid.Health > 0 then
			victimHumanoid:TakeDamage(result.Damage)
		end
	end

	-- 7. Всем — трассер и точка попадания.
	CombatService.shotResult:FireAllClients({
		origin = origin,
		position = result.Position,
		normal = result.Normal,
		hit = result.Hit,
		partName = result.PartName,
		damage = result.Damage,
		shooter = player,
	})
end

function CombatService.initialize()
	CombatService.shotResult = Net.get(Net.Names.ShotResult)

	Net.get(Net.Names.Fire).OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(CombatService.handleFire, player, payload)
		if not ok then
			warn("[HardOut] Ошибка обработки выстрела: " .. tostring(err))
		end
	end)

	Net.get(Net.Names.Reload).OnServerEvent:Connect(function(player)
		-- Тут позже можно проверять реальный запас патронов в инвентаре.
		local state = getState(player)
		state.lastShotAt = math.max(state.lastShotAt, os.clock() - 1)
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService

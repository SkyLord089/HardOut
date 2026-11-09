--!nonstrict
--[[
	RaidSandbox.luau
	Заготовка "рейдового" слоя в духе Таркова — пока без бэкенда, но с реальными
	формулами. Всё пишется в атрибуты игрока, поэтому клиент может читать их
	без отдельной сети:

		HardOutWeight       — вес снаряжения, кг
		HardOutSpeedMult    — множитель скорости от веса и состояния
		HardOutSpreadMult   — множитель разброса от веса
		HardOutStamina      — выносливость 0..100

	Команды в чате (для проверки ощущений):
		/weight 25     вес снаряжения
		/fracture      переключить перелом
		/bleed         переключить кровотечение
		/stamina 40    выносливость
		/reset         сброс

	Когда дойдёшь до настоящих рейдов — это место, куда вешать инвентарь,
	сохранения и лут. Формулы уже вынесены в чистые функции и покрыты тестами.
]]

local Players = game:GetService("Players")

local RaidSandbox = {}

-- 0 кг -> 1.0, 40 кг -> ~0.62 (тяжёлый рюкзак реально замедляет).
local WEIGHT_SPEED_FALLOFF = 0.0095
-- Вес добавляет разброс: 50 кг -> +35%.
local WEIGHT_SPREAD_FACTOR = 0.35

type Condition = {
	bleeding: boolean?,
	fractured: boolean?,
	stamina: number?,
}

local conditions: { [Player]: Condition } = {}

--[[ Множитель скорости от веса (кг). ]]
function RaidSandbox.speedMultiplier(weightKg: number): number
	local weight = math.max(tonumber(weightKg) or 0, 0)
	return math.clamp(1 - weight * WEIGHT_SPEED_FALLOFF, 0.45, 1)
end

--[[ Множитель разброса от веса. ]]
function RaidSandbox.spreadMultiplier(weightKg: number): number
	local weight = math.clamp(tonumber(weightKg) or 0, 0, 50)
	return 1 + (weight / 50) * WEIGHT_SPREAD_FACTOR
end

--[[ Множитель скорости от состояний (перелом/кровотечение/усталость). ]]
function RaidSandbox.conditionMultiplier(condition: Condition?): number
	if not condition then
		return 1
	end
	local multiplier = 1
	if condition.fractured then
		multiplier *= 0.55
	end
	if condition.bleeding then
		multiplier *= 0.85
	end
	local stamina = condition.stamina
	if type(stamina) == "number" and stamina < 30 then
		multiplier *= 0.8
	end
	return multiplier
end

local function publish(player: Player, condition: Condition?)
	local weight = player:GetAttribute("HardOutWeight") or 0
	player:SetAttribute(
		"HardOutSpeedMult",
		RaidSandbox.speedMultiplier(weight) * RaidSandbox.conditionMultiplier(condition)
	)
	player:SetAttribute("HardOutSpreadMult", RaidSandbox.spreadMultiplier(weight))
	player:SetAttribute("HardOutStamina", (condition and condition.stamina) or 100)
end

--[[ Задать вес снаряжения. ]]
function RaidSandbox.setLoadout(player: Player, weightKg: number)
	player:SetAttribute("HardOutWeight", math.clamp(tonumber(weightKg) or 0, 0, 80))
	publish(player, conditions[player])
end

--[[ Задать состояния. ]]
function RaidSandbox.applyCondition(player: Player, condition: Condition)
	conditions[player] = condition
	publish(player, condition)
end

function RaidSandbox.getCondition(player: Player): Condition?
	return conditions[player]
end

--[[ Сброс. ]]
function RaidSandbox.reset(player: Player)
	conditions[player] = nil
	player:SetAttribute("HardOutWeight", 0)
	publish(player, nil)
end

local function toggle(player: Player, key: string): boolean
	local condition = conditions[player] or {}
	condition[key] = not condition[key]
	RaidSandbox.applyCondition(player, condition)
	return condition[key] == true
end

local function handleCommand(player: Player, message: string)
	local command, argument = string.match(message, "^/(%a+)%s*(.*)$")
	if not command then
		return
	end
	command = string.lower(command)

	if command == "weight" then
		local weight = tonumber(argument) or 0
		RaidSandbox.setLoadout(player, weight)
	elseif command == "fracture" or command == "fractured" then
		toggle(player, "fractured")
	elseif command == "bleed" or command == "bleeding" then
		toggle(player, "bleeding")
	elseif command == "stamina" then
		local condition = conditions[player] or {}
		condition.stamina = math.clamp(tonumber(argument) or 100, 0, 100)
		RaidSandbox.applyCondition(player, condition)
	elseif command == "reset" then
		RaidSandbox.reset(player)
	end
end

function RaidSandbox.initialize()
	local function bindPlayer(player: Player)
		RaidSandbox.reset(player)
		player.Chatted:Connect(function(message)
			handleCommand(player, message)
		end)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(bindPlayer, player)
	end
	Players.PlayerAdded:Connect(bindPlayer)

	Players.PlayerRemoving:Connect(function(player)
		conditions[player] = nil
	end)
end

return RaidSandbox

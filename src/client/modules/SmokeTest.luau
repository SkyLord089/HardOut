--!nonstrict
--[[
	SmokeTest.luau
	Самопроверка «а скрипт-то правда работает?».

	Проблема: если клиентский код не запустился или упал на этапе require,
	снаружи это выглядит просто как «ничего не происходит» — ни ошибок на
	экране, ни изменений.

	Что делает модуль:
	  * каждую секунду печатает в Output пульс: FPS, жив ли кадровый цикл,
	    тип камеры и накопленное время;
	  * если кадры перестали идти (цикл умер) — выводит явное предупреждение;
	  * один раз печатает сводку окружения (Roblox клиент / Studio).

	Ищи в Output строки `[HardOut:пульс]`. Нет строк — код не выполняется.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SmokeTest = {}

local player = Players.LocalPlayer

function SmokeTest.start()
	local frames = 0
	local elapsed = 0
	local started = os.clock()
	local alive = true

	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		alive = true
	end)

	task.spawn(function()
		while true do
			task.wait(1)

			local fps = elapsed > 0 and (frames / elapsed) or 0
			local camera = workspace.CurrentCamera
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			print(
				string.format(
					"[HardOut:пульс] FPS %.0f | кадров %d | камера %s | персонаж %s",
					fps,
					frames,
					camera and camera.CameraType.Name or "нет",
					character and (humanoid and humanoid.RigType.Name or "есть") or "нет"
				)
			)

			if not alive then
				warn("[HardOut] Кадровый цикл не идёт — canvas/цикл завис.")
			end
			alive = false
			frames = 0
			elapsed = 0

			if os.clock() - started > 8 then
				-- дальше пульс реже, чтобы не спамить
				task.wait(4)
			end
		end
	end)
end

return SmokeTest

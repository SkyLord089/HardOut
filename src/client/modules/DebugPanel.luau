--!nonstrict
--[[
	DebugPanel.luau
	Панель диагностики прямо в игре: показывает, работает ли скрипт и что
	сейчас с телом/камерой.

	Открыть/закрыть: F2.
	Команды в чате (работают без открытия панели):
		/ho                 — краткий статус в чат
		/eye 0.8            — выдвинуть камеру из головы (Config.Camera.EyeForward)
		/eyeoff 0.4         — поднять/опустить глаза (Config.Camera.EyeOffset.Y)
		/body on|off        — видеть своё тело или спрятать
		/head on|off        — прятать голову/шляпы
		/fov 80             — угол обзора
		/bob 0.02           — сила покачивания головы
		/shake 0.2          — тряска от выстрела
		/lean 1.2           — наклон в стрейфе

	Все изменения живут до перезапуска игры. Чтобы сохранить навсегда —
	поправь те же числа в src/shared/HardOut/Config.luau.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HardOut = ReplicatedStorage:WaitForChild("HardOut")
local Config = require(HardOut:WaitForChild("Config"))

local DebugPanel = {}

local player = Players.LocalPlayer
local gui, textLabel

local function describeCharacter()
	local character = player.Character
	if not character then
		return "персонаж: НЕТ (ещё не заспавнился)"
	end
	local lines = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	lines[1] = string.format(
		"персонаж: %s | Humanoid: %s | Rig: %s",
		character.Name,
		humanoid and "да" or "нет",
		humanoid and humanoid.RigType.Name or "?"
	)

	local parts = {
		"Head",
		"Torso",
		"UpperTorso",
		"LowerTorso",
		"Right Arm",
		"RightUpperArm",
		"RightHand",
		"Left Arm",
		"LeftUpperArm",
		"Right Leg",
		"RightUpperLeg",
		"RightFoot",
	}
	local shown = {}
	for _, name in parts do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			-- Итоговая прозрачность = свойство + локальный модификатор.
			local total = part.Transparency + part.LocalTransparencyModifier * (1 - part.Transparency)
			table.insert(shown, string.format("%s=%.2f", name, total))
		end
	end
	lines[2] = "прозрачность: "
		.. (#shown > 0 and table.concat(shown, " ") or "частей не найдено")
	return table.concat(lines, "\n")
end

local function describeCamera()
	local camera = workspace.CurrentCamera
	return string.format(
		"камера: %s | FOV %.0f | EyeForward %.2f | EyeOffset.Y %.2f\nтело: %s | голова: %s | боб %.3f | тряска %.2f",
		camera.CameraType.Name,
		camera.FieldOfView,
		Config.Camera.EyeForward or 0,
		Config.Camera.EyeOffset.Y,
		Config.ViewModel.ShowBody and "ВИДНО" or "скрыто",
		Config.ViewModel.HideHead and "спрятана" or "видна",
		Config.Camera.HeadBob.Amplitude,
		Config.Camera.ShakeScale or 0
	)
end

local lastCameraCFrame = nil
local cameraMoved = false

local function refresh()
	if not textLabel then
		return
	end
	local camera = workspace.CurrentCamera
	if lastCameraCFrame and (camera.CFrame.Position - lastCameraCFrame.Position).Magnitude > 0.001 then
		cameraMoved = true
	end
	lastCameraCFrame = camera.CFrame

	textLabel.Text = string.format(
		"[HardOut] диагностика (F2 — закрыть)\n\n%s\n\n%s\nкамера двигалась: %s\n\n/eye 0.8   /eyeoff 0.4   /body on|off   /head on|off\n/fov 80   /bob 0.035|off   /sway 0.01   /roll 0.5   /ho",
		describeCharacter(),
		describeCamera(),
		cameraMoved and "ДА" or "нет (стоишь на месте?)"
	)
end

local function notify(message: string)
	print("[HardOut] " .. message)
	if textLabel then
		refresh()
	end
end

-- ------------------------------------------------------------------ команды

local commands = {}

commands.ho = function()
	notify(describeCharacter())
	notify(describeCamera())
end

commands.eye = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/eye 0.6   (насколько камера выдвинута из головы)")
	end
	Config.Camera.EyeForward = math.clamp(value, 0, 3)
	notify(string.format("EyeForward = %.2f", Config.Camera.EyeForward))
end

commands.eyeoff = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/eyeoff 0.35   (высота глаз)")
	end
	Config.Camera.EyeOffset = Vector3.new(0, value, 0)
	notify(string.format("EyeOffset.Y = %.2f", value))
end

commands.body = function(argument)
	local enabled = argument ~= "off"
	Config.ViewModel.ShowBody = enabled
	notify("тело: " .. (enabled and "ВИДНО" or "скрыто"))
	if enabled then
		-- Мгновенно применяем ко всем частям.
		local character = player.Character
		if character then
			for _, part in character:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Head" then
					part.LocalTransparencyModifier = 0
				end
			end
		end
	end
end

commands.head = function(argument)
	local enabled = argument ~= "off" -- "/head on" = прятать
	Config.ViewModel.HideHead = enabled
	notify("голова: " .. (enabled and "спрятана" or "видна"))
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.LocalTransparencyModifier = enabled and 1 or 0
	end
end

commands.fov = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/fov 75")
	end
	Config.Camera.BaseFov = math.clamp(value, 40, 120)
	notify(string.format("FOV = %.0f", Config.Camera.BaseFov))
end

commands.bob = function(argument)
	if argument == "off" then
		Config.Camera.HeadBob.Enabled = false
		return notify("покачивание выключено")
	end
	if argument == "on" then
		Config.Camera.HeadBob.Enabled = true
		return notify("покачивание включено")
	end
	local value = tonumber(argument)
	if not value then
		return notify("/bob 0.035 | /bob off")
	end
	Config.Camera.HeadBob.Enabled = true
	Config.Camera.HeadBob.Amplitude = math.clamp(value, 0, 0.5)
	notify(string.format("покачивание: Amplitude = %.3f", Config.Camera.HeadBob.Amplitude))
end

commands.sway = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/sway 0.01   (боковое смещение, 0 = выключено)")
	end
	Config.Camera.HeadBob.Sway = math.clamp(value, 0, 0.2)
	notify(string.format("боковое покачивание = %.3f", Config.Camera.HeadBob.Sway))
end

commands.roll = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/roll 0.5   (крен в градусах, 0 = выключено)")
	end
	Config.Camera.HeadBob.RollDegrees = math.clamp(value, 0, 5)
	notify(string.format("крен = %.2f град", Config.Camera.HeadBob.RollDegrees))
end

commands.shake = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/shake 0.35")
	end
	Config.Camera.ShakeScale = math.clamp(value, 0, 3)
	notify(string.format("тряска = %.2f", Config.Camera.ShakeScale))
end

commands.lean = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/lean 1.2")
	end
	Config.Camera.LeanAngle = math.clamp(value, 0, 10)
	notify(string.format("наклон = %.2f", Config.Camera.LeanAngle))
end

commands.smooth = function(argument)
	local value = tonumber(argument)
	if not value then
		return notify("/smooth 0.3   (0 = 1:1 с мышью)")
	end
	Config.Camera.Smoothing = math.clamp(value, 0, 1)
	notify(string.format("сглаживание = %.2f", Config.Camera.Smoothing))
end

local function handleMessage(message: string)
	local command, argument = string.match(message, "^/(%a+)%s*(.-)%s*$")
	if not command then
		return
	end
	local handler = commands[string.lower(command)]
	if handler then
		handler(argument)
	end
end

-- ------------------------------------------------------------------ панель

local function buildPanel()
	local playerGui = player:WaitForChild("PlayerGui")

	gui = Instance.new("ScreenGui")
	gui.Name = "HardOutDebug"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(760, 260)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.Code
	textLabel.TextSize = 14
	textLabel.TextColor3 = Color3.fromRGB(225, 225, 215)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.Text = ""
	textLabel.Parent = frame
end

--[[ Короткий баннер при старте: визуальное доказательство, что скрипт работает. ]]
function DebugPanel.showStartupBanner()
	local playerGui = player:WaitForChild("PlayerGui")
	local banner = Instance.new("ScreenGui")
	banner.Name = "HardOutBanner"
	banner.ResetOnSpawn = false
	banner.IgnoreGuiInset = true
	banner.DisplayOrder = 200
	banner.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 18)
	label.Size = UDim2.fromOffset(460, 34)
	label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(210, 200, 150)
	label.Text = "HardOut загружен — F2: диагностика, /ho: статус"
	label.Parent = banner

	task.delay(6, function()
		label.TextTransparency = 1
		label.BackgroundTransparency = 1
		task.delay(0.6, function()
			banner:Destroy()
		end)
	end)
end

function DebugPanel.initialize()
	buildPanel()
	DebugPanel.showStartupBanner()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 then
			gui.Enabled = not gui.Enabled
			if gui.Enabled then
				refresh()
			end
		end
	end)

	player.Chatted:Connect(handleMessage)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if gui.Enabled then
				refresh()
			end
		end
	end)

	print("[HardOut] Диагностика готова: F2 — панель, /ho — статус в чат.")
	return DebugPanel
end

return DebugPanel

--!nonstrict
--[[
	TestRange.luau
	Тестовый полигон, который строится кодом при старте сервера.

	Состав:
	  * бетонный пол 120x120 + стены + потолочный навес (закрытая коробка),
	  * точка спавна игрока,
	  * 3 манекена с Humanoid на 10 / 25 / 50 метров (проверка зон урона),
	  * ящики-укрытия и разметка дистанций,
	  * лампы, чтобы внутри не было темно.

	Выключить и использовать свой уровень: Config.TestRange.Enabled = false
	(или удалить Workspace.TestRange и поставить false).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("HardOut"):WaitForChild("Config"))

local TestRange = {}

local FLOOR_COLOR = Color3.fromRGB(56, 55, 51)
local WALL_COLOR = Color3.fromRGB(43, 42, 39)
local SPAN = 120
local WALL_HEIGHT = 22

local function newPart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Concrete
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[ Манекен: части + Humanoid, чтобы серверный код наносил честный урон. ]]
local function buildMannequin(parent, position, label)
	local model = Instance.new("Model")
	model.Name = "Mannequin_" .. label

	local torsoColor = Color3.fromRGB(68, 82, 70)
	local limbColor = Color3.fromRGB(50, 58, 52)
	local skinColor = Color3.fromRGB(212, 196, 168)

	local root = newPart(
		"HumanoidRootPart",
		Vector3.new(1, 1, 1),
		CFrame.new(position + Vector3.new(0, 3.6, 0)),
		torsoColor,
		Enum.Material.Fabric,
		model
	)
	root.Transparency = 1

	local torso = newPart(
		"Torso",
		Vector3.new(1.8, 2.4, 1),
		CFrame.new(position + Vector3.new(0, 3.6, 0)),
		torsoColor,
		Enum.Material.Fabric,
		model
	)
	local head = newPart(
		"Head",
		Vector3.new(1.1, 1.1, 1.1),
		CFrame.new(position + Vector3.new(0, 5.4, 0)),
		skinColor,
		Enum.Material.SmoothPlastic,
		model
	)
	local leftArm = newPart(
		"LeftArm",
		Vector3.new(0.6, 2.2, 0.6),
		CFrame.new(position + Vector3.new(1.2, 3.6, 0)),
		limbColor,
		Enum.Material.Fabric,
		model
	)
	local rightArm = newPart(
		"RightArm",
		Vector3.new(0.6, 2.2, 0.6),
		CFrame.new(position + Vector3.new(-1.2, 3.6, 0)),
		limbColor,
		Enum.Material.Fabric,
		model
	)
	local leftLeg = newPart(
		"LeftLeg",
		Vector3.new(0.7, 2.3, 0.7),
		CFrame.new(position + Vector3.new(0.45, 1.15, 0)),
		limbColor,
		Enum.Material.Fabric,
		model
	)
	local rightLeg = newPart(
		"RightLeg",
		Vector3.new(0.7, 2.3, 0.7),
		CFrame.new(position + Vector3.new(-0.45, 1.15, 0)),
		limbColor,
		Enum.Material.Fabric,
		model
	)

	for _, part in { torso, head, leftArm, rightArm, leftLeg, rightLeg } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 44)
	billboard.StudsOffset = Vector3.new(0, 2.3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 400
	billboard.Parent = head

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Code
	text.TextSize = 16
	text.TextColor3 = Color3.fromRGB(232, 228, 216)
	text.Text = label
	text.Parent = billboard

	local health = Instance.new("TextLabel")
	health.Name = "Health"
	health.Size = UDim2.new(1, 0, 1, 0)
	health.Position = UDim2.fromOffset(0, 20)
	health.BackgroundTransparency = 1
	health.Font = Enum.Font.Code
	health.TextSize = 13
	health.TextColor3 = Color3.fromRGB(200, 170, 110)
	health.Text = "100"
	health.Parent = billboard

	model.PrimaryPart = root
	model.Parent = parent

	-- Обновление цифры здоровья + бесконечный респавн для тестов.
	local function updateHealth()
		health.Text = tostring(math.max(0, math.floor(humanoid.Health)))
	end
	humanoid.HealthChanged:Connect(updateHealth)

	humanoid.Died:Connect(function()
		task.delay(2.5, function()
			if model.Parent then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
	end)

	return model
end

function TestRange.build()
	if not Config.TestRange.Enabled then
		return nil
	end

	local existing = workspace:FindFirstChild("TestRange")
	if existing then
		return existing
	end

	local map = Instance.new("Model")
	map.Name = "TestRange"
	map:SetAttribute("HardOutMap", true)

	local half = SPAN / 2

	newPart("Floor", Vector3.new(SPAN, 2, SPAN), CFrame.new(0, -1, 0), FLOOR_COLOR, Enum.Material.Concrete, map)
	newPart("WallNorth", Vector3.new(SPAN, WALL_HEIGHT, 2), CFrame.new(0, WALL_HEIGHT / 2, -half), WALL_COLOR, nil, map)
	newPart("WallSouth", Vector3.new(SPAN, WALL_HEIGHT, 2), CFrame.new(0, WALL_HEIGHT / 2, half), WALL_COLOR, nil, map)
	newPart("WallEast", Vector3.new(2, WALL_HEIGHT, SPAN), CFrame.new(half, WALL_HEIGHT / 2, 0), WALL_COLOR, nil, map)
	newPart("WallWest", Vector3.new(2, WALL_HEIGHT, SPAN), CFrame.new(-half, WALL_HEIGHT / 2, 0), WALL_COLOR, nil, map)
	newPart("Roof", Vector3.new(SPAN, 1, SPAN), CFrame.new(0, WALL_HEIGHT, 0), Color3.fromRGB(34, 34, 32), nil, map)

	-- Мишени на разных дистанциях.
	buildMannequin(map, Vector3.new(-7, 0, 26), "10 м")
	buildMannequin(map, Vector3.new(6, 0, 10), "25 м")
	buildMannequin(map, Vector3.new(0, 0, -14), "50 м")
	buildMannequin(map, Vector3.new(-24, 0, -20), "60 м")

	-- Укрытия.
	local crates = {
		{ Vector3.new(-16, 1.5, 34), Vector3.new(4, 3, 4) },
		{ Vector3.new(13, 2, 32), Vector3.new(5, 4, 5) },
		{ Vector3.new(-22, 1, 14), Vector3.new(3, 2, 3) },
		{ Vector3.new(19, 1.5, 12), Vector3.new(4, 3, 4) },
		{ Vector3.new(-6, 1, -4), Vector3.new(6, 2, 2) },
		{ Vector3.new(22, 2.5, -26), Vector3.new(5, 5, 5) },
	}
	for index, crate in crates do
		newPart(
			"Crate" .. index,
			crate[2],
			CFrame.new(crate[1]),
			Color3.fromRGB(74, 60, 42),
			Enum.Material.WoodPlanks,
			map
		)
	end

	-- Разметка дистанций от точки спавна (z = 38).
	local spawnZ = 38
	for _, distance in { 10, 25, 50 } do
		local marker = newPart(
			"Marker" .. distance,
			Vector3.new(20, 0.1, 0.35),
			CFrame.new(0, 0.06, spawnZ - distance),
			Color3.fromRGB(186, 152, 88),
			Enum.Material.Neon,
			map
		)
		marker.CanCollide = false

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(70, 24)
		billboard.StudsOffset = Vector3.new(0, 1, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = marker

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Code
		text.TextSize = 13
		text.TextColor3 = Color3.fromRGB(214, 184, 124)
		text.Text = distance .. " м"
		text.Parent = billboard
	end

	-- Свет.
	for index, position in { Vector3.new(-30, 18, -30), Vector3.new(30, 18, -30), Vector3.new(0, 18, 30) } do
		local lamp = Instance.new("Part")
		lamp.Name = "Lamp" .. index
		lamp.Size = Vector3.new(4, 0.4, 4)
		lamp.CFrame = CFrame.new(position)
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.Material = Enum.Material.Neon
		lamp.Color = Color3.fromRGB(255, 244, 214)
		lamp.Parent = map

		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 48
		light.Color = Color3.fromRGB(255, 240, 210)
		light.Parent = lamp
	end

	-- Спавн: невидимый, но стоит на полу, чтобы персонаж не падал с высоты.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Size = Vector3.new(12, 0.6, 12)
	spawnLocation.CFrame = CFrame.new(0, 0.3, spawnZ)
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.Transparency = 1
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = map

	map.Parent = workspace
	return map
end

return TestRange

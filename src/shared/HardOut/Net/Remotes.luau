--!strict
--[[
	Remotes.luau
	Имена и ленивое создание RemoteEvent'ов. Сервер создаёт их в ReplicatedStorage.HardOut.Net,
	клиент только ждёт. Один список — чтобы не расползлись опечатки.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.Names = {
	Fire = "Fire", -- client -> server: запрос выстрела
	ShotResult = "ShotResult", -- server -> client: подтверждённый выстрел (трассер/попадание)
	Reload = "Reload", -- client -> server: перезарядка
	Inventory = "Inventory", -- server -> client: список выданного оружия и патронов
	StateUpdate = "StateUpdate", -- server -> client: патроны/перезарядка
}

function Remotes.getFolder(): Instance
	local hardOut = ReplicatedStorage:FindFirstChild("HardOut")
	local folder = hardOut and hardOut:FindFirstChild("Net")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Net"
		created.Parent = hardOut
		return created
	end
	return folder
end

function Remotes.get(name: string): RemoteEvent
	local folder = Remotes.getFolder()
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if not remote then
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		return created
	end
	error(`Remotes: "{name}" существует, но это не RemoteEvent`)
end

function Remotes.waitFor(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("HardOut"):WaitForChild("Net")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes

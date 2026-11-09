--!strict
--[[
	Signal.luau
	Минимальный сигнал (без RBXScriptSignal), чтобы модули не зависели от Instances.
	Нужен для событий вида "персонаж загрузился" / "риг пересоздан".
]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if self._disconnected then
		return
	end
	self._disconnected = true
	self._signal._connections[self] = nil
end

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(callback)
	local connection = setmetatable({
		_signal = self,
		_callback = callback,
		_disconnected = false,
	}, Connection)
	self._connections[connection] = true
	return connection
end

function Signal:Fire(...)
	-- Копия, чтобы отписки внутри колбэка не ломали обход.
	local snapshot = {}
	for connection in pairs(self._connections) do
		table.insert(snapshot, connection)
	end
	for _, connection in snapshot do
		if not connection._disconnected then
			task.spawn(connection._callback, ...)
		end
	end
end

function Signal:DisconnectAll()
	for connection in pairs(self._connections) do
		connection._disconnected = true
	end
	table.clear(self._connections)
end

return Signal

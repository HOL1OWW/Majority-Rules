--!nonstrict
--[[
	Signal.lua — a tiny event object so services can expose change notifications without
	reaching for BindableEvents.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: any) -> (),
}

export type Signal = typeof(setmetatable(
	{} :: { _handlers: { any } },
	Signal
))

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local connection = {
		_fn = fn,
		Connected = true,
	}
	function connection:Disconnect()
		self.Connected = false
	end
	table.insert(self._handlers, connection)
	return connection
end

function Signal:DisconnectAll()
	for _, connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

function Signal:Fire(...: any)
	local snapshot = table.clone(self._handlers)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

--! Fires inline instead of in a new thread. Use when ordering matters.
function Signal:FireSync(...: any)
	local snapshot = table.clone(self._handlers)
	for _, connection in snapshot do
		if connection.Connected then
			connection._fn(...)
		end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal

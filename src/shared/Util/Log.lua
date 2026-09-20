--!nonstrict
--[[
	Log.lua — the only place the game prints.

	Never leave a bare print() in shipped code: search the tree for "print(" and you should
	only ever find this file. Log.debug is silenced outside Studio.
]]

local RunService = game:GetService("RunService")

local Log = {}

local PREFIX = "[MR] "

local function emit(level: string, fmt: string, ...: any)
	local count = select("#", ...)
	local message
	if count == 0 then
		message = fmt
	else
		local ok, formatted = pcall(string.format, fmt, ...)
		message = ok and formatted or (fmt .. " " .. table.concat({ ... }, " "))
	end

	local line = PREFIX .. level .. " " .. tostring(message)
	if level == "ERROR" then
		error(line, 0)
	elseif level == "WARN" then
		warn(line)
	else
		print(line)
	end
end

function Log.info(fmt: string, ...: any)
	emit("", fmt, ...)
end

function Log.warn(fmt: string, ...: any)
	emit("WARN", fmt, ...)
end

function Log.error(fmt: string, ...: any)
	emit("ERROR", fmt, ...)
end

function Log.debug(fmt: string, ...: any)
	if RunService:IsStudio() then
		emit("DEBUG", fmt, ...)
	end
end

--! Loud, transactional failure used by service init.
function Log.assert(condition: any, fmt: string, ...: any)
	if not condition then
		Log.error(fmt, ...)
	end
end

return Log

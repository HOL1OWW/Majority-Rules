--!nocheck
-- Studio half of the sync audit. Prints "<InstancePath>\t<djb2>" for every script in the place.
--
-- Run it in Roblox Studio with the Studio MCP `execute_luau` tool (datamodel_type = "Edit"),
-- then save the returned text to .sync-audit/place.txt and run:
--
--     py tests/sync_audit.py --place-dump .sync-audit/place.txt
--
-- The hash must stay identical to `djb2` in tests/sync_audit.py: base 5381, multiplier 33,
-- modulo 2^32, over the script's Source bytes.

local SERVICES = {
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterPlayer",
	"StarterGui",
	"StarterPack",
	"ReplicatedFirst",
	"Workspace",
}

local function djb2(text)
	local hash = 5381
	for index = 1, #text do
		hash = (hash * 33 + string.byte(text, index)) % 4294967296
	end
	return hash
end

local lines = {}

local function scan(instance, prefix)
	for _, child in ipairs(instance:GetChildren()) do
		local path = prefix .. "." .. child.Name
		if child:IsA("LuaSourceContainer") then
			table.insert(lines, path .. "\t" .. string.format("%.0f", djb2(child.Source)))
		end
		scan(child, path)
	end
end

for _, serviceName in ipairs(SERVICES) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service ~= nil then
		scan(service, serviceName)
	end
end

table.sort(lines)
return table.concat(lines, "\n")

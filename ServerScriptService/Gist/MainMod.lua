--[[
Copyright (C) 2026 Iuha Dust

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
]]--

-- The array has two subelements for each item;
local gistIstr: {{string}} = {
    {"Magic", "0x49756861"},
    {"Sample", "Data"}
}

function getIstr(row)
local Valued = table.unpack(gistIstr[row])
return Valued
end

return getIstr

--[[
To call from another script, for example the first row:

local OutstandingBeautifulVariable = getIstr(1)
print(OutstandingBeautifulVariable)
--]]

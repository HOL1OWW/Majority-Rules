--[[
Copyright (C) 2026 Iuha Dust

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
]]--

local ExtMod = game.Workspace.trdm
local VariableDistribution = 0

-- Remove children of ExtMod
if game:IsAncestorOf(workspace) then
    ExtMod:ClearAllChildren()
end

    -- Confirm VariableDistribution is set correctly
if VariableDistribution == 0 then
    print("No errors.")
else
    warn("VariableDistribution is incorrect.")
end


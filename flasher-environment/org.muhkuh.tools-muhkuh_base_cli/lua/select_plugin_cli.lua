-----------------------------------------------------------------------------
--   Copyright (C) 2010 by Christoph Thelen                                --
--   doc_bacardi@users.sourceforge.net                                     --
--                                                                         --
--   This program is free software; you can redistribute it and/or modify  --
--   it under the terms of the GNU General Public License as published by  --
--   the Free Software Foundation; either version 2 of the License, or     --
--   (at your option) any later version.                                   --
--                                                                         --
--   This program is distributed in the hope that it will be useful,       --
--   but WITHOUT ANY WARRANTY; without even the implied warranty of        --
--   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
--   GNU General Public License for more details.                          --
--                                                                         --
--   You should have received a copy of the GNU General Public License     --
--   along with this program; if not, write to the                         --
--   Free Software Foundation, Inc.,                                       --
--   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             --
-----------------------------------------------------------------------------

local M = {}


function M.SelectPlugin(strPattern)
	strPattern = strPattern or ".*"
	local iInterfaceIdx
	local aDetectedInterfaces
	local tPlugin
	local strInterface


	repeat do
		-- Detect all interfaces.
		aDetectedInterfaces = {}
		for _,v in ipairs(_G.__MUHKUH_PLUGINS) do
			local iDetected
			print(string.format("Detecting interfaces with plugin %s", v:GetID()))
			iDetected = v:DetectInterfaces(aDetectedInterfaces)
			print(string.format("Found %d interfaces with plugin %s", iDetected, v:GetID()))
		end
		print(string.format("Found a total of %d interfaces with %d plugins", #aDetectedInterfaces, #_G.__MUHKUH_PLUGINS))
		print("")

		-- Show all detected interfaces.
		print("Please select the interface:")
		for i,v in ipairs(aDetectedInterfaces) do
			print(string.format(
				"%d: %s (%s) Used: %s, Valid: %s",
				i,
				v:GetName(),
				v:GetTyp(),
				tostring(v:IsUsed()),
				tostring(v:IsValid())
			))
		end
		print("R: rescan")
		print("C: cancel")

		-- Get the user input.
		repeat do
			io.write(">")
			strInterface = io.read():lower()
			iInterfaceIdx = tonumber(strInterface)
		-- Ask again until...
		--  1) the user requested a rescan ("r")
		--  2) the user canceled the selection ("c")
		--  3) the input is a number and it is an index to an entry in aDetectedInterfaces
		end until(
			strInterface=="r" or
			strInterface=="c" or
			(iInterfaceIdx~=nil and iInterfaceIdx>0 and iInterfaceIdx<=#aDetectedInterfaces)
		)
	-- Scan again if the user requested it.
	end until strInterface~="r"

	if strInterface~="c" then
		-- Create the plugin.
		tPlugin = aDetectedInterfaces[iInterfaceIdx]:Create()
	else
		tPlugin = nil
	end

	return tPlugin
end


return M

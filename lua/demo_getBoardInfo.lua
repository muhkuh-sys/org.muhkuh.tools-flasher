-----------------------------------------------------------------------------
--   Copyright (C) 2011 by Christoph Thelen                                --
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

require("muhkuh_cli_init")
flasher = require("flasher")

tPlugin = tester.getCommonPlugin()
if not tPlugin then
	error("No plugin selected, nothing to do!")
end

-- Download the flasher binary.
aAttr = flasher.download(tPlugin, "netx/", tester.callback_progress)

-- Get the board info table.
aBoardInfo = flasher.getBoardInfo(tPlugin, aAttr)
print("Board info:")
for iBusCnt,tBusInfo in ipairs(aBoardInfo) do
	print(string.format("Bus %d:\t%s", tBusInfo.iIdx, tBusInfo.strName))
	if not tBusInfo.aUnitInfo then
		print("\tNo units.")
	else
		for iUnitCnt,tUnitInfo in ipairs(tBusInfo.aUnitInfo) do
			print(string.format("\tUnit %d:\t%s", tUnitInfo.iIdx, tUnitInfo.strName))
		end
	end
	print("")
end

-- Disconnect the plugin.
tester.closeCommonPlugin()


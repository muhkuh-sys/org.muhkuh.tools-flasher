-----------------------------------------------------------------------------
-- Copyright (C) 2011 by Christoph Thelen                               <br/>
-- <a href="mailto:doc_bacardi@users.sourceforge.net">doc_bacardi@users.sourceforge.net</a><br/>
--                                                                      <br/>
-- This program is free software; you can redistribute it and/or modify <br/>
-- it under the terms of the GNU General Public License as published by <br/>
-- the Free Software Foundation; either version 2 of the License, or    <br/>
-- (at your option) any later version.                                  <br/>
--                                                                      <br/>
-- This program is distributed in the hope that it will be useful,      <br/>
-- but WITHOUT ANY WARRANTY; without even the implied warranty of       <br/>
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        <br/>
-- GNU General Public License for more details.                         <br/>
--                                                                      <br/>
-- You should have received a copy of the GNU General Public License    <br/>
-- along with this program; if not, write to the                        <br/>
-- Free Software Foundation, Inc.,                                      <br/>
-- 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.            <br/>
-----------------------------------------------------------------------------

local M = {}


local function load_from_working_folder(strFileName, fFileIsText)
	-- Unify the path (convert backslashes to slashes).
	local strUniPath = string.gsub(strFileName, "\\", "/")

	-- Does the string start with a slash?
	local iSlashIdx = string.find(strUniPath, "/", 1, true)
	if iSlashIdx==1 then
		-- Yes -> cut off the leading slash.
		strUniPath = string.sub(strUniPath,2)
	end

	-- Prepend the working folder to the file name.
	local strPath = _G.__MUHKUH_WORKING_FOLDER .. strUniPath

	-- Get the file mode.
	local strMode = "r"
	if fFileIsText~=true then
		strMode = strMode .. "b"
	end

	-- Load the complete file.
	local hFile = io.open(strPath, strMode)
	if hFile==nil then
		error("Failed to open file: " .. strPath)
	end
	local strData = hFile:read("*a")
	hFile:close()

	return strData
end


function M.include(strFileName)
	-- Get the file data as text.
	local strData = load_from_working_folder(strFileName, true)
	assert(loadstring(strData))()
end


function M.load(strFileName)
	-- Get the file data as binary.
	local strData = load_from_working_folder(strFileName, false)
	return strData
end


return M

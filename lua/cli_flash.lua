-----------------------------------------------------------------------------
-- Copyright (C) 2017 Hilscher Gesellschaft f�r Systemautomation mbH
--
-- Description:
--   cli_flash.lua: command line flasher tool
--
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- SVN Keywords
SVN_DATE   ="$Date$"
SVN_VERSION="$Revision$"
SVN_AUTHOR ="$Author$"
-----------------------------------------------------------------------------

-- Uncomment to debug with LuaPanda
-- require("LuaPanda").start("127.0.0.1",8818)

-- Requires are below, because they cause a lot of text to be printed.

local stringx = require "pl.stringx"
local tFlasher = require 'flasher'

-- exit code for detect_netx
STATUS_OK = 0
STATUS_ERROR = 1
STATUS_START_MI_IMAGE_FAILED = 2

-- exit codes for detect_secure_boot_mode
SECURE_BOOT_DISABLED = 0
SECURE_BOOT_ENABLED = 5
SECURE_BOOT_ONLY_APP_ENABLED = 50
SECURE_BOOT_UNKNOWN = 2
SECURE_BOOT_ERROR = 1

--------------------------------------------------------------------------
-- Usage
--------------------------------------------------------------------------

strUsage = [==[
Usage: lua cli_flash.lua mode parameters
        
Mode        Parameters                                                  
flash       [p][t][o] dev [offset]      file   Write file to flash    
read        [p][t][o] dev [offset] size file   Read flash and write to file      
erase       [p][t][o] dev [offset] size        Erase area or whole flash       
verify      [p][t][o] dev [offset]      file   Byte-by-byte compare
verify_hash [p][t][o] dev [offset]      file   Quick compare using checksums
hash        [p][t][o] dev [offset] size        Compute SHA1
info        [p][t][o]                          Show busses/units/chip selects
detect      [p][t][o] dev                      Check if flash is recognized
test        [p][t][o] dev                      Test flasher      
testcli     [p][t][o] dev                      Test cli flasher  
list_interfaces[t][o]                          List all usable interfaces
detect_netx [p][t][o]                          Detect the netx chip type
reset_netx  [p][t][o]                          Reset the netx 90
-h                                             Show this help   
-version                                       Show flasher version 
        
p:    -p plugin_name
      select plugin
      example: -p romloader_usb_00_01
      
t:    -t plugin_type
      select plugin type
      example: -t romloader_jtag
        
o:    [-jtag_khz frequency] [-jtag_reset mode]
      -jtag_khz: override JTAG frequency 
      -jtag_reset: hard(default)/soft/attach

dev:  -b bus [-u unit -cs chip_select]
      select flash device
      default: -u 0 -cs 0
       
off:  -s device_start_offset
      offset in the flash device, defaults to 0
       
size: -l length
      number of bytes to read/erase/hash
      read/erase: 0xffffffff = from offset to end of chip


Limitations:

The reset_netx command currently supports only the netx 90.

The hash and verify_hash commands do not support the netx 90 and netIOL.


Examples:

Write file to serial flash:
lua cli_flash.lua flash -b 1 NETX100-BSL.bin

Erase boot cookie from serial flash:
lua cli_flash.lua erase -b 1 -l 4 

Erase boot cookie from parallel flash:
lua cli_flash.lua erase -b 0 -l 4

]==]

--------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------

-- strData, strMsg loadBin(strFilePath)
-- Load a binary file.
-- returns 
--   data if successful 
--   nil, message if an error occurred
function loadBin(strFilePath)
	local strData
	local tFile
	local strMsg
	
	tFile, strMsg = io.open(strFilePath, "rb")
	if tFile then
		strData = tFile:read("*a")
		tFile:close()
		if strData == nil then
			strMsg = string.format("Could not read from file %s", strFilePath)
		end
	else
		strMsg = string.format("Could not open file %s: %s", strFilePath, strMsg or "Unknown error")
	end
	return strData, strMsg
end


-- fOk, strMsg writeBin(strName, strBin)
-- Write string to binary file.
-- returns true or false, message
function writeBin(strName, bin)
	local f, msg = io.open(strName, "wb")
	if f then 
		f:write(bin)
		f:close()
		return true, string.format("%d bytes written to file %s", bin:len(), strName)
	else
		print("Failed to open file for writing")
		return false, msg
	end
end

-- get hex representation (no spaces) of a byte string
function getHexString(strBin)
	local strHex = ""
	for i=1, strBin:len() do
		strHex = strHex .. string.format("%02x", strBin:byte(i))
	end
	return strHex
end


function printf(...) print(string.format(...)) end

--------------------------------------------------------------------------
-- get plugin
--------------------------------------------------------------------------

-- Show the available interfaces and let the user select one interactively.
--
-- strPattern is not evaluated.
-- 
-- If strPluginType is a string (a plugin ID as obtained by calling GetID on 
-- a plugin provider, e.g. "romloader_uart"), only this plugin provider
-- is scanned.
-- If strPluginType is nil, all plugin providers are scanned. 

function SelectPlugin(strPattern, strPluginType, atPluginOptions)
	local iInterfaceIdx
	local aDetectedInterfaces
	local tPlugin
	local strPattern = strPattern or ".*"

	show_plugin_options(atPluginOptions)
	
	repeat do
		-- Detect all interfaces.
		aDetectedInterfaces = {}
		for i,v in ipairs(__MUHKUH_PLUGINS) do
			if strPluginType == nil or strPluginType == v:GetID() then
				local iDetected
				print(string.format("Detecting interfaces with plugin %s", v:GetID()))
				iDetected = v:DetectInterfaces(aDetectedInterfaces,  atPluginOptions)
				print(string.format("Found %d interfaces with plugin %s", iDetected, v:GetID()))
			end
		end
		print(string.format("Found a total of %d interfaces with %d plugins", #aDetectedInterfaces, #__MUHKUH_PLUGINS))
		print("")

		-- Show all detected interfaces.
		print("Please select the interface:")
		for i,v in ipairs(aDetectedInterfaces) do
			print(string.format("%d: %s (%s) Used: %s, Valid: %s", i, v:GetName(), v:GetTyp(), tostring(v:IsUsed()), tostring(v:IsValid())))
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
		end until strInterface=="r" or strInterface=="c" or (iInterfaceIdx~=nil and iInterfaceIdx>0 and iInterfaceIdx<=#aDetectedInterfaces)
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

-- Try to open a plugin for an interface with the given name.
-- This function assumes that the name starts with the name of the interface,
-- e.g. romloader_uart, and scans only for interfaces whose type is contained
-- in the name string.
function getPluginByName(strName, strPluginType, atPluginOptions)
	show_plugin_options(atPluginOptions)
	
	for iPluginClass, tPluginClass in ipairs(__MUHKUH_PLUGINS) do
		if strPluginType == nil or strPluginType == tPluginClass:GetID() then
			local iDetected
			local aDetectedInterfaces = {}
	
			local strPluginType = tPluginClass:GetID()
			if strName:match(strPluginType) then
				print(string.format("Detecting interfaces with plugin %s", tPluginClass:GetID()))
				iDetected = tPluginClass:DetectInterfaces(aDetectedInterfaces, atPluginOptions)
				print(string.format("Found %d interfaces with plugin %s", iDetected, tPluginClass:GetID()))
			end
			
			for i,v in ipairs(aDetectedInterfaces) do
				print(string.format("%d: %s (%s) Used: %s, Valid: %s", i, v:GetName(), v:GetTyp(), tostring(v:IsUsed()), tostring(v:IsValid())))
				if strName == v:GetName() then
					if not v:IsValid() then
						return nil, "Plugin is not valid"
					elseif v:IsUsed() then
						return nil, "Plugin is in use"
					else
						print("found plugin")
						local tPlugin = v:Create()
						if tPlugin then 
							return tPlugin
						else
							return nil, "Error creating plugin instance"
						end
					end
				end
			end
		end
	end
	return nil, "plugin not found"
end

-- If strPluginName is the name of an interface, try to create a plugin 
-- instance for exactly the named interface.
-- Otherwise, show a list of available interface and let the user select one.
--
-- If strPluginType is a string (a plugin ID as obtained by calling GetID on 
-- a plugin provider, e.g. "romloader_uart"), only this plugin provider
-- is scanned.

function getPlugin(strPluginName, strPluginType, atPluginOptions)
	local tPlugin, strError
	if strPluginName then
		-- get the plugin by name
		tPlugin, strError = getPluginByName(strPluginName, strPluginType, atPluginOptions)
	else
		-- Ask the user to pick a plugin.
		tPlugin = SelectPlugin(nil, strPluginType, atPluginOptions)
		if tPlugin == nil then
			strError = "No plugin selected!"
		end
	end
	
	return tPlugin, strError
end


function printf(...) print(string.format(...)) end
function list_interfaces(strPluginType, atPluginOptions)
	show_plugin_options(atPluginOptions)

	-- detect all interfaces
	local aDetectedInterfaces = {}
	for iPluginClass, tPluginClass in ipairs(__MUHKUH_PLUGINS) do
		if strPluginType == nil or strPluginType == tPluginClass:GetID() then
			tPluginClass:DetectInterfaces(aDetectedInterfaces, atPluginOptions)
		end
	end
	-- filter used and non valid interfaces
	local aUnusedInterfaces = {}
	for i,v in ipairs(aDetectedInterfaces) do
		if not v:IsUsed() and v:IsValid() then
				table.insert(aUnusedInterfaces, v)
		end
	end
	-- output of not used and valid interfaces
	print()
	printf("START LIST NOT USED INTERFACES (%d Interfaces found)", #aUnusedInterfaces)
	print()
	for i, v in ipairs(aUnusedInterfaces) do
		printf("%d : Name:%-30s Typ: %-25s", i, v:GetName(), v:GetTyp())
	end
	print()
	print("END LIST INTERFACES")
end



function detect_chiptype(aArgs)
	local strPluginName  = aArgs.strPluginName
	local strPluginType  = aArgs.strPluginType
	local atPluginOptions= aArgs.atPluginOptions

	local fConnected
	local iChiptype
	local strChipName
	
	local iRet = STATUS_OK -- assume success
	
	local tPlugin, strMsg = getPlugin(strPluginName, strPluginType, atPluginOptions)
	if tPlugin then
		fConnected, strMsg = pcall(tPlugin.Connect, tPlugin)
		print("Connect() result: ", fConnected, strMsg)
		
		-- translate this message string to a specific return code
		local strMsgComp = "start_mi image has been rejected or execution has failed."
		if not fConnected and strMsg:find(strMsgComp) then
			iRet = STATUS_START_MI_IMAGE_FAILED
		end
		
		iChiptype = tPlugin:GetChiptyp()
		strChipName = tPlugin:GetChiptypName(iChiptype)
		
		-- Detect the PHY version to discriminate
		-- between netX 90 Rev1 and netx 90 Rev1 PHY V3
		if iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or
		iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C then
			strChipName = "netX90 Rev1 (suspicious, PHY version not checked)"
		
			-- Note: if the connection has failed, we keep the previously read chip type.
			if fConnected == true then
				print("Detecting PHY version on netX 90 Rev1")
				local bootpins = require("bootpins")
				bootpins:_init()
				local atResult = bootpins:read(tPlugin)
				if atResult.chip_id == bootpins.atChipID.NETX90B then 
					iChiptype = romloader.ROMLOADER_CHIPTYP_NETX90B
					strChipName = "netX90 Rev1 (PHY V2)"
				elseif atResult.chip_id == bootpins.atChipID.NETX90BPHYR3 then 
					iChiptype = romloader.ROMLOADER_CHIPTYP_NETX90C
					strChipName = tPlugin:GetChiptypName(iChiptype)
				end
			end
		end

		if iChiptype and iChiptype ~= romloader.ROMLOADER_CHIPTYP_UNKNOWN then
			
			print("")
			printf("Chip type: (%d) %s", iChiptype, strChipName)
			print("")
			
		else
			strMsg = "Failed to get chip type"
			iRet = STATUS_ERROR
		end -- if iChiptype
	else
		strMsg = strMsg or "Could not connect to device"
		iRet = STATUS_ERROR
	end -- if tPlugin
	
	return iRet, strMsg
end


function detect_secure_boot_mode(aArgs)
	local strPluginName  = aArgs.strPluginName
	local strPluginType  = aArgs.strPluginType
	local atPluginOptions= aArgs.atPluginOptions
	
	local fConnected
	local iChiptype
	local strChipName
	local fStartMiFailed
	local tConsoleMode
	local usMiVersionMaj
	local usMiVersionMin
	local strImageBin
	
	local iSecureBootStatus = SECURE_BOOT_ERROR
	
	local tPlugin, strMsg = getPlugin(strPluginName, strPluginType, atPluginOptions)
	if tPlugin == nil then 
		strMsg = strMsg or "Could not connect to device."
	elseif tPlugin:GetTyp() ~= "romloader_uart" then
		strMsg = "Only romloader_uart is supported."
	else 
		fConnected, strMsg = pcall(tPlugin.Connect, tPlugin)
		print("Connect() result: ", fConnected, strMsg)
		
		local strMsgComp = "start_mi image has been rejected or execution has failed."
		if not fConnected and strMsg:find(strMsgComp) then
			print("Failed to execute the boot image to start the machine interface.")
			fStartMiFailed = true
		else 
			fStartMiFailed = false
		end
		
		iChiptype = tPlugin:GetChiptyp()
		strChipName = tPlugin:GetChiptypName(iChiptype)
		if iChiptype then
			printf("Chip type: %s (%d) (may be suspicious, PHY version not verified)", strChipName, iChiptype)
		else 
			print("Could not detect chip type")
		end
		
		tConsoleMode = tPlugin:get_console_mode()
		if tConsoleMode == romloader.CONSOLE_MODE_Open then
			print("Console mode: open")
		elseif tConsoleMode == romloader.CONSOLE_MODE_Secure then
			print("Console mode: secure")
		elseif tConsoleMode == romloader.CONSOLE_MODE_Unknown then
			print("Console mode: unknown")
		else 
			printf("Console mode: ?? (%d)", tConsoleMode)
		end
		
		usMiVersionMaj = tPlugin:get_mi_version_maj()
		usMiVersionMin = tPlugin:get_mi_version_min()
		printf("MI version: %d.%d", usMiVersionMaj, usMiVersionMin)

		if iChiptype == nil or iChiptype == romloader.ROMLOADER_CHIPTYP_UNKNOWN then
			strMsg = "Failed to get chip type"
			
		elseif iChiptype~=romloader.ROMLOADER_CHIPTYP_NETX90B
		and iChiptype~=romloader.ROMLOADER_CHIPTYP_NETX90C
		and iChiptype~=romloader.ROMLOADER_CHIPTYP_NETX90D then
			strMsg = "detect_secure_boot_mode supports only netX 90 Rev.1 and 2"
			
		else
			if tConsoleMode == romloader.CONSOLE_MODE_Open then
				-- Console mode: open => secure boot is disabled.
				iSecureBootStatus = SECURE_BOOT_DISABLED
			elseif tConsoleMode == romloader.CONSOLE_MODE_Secure then 
				if usMiVersionMaj == 0 and usMiVersionMin == 0  and fStartMiFailed then 
					-- MI not active, boot image failed => COM CPU is in secure boot mode.
					iSecureBootStatus = SECURE_BOOT_ENABLED
				elseif usMiVersionMaj == 3 and usMiVersionMin == 0 then
					-- MI 3.0, secure console => COM CPU is open, APP CPU is secure
					iSecureBootStatus = SECURE_BOOT_ONLY_APP_ENABLED
				elseif usMiVersionMaj == 3 and usMiVersionMin == 1 then 
					print("Found machine interface v3.1 in secure mode.")
					print("Attempting to run an unsigned boot image.")
				
					local strImagePath = path.join(tFlasher.DEFAULT_HBOOT_OPTION, "netx90", "exec_bxlr.bin")
					printf("Trying to load netX 90 exec_bxlr image from %s", strImagePath)
			
					strImageBin, strMsg = loadBin(strImagePath)
			
					if strImageBin == nil then
						printf("Error: Failed to load netX 90 exec_bxlr image: %s", strMsg or "unknown error")
					else
						printf("%d bytes loaded.", strImageBin:len())
						flasher.write_image(tPlugin, 0x200c0, strImageBin)
						tPlugin:write_data32(0x22000, 0xffffffff)
						local ulVal = tPlugin:read_data32(0x22000)
						printf("Value at 0x22000 before running boot image: 0x%08x", ulVal)
						local tRet = flasher.call_hboot(tPlugin)
						print("return value from call_hboot:" , tRet)
						local ulVal = tPlugin:read_data32(0x22000)
						printf("Value at 0x22000 after running boot image: 0x%08x", ulVal)
						
						if (ulVal == 0) then
							-- Unsigned image executed.=> The COM CPU is not in secure boot mode.
							iSecureBootStatus = SECURE_BOOT_ONLY_APP_ENABLED
						elseif (ulVal == 0xffffffff) then
							-- Unsigned boot image not executed. => The COM CPU is in secure boot mode.
							iSecureBootStatus = SECURE_BOOT_ENABLED
						else 
							strMsg = "Unexpected value from boot image."
							print("Unexpected value from boot image. => Cannot detect secure boot mode.")
						end
					end
				else 
					strMsg = "Invalid MI version"
				end
			else -- console mode unknown
				-- The console mode is iunknown and machine interface 3.0 is active.
				-- If the console was in the initial "wait for knock" state after reset,
				-- and started the machine interface during Connect(), secure boot is disabled.
				-- However, it is possible that it already was in MI mode, and in that case 
				-- we don't know how it got there.
				if usMiVersionMaj == 3 and usMiVersionMin == 0 then
					iSecureBootStatus = SECURE_BOOT_UNKNOWN
				else
					strMsg = "Unknown console mode"
				end
			end -- console mode
		end -- chip type
	end -- if tPlugin

	if iSecureBootStatus==SECURE_BOOT_DISABLED then 
		strMsg = "Secure boot mode disabled. COM and APP CPU are in open mode."
	elseif iSecureBootStatus==SECURE_BOOT_ENABLED then 
		strMsg = "Secure boot mode enabled. COM CPU is in secure boot mode, APP CPU is unknown."
	elseif iSecureBootStatus==SECURE_BOOT_ONLY_APP_ENABLED then 
		strMsg = "Secure boot mode enabled. COM CPU is in open mode, APP CPU is in secure boot mode."
	elseif iSecureBootStatus==SECURE_BOOT_UNKNOWN then 
		strMsg = "Cannot detect secure boot mode. "..
		"If the netX was just reset, COM and APP are in open mode."
	else 
		strMsg = "Cannot detect secure boot mode: " .. strMsg or "unknown error"
	end
	
	return iSecureBootStatus, strMsg
	
end



-- Sleep for a number of seconds
-- (between seconds and seconds+1)
function sleep_s(seconds)
	local t1 = os.time()
	local t2
	repeat 
		t2 = os.time()
	until os.difftime(t2, t1) >= (seconds+1)
end

-- Set up the watchdog to reset after one second. 
-- This gives us time to disconnect the plugin.
--
-- Notes: 
-- Currently does not support netIOL (not tested)
-- Does not work reliably via JTAG.
--
-- watchdog CTRL register: at base address + 0
-- bit 31   write_enable 
-- bit 29   wdg_active_enable_w (*)
-- bit 28   wdg_counter_trigger_w
-- bit 24   irq_req_watchdog 
-- bit 19-0 access code
-- 
-- (*) Watchdog Active Enable. 
-- If this bit is set, the WDGACT output signal(PIN D16) is enabled.
-- Only on netx 500/100/50.
-- 
-- IRQ_TIMEOUT: at base address + 8
-- bit 15-0 IRQ timeout in units of 100 µs
-- 
-- RES_TIMEOUT: at base address + 12 
-- bit 15-0 RESET timeout in units of 100 µs

function reset_netx_via_watchdog(aArgs)
	local tPlugin
	local fOk
	local strMsg

	local strPluginName  = aArgs.strPluginName
	local strPluginType  = aArgs.strPluginType
	local atPluginOptions= aArgs.atPluginOptions

	local atChiptyp2WatchdogBase = {
		-- [romloader.ROMLOADER_CHIPTYP_NETX500]          = 0x00100200,
		-- [romloader.ROMLOADER_CHIPTYP_NETX100]          = 0x00100200,
		-- [romloader.ROMLOADER_CHIPTYP_NETX50]           = 0x1c000200,
		-- [romloader.ROMLOADER_CHIPTYP_NETX10]           = 0x101c0200,
		-- [romloader.ROMLOADER_CHIPTYP_NETX56]           = 0x1018c5b0,
		-- [romloader.ROMLOADER_CHIPTYP_NETX56B]          = 0x1018c5b0,
		-- [romloader.ROMLOADER_CHIPTYP_NETX4000_RELAXED] = 0xf409c200,
		-- [romloader.ROMLOADER_CHIPTYP_NETX4000_FULL]    = 0xf409c200,
		-- [romloader.ROMLOADER_CHIPTYP_NETX4100_SMALL]   = 0xf409c200,
		[romloader.ROMLOADER_CHIPTYP_NETX90_MPW]       = 0xFF001640,
		[romloader.ROMLOADER_CHIPTYP_NETX90]           = 0xFF001640,
		[romloader.ROMLOADER_CHIPTYP_NETX90B]          = 0xFF001640,
		[romloader.ROMLOADER_CHIPTYP_NETX90C]          = 0xFF001640,
		[romloader.ROMLOADER_CHIPTYP_NETX90D]          = 0xFF001640,
		-- [romloader.ROMLOADER_CHIPTYP_NETIOLA]          = 0x00000500,
		-- [romloader.ROMLOADER_CHIPTYP_NETIOLB]          = 0x00000500,
	}

	fOk = false
	
	-- open the plugin
	tPlugin, strMsg = getPlugin(strPluginName, strPluginType, atPluginOptions)

	if tPlugin ~= nil then 
		fOk, strMsg = pcall(tPlugin.Connect, tPlugin)
		if not fOk then 
			strMsg = strMsg or "Failed to open connection"
		else 
			local iChiptype = tPlugin:GetChiptyp()
			local strChiptypName = tPlugin:GetChiptypName(iChiptype)
			local ulWdgBaseAddr = atChiptyp2WatchdogBase[iChiptype]
			
			if ulWdgBaseAddr == nil then
				-- unknown chip type or not supported
				strMsg = string.format("The reset_netx command is not supported on %s (%d)", strChiptypName, iChiptype)
				
			elseif iChiptype == romloader.ROMLOADER_CHIPTYP_NETIOLA or 
				iChiptype == romloader.ROMLOADER_CHIPTYP_NETIOLB then 
				-- Watchdog reset on netIOL
	
				local ulAddr_wdg_sys_cfg            = ulWdgBaseAddr + 0
				local ulAddr_wdg_sys_cmd            = ulWdgBaseAddr + 4
				local ulAddr_wdg_sys_cnt_upper_rld  = ulWdgBaseAddr + 8
				local ulAddr_wdg_sys_cnt_lower_rld  = ulWdgBaseAddr + 12
				local ulPwd = 0x3fa * 4
				local ulVal
				
				-- disable watchdog 
				tPlugin:write_data16(ulAddr_wdg_sys_cfg, ulPwd)
				
				-- check if it is disabled
				ulVal = tPlugin:read_data16(ulAddr_wdg_sys_cfg)
				ulVal = ulVal % 2
				--ulVal = bit.band(ulVal, 1)
				if ulVal ~= 0 then
					print("Warning: cannot disable watchdog on netIOL")
				end
				
				-- todo: what values for prescaler/counter?
				tPlugin:write_data16(ulAddr_wdg_sys_cnt_upper_rld, 0x07ff)
				tPlugin:write_data16(ulAddr_wdg_sys_cnt_lower_rld, 0xffff)
				
				-- enable watchdog
				tPlugin:write_data16(ulAddr_wdg_sys_cfg, ulPwd + 1)
				
				-- trigger watchdog
				tPlugin:write_data16(ulAddr_wdg_sys_cmd, 0x72b4)
				tPlugin:write_data16(ulAddr_wdg_sys_cmd, 0xde80)
				tPlugin:write_data16(ulAddr_wdg_sys_cmd, 0xd281)
				
				print ("The netX should reset after one second.")
				fOk = true
	
			else
				-- watchdog reset on other netX types
				local ulAddr_WdgCtrl       = ulWdgBaseAddr + 0
				local ulAddr_WdgIrqTimeout = ulWdgBaseAddr + 8
				local ulAddr_WdgResTimeout = ulWdgBaseAddr + 12
				local ulVal
				
				-- Set write enable for the timeout regs
				ulVal = tPlugin:read_data32(ulAddr_WdgCtrl)
				ulVal = ulVal + 0x80000000
				tPlugin:write_data32(ulAddr_WdgCtrl, ulVal)
				
				-- IRQ after 0.9 seconds (9000 * 100µs, not handled)
				tPlugin:write_data32(ulAddr_WdgIrqTimeout, 9000)
				-- reset 0.1 seconds later
				tPlugin:write_data32(ulAddr_WdgResTimeout, 1000)
	
				-- Trigger the watchdog once to start it
				ulVal = tPlugin:read_data32(ulAddr_WdgCtrl)
				ulVal = ulVal + 0x10000000
				tPlugin:write_data32(ulAddr_WdgCtrl, ulVal)
				
				print ("The netX should reset after one second.")
				fOk = true
			end
			
			tPlugin:Disconnect()
			tPlugin = nil
			
			-- Wait 1 second (actually between 1 and 2 seconds)
			if (fOk == true) then
				sleep_s(1)
			end
		end 
	end
	
	return fOk, strMsg
end



--------------------------------------------------------------------------
-- handle command line arguments
--------------------------------------------------------------------------

MODE_FLASH = 0
MODE_READ = 2
MODE_VERIFY = 3
MODE_ERASE = 4
MODE_HASH = 5
MODE_DETECT = 6
MODE_VERIFY_HASH = 7
MODE_INFO = 8
MODE_HELP = 10
MODE_LIST_INTERFACES = 15
MODE_DETECT_CHIPTYPE = 16
MODE_VERSION = 17
MODE_RESET = 18
MODE_IDENTIFY = 19

-- test modes
MODE_TEST = 11
MODE_TEST_CLI = 12
-- used by test modes
MODE_IS_ERASED = 13
MODE_GET_DEVICE_SIZE = 14

-- functions to add arguments to subcommands

function addFilePathArg(tParserCommand)
   tParserCommand:argument('file', 'file name'):target('strDataFileName')
end

function addBusOptionArg(tParserCommand)
    -- tOption = tParserCommand:option('-b --bus', 'bus number'):target('iBus')
    tOption = tParserCommand:option('-b', 'bus number'):target('iBus'):convert(tonumber)
    tOption._mincount = 1
end

function addUnitOptionArg(tParserCommand)
    -- tOption = tParserCommand:option('-u --unit', 'unit number'):target('iUnit')
    tOption = tParserCommand:option('-u', 'unit number'):target('iUnit'):default(0):convert(tonumber)
    -- tOption._mincount = 1
end

function addChipSelectOptionArg(tParserCommand)
    -- tOption = tParserCommand:option('-cs --chip_select', 'chip select number'):target('iChipSelect')
    tOption = tParserCommand:option('-c', 'chip select number'):target('iChipSelect'):default(0):convert(tonumber)
    -- tOption._mincount = 1
end

function addStartOffsetArg(tParserCommand)
    -- tParserCommand:option('-s --start_offset', 'start offset'):target('ulStartOffset'):default(0)
    tParserCommand:option('-s', 'start offset'):target('ulStartOffset'):default(0):convert(tonumber)
end

function addLengthArg(tParserCommand)
    -- tOption = tParserCommand:option('-l --length', 'number of bytes to read/erase/hash'):target('ulLen')
    tOption = tParserCommand:option('-l', 'number of bytes to read/erase/hash'):target('ulLen'):convert(tonumber)
    tOption._mincount = 1
end

function addPluginNameArg(tParserCommand)
    -- tParserCommand:option('-p --plugin_name', 'plugin name'):target('strPluginName')
    tParserCommand:option('-p', 'plugin name'):target('strPluginName')
end

function addPluginTypeArg(tParserCommand)
    -- tParserCommand:option('--t --plugin_type', 'plugin type'):target('strPluginType')
    tParserCommand:option('-t', 'plugin type'):target('strPluginType')
end

function addSecureArgs(tParserCommand)
    tParserCommand:mutex(
            tParserCommand:flag('--comp'):description("use compatibility mode for netx90 M2M interfaces"):target('bCompMode'):default(false),
            tParserCommand:option('--sec'):description("path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
    )
end

function addJtagKhzArg(tParserCommand)
    tParserCommand:option('--jtag_khz', 'JTAG clock in kHz'):target('iJtagKhz'):convert(tonumber)
end

function addJtagResetArg(tParserCommand)
    tOption = tParserCommand:option('--jtag_reset',
            'JTAG reset method. Possible values are: hard (default), soft, attach'):target('strJtagReset')
    tOption._options = {"HardReset", "SoftReset", "Attach" }
end

local argparse = require 'argparse'

local strEpilog = [==[
Limitations:

The reset_netx command currently supports only the netx 90.

The hash and verify_hash commands do not support the netx 90 and netIOL.

The secure mode features ('--sec' and '--comp') are only valid for netx90


Examples:

Write file to serial flash:
lua cli_flash.lua flash -b 1 NETX100-BSL.bin

Erase boot cookie from serial flash:
lua cli_flash.lua erase -b 1 -l 4

Erase boot cookie from parallel flash:
lua cli_flash.lua erase -b 0 -l 4
]==]

local tParser = argparse('Cli Flasher', ''):command_target("strSubcommand"):epilog(strEpilog)

tParser:flag "-v --version":description "Show version info and exit. ":action(function()
    require("flasher_version")
    print(FLASHER_VERSION_STRING)
    os.exit(0)
end)

-- 	flashfCommandFlashSelected
local tParserCommandFlash = tParser:command('flash f', 'Flash a file to the netX'):target('fCommandFlashSelected')
-- required_args = {"b", "u", "cs", "s", "f"},
addFilePathArg(tParserCommandFlash)
addBusOptionArg(tParserCommandFlash)
addUnitOptionArg(tParserCommandFlash)
addChipSelectOptionArg(tParserCommandFlash)
addStartOffsetArg(tParserCommandFlash)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandFlash)
addPluginTypeArg(tParserCommandFlash)
addJtagResetArg(tParserCommandFlash)
addJtagKhzArg(tParserCommandFlash)
addSecureArgs(tParserCommandFlash)

-- 	read
local tParserCommandRead = tParser:command('read r', 'Read data from netX to a File'):target('fCommandReadSelected')
-- required_args = {"b", "u", "cs", "s", "l", "f"}
addFilePathArg(tParserCommandRead)
addBusOptionArg(tParserCommandRead)
addUnitOptionArg(tParserCommandRead)
addChipSelectOptionArg(tParserCommandRead)
addStartOffsetArg(tParserCommandRead)
addLengthArg(tParserCommandRead)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandRead)
addPluginTypeArg(tParserCommandRead)
addJtagResetArg(tParserCommandRead)
addJtagKhzArg(tParserCommandRead)
addSecureArgs(tParserCommandRead)

-- erase
local tParserCommandErase = tParser:command('erase e', 'Erase area inside flash'):target('fCommandEraseSelected')
-- required_args = {"b", "u", "cs", "s", "l"}
addBusOptionArg(tParserCommandErase)
addUnitOptionArg(tParserCommandErase)
addChipSelectOptionArg(tParserCommandErase)
addStartOffsetArg(tParserCommandErase)
addLengthArg(tParserCommandErase)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandErase)
addPluginTypeArg(tParserCommandErase)
addJtagResetArg(tParserCommandErase)
addJtagKhzArg(tParserCommandErase)
addSecureArgs(tParserCommandErase)

-- verify
local tParserCommandVerify = tParser:command('verify v', 'Verify that a file is flashed'):target('fCommandVerifySelected')
-- required_args = {"b", "u", "cs", "s", "f"}
addFilePathArg(tParserCommandVerify)
addBusOptionArg(tParserCommandVerify)
addUnitOptionArg(tParserCommandVerify)
addChipSelectOptionArg(tParserCommandVerify)
addStartOffsetArg(tParserCommandVerify)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandVerify)
addPluginTypeArg(tParserCommandVerify)
addJtagResetArg(tParserCommandVerify)
addJtagKhzArg(tParserCommandVerify)
addSecureArgs(tParserCommandVerify)

-- verify_hash
local tParserCommandVerifyHash = tParser:command('verify_hash vh', 'Quick compare using checksums'):target('fCommandVerifyHashSelected')
-- required_args = {"b", "u", "cs", "s", "f"}
addFilePathArg(tParserCommandVerifyHash)
addBusOptionArg(tParserCommandVerifyHash)
addUnitOptionArg(tParserCommandVerifyHash)
addChipSelectOptionArg(tParserCommandVerifyHash)
addStartOffsetArg(tParserCommandVerifyHash)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandVerifyHash)
addPluginTypeArg(tParserCommandVerifyHash)
addJtagResetArg(tParserCommandVerifyHash)
addJtagKhzArg(tParserCommandVerifyHash)

-- hash
local tParserCommandHash = tParser:command('hash h', 'Compute SHA1'):target('fCommandHashSelected')
-- required_args = {"b", "u", "cs", "s", "l"}
addBusOptionArg(tParserCommandHash)
addUnitOptionArg(tParserCommandHash)
addChipSelectOptionArg(tParserCommandHash)
addStartOffsetArg(tParserCommandHash)
addLengthArg(tParserCommandHash)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandHash)
addPluginTypeArg(tParserCommandHash)
addJtagResetArg(tParserCommandHash)
addJtagKhzArg(tParserCommandHash)

-- detect
local tParserCommandDetect = tParser:command('detect d', 'Check if flash is recognized'):target('fCommandDetectSelected')
-- required_args = {"b", "u", "cs"}
addBusOptionArg(tParserCommandDetect)
addUnitOptionArg(tParserCommandDetect)
addChipSelectOptionArg(tParserCommandDetect)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandDetect)
addPluginTypeArg(tParserCommandDetect)
addJtagResetArg(tParserCommandDetect)
addJtagKhzArg(tParserCommandDetect)
addSecureArgs(tParserCommandDetect)

-- test
local tParserCommandTest = tParser:command('test t', 'Test flasher'):target('fCommandTestSelected')
-- required_args = {"b", "u", "cs"}
addBusOptionArg(tParserCommandTest)
addUnitOptionArg(tParserCommandTest)
addChipSelectOptionArg(tParserCommandTest)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandTest)
addPluginTypeArg(tParserCommandTest)
addJtagResetArg(tParserCommandTest)
addJtagKhzArg(tParserCommandTest)
addSecureArgs(tParserCommandTest)

-- testcli
local tParserCommandTestCli = tParser:command('testcli tc', 'Test cli flasher'):target('fCommandTestCliSelected')
-- required_args = {"b", "u", "cs"}
addBusOptionArg(tParserCommandTestCli)
addUnitOptionArg(tParserCommandTestCli)
addChipSelectOptionArg(tParserCommandTestCli)
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandTestCli)
addPluginTypeArg(tParserCommandTestCli)
addJtagResetArg(tParserCommandTestCli)
addJtagKhzArg(tParserCommandTestCli)
addSecureArgs(tParserCommandTestCli)

-- info
local tParserCommandInfo = tParser:command('info i', 'Show information about the netX'):target('fCommandInfoSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandInfo)
addPluginTypeArg(tParserCommandInfo)
addJtagResetArg(tParserCommandInfo)
addJtagKhzArg(tParserCommandInfo)
addSecureArgs(tParserCommandInfo)

-- list_interfaces
local tParserCommandListInterfaces = tParser:command('list_interfaces li', 'List all connected interfaces'):target('fCommandListInterfacesSelected')
-- optional_args = {"t", "jf", "jr"}
addPluginTypeArg(tParserCommandListInterfaces)
addJtagResetArg(tParserCommandListInterfaces)
addJtagKhzArg(tParserCommandListInterfaces)


-- detect_netx
local tParserCommandDetectNetx = tParser:command('detect_netx dn', 'Detect if an interface is a netX'):target('fCommandDetectNetxSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandDetectNetx)
addPluginTypeArg(tParserCommandDetectNetx)
addJtagResetArg(tParserCommandDetectNetx)
addJtagKhzArg(tParserCommandDetectNetx)
addSecureArgs(tParserCommandDetectNetx)

-- detect_secure_boot_mode
local tParserCommandDetectSecureBoot = tParser:command('detect_secure_boot_mode ds', 'Detect if secure boot is enabled (netX 90 only)'):target('fCommandDetectSecureBootSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandDetectSecureBoot)
addPluginTypeArg(tParserCommandDetectSecureBoot)
addJtagResetArg(tParserCommandDetectSecureBoot)
addJtagKhzArg(tParserCommandDetectSecureBoot)


-- reset_netx
local tParserCommandResetNetx = tParser:command('reset_netx r', 'Reset the netX'):target('fCommandResetSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandResetNetx)
addPluginTypeArg(tParserCommandResetNetx)
addJtagResetArg(tParserCommandResetNetx)
addJtagKhzArg(tParserCommandResetNetx)
addSecureArgs(tParserCommandResetNetx)

-- reset_netx
local tParserCommandIdentifyNetx = tParser:command('identify_netx i', 'Blink SYS LED for 5 sec'):target('fParserCommandIdentifyNetxSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandIdentifyNetx)
addPluginTypeArg(tParserCommandIdentifyNetx)
addJtagResetArg(tParserCommandIdentifyNetx)
addJtagKhzArg(tParserCommandIdentifyNetx)



-- return true if list l contains element e 
function list_contains(l, e)
	for _k, v in ipairs(l) do
		if v==e then 
			return true
		end
	end
	return false
end


function showArgs(aArgs)
	local arg_order = {"p", "t", "b", "u", "cs", "s", "l", "f", "jr", "jf"}
	local astrArgLines = {}
		
	for i, k in ipairs(arg_order) do
		local tArgdef = argdefs[k]
		local tVal = aArgs[tArgdef.argkey]
		local strVal 
		local strLine
		if tVal ~= nil then
			if type(tVal) == "number" then 
				strVal = string.format("0x%x", tVal)
			else
				strVal = tostring(tVal)
			end
			strLine = string.format("%-40s %-s", tArgdef.name, strVal)
			table.insert(astrArgLines, strLine)
		end
	end
	
	if #astrArgLines == 0 then
		table.insert(astrArgLines, "none")
	end
	
	print("")
	print("Arguments:")
	for i, strLine in ipairs(astrArgLines) do
		print(strLine)
	end
	print("")
end

function show_plugin_options(tOpts)
	print("Plugin options:")
	for strPluginId, tPluginOptions in pairs(tOpts) do
		print(string.format("For %s:", strPluginId))
		for strKey, tVal in pairs(tPluginOptions) do
			print(strKey, tVal)
		end
	end
end

--------------------------------------------------------------------------
--  board info
--------------------------------------------------------------------------


function printobj(val, key, indent)
	key = key or ""
	indent = indent or ""
	
	if type(val)=="number" then
		print(string.format("%s%s = %d (number)", indent, key, val))
	elseif type(val)=="string" then
		print(string.format("%s%s = %s (string)", indent, key, val))
	elseif type(val)=="table" then
		local indent = indent .. "  "
		print(string.format("%s%s = {", indent, key))
		for k,v in pairs(val) do
			printobj(v, tostring(k), indent)
		end
		print(string.format("%s} -- %s", indent, key))
	end
end


function printBoardInfo(tBoardInfo)
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
end


---------------------------------------------------------------------------------------
--                   Execute flash operation
---------------------------------------------------------------------------------------


--                  info   detect   flash   verify   erase   read   hash   verify_hash
---------------------------------------------------------------------------------------
-- open plugin        x       x       x       x        x      x       x         x     
-- load flasher       x       x       x       x        x      x       x         x     
-- download flasher   x       x       x       x        x      x       x         x     
-- info               x
-- detect                     x       x       x        x      x       x         x
-- load data file                     x       x                                 x
-- eraseArea                          x                x
-- flashArea                          x
-- verifyArea                                 x
-- readArea                                                   x
-- SHA over data file                                                           x
-- SHA over flash                                                     x         x
-- save file                                                  x

function exec(aArgs)
	local iMode          = aArgs.iMode
	local strPluginName  = aArgs.strPluginName
	local strPluginType  = aArgs.strPluginType
	local iBus           = aArgs.iBus
	local iUnit          = aArgs.iUnit
	local iChipSelect    = aArgs.iChipSelect
	local ulStartOffset  = aArgs.ulStartOffset
	local ulLen          = aArgs.ulLen
	local strDataFileName= aArgs.strDataFileName
	local atPluginOptions= aArgs.atPluginOptions
    local bCompMode = aArgs.bCompMode
	local strSecureOption = nil
	if aArgs.strSecureOption~= nil then
		strSecureOption = path.abspath(aArgs.strSecureOption)
	end
	
	local tPlugin
	local aAttr
	local strData
	local fOk
	local strMsg
	
	local ulDeviceSize
	local tDevInfo = {}
	
	local strFileHashBin, strFlashHashBin
	local strFileHash , strFlashHash
	
	-- open the plugin
	tPlugin, strMsg = getPlugin(strPluginName, strPluginType, atPluginOptions)
	if tPlugin then
		fOk, strMsg = pcall(tPlugin.Connect, tPlugin)
		if not fOk then 
			strMsg = strMsg or "Failed to open connection"
		end
		print("Connect() result: ", fOk, strMsg)
		
		-- On netx 4000, there may be a boot image in intram that makes it
		-- impossible to boot a firmware from flash by resetting the hardware.
		-- Therefore we clear the start of the intram boot image.
		if fOk then
			local iChiptype = tPlugin:GetChiptyp()
			if iChiptype == romloader.ROMLOADER_CHIPTYP_NETX4000_SMALL
			or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX4000_FULL
			or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX4000_RELAXED then
				print("Clear intram image on netx 4000")
				for i=0, 3 do
					local ulAddr = 0x05100000 + i*4
					tPlugin:write_data32(ulAddr, 0)
				end
			end
		end 
		
		-- load input file  strDataFileName --> strData
		if fOk and (aArgs.fCommandFlashSelected or aArgs.fCommandVerifySelected or aArgs.fCommandVerifyHashSelected) then
			print("Loading data file")
			strData, strMsg = loadBin(strDataFileName)
			if not strData then
				fOk = false
			else
				ulLen = strData:len()
			end
		end
		
		-- Download the flasher.
		if fOk then
			print("Downloading flasher binary")
			aAttr = flasher.download(tPlugin, FLASHER_PATH, nil, bCompMode, strSecureOption)
			if not aAttr then
				fOk = false
				strMsg = "Error while downloading flasher binary"
			end
		end
		
		if fOk then 
			if aArgs.fCommandInfoSelected then
				-- Get the board info table.
				aBoardInfo = flasher.getBoardInfo(tPlugin, aAttr)
				if aBoardInfo then
					printBoardInfo(aBoardInfo)
					fOk = true
				else
					fOk = false
					strMsg = "Failed to read board info"
				end
	        elseif aArgs.fParserCommandIdentifyNetxSelected then
                -- no action nescessary
				fOk = true;
			else
				-- check if the selected flash is present
				print("Detecting flash device")
				fOk = flasher.detect(tPlugin, aAttr, iBus, iUnit, iChipSelect)
				if fOk ~= true then
					fOk = false
					strMsg = "Failed to get a device description!"
				else
				
					if iBus == flasher.BUS_Spi then
						local strDevDesc = flasher.readDeviceDescriptor(tPlugin, aAttr)
						if strDevDesc==nil then
							strMsg = "Failed to read the flash device descriptor!"
							fOk = false
						else 
							local strSpiDevName, strSpiDevId = flasher.SpiFlash_getNameAndId(strDevDesc)
							tDevInfo.strDevName = strSpiDevName or "unknown"
							tDevInfo.strDevId = strSpiDevId or "unknown"
						end
					end
				
					ulDeviceSize = flasher.getFlashSize(tPlugin, aAttr)
					if ulDeviceSize == nil then
						fOk = false
						strMsg = "Failed to get the device size!"
					else 
						-- if offset/len are set, we require that offset+len is less than or equal the device size
						if ulStartOffset~= nil and ulLen~= nil and ulStartOffset+ulLen > ulDeviceSize and ulLen ~= 0xffffffff then
							fOk = false
							strMsg = string.format("Offset+size exceeds flash device size: 0x%08x bytes", ulDeviceSize)
						else
							fOk = true
							strMsg = string.format("Flash device size: %d/0x%08x bytes", ulDeviceSize, ulDeviceSize)
						end
						
					end
				end
			end
		end
		
		-- flash/erase: erase the area

		if fOk and (aArgs.fCommandEraseSelected or (aArgs.fCommandFlashSelected and iBus ~= flasher.BUS_SDIO))then
			fOk, strMsg = flasher.eraseArea(tPlugin, aAttr, ulStartOffset, ulLen)
		end
		
		-- flash: flash the data
		if fOk and aArgs.fCommandFlashSelected then
			fOk, strMsg = flasher.flashArea(tPlugin, aAttr, ulStartOffset, strData)
		end
		
		-- verify
		if fOk and aArgs.fCommandVerifySelected then
			fOk, strMsg = flasher.verifyArea(tPlugin, aAttr, ulStartOffset, strData)
		end
		
		-- read
		if fOk and aArgs.fCommandReadSelected then
			strData, strMsg = flasher.readArea(tPlugin, aAttr, ulStartOffset, ulLen)
			if strData == nil then
				fOk = false
				strMsg = strMsg or "Error while reading"
			end
		end
		
		-- for test mode
		if fOk and aArgs.fCommandTestSelected then
			flasher_test.flasher_interface:configure(tPlugin, FLASHER_PATH, iBus, iUnit, iChipSelect)
			fOk, strMsg = flasher_test.testFlasher()
		end
		
		-- for test mode
		if fOk and iMode == MODE_IS_ERASED then
			local fOk = flasher.isErased(tPlugin, aAttr, ulStartOffset, ulStartOffset + ulLen)
			strMsg = fOk and "Area is empty" or "Area is not empty"
		end
		
		-- for test mode
		if fOk and iMode == MODE_GET_DEVICE_SIZE then
			ulLen = flasher.getFlashSize(tPlugin, aAttr)
			if ulLen == nil then
				fOk = false
				strMsg = "Failed to get device size"
			end
		end
		
		
		-- hash, verify_hash: compute the SHA1 of the data in the flash
		if fOk and (aArgs.fCommandHashSelected or aArgs.fCommandVerifyHashSelected) then
			strFlashHashBin, strMsg = flasher.hashArea(tPlugin, aAttr, ulStartOffset, ulLen)
			if strFlashHashBin then
				fOk = true
				strFlashHash = getHexString(strFlashHashBin)
				print("Flash SHA1: " .. strFlashHash)
			else
				fOk = false
				strMsg = strMsg or "Could not compute the hash sum of the flash contents"
			end
		end
		
		
		-- verify_hash: compute the hash of the input file and compare
		if fOk and aArgs.fCommandVerifyHashSelected then
			local mh = mhash.mhash_state()
			mh:init(mhash.MHASH_SHA1)
			mh:hash(strData)
			strFileHashBin = mh:hash_end()
			strFileHash = getHexString(strFileHashBin)
			print("File SHA1: " .. strFileHash)

			if strFileHashBin == strFlashHashBin then
				print("Checksums are equal!")
				fOk = true
				strMsg = "The data in the flash and the file have the same checksum"
			else
				print("Checksums are not equal!")
				fOk = true
				strMsg = "The data in the flash and the file do not have the same checksum"
			end
		end
	
		-- save output file   strData --> strDataFileName
		if fOk and aArgs.fCommandReadSelected then
			fOk, strMsg = writeBin(strDataFileName, strData)
		end
        -- identify_netx
        if aArgs.fParserCommandIdentifyNetxSelected then
            fOk = flasher.identify(tPlugin, aAttr)
			strMsg = "LED sequence finished"
        end
		
		tPlugin:Disconnect()
		tPlugin = nil
	end
	
	if iMode == MODE_GET_DEVICE_SIZE then
		return ulLen, strMsg, tDevInfo
	else
		return fOk, strMsg, tDevInfo
	end
end



--========================================================================
--                    test interface
--========================================================================

flasher_interface = {}

function flasher_interface.configure(self, strPluginName, iBus, iUnit, iChipSelect)
	self.aArgs = {
		strPluginName = strPluginName,
		iBus = iBus,
		iUnit = iUnit,
		iChipSelect = iChipSelect,
		strDataFileName = "flashertest.bin"
		}
end


function flasher_interface.init(self)
	return true
end


function flasher_interface.finish(self)
end


function flasher_interface.getDeviceSize(self)
	self.aArgs.iMode = MODE_GET_DEVICE_SIZE
	return exec(self.aArgs)
end


-- bus 0: parallel, bus 1: serial
function flasher_interface.getBusWidth(self)
	if self.aArgs.iBus==flasher.BUS_Parflash then
		return 2 -- may be 1, 2 or 4
	elseif self.aArgs.iBus==flasher.BUS_Spi then
		return 1
	elseif self.aArgs.iBus==flasher.BUS_IFlash then
		return 4
	elseif self.aArgs.iBus == flasher.BUS_SDIO then
		return 1
	end
end

function flasher_interface.getEmptyByte(self)
	if self.aArgs.iBus == flasher.BUS_Parflash then
		return 0xff
	elseif self.aArgs.iBus == flasher.BUS_Spi then
		return 0xff
	elseif self.aArgs.iBus == flasher.BUS_IFlash then
		return 0xff
	elseif self.aArgs.iBus == flasher.BUS_SDIO then
		return 0x00
	end
end

function flasher_interface.flash(self, ulOffset, strData)
	local fOk, strMsg = writeBin(self.aArgs.strDataFileName, strData)
	if fOk == false then
		return false, strMsg
	end
    self.aArgs.fCommandFlashSelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = strData:len()
	return exec(self.aArgs)
end


function flasher_interface.verify(self, ulOffset, strData)
	local fOk, strMsg = writeBin(self.aArgs.strDataFileName, strData)
	if fOk == false then
		return false, strMsg
	end
    self.aArgs.fCommandVerifySelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = strData:len()
	return exec(self.aArgs)
end

function flasher_interface.read(self, ulOffset, ulSize)
    self.aArgs.fCommandReadSelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = ulSize
	
	local fOk, strMsg = exec(self.aArgs)

	if not fOk then
		return nil, strMsg
	else
		strData, strMsg = loadBin(self.aArgs.strDataFileName)
	end
	
	return strData, strMsg
end


function flasher_interface.erase(self, ulOffset, ulSize)
    self.aArgs.fCommandEraseSelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = ulSize
	return exec(self.aArgs)
end


function flasher_interface.isErased(self, ulOffset, ulSize)
	self.aArgs.iMode = MODE_IS_ERASED
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = ulSize
	return exec(self.aArgs)
end


function flasher_interface.eraseChip(self)
	return self:erase(0, self:getDeviceSize())
end


function flasher_interface.readChip(self)
	return self:read(0, self:getDeviceSize())
end


function flasher_interface.isChipErased(self)
	return self:isErased(0, self:getDeviceSize())
end

--------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------

FLASHER_PATH = "netx/"

function main()
    local aArgs
    local fOk
    local iRet
    local strMsg

    io.output():setvbuf("no")

    aArgs = tParser:parse()

    -- construct the argument list for DetectInterfaces
    aArgs.atPluginOptions = {
        romloader_jtag = {
            jtag_reset = aArgs.strJtagReset,
            jtag_frequency_khz = aArgs.iJtagKhz
        }
    }

    -- todo: how to set this properly?
    aArgs.strSecureOption = aArgs.strSecureOption or tFlasher.DEFAULT_HBOOT_OPTION
    if aArgs.strSecureOption ~= nil then

        local strnetX90M2MImagePath = path.join(aArgs.strSecureOption, "netx90", "hboot_start_mi_netx90_com_intram.bin")
        printf("Trying to load netX 90 M2M image from %s", strnetX90M2MImagePath)

        local strnetX90M2MImageBin, strMsg = loadBin(strnetX90M2MImagePath)

        if strnetX90M2MImageBin then
            printf("%d bytes loaded.", strnetX90M2MImageBin:len())
            aArgs.atPluginOptions.romloader_uart = {
                netx90_m2m_image = strnetX90M2MImageBin
            }
        else
            printf("Error: Failed to load netX 90 M2M image: %s", strMsg or "unknown error")
            os.exit(1)
        end
    end


    fOk = true

    -- showArgs(aArgs)

    require("muhkuh_cli_init")
    require("mhash")
    require("flasher")
    require("flasher_test")

    if aArgs.fCommandListInterfacesSelected then
        list_interfaces(aArgs.strPluginType, aArgs.atPluginOptions)
        os.exit(0)

    elseif aArgs.fCommandResetSelected then
        fOk, strMsg = reset_netx_via_watchdog(aArgs)
        if fOk then
            if strMsg then
                print(strMsg)
            end
            os.exit(0)
        else
            printf("Error: %s", strMsg or "unknown error")
            os.exit(1)
        end

    elseif aArgs.fCommandDetectNetxSelected then
        iRet, strMsg = detect_chiptype(aArgs)
        if iRet==0 then
            if strMsg then
                print(strMsg)
            end
        else
            printf("Error: %s", strMsg or "unknown error")
        end
        os.exit(iRet)

    elseif aArgs.fCommandDetectSecureBootSelected then
        iRet, strMsg = detect_secure_boot_mode(aArgs)
        print(strMsg)
        os.exit(iRet)

    elseif aArgs.fCommandTestCliSelected then
        flasher_interface:configure(aArgs.strPluginName, aArgs.iBus, aArgs.iUnit, aArgs.iChipSelect)
        fOk, strMsg = flasher_test.testFlasher(flasher_interface)
        if fOk then
            if strMsg then
                print(strMsg)
            end
            print("Test PASSED")
            os.exit(0)
        else
            printf("Error: %s", strMsg or "unknown error")
            print("Test FAILED")
            os.exit(1)
        end

    else
        fOk, strMsg, tDevInfo = exec(aArgs)

        if tDevInfo.strDevName then
            printf("Flash device name: %s", tDevInfo.strDevName)
        end
        if tDevInfo.strDevId then
            printf("Flash device has JEDEC ID: %s", tDevInfo.strDevId)
        end

        if fOk then
            if strMsg then
                print(strMsg)
            end
            os.exit(0)
        else
            print(strMsg or "an unknown error occurred")
            os.exit(1)
        end
    end
end

main()

local M = {}

-----------------------------------------------------------------------------
-- Copyright (C) 2017 Hilscher Gesellschaft für Systemautomation mbH
--
-- Description:
--   flasher_helper.lua: helper function for CLI Flasher
--
-----------------------------------------------------------------------------

local class = require 'pl.class'

-- exit code for detect_netx
local STATUS_OK = 0
local STATUS_ERROR = 1
local STATUS_START_MI_IMAGE_FAILED = 2

-- exit codes for detect_secure_boot_mode
local SECURE_BOOT_DISABLED = 0
local SECURE_BOOT_ENABLED = 5
local SECURE_BOOT_ONLY_APP_ENABLED = 50
local SECURE_BOOT_UNKNOWN = 2
local SECURE_BOOT_ERROR = 1

--------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------

-- Checking is enabled by default.
local fStoreTempFiles = false

-- Disable the checks
function M.disableStoreTempFiles()
    -- print("Disabling automatic helper file checks")
    fStoreTempFiles = false
end

-- Enable the checks
function M.enableStoreTempFiles()
    -- print("Enabling automatic helper file checks")
    fStoreTempFiles = true
end

function M.getStoreTempFiles()
  return fStoreTempFiles
end


-- strData, strMsg loadBin(strFilePath)
-- Load a binary file.
-- returns
--   data if successful
--   nil, message if an error occurred
function M.loadBin(strFilePath)
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
function M.writeBin(strName, bin)
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
function M.getHexString(strBin)
	local strHex = ""
	for i=1, strBin:len() do
		strHex = strHex .. string.format("%02x", strBin:byte(i))
	end
	return strHex
end

-- Convert a binary string to an unsigned integer.
-- str must be 1 to 4 bytes long and in little-endian byte order.
function M.bytes_to_uint32(str)
    local ulValue = 0

    for i= str:len(), 1, -1 do
        ulValue = ulValue * 256 + str:byte(i)
    end

    return ulValue
end


local function printf(...) print(string.format(...)) end

--------------------------------------------------------------------------
-- get plugin
--------------------------------------------------------------------------

local function show_plugin_options(tOpts)
	print("Plugin options:")
	for strPluginId, tPluginOptions in pairs(tOpts) do
		print(string.format("For %s:", strPluginId))
		for strKey, tVal in pairs(tPluginOptions) do
			print(strKey, tVal)
		end
	end
end


-- Show the available interfaces and let the user select one interactively.
--
-- strPattern is not evaluated.
--
-- If strPluginType is a string (a plugin ID as obtained by calling GetID on
-- a plugin provider, e.g. "romloader_uart"), only this plugin provider
-- is scanned.
-- If strPluginType is nil, all plugin providers are scanned.

local function SelectPlugin(_, strPluginType, atPluginOptions)
	local iInterfaceIdx
	local aDetectedInterfaces
	local tPlugin
  local strInterface
  local __MUHKUH_PLUGINS = _G.__MUHKUH_PLUGINS

	show_plugin_options(atPluginOptions)

	repeat do
		-- Detect all interfaces.
		aDetectedInterfaces = {}
		for _,v in ipairs(__MUHKUH_PLUGINS) do
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
		end until (
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

function M.connect_retry(tPlugin, uLRetries)
    local fCallSuccess
    local strError
    print("connect to plugin")

    if tPlugin == nil then
        strError = "No plugin selected for connect"
    end

    -- default retries are 5
    if uLRetries == nil then
        uLRetries = 5
    end

    while uLRetries > 0 do
        fCallSuccess, strError = pcall(function () tPlugin:Connect() end)
        if fCallSuccess then
            print("connect successful")
            break
        end
        print("connect not successful")
        uLRetries = uLRetries - 1
        M.sleep_s(1)
        if uLRetries > 0 then
            print("retry connecting ... ")
        end
    end

    return fCallSuccess, strError
end

-- Try to open a plugin for an interface with the given name.
-- This function assumes that the name starts with the name of the interface,
-- e.g. romloader_uart, and scans only for interfaces whose type is contained
-- in the name string.
local function getPluginByName(strName, strPluginType, atPluginOptions)
	show_plugin_options(atPluginOptions)

	for _, tPluginClass in ipairs(_G.__MUHKUH_PLUGINS) do
		if strPluginType == nil or strPluginType == tPluginClass:GetID() then
			local iDetected
			local aDetectedInterfaces = {}

			local strPluginClassType = tPluginClass:GetID()
			if strName:match(strPluginClassType) then
				print(string.format("Detecting interfaces with plugin %s", tPluginClass:GetID()))
				iDetected = tPluginClass:DetectInterfaces(aDetectedInterfaces, atPluginOptions)
				print(string.format("Found %d interfaces with plugin %s", iDetected, tPluginClass:GetID()))
			end

			for i,v in ipairs(aDetectedInterfaces) do
				print(string.format(
          "%d: %s (%s) Used: %s, Valid: %s",
          i,
          v:GetName(),
          v:GetTyp(),
          tostring(v:IsUsed()),
          tostring(v:IsValid())
        ))
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

function M.getPlugin(strPluginName, strPluginType, atPluginOptions)
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


function M.list_interfaces(strPluginType, atPluginOptions)
	show_plugin_options(atPluginOptions)

	-- detect all interfaces
	local aDetectedInterfaces = {}
	for _, tPluginClass in ipairs(_G.__MUHKUH_PLUGINS) do
		if strPluginType == nil or strPluginType == tPluginClass:GetID() then
			tPluginClass:DetectInterfaces(aDetectedInterfaces, atPluginOptions)
		end
	end
	-- filter used and non valid interfaces
	local aUnusedInterfaces = {}
	for _,v in ipairs(aDetectedInterfaces) do
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


local function netx90_disable_uart_pulldown_resistors(tPlugin)
	local addr_pad_ctrl_uart_rxd    = 0xff401028
	local addr_pad_ctrl_uart_txd    = 0xff40102c
	local addr_asic_ctrl_access_key = 0xff4012c0

	local val_pad_ctrl_uart_rxd = tPlugin:read_data32(addr_pad_ctrl_uart_rxd)
	val_pad_ctrl_uart_rxd = val_pad_ctrl_uart_rxd & 0xef
	local val_asic_ctrl_access_key = tPlugin:read_data32(addr_asic_ctrl_access_key)
	tPlugin:write_data32(addr_asic_ctrl_access_key, val_asic_ctrl_access_key)
	tPlugin:write_data32(addr_pad_ctrl_uart_rxd, val_pad_ctrl_uart_rxd)

	local val_pad_ctrl_uart_txd = tPlugin:read_data32(addr_pad_ctrl_uart_txd)
	val_pad_ctrl_uart_txd = val_pad_ctrl_uart_txd & 0xef
	val_asic_ctrl_access_key = tPlugin:read_data32(addr_asic_ctrl_access_key)
	tPlugin:write_data32(addr_asic_ctrl_access_key, val_asic_ctrl_access_key)
	tPlugin:write_data32(addr_pad_ctrl_uart_txd, val_pad_ctrl_uart_txd)
end

local function netx90_check_uart_padctrl(tPlugin)
	local addr_pad_ctrl_uart_rxd = 0xff401028
	local addr_pad_ctrl_uart_txd = 0xff40102c
	local val_pad_ctrl_uart_rxd = tPlugin:read_data32(addr_pad_ctrl_uart_rxd)
	local val_pad_ctrl_uart_txd = tPlugin:read_data32(addr_pad_ctrl_uart_txd)
	printf("val_pad_ctrl_uart_rxd: 0x%08x", val_pad_ctrl_uart_rxd)
	printf("val_pad_ctrl_uart_txd: 0x%08x", val_pad_ctrl_uart_txd)
end

function M.detect_chiptype(aArgs)
  local romloader = require 'romloader'
	local strPluginName  = aArgs.strPluginName
	local strPluginType  = aArgs.strPluginType
	local atPluginOptions= aArgs.atPluginOptions

	local fConnected
	local iChiptype
	local strChipName

	local iRet = STATUS_OK -- assume success

	local tPlugin, strMsg = M.getPlugin(strPluginName, strPluginType, atPluginOptions)
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
				print("Disabling pull-down resistors for UART RXD and TXD")
				netx90_disable_uart_pulldown_resistors(tPlugin)
				netx90_check_uart_padctrl(tPlugin)

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




-- return tRes OR nil, strErrorMsg
local function readSip_via_jtag(tPlugin, strReadSipHbootImg)
  local tFlasher = require 'flasher'
	local strErrorMsg = ""

	local ulReadSipExeAddress    = 0x00060000 -- Load address for the read_sip executable
	local ulReadSipDataAddress   = 0x00062000 -- Location where read_sip stores the SIP pages.

	-- The magic cookie is set by the read_sip program to indicate its state.
	local ulReadSipMagicAddress  = 0x00065004 -- Location of the read_sip magic cookie
	local MAGIC_COOKIE_INIT      = 0x5541494d -- (MIAU) read_sip has entered pass 1, before resetting
	local MAGIC_COOKIE_END       = 0x464f4f57 -- (WOOF) read_sip has finished pass 2, info pages validated/copied.

	-- read sip result address and bit masks to interpret the result
	local ulReadSipResultAddress = 0x00065000
	local COM_SIP_CPY_VALID_MSK  = 0x00000001
	local COM_SIP_VALID_MSK      = 0x00000002
	local APP_SIP_CPY_VALID_MSK  = 0x00000100
	local APP_SIP_VALID_MSK      = 0x00000200
	local FIRST_RUN_DONE         = 0x00010000 -- read_sip pass 1 done, shortly before reset

	local ulReadSipResult
	local ulMagicResult
	local strComSipData
	local strAppSipData
	local tRes

	-- for debugging
	-- local ulIflash0ProtectionInfo = tPlugin:read_data32(0xff001c48)
	-- local ulIflash1ProtectionInfo = tPlugin:read_data32(0xff001cc8)
	-- local ulIflash2ProtectionInfo = tPlugin:read_data32(0xff401448)
	-- printf("intflash 0 protection info: 0x%08x", ulIflash0ProtectionInfo)
	-- printf("intflash 1 protection info: 0x%08x", ulIflash1ProtectionInfo)
	-- printf("intflash 2 protection info: 0x%08x", ulIflash2ProtectionInfo)

	-- extract the executable portion of the read_sip image from the data chunk
	-- and download it to RAM.
	printf("download the read_sip binary to0x%08x", ulReadSipExeAddress)
	local strReadSipExe = string.sub(strReadSipHbootImg, 0x40D)
	tFlasher.write_image(tPlugin, ulReadSipExeAddress, strReadSipExe)

	-- Set the FIRST_RUN_DONE flag in ReadSipResult.
	-- This prevents read_sip from performing a reset.
	printf("reset the value of the read sip result address 0x%08x", ulReadSipResultAddress)
	tPlugin:write_data32(ulReadSipResultAddress, FIRST_RUN_DONE)

	-- Set the cookie to MAGIC_COOKIE_INIT.
	-- This prevents read_sip from clearing the ReadSipResult.
	tPlugin:write_data32(ulReadSipMagicAddress, MAGIC_COOKIE_INIT)

	--M.sleep_s(2) -- what for?

	print("Start read_sip binary via call")
	tFlasher.call(
			tPlugin,
			ulReadSipExeAddress + 1,
			ulReadSipResultAddress
	)

	ulReadSipResult = tPlugin:read_data32(ulReadSipResultAddress)
	ulMagicResult = tPlugin:read_data32(ulReadSipMagicAddress)
	-- printf("read_sip magic cookie value: 0x%08x", ulMagicResult)
	-- printf("read_sip result: 0x%08x", ulReadSipResult)

	if ulMagicResult ~= MAGIC_COOKIE_END then
		strErrorMsg = "An error has occurred while executing read_sip (MAGIC_COOKIE_END not found)."
	else
		printf("read_sip has finished (found MAGIC_COOKIE_END).")

		-- ignore the CAL page.
		--strCalSipData = tFlasher.read_image(tPlugin, ulReadSipDataAddress, 0x1000)

		local fComSipOk = (ulReadSipResult & COM_SIP_VALID_MSK) ~= 0
		local fComCopyOk = (ulReadSipResult & COM_SIP_CPY_VALID_MSK) ~= 0
		if fComSipOk or fComCopyOk then
			strComSipData = tFlasher.read_image(tPlugin, ulReadSipDataAddress + 0x1000, 0x1000)
		end

		if fComCopyOk then
			print("The COM SIP copy is valid.")
		elseif fComSipOk then
			print("The COM SIP copy is invalid.")
			print("The COM SIP is available and valid.")
		else
			print("The COM SIP copy is invalid.")
			print("The COM SIP is not available.")
		end

		local fAppSipOk = (ulReadSipResult & APP_SIP_VALID_MSK) ~= 0
		local fAppCopyOk = (ulReadSipResult & APP_SIP_CPY_VALID_MSK) ~= 0
		if fAppSipOk or fAppCopyOk then
			strAppSipData = tFlasher.read_image(tPlugin, ulReadSipDataAddress + 0x2000, 0x1000)
		end

		if fAppCopyOk then
			print("The APP SIP Copy is valid.")
		elseif fAppSipOk then
			print("The APP SIP Copy is invalid.")
			print("The APP SIP is available and valid.")
		else
			print("The APP SIP Copy is invalid.")
			print("The APP SIP is not available.")
		end

		tRes = {
			fComSipOk  = fComSipOk,
			fComCopyOk = fComCopyOk,
			fAppSipOk  = fAppSipOk,
			fAppCopyOk = fAppCopyOk,
			--strCalSipData = strCalSipData, -- ignore the CAL page.
			strComSipData = strComSipData,
			strAppSipData = strAppSipData
		}
	end

	return tRes, strErrorMsg
end

function M.detect_secure_boot_mode(aArgs)
  local tFlasher = require 'flasher'
  local romloader = require 'romloader'
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

  local path = require 'pl.path'

	local tPlugin, strMsg = M.getPlugin(strPluginName, strPluginType, atPluginOptions)
	if tPlugin == nil then
		strMsg = strMsg or "Could not connect to device."

	elseif tPlugin:GetTyp() == "romloader_uart" then
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

					local strImagePath = path.join(tFlasher.HELPER_FILES_PATH, "netx90", "hboot_netx90_exec_bxlr.bin")
					printf("Trying to load netX 90 exec_bxlr image from %s", strImagePath)

					strImageBin, strMsg = M.loadBin(strImagePath)

					if strImageBin == nil then
						printf("Error: Failed to load netX 90 exec_bxlr image: %s", strMsg or "unknown error")
					else
						printf("%d bytes loaded.", strImageBin:len())
						tFlasher.write_image(tPlugin, 0x200c0, strImageBin)
						tPlugin:write_data32(0x22000, 0xffffffff)
						local ulVal = tPlugin:read_data32(0x22000)
						printf("Value at 0x22000 before running boot image: 0x%08x", ulVal)
						local tRet = tFlasher.call_hboot(tPlugin)
						print("return value from call_hboot:" , tRet)
						ulVal = tPlugin:read_data32(0x22000)
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

	elseif tPlugin:GetTyp() == "romloader_jtag" then
		local strReadSipPath = path.join(
      "netx",
      "hboot",
      "unsigned",
      "netx90",
      "read_sip_M2M.bin"
    )  --tFlasher.HELPER_FILES_PATH,
		printf("Trying to load netX 90 read_sip_M2M image from %s", strReadSipPath)
    local strReadSipBin
		strReadSipBin, strMsg = M.loadBin(strReadSipPath)
		if strReadSipBin == nil then
			print(strMsg)
		else
			fConnected, strMsg = pcall(tPlugin.Connect, tPlugin)
			print("Connect() result: ", fConnected, strMsg)

			if not fConnected then
				print("Failed to connect.")
			else
				iChiptype = tPlugin:GetChiptyp()
				strChipName = tPlugin:GetChiptypName(iChiptype)

				if iChiptype == nil or iChiptype == romloader.ROMLOADER_CHIPTYP_UNKNOWN then
					print("Could not detect chip type")
					strMsg = "Failed to get chip type"

				elseif iChiptype~=romloader.ROMLOADER_CHIPTYP_NETX90B
				and iChiptype~=romloader.ROMLOADER_CHIPTYP_NETX90C
				and iChiptype~=romloader.ROMLOADER_CHIPTYP_NETX90D then
					strMsg = "detect_secure_boot_mode supports only netX 90 Rev.1 and 2"

				else
					printf("Chip type: %s (%d) (may be suspicious, PHY version not verified)", strChipName, iChiptype)

					-- Make sure that the SIP copies in RAM are updated, if they are enabled at all.
					-- We do this by clearing the hashes of the SIP copies and then triggering a reset
					-- by closing and re-opening the JTAG connection.
					-- The reset mechanism built into read_sip is NOT used, because that would require
					-- read_sip to be signed if secure boot is on.

					local COM_SIP_COPY_ADDR = 0x200a7000 -- address of the copied com secure info page
					local APP_SIP_COPY_ADDR = 0x200a6000 -- address of the copied app secure info page
					local OFF_COM_SIP_HASH = 0x0fd0
					local OFF_APP_SIP_HASH = 0x0fd0
					local SIZ_COM_SIP_HASH = 0x30
					local SIZ_APP_SIP_HASH = 0x30

					local strZero = string.rep(string.char(0x55), SIZ_COM_SIP_HASH)
					tFlasher.write_image(tPlugin, COM_SIP_COPY_ADDR+OFF_COM_SIP_HASH, strZero)
					local strReadback = tFlasher.read_image(tPlugin, COM_SIP_COPY_ADDR+OFF_COM_SIP_HASH, SIZ_COM_SIP_HASH)
					if strReadback ~= strZero then
						printf("Failed to clear COM SIP hash")
					else
						strZero = string.rep(string.char(0x55), SIZ_APP_SIP_HASH)
						tFlasher.write_image(tPlugin, APP_SIP_COPY_ADDR+OFF_APP_SIP_HASH, strZero)
						strReadback = tFlasher.read_image(tPlugin, APP_SIP_COPY_ADDR+OFF_APP_SIP_HASH, SIZ_APP_SIP_HASH)
						if strReadback ~= strZero then
							printf("Failed to clear APP SIP hash")
						else
							tPlugin:Disconnect()
							strPluginName = tPlugin:GetName()
							strPluginType = tPlugin:GetTyp()
							if atPluginOptions.romloader_jtag.jtag_reset == "Attach" then
								atPluginOptions.romloader_jtag.jtag_reset = "SoftReset"
							end

							tPlugin, strMsg = M.getPlugin(strPluginName, strPluginType, atPluginOptions)
							if tPlugin == nil then
								strMsg = strMsg or "Could not re-open the JTAG interface."
							else
								fConnected, strMsg = pcall(tPlugin.Connect, tPlugin)
								print("Connect() result: ", fConnected, strMsg)

								if not fConnected then
									print("Failed to reconnect.")
								else
									-- read the SIP pages
                  local tRes
									tRes, strMsg = readSip_via_jtag(tPlugin, strReadSipBin)

									if tRes == nil then
										print(strMsg)
									else
										-- Get the secure boot flags from the info pages.
										local OFF_COM_SIP_PROTECTION_FLAGS = 556+1
										local MSK_COM_SIP_PROTECTION_FLAGS_SECURE_BOOT = 4
										local OFF_APP_SIP_PROTECTION_FLAGS = 552+1
										local MSK_APP_SIP_PROTECTION_FLAGS_SECURE_BOOT = 4

										local fSecureBootCOM = nil
										local fSecureBootAPP = nil

										if tRes.strComSipData ~= nil then
											local bSecureBootCOM = tRes.strComSipData:byte(OFF_COM_SIP_PROTECTION_FLAGS)
											-- printf("COM secure boot options bit 0-7: 0x%02x", bSecureBootCOM)
											fSecureBootCOM = (
                        (bSecureBootCOM & MSK_COM_SIP_PROTECTION_FLAGS_SECURE_BOOT) ==
                        MSK_COM_SIP_PROTECTION_FLAGS_SECURE_BOOT
                      )
										end

										if tRes.strAppSipData ~= nil then
											local bSecureBootAPP = tRes.strAppSipData:byte(OFF_APP_SIP_PROTECTION_FLAGS)
											-- printf("APP secure boot options bit 0-7: 0x%02x", bSecureBootAPP)
											fSecureBootAPP = (
                        (bSecureBootAPP & MSK_APP_SIP_PROTECTION_FLAGS_SECURE_BOOT) ==
                        MSK_APP_SIP_PROTECTION_FLAGS_SECURE_BOOT
                      )
										end

										-- Derive the secure boot status.
										if fSecureBootCOM == false and fSecureBootAPP == false then
											iSecureBootStatus = SECURE_BOOT_DISABLED
										elseif fSecureBootCOM == true then
											iSecureBootStatus = SECURE_BOOT_ENABLED
										elseif fSecureBootCOM == false and fSecureBootAPP == true then
											iSecureBootStatus = SECURE_BOOT_ONLY_APP_ENABLED
										else
											iSecureBootStatus = SECURE_BOOT_UNKNOWN
										end
									end -- tRes == nil
								end -- fConnected the 2nd time
							end -- getPlugin
						end -- clear APP SIP hash
					end -- clear COM SIP Hash
				end -- chip typ e netx 90
			end -- connected the 1st time
		end -- readSipM2M image

	else
		strMsg = "Only romloader_uart and romloader_jtag are supported."
	end -- if tPlugin

	if iSecureBootStatus==SECURE_BOOT_DISABLED then
		strMsg = "Secure boot mode disabled. COM and APP CPU are in open mode."
	elseif iSecureBootStatus==SECURE_BOOT_ENABLED then
		strMsg = "Secure boot mode enabled. COM CPU is in secure boot mode, APP CPU is unknown."
	elseif iSecureBootStatus==SECURE_BOOT_ONLY_APP_ENABLED then
		strMsg = "Secure boot mode enabled. COM CPU is in open mode, APP CPU is in secure boot mode."
	elseif iSecureBootStatus==SECURE_BOOT_UNKNOWN then
		strMsg = "Cannot detect secure boot mode. "
		if tPlugin:GetTyp() == "romloader_uart" then
			strMsg = strMsg .. "If the netX was just reset, COM and APP are in open mode."
		end
	else
		strMsg = "Cannot detect secure boot mode: " .. (strMsg or "unknown error")
	end

	tPlugin:Disconnect()

	return iSecureBootStatus, strMsg

end



-- Sleep for a number of seconds
-- (between seconds and seconds+1)
function M.sleep_s(seconds)
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

function M.reset_netx_via_watchdog(aArgs, tPlugin)
  local romloader = require 'romloader'
	local fOk
	local strMsg

    if tPlugin == nil then
        local strPluginName  = aArgs.strPluginName
        local strPluginType  = aArgs.strPluginType
        local atPluginOptions= aArgs.atPluginOptions
        -- open the plugin
        tPlugin, strMsg = M.getPlugin(strPluginName, strPluginType, atPluginOptions)
    end

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
				--ulVal = ulVal & 1
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
			collectgarbage('collect')

			-- Wait 1 second (actually between 1 and 2 seconds)
			if (fOk == true) then
				M.sleep_s(1)
			end
		end
	end

	return fOk, strMsg
end

function M.switch_endian(ulValue)
    local ulNewValue = 0
    local mskedVal
    local shiftedVal

    mskedVal = ulValue & 0x000000ff
    shiftedVal = mskedVal << 24
    ulNewValue = ulNewValue | shiftedVal

	mskedVal = ulValue & 0x0000ff00
    shiftedVal = mskedVal << 8
    ulNewValue = ulNewValue | shiftedVal

	mskedVal = ulValue & 0x00ff0000
    shiftedVal = mskedVal >> 8
    ulNewValue = ulNewValue | shiftedVal

	mskedVal = ulValue & 0xff000000
    shiftedVal = mskedVal >> 24
    ulNewValue = ulNewValue | shiftedVal

    return ulNewValue
end

function M.dump_intram(tPlugin, ulAddress, ulSize, strOutputFolder, strOutputFileName)
  local path = require 'pl.path'
  local tFlasher = require 'flasher'
	local strOutputFilePath = path.join(strOutputFolder, strOutputFileName)

	local strTraceDumpData = tPlugin:read_image(ulAddress, ulSize, tFlasher.default_callback_progress, ulSize)

  M.writeBin(strOutputFilePath, strTraceDumpData)
end

function M.dump_trace(tPlugin, strOutputFolder, strOutputFileName)
	local ulTraceAddress = 0x200a0000
	local ulDumpSize = 0x8000
	M.dump_intram(tPlugin, ulTraceAddress, ulDumpSize, strOutputFolder, strOutputFileName)
end


-- helper class 'StringHandle' takes a string and mimics a file handle and some of it's functions
-- !! this class does not provide every functionality of a file handle !!

local StringHandle = class()

function StringHandle:_init(strData)
    self.strData = strData
    self.ulCurrentPointer = 1
    self.ulSize = string.len(strData)
end

function StringHandle:read(ulReadBytes)
	local strReadData
    local ulReadLength = ulReadBytes
	strReadData = string.sub(self.strData,self.ulCurrentPointer,(self.ulCurrentPointer + ulReadLength - 1))
	self.ulCurrentPointer = self.ulCurrentPointer + ulReadLength
    return strReadData
end

function StringHandle:__getStringPosInBytes()
    return (self.ulCurrentPointer - 1)
end

function StringHandle:seek(strWhence, ulOffset)

    local ulNewOffset

    if ulOffset == nil then
        ulOffset = 0
    end

    ulNewOffset = ulOffset -- * 4

    if strWhence == "set" then
        self.ulCurrentPointer = 1 + ulNewOffset
    elseif strWhence == "cur" then
        self.ulCurrentPointer = self.ulCurrentPointer + ulNewOffset
    elseif strWhence == "end" then
        self.ulCurrentPointer = self.ulSize + ulNewOffset
    end

    return self:__getStringPosInBytes()
end

function StringHandle.close()
    -- dummy function that does nothing
end

M.StringHandle = StringHandle

return M

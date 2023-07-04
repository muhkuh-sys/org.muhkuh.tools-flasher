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

local tFlasher = require 'flasher'
local tFlasherHelper = require 'flasher_helper'
local tHelperFiles = require 'helper_files'
local tVerifySignature = require 'verify_signature'

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



function printf(...) print(string.format(...)) end

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

aJtagResetOptions = {}
aJtagResetOptions["hard"] = "HardReset"
aJtagResetOptions["soft"] = "SoftReset"
aJtagResetOptions["attach"] = "Attach"

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
            tParserCommand:option('--sec'):description("Path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
    )
    tParserCommand:flag('--disable_helper_signature_check'):description('Disable signature checks on helper files.'):target('fDisableHelperSignatureChecks'):default(false)
    
end

function addJtagKhzArg(tParserCommand)
    tParserCommand:option('--jtag_khz', 'JTAG clock in kHz'):target('iJtagKhz'):convert(tonumber)
end

function addJtagResetArg(tParserCommand)
    tOption = tParserCommand:option('--jtag_reset',
            'JTAG reset method. Possible values are: hard (default), soft, attach'):target('strJtagReset')
    tOption.choices = {"hard", "soft", "attach" }
end

local argparse = require 'argparse'

local strEpilog = [==[
Limitations:

The reset_netx command currently supports only the netx 90.

The hash and verify_hash commands do not support the netIOL.

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

-- Add a hidden flag to disable the version checks on helper files.
tParser:flag "--disable_helper_version_check":hidden(true)
    :description "Disable version checks on helper files."
    :action(function()
        tHelperFiles.disableHelperFileChecks()
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
addSecureArgs(tParserCommandVerifyHash)

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
addSecureArgs(tParserCommandHash)

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
local tParserCommandDetectSecureBoot = tParser:command('detect_secure_boot_mode dsbm', 'Detect if secure boot is enabled (netX 90 only)'):target('fCommandDetectSecureBootSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandDetectSecureBoot)
addPluginTypeArg(tParserCommandDetectSecureBoot)
addJtagResetArg(tParserCommandDetectSecureBoot)
addJtagKhzArg(tParserCommandDetectSecureBoot)


-- reset_netx
local tParserCommandResetNetx = tParser:command('reset_netx rn', 'Reset the netX'):target('fCommandResetSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandResetNetx)
addPluginTypeArg(tParserCommandResetNetx)
addJtagResetArg(tParserCommandResetNetx)
addJtagKhzArg(tParserCommandResetNetx)
addSecureArgs(tParserCommandResetNetx)

-- identify_netx
local tParserCommandIdentifyNetx = tParser:command('identify_netx in', 'Blink SYS LED for 5 sec'):target('fParserCommandIdentifyNetxSelected')
-- optional_args = {"p", "t", "jf", "jr"}
addPluginNameArg(tParserCommandIdentifyNetx)
addPluginTypeArg(tParserCommandIdentifyNetx)
addJtagResetArg(tParserCommandIdentifyNetx)
addJtagKhzArg(tParserCommandIdentifyNetx)
addSecureArgs(tParserCommandIdentifyNetx)

-- check_helper_version
local tParserCommandCheckHelperVersion = tParser:command('check_helper_version chv', 'Check that the helper files have the correct versions'):target('fCommandCheckHelperVersionSelected')
addSecureArgs(tParserCommandCheckHelperVersion)

-- check_helper_signature 
local tParserCommandCheckHelperSignature = tParser:command('check_helper_signature chs', strUsipHelp):target('fCommandCheckHelperSignatureSelected')
-- tParserCommandCheckHelperSignature:option(
--     '-V --verbose'
-- ):description(
--     string.format(
--         'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
--     )
-- ):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandCheckHelperSignature:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandCheckHelperSignature:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserCommandCheckHelperSignature:option('--sec'):description("Path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)


-- printArgs(tArguments)
-- Print all arguments in a table
-- returns
--   nothing
function printArgs(tArguments)
    print("")
    print("Running CLI flasher with the following args:")
    print("--------------------------------------------")
    printTable(tArguments, 0)
    print("")
end


-- printTable(tTable, ulIndent)
-- Print all elements from a table
-- returns
--   nothing
function printTable(tTable, ulIndent)
    local strIndentSpace = string.rep(" ", ulIndent)
    for key, value in pairs(tTable) do
        if type(value) == "table" then
            printf( "%s%s",strIndentSpace, key )
            printTable(value, ulIndent + 4)
        else
            printf( "%s%s%s%s",strIndentSpace, key, " = ", tostring(value) )
        end
    end
    if next(tTable) == nil then
        printf( "%s%s",strIndentSpace, " -- empty --" )
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
	tPlugin, strMsg = tFlasherHelper.getPlugin(strPluginName, strPluginType, atPluginOptions)
	if tPlugin then
		fOk, strMsg = tFlasherHelper.connect_retry(tPlugin, 5)
		if not fOk then 
			strMsg = strMsg or "Failed to open connection"
		end
		print("Connect() result: ", fOk, strMsg)
		
		if fOk then 
			-- check helper signatures
			fOk, strMsg = verify_signature.verifyHelperSignatures_wrap(tPlugin, aArgs.strSecureOption, aArgs.aHelperKeysForSigCheck)
		end

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
			strData, strMsg = tFlasherHelper.loadBin(strDataFileName)
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
				fOk, strMsg, ulDeviceSize = flasher.detectAndCheckSizeLimit(tPlugin, aAttr, iBus, iUnit, iChipSelect)
				if fOk ~= true then
					fOk = false
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
				
					-- if offset/len are set, we require that offset+len is less than or equal the device size
					if ulStartOffset~= nil and ulLen~= nil and ulStartOffset+ulLen > ulDeviceSize and ulLen ~= 0xffffffff then
						fOk = false
						strMsg = string.format("Offset+size exceeds flash device size: 0x%08x bytes", ulDeviceSize)
					else
						fOk = true
						strMsg = string.format("Flash device size: %u/0x%08x bytes", ulDeviceSize, ulDeviceSize)
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
			flasher_test.flasher_interface:configure(tPlugin, FLASHER_PATH, iBus, iUnit, iChipSelect, bCompMode, strSecureOption)
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
				strFlashHash = tFlasherHelper.getHexString(strFlashHashBin)
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
			strFileHash = tFlasherHelper.getHexString(strFileHashBin)
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
			fOk, strMsg = tFlasherHelper.writeBin(strDataFileName, strData)
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

function flasher_interface.configure(self, strPluginName, iBus, iUnit, iChipSelect, atPluginOptions)
	self.aArgs = {
		strPluginName = strPluginName,
		iBus = iBus,
		iUnit = iUnit,
		iChipSelect = iChipSelect,
		strDataFileName = "flashertest.bin",

		atPluginOptions = atPluginOptions
		}
end

-- Since we're using a static argument list and iMode has been largely 
-- replaced with individual flags for each operation, we need to clear 
-- these flags after use or before re-using the argument list.
-- Note: This function must be updated when the argument list changes
function flasher_interface.clearArgs(aArgs)
	aArgs.iMode = nil
	aArgs.fCommandFlashSelected = nil
	aArgs.fCommandVerifySelected = nil
	aArgs.fCommandReadSelected = nil
	aArgs.fCommandEraseSelected = nil
	aArgs.ulStartOffset = nil
	aArgs.ulLen = nil
end

function flasher_interface.init(self)
	return true
end


function flasher_interface.finish(self)
end


function flasher_interface.getDeviceSize(self)
	flasher_interface.clearArgs(self.aArgs)
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

	local fOk, strMsg = tFlasherHelper.writeBin(self.aArgs.strDataFileName, strData)

	if fOk == false then
		return false, strMsg
	end
    self.aArgs.fCommandFlashSelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = strData:len()
	return exec(self.aArgs)
end


function flasher_interface.verify(self, ulOffset, strData)

	local fOk, strMsg = tFlasherHelper.writeBin(self.aArgs.strDataFileName, strData)

	if fOk == false then
		return false, strMsg
	end
    self.aArgs.fCommandVerifySelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = strData:len()
	return exec(self.aArgs)
end

function flasher_interface.read(self, ulOffset, ulSize)
	flasher_interface.clearArgs(self.aArgs)
	self.aArgs.fCommandReadSelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = ulSize

	local fOk, strMsg = exec(self.aArgs)

	if not fOk then
		return nil, strMsg
	else
		strData, strMsg = tFlasherHelper.loadBin(self.aArgs.strDataFileName)
	end

	return strData, strMsg
end


function flasher_interface.erase(self, ulOffset, ulSize)
	flasher_interface.clearArgs(self.aArgs)
	self.aArgs.fCommandEraseSelected = true
	self.aArgs.ulStartOffset = ulOffset
	self.aArgs.ulLen = ulSize
	return exec(self.aArgs)
end


function flasher_interface.isErased(self, ulOffset, ulSize)
	flasher_interface.clearArgs(self.aArgs)
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
            jtag_reset = aJtagResetOptions[aArgs.strJtagReset],
            jtag_frequency_khz = aArgs.iJtagKhz
        }
    }

    -- todo: how to set this properly?
    aArgs.strSecureOption = aArgs.strSecureOption or tFlasher.DEFAULT_HBOOT_OPTION
    if aArgs.strSecureOption ~= nil and aArgs.fCommandCheckHelperVersionSelected ~= true then

        local strnetX90HelperPath = path.join(aArgs.strSecureOption, "netx90")

--        Test code - todo: remove
--        print()
--        print("checkHelperFiles")
--        tHelperFiles.checkHelperFiles({strnetX90HelperPath_Default, strnetX90HelperPath}, {"start_mi", "bootswitch"})
--
--        print()
--        print("getHelperFile without checking (false)")
--        local strnetX90M2MImageBin, strMsg = tHelperFiles.getHelperFile(strnetX90HelperPath, "start_mi", false)
--
--        print()
--        print("getHelperFile with checking (true) (if globally enabled)")
--        strnetX90M2MImageBin, strMsg = tHelperFiles.getHelperFile(strnetX90HelperPath, "start_mi", true)

        print()
        -- print("getHelperFile with checking (nil) (default)")
        strnetX90M2MImageBin, strMsg = tHelperFiles.getHelperFile(strnetX90HelperPath, "start_mi")

        if strnetX90M2MImageBin then
            aArgs.atPluginOptions.romloader_uart = {
                netx90_m2m_image = strnetX90M2MImageBin
            }
        else
            printf(strMsg or "Error: Failed to load netX 90 M2M image (unknown error)")
            --printf("Error: Failed to load netX 90 M2M image: %s", strMsg or "unknown error")
            os.exit(1)
        end
    end

    if aArgs.strSecureOption ~= nil 
    and aArgs.strSecureOption ~= tFlasher.DEFAULT_HBOOT_OPTION 
    and aArgs.fDisableHelperSignatureChecks ~= true then

        if aArgs.fCommandFlashSelected               -- flash         
        or aArgs.fCommandReadSelected                -- read          
        or aArgs.fCommandEraseSelected               -- erase         
        or aArgs.fCommandVerifySelected              -- verify        
        or aArgs.fCommandVerifyHashSelected          -- verify_hash   
        or aArgs.fCommandHashSelected                -- hash          
        or aArgs.fCommandDetectSelected              -- detect        
        or aArgs.fCommandTestSelected                -- test          
        or aArgs.fCommandTestCliSelected             -- testcli       
        or aArgs.fCommandInfoSelected                -- info          
        or aArgs.fParserCommandIdentifyNetxSelected  -- identify_netx 
        then
            aArgs.aHelperKeysForSigCheck = {"start_mi", "flasher_netx90_hboot"}
            
        elseif aArgs.fCommandDetectNetxSelected          -- detect_netx 
            or aArgs.fCommandDetectSecureBootSelected    -- detect_secure_boot_mode 
            or aArgs.fCommandResetSelected               -- reset_netx 
        then
            aArgs.aHelperKeysForSigCheck = {"start_mi"}
        end
    end


    printArgs(aArgs)
    local strHelperFileStatus = tHelperFiles.getStatusString()
    print(strHelperFileStatus)
    print()
    

    fOk = true

    require("muhkuh_cli_init")
    require("mhash")
    require("flasher")
    require("flasher_test")
    
    if aArgs.fCommandListInterfacesSelected then
        tFlasherHelper.list_interfaces(aArgs.strPluginType, aArgs.atPluginOptions)
        os.exit(0)

    elseif aArgs.fCommandResetSelected then

        tPlugin, strMsg = tFlasherHelper.getPlugin(aArgs.strPluginName, aArgs.strPluginType, aArgs.atPluginOptions)
        local strPluginType = tPlugin:GetTyp()
        local ulM2MMajor = tPlugin:get_mi_version_maj()
        local ulM2MMinor = tPlugin:get_mi_version_min()
        if ulM2MMajor == 3 and ulM2MMinor >= 1 and strPluginType ~= "romloader_jtag" then
            print("use call usip command to reset netx")
            tFlasher.write_data32(0x200C0, 0x0)  -- delete possible cookie in data area to avoid booting the same image again
            tFlasher.call_usip(tPlugin) -- use call usip command as workaround to trigger reset
        else
            print("reset netx via watchdog")
            tFlasherHelper.reset_netx_via_watchdog(nil, tPlugin)
        end

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
        iRet, strMsg = tFlasherHelper.detect_chiptype(aArgs)
        if iRet==0 then
            if strMsg then
                print(strMsg)
            end
        else
            printf("Error: %s", strMsg or "unknown error")
        end
        os.exit(iRet)

    elseif aArgs.fCommandDetectSecureBootSelected then
        iRet, strMsg = tFlasherHelper.detect_secure_boot_mode(aArgs)
        print(strMsg)
        os.exit(iRet)

    elseif aArgs.fCommandCheckHelperVersionSelected then
        local t1 = os.time()
        
        local strnetX90UnsignedHelperPath = path.join(tFlasher.DEFAULT_HBOOT_OPTION, "netx90")
        local strnetX90HelperPath = path.join(aArgs.strSecureOption, "netx90")
        fOk = tHelperFiles.checkAllHelperFiles({strnetX90UnsignedHelperPath, strnetX90HelperPath})
        local t2 = os.time()
        local dt = os.difftime(t2, t1)
        printf("Time: %d seconds", dt)
        os.exit(fOk and 0 or 1)
        
    elseif aArgs.fCommandCheckHelperSignatureSelected then 
        fOk = tVerifySignature.verifyHelperSignatures(
            aArgs.strPluginName, aArgs.strPluginType, aArgs.atPluginOptions, aArgs.strSecureOption)
        -- verifyHelperSignatures has printed a success/failure message
        os.exit(fOk and 0 or 1)
            
    elseif aArgs.fCommandTestCliSelected then
        flasher_interface:configure(aArgs.strPluginName, aArgs.iBus, aArgs.iUnit, aArgs.iChipSelect, aArgs.atPluginOptions)
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

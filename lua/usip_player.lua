-----------------------------------------------------------------------------
-- Copyright (C) 2021 Hilscher Gesellschaft fuer Systemautomation mbH
--
-- Description:
--   usip_player.lua: command line usip loader tool
--
-----------------------------------------------------------------------------

-- requirements
local archive = require 'archive'
local argparse = require 'argparse'
local mhash = require 'mhash'
local usipPlayerConf = require 'usip_player_conf'
local tFlasher = require 'flasher'
local tempFolderConfPath = usipPlayerConf.tempFolderConfPath
local usip_generator = require 'usip_generator'
local sipper = require 'sipper'
local tFlasherHelper = require 'flasher_helper'

-- uncomment for debugging with LuaPanda
-- require("LuaPanda").start("127.0.0.1",8818)

-- global variables
-- all supported log levels
local atLogLevels = {
    'debug',
    'info',
    'warning',
    'error',
    'fatal'
}

local separator = package.config:sub(1,1)
local fIsRev2

--------------------------------------------------------------------------
-- ArgParser
--------------------------------------------------------------------------

strUsipPlayerGeneralHelp = [[
    The USIP-Player is a Flasher extension to modify, read-out and verify the Secure-Info-Pages on a netX90.

    The secure info pages (SIPs) are a part of the secure boot functionality of the netX90 and are not supposed
    to modify directly as a security feature. There is a SIP for the COM and a SIP for the APP side of the netX90.

    To actually modify the secure info pages a update-secure-info-page (USIP) file is necessary. These USIP files
    can be generated with the newest netX-Studio version.

    Folder structure inside flasher:
    |- flasher_cli-1.6.3                     -- main folder
    |- .tmp                                  -- temporary folder created by the usip_player to save temp files
    |- doc
    |- ext                                   -- folder for external tools
       |- SIPper                             -- tool to interact with the secure info pages and everything around that
       |- USIP_Generator_CLI                 -- tool to generate and analyze usip files
    |- lua                                   -- more lua files
    |- lua_pugins                            -- lua plugins
    |- netx
       |- hboot                             -- hboot images, necessary for for the flasher
          |- unsigned                       -- unsigned hboot images
             |- netx90                      -- netx specific folder
          |- signed                         -- signed images
    |- lua5.1(.exe)                         -- lua executable
    |- usip_player.lua                      -- usip_player lua file

    The .tmp folder is generated and used in the processes of the usip_player.

    To use the usip_player in secure mode some hboot images have to be signed,
    that the netX can execute them correctly.
    The following images are located into the unsigned folder that have to be
    signed to use the usip_player in secure mode:
    - read_sip.bin
    - verify_sig.bin
    - bootswitch.bin
]]
local tParser = argparse('usip_player', strUsipPlayerGeneralHelp):command_target("strSubcommand")

-- Add the "usip" command and all its options.
strBootswitchHelp = [[
    Control the bootprocess after the execution of the sip update.

    Options:
     - 'UART' (Open uart-console-mode)
     - 'ETH' (Open ethernet-console-mode)
     - 'MFW' (Start MFW)
     - 'JTAG' (Use an execute-chunk to activate JTAG)
]]

strResetHelp = [[
    Force a reset after the last usip is send to activate the updated SIP.

    Options:
    - 'unsigned'
    - '<security-folder-search-path + security-folder-name>'
]]


strUsipHelp = [[
    Loads an usip file on the netX, reset the netX and process
    the usip file to update the SecureInfoPage and continue standard boot process.
]]
local tParserCommandUsip = tParser:command('u usip', strUsipHelp):target('fCommandUsipSelected')
tParserCommandUsip:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
tParserCommandUsip:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandUsip:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandUsip:option('-t'):description("plugin type"):target("strPluginType")
tParserCommandUsip:flag('--verify_sig'):description(
    "Verify the signature of an usip image against a netX, if the signature does not match, cancel the process!"
):target('fVerifySigEnable')
tParserCommandUsip:flag('--no_verify'):description(
    "Do not verify the content of an usip image against a netX."
):target('fVerifyContentDisabled')
-- tParserCommandUsip:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserCommandUsip:flag('--extend_exec'):description(
--     "Extends the usip file with an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserCommandUsip:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserCommandUsip:option('--reset'):description(strResetHelp):target('strForceReset'):default(tFlasher.DEFAULT_HBOOT_OPTION)

tParserCommandUsip:option('--sec'):description("path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)


-- Add the "set_sip_protection" command and all its options.
strSetSipProtectionHelp = [[
    Set the SipProtectionCookie, enable protection of SIPs.

    The default COM SIP page for netX 90 rev2 is written.

    That means all of the following parameter will be overwritten:
    - remove secure boot mode
    - remove all keys
    - remove protection level => set to protection level 0 := open mode
    - Enable all ROOT ROMkeys
    - remove protection option flags
        - SIPs will not be copied
        - SIPs will be visiable
]]
local tParserCommandSip = tParser:command('set_sip_protection', strSetSipProtectionHelp):target('fCommandSipSelected')
tParserCommandSip:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandSip:option('-t'):description("plugin type"):target("strPluginType")
tParserCommandSip:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
-- Add the "set_kek" command and all its options.
strSetKekHelp = [[
    Set the KEK (Key exchange key).
    If the input parameter is set an usip file is afterwards loaded on the netX,
    reset the netX and process \n the usip file to update the SecureInfoPage and
    continue standard boot process.
]]
local tParserCommandKek = tParser:command('set_kek', strSetKekHelp):target('fCommandKekSelected')
tParserCommandKek:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
tParserCommandKek:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandKek:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandKek:option('-t'):description("plugin type"):target("strPluginType")
tParserCommandKek:flag('--verify_sig'):description(
    "Verify the signature of an usip image against a netX, if the signature does not match, cancel the process!"
):target('fVerifySigEnable')
tParserCommandKek:flag('--no_verify'):description(
    "Do not verify the content of an usip image against a netX."
):target('fVerifyContentDisabled')
-- tParserCommandKek:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserCommandKek:flag('--extend_exec'):description(
--     "Extends the usip file with an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserCommandKek:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserCommandKek:option('--reset'):description(strResetHelp):target('strForceReset'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserCommandKek:option('--sec'):description("path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
-- Add the "verify_content" command and all its options.
strVerifyHelp = [[
    Verify the content of a usip file against the content of a secure info page
]]
local tParserVerifyContent = tParser:command('verify', strVerifyHelp):target('fCommandVerifySelected')
tParserVerifyContent:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserVerifyContent:option('-t'):description("plugin type"):target("strPluginType")
tParserVerifyContent:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserVerifyContent:option('-i --input'):description("USIP binary file path"):target('strUsipFilePath')
-- tParserVerifyContent:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserVerifyContent:flag('--extend_exec'):description(
--     "Use an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserVerifyContent:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserVerifyContent:option('--sec'):description("path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)

-- Add the "read_sip" command and all its options.
strReadHelp = [[
    Read out the sip content and save it into a temporary folder
]]
local tParserReadSip = tParser:command('read', strReadHelp):target('fCommandReadSelected')
tParserReadSip:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserReadSip:option('-o --output'):description(
    "Set the output directory. Default is specified in the config file of the usip-player."
):target("strOutputFolder"):default(tempFolderConfPath)
tParserReadSip:option('-t'):description("plugin type"):target("strPluginType")
tParserReadSip:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
-- tParserReadSip:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserReadSip:flag('--extend_exec'):description(
--     "Use an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserReadSip:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserReadSip:option('--sec'):description("path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)

-- Add the "detect_secure_mode" command and all its options.
strDetectSecureModeHelp = [[
Detect the secure boot mode of the netX. The secure boot mode descrips
if the booting process is in secure mode. Each side (COM/APP) can be
indivudally in secure boot mode. If secure boot mode is enabled the
firmware or any used helper hboot-image have to be signed.
Options:
- SECURE_BOOT_ENABLED            COM and APP is in secure boot mode.
- SECURE_BOOT_ENABLED            COM is in secure boot mode, APP is unknown.
- SECURE_BOOT_ONLY_APP_ENABLED   Only APP is in secure boot mode.
- SECURE_BOOT_DISABLED           COM and APP is not in secure boot mode.
NOTE: The secure boot mode does not identify which security level is set.
      That means the detect_secure_mode call is not an indicator to
      decide if an USIP file have to be signed.
]]
local tParserDetectSecure = tParser:command(
    'detect_secure_mode', strDetectSecureModeHelp
):target('fCommandDetectSelected')
tParserDetectSecure:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserDetectSecure:option('-t'):description("plugin type"):target("strPluginType")
tParserDetectSecure:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
-- tParserDetectSecure:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserDetectSecure:flag('--extend_exec'):description(
--     "Use an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserDetectSecure:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
-- Add the "get_uid" command and all its options.
local tParserGetUid = tParser:command('get_uid', 'Get the unique ID.'):target('fCommandGetUidSelected')
tParserGetUid:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserGetUid:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserGetUid:option('-t'):description("plugin type"):target("strPluginType")
-- tParserGetUid:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- parse args
local tArgs = tParser:parse()

-- convert the parameter strBootswitchParams to all upper case
if tArgs.strBootswitchParams ~= nil then
    tArgs.strBootswitchParams = string.upper(tArgs.strBootswitchParams)
end

--------------------------------------------------------------------------
-- Logger
--------------------------------------------------------------------------

local tLogWriterConsole = require 'log.writer.console'.new()
local tLogWriterFilter = require 'log.writer.filter'.new(tArgs.strLogLevel, tLogWriterConsole)
local tLogWriter = require 'log.writer.prefix'.new('[Main] ', tLogWriterFilter)
local tLog = require 'log'.new('trace', tLogWriter, require 'log.formatter.format'.new())

local tUsipGen = usip_generator(tLog)
local tSipper = sipper(tLog)

-- more requirements
-- Set the search path for LUA plugins.
package.cpath = package.cpath .. ";lua_plugins/?.dll"

-- Set the search path for LUA modules.
package.path = package.path .. ";lua/?.lua;lua/?/init.lua"

-- Load the common romloader plugins.
require("romloader_uart")
require("romloader_jtag")

flasher = require 'flasher'

-- options for the jtag plugin
-- with this option the jtag plug does no soft or hard reset in the connect routine of the jtag interface plugin
-- the jtag just attach to a device. This is necessary in case secure boot is enabled via an usip file. If the
-- jtag plugin would perform a reset the usip flags would directly be activated and it could be possible that
-- the debugging is disabled and the jtag is no longer available.
local strnetX90M2MImagePath = path.join(tArgs.strSecureOption, "netx90", "hboot_start_mi_netx90_com_intram.bin")

tLog.info("Trying to load netX 90 M2M image from %s", strnetX90M2MImagePath)
local strnetX90M2MImageBin, strMsg = tFlasherHelper.loadBin(strnetX90M2MImagePath)
if strnetX90M2MImageBin then
    tLog.info("%d bytes loaded.", strnetX90M2MImageBin:len())
else
    tLog.info("Error: Failed to load netX 90 M2M image: %s", strMsg or "unknown error")
    os.exit(1)
end
local atPluginOptions = {
    romloader_jtag = {
    jtag_reset = "Attach", -- HardReset, SoftReset or Attach
    jtag_frequency_khz = 6000 -- optional
    },
    romloader_uart = {
    netx90_m2m_image = strnetX90M2MImageBin
    }
}

-- todo add secure flag here
-- fIsSecure, strErrorMsg = tFlasherHelper.detect_secure_boot_mode(aArgs)

-- options for the jtag plugin
-- these options are just used for the first connect, in the usip command call, to bring the netX, with a reset,
-- in a dedicated state. After the first connect, the jtag will just attach to the netX with the atPluginOptions
-- declared above.
local atPluginOptionsFirstConnect = {
    romloader_jtag = {
    jtag_reset = "HardReset", -- HardReset, SoftReset or Attach
    jtag_frequency_khz = 6000 -- optional
    }
}

--------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------


-- Source: http://lua-users.org/wiki/SleepFunction
-- sleep for n seconds
-- this function is blocking!
-- returns after n seconds
function sleep(iSeconds)  -- seconds
    local tClock = os.clock
    local tT0 = tClock()
  while tClock() - tT0 <= iSeconds do end
end


-- strData, strMsg fileExists(strFilePath)
-- check if a file exists
-- returns
--   true if file exists
--   false otherwise
function fileExists(strFilePath)
    local f = nil
    if strFilePath then
        -- try to oopen a file
        f = io.open(strFilePath, "rb")
        -- if the file exists just close it
        if f then f:close() end
        -- return nil if the file can not be opend because it does not exists
    end
    return f ~= nil
end


-- strData, strMsg fileExeExists(strFilePath)
-- check if a .exe file exists.
-- first a check of the path with the .exe ending is performed, as a second attempt the file path without
-- the .exe ending is checked.
-- returns
--   true if file exists
--   false otherwise
function fileExeExists(strFilePath)
    local strExePath = string.format("%s.exe", strFilePath)
    -- try to open a file with an .exe ending
    local f = io.open(strExePath, "rb")
    -- if the file exists, close it and return true
    if f then
        f:close()
        return true
    end
    -- try to oopen a file without an .exe ending
    f = io.open(strFilePath, "rb")
    -- if the file exists just close it and return true
    if f then
        f:close()
        return true
    end
    -- return nil if the file can not be opend because it does not exists
    return f ~= nil
end


-- exists(folder)
-- check if a folder exists
-- returns true if the folder exists, otherwise false and an error message
function exists(folder)
    local ok, err, code = os.rename(folder, folder)
    if not ok then
       if code == 13 then
          -- Permission denied, but it exists
          return true, "permission denied"
       end
    end
    return ok, err
 end


-- strEncodedData uuencode(strFilePath)
-- UU-encode a binary file
-- returns
--   uuencoded data
function uuencode(strFilePath)
    local strData
    strData = tFlasherHelper.loadBin(strFilePath)

    -- Create a new archive.
    local tArchive = archive.ArchiveWrite()
    -- Output only the data from the filters.
    tArchive:set_format_raw()
    -- Filter the input data with uuencode.
    tArchive:add_filter_uuencode()
    -- NOTE: 2 * the size of the input data is way to much.
    tArchive:open_memory(string.len(strData)*2)

    -- Now create a new archive entry - even if we do not have a real archive here.
    -- It is necessary to set the filetype of the entry to "regular file", or no
    -- data will arrive on the output side.
    local tEntry = archive.ArchiveEntry()
    tEntry:set_filetype(archive.AE_IFREG)
    -- First write the header, then the data, the finish the entry.
    tArchive:write_header(tEntry)
    tArchive:write_data(strData)
    tArchive:finish_entry()
    -- Write only one entry, as this is no real archive.
    tArchive:close()

    -- Get encoded data.
    local strEncodedData = tArchive:get_memory()
    return strEncodedData
end


-- printArgs(tArguments)
-- Print all arguments in a table
-- returns
--   nothing
function printArgs(tArguments)
    tLog.info("")
    tLog.info("run usip_player.lua with the following args:")
    tLog.info("--------------------------------------------")
    printTable(tArguments, 0)
    tLog.info("")
end


-- printTable(tTable, ulIndent)
-- Print all elements from a table
-- returns
--   nothing
function printTable(tTable, ulIndent)
    local strIndentSpace = string.rep(" ", ulIndent)
    for key, value in pairs(tTable) do
        if type(value) == "table" then
            tLog.info( "%s%s",strIndentSpace, key )
            printTable(value, ulIndent + 4, tLog)
        else
            tLog.info( "%s%s%s%s",strIndentSpace, key, " = ", tostring(value) )
        end
    end
    if next(tTable) == nil then
        tLog.info( "%s%s",strIndentSpace, " -- empty --" )
    end
end


-- fCommandResult, strOutput executeCommand(strCommand)
-- executes a command in the shell
-- returns the command return code and the command output as a string
function executeCommand(strCommand, strTempFolderPath)
    local fCommandResult
    local strOutput = ""
    -- set temp file path for the output
    local strTempFilePath = path.join(strTempFolderPath, "command_output.txt")
    if not fileExists(strTempFilePath) then
        local tFile = io.open(strTempFilePath, "wb")
        tFile:close()
    end

    -- execute the command and redirect the output into a file
    fCommandResult = os.execute (string.format("%s > %s", strCommand, strTempFilePath ))

    -- display output
    for line in io.lines (strTempFilePath) do
      strOutput = strOutput .. line .. "\n"
    end

    return fCommandResult, strOutput
end


-- strSerialPort getSerialPort(strPluginName)
-- get the serial port string depending on the romloader plugin name
function getSerialPort(strPluginName)
    strSerialPort = string.match( strPluginName, "romloader.uart.(.*)" )
    if strSerialPort:find "tty" then
        strSerialPort = "/dev/" .. strSerialPort
    end
    return strSerialPort
end

-- strNetxName chiptypeToName(iChiptype)
-- transfer integer chiptype into a netx name
-- returns netX name as a string otherwise nil
function chiptypeToName(iChiptype)
    local strNetxName
    -- First catch the unlikely case that "iChiptype" is nil.
	-- Otherwise each ROMLOADER_CHIPTYP_* which is also nil will match.
	if iChiptype==nil then
		strNetxName = nil
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX500 or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX100 then
		strNetxName = 'netx500'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX50 then
		strNetxName = 'netx50'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX10 then
		strNetxName = 'netx10'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX56 or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX56B then
		strNetxName = 'netx56'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX4000_RELAXED or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX4000_FULL or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX4100_SMALL then
		strNetxName = 'netx4000'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90_MPW then
		strNetxName = 'netx90_mpw'
    elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90 then
		strNetxName = 'netx90_rev_0'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D_INTRAM then
		strNetxName = 'netx90'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETIOLA or iChiptype==romloader.ROMLOADER_CHIPTYP_NETIOLB then
		strNetxName = 'netiol'
    else
        strNetxName = nil
	end
    return strNetxName
end


--------------------------------------------------------------------------
-- loading images
--------------------------------------------------------------------------


-- LoadImage(tPlugin, strPath, ulLoadAddress, fnCallbackProgress)
-- load an image to a dedicated address
-- returns nothing, in case of a romlaoder error MUHKUH_PLUGIN_ERROR <- ??
function loadImage(tPlugin, strPath, ulLoadAddress, fnCallbackProgress)
    local fResult = false
    tLog.info( "Loading image path: '%s'", strPath )
    -- get the binary data from the file
    local tFile, strMsg = io.open(strPath, 'rb')
    -- check if the file exists
    if tFile then
        -- read out all the binary data
        local strFileData = tFile:read('*a')
        tFile:close()
        if strFileData then
            tLog.debug( "Loading image to 0x%08x", ulLoadAddress )
            -- write the image to the netX
            flasher.write_image(tPlugin, ulLoadAddress, strFileData, fnCallbackProgress)
            tLog.info("Writing image complete!")
            fResult = true
        else
            tLog.error( "Could not read from file %s", strPath )
        end
    -- error message if the file does not exist
    else
        tLog.error( 'Failed to open file "%s" for reading: %s', strPath, strMsg )
    end

    return fResult
end


-- fResult loadUsipImage(tPlugin, strPath, fnCallbackProgress)
-- Load an USIP image to 0x000200C0
-- return true if the image was loaded correctly otherwise false
function loadUsipImage(tPlugin, strPath, fnCallbackProgress)
    local fResult
    -- this address is necessary for the new usip commands in the MI-Interfaces
    local ulLoadAddress = 0x000200C0
    fResult = loadImage(tPlugin, strPath, ulLoadAddress, fnCallbackProgress)

    return fResult
end


-- fResult LoadIntramImage(tPlugin, strPath, ulLoadAddress, fnCallbackProgress)
-- Load an image in the intram to probe it after an reset
-- intram3 address is 0x20080000
-- return true if the image was loaded correctly otherwise false
function loadIntramImage(tPlugin, strPath, ulIntramLoadAddress, fnCallbackProgress)
    local fResult
    local ulLoadAddress
    if ulIntramLoadAddress  then
        ulLoadAddress = ulIntramLoadAddress
    else
        -- this address is the intram 3 address. This address will be probed at the startup
        ulLoadAddress = 0x20080000
    end
    fResult = loadImage(tPlugin, strPath, ulLoadAddress, fnCallbackProgress)

    return fResult
end


-- resetNetx90ViaWdg(tPlugin)
-- make a reset via the WatchDog of the netX90, the reset will be triggert after 1 second
-- returns
--   nothing
function resetNetx90ViaWdg(tPlugin)
    tLog.debug("Trigger reset via watchdog.")
    -- Reset netx 90 via watchdog
    -- watchdog addresses
    local addr_nx90_wdg_com_ctrl = 0xFF001640
    local addr_nx90_wdg_com_irq_timeout= 0xFF001648
    local addr_nx90_wdg_com_res_timeout = 0xFF00164c
    local ulVal

    -- Set write enable for the timeout regs
    ulVal = tPlugin:read_data32(addr_nx90_wdg_com_ctrl)
    -- set the neccessary bit
    ulVal = ulVal + 0x80000000
    tPlugin:write_data32(addr_nx90_wdg_com_ctrl, ulVal)

    -- IRQ after 0.9 seconds (9000 * 100µs, not handled)
    tPlugin:write_data32(addr_nx90_wdg_com_irq_timeout, 9000)
    -- reset 0.1 seconds later
    tPlugin:write_data32(addr_nx90_wdg_com_res_timeout, 1000)

    -- Trigger the watchdog once to start it
    ulVal = tPlugin:read_data32(addr_nx90_wdg_com_ctrl)
    -- set the neccessary bit
    ulVal = ulVal + 0x10000000
    tPlugin:write_data32(addr_nx90_wdg_com_ctrl, ulVal)
    tLog.warning("netX should reset in 1s.")
end


-- resetNetX90InSecure(strPluginName, strUsipGenExePath, strTmpFolderPath, strBootswitchFilePath)
-- reset the netX via the uart console interface by executing the bootswitch with the usip command
-- the usip command is used at this point to automatically reset the netX and directly execute the bootswitch binary.
-- in the trace and the console output an "usip-file is send" but actually its just the bootswitch binary.
function resetNetX90InSecure(strPluginName, strUsipGenExePath, strTmpFolderPath, strBootswitchFilePath)
    -- this function works only with the uart console interface
    local strBootswitchData
    local strBootSwitchOnlyPornParam
    local strExtendedBootswitchPath
    local strOutput
    local fResult
    -- extend the bootswitch with the uart parameter and uu-encode it
    tLog.debug("reset netX in secure mode.")

    strBootswitchData = tFlasherHelper.loadBin(strBootswitchFilePath)
    -- this is always the uart parameter because in secure mode only uart is working
    strBootSwitchOnlyPornParam = string.char(0x14, 0x00, 0x00, 0x00)
    if string.len( strBootswitchData ) < 0x8000 then
        -- calculate the length of the fill up data
        local ulFillUpLength = 0x8000 - string.len(strBootswitchData)
        -- generate the fill up data
        local strFillUpData = string.rep(string.char(255), ulFillUpLength)
        -- extend the bootswitch parameters at the end
        strBootswitchData = strBootswitchData .. string.sub(strFillUpData, 1, -17) .. strBootSwitchOnlyPornParam
        -- extend with zeros to flush the image
        strBootswitchData = strBootswitchData .. string.char(0, 0, 0, 0, 0, 0, 0, 0)
        -- set extended bootswitch file path
        strExtendedBootswitchPath = path.join( strTmpFolderPath, "extended.usp")

        -- write the data back to the extended usip binary file
        local tFile
        tFile = io.open(strExtendedBootswitchPath, "wb")
        tFile:write(strBootswitchData)
        tFile:close()

        strOutput, fResult = loadSecureUsip(
            strExtendedBootswitchPath,
            strPluginName,
            strUsipGenExePath,
            strTmpFolderPath
        )
    else
        fResult = 1
        strOutput = "Bootswitch file extends the max length of 0x8000 bytes."
    end

    if fResult == 0 then
        tLog.debug(strOutput)
    else
        tLog.error(strOutput)
    end

    return fResult
end


-- execBinViaIntram(tPlugin, strFilePath, ulIntramLoadAddress)
-- loads an image into the intram, flushes the data and reset via watchdog
-- returns
--    nothing
function execBinViaIntram(tPlugin, strFilePath, ulIntramLoadAddress)
    local fResult
    local ulLoadAddress
    if ulIntramLoadAddress == nil then
        ulLoadAddress = 0x20080000
    else
        ulLoadAddress = ulIntramLoadAddress
    end

    -- load an image into the intram
    fResult = loadIntramImage(tPlugin, strFilePath, ulLoadAddress)
    if fResult then
        -- flush the image
        -- flush the intram by reading 32 bit and write them back
        -- the flush only works if the file is grater than 4byte and smaller then 64kb
        -- the read address must be an other DWord address as the last used
        -- if a file is greater than the 64kb the file size exeeds the intram area space, so every
        -- intram has to be flushed separately
        -- the flush only works if the file is greater than 4byte and smaller then 64kb
        tLog.debug( "Flushing...")
        -- read 32 bit
        local data = tPlugin:read_data32(ulLoadAddress)
        -- write the data back
        tPlugin:write_data32(ulLoadAddress, data)
        -- reset via the watchdog
        -- todo: switch to reset netx via watchdog from flasher_helper.lua
        resetNetx90ViaWdg(tPlugin)
    end

    return fResult
end


--------------------------------------------------------------------------
-- functions
--------------------------------------------------------------------------

-- astrUsipPathList, tUsipGenMultiOutput, tUsipGenMultiResult genMultiUsips(
--    strUsipGenExePath, strTmpPath, strUsipConfigPath
-- )
-- generates depending on the usip-config json file multiple usip files. The config json file is generated
-- with the usip generator. Every single generated usip file has the same header and differs just in the body part.
-- The header is not rellevant at this point, because the header of the usip file is just checked once if
-- the hash is correct and is not relevant for the usip process
-- returns a list of all generated usip file paths and the output of the command
function genMultiUsips(strTmpFolderPath, tUsipConfigDict)
    -- list of all generated usip file paths
    local astrUsipPathList = {}

    local tResult, aFileList = tUsipGen:gen_multi_usip_hboot(tUsipConfigDict, strTmpFolderPath)

    return tResult, aFileList
end


-- fOk verifySignature(tPlugin, strPluginType, astrPathList, strTempPath, strSipperExePath, strVerifySigPath)
-- verify the signautre of every usip file in the list
-- the SIPper is used for the data-block generation only
-- the verify_sig binary does not need to be sined, because the image is called directly via the tPlugin:call command.
-- both addresses for the result and debug registers are hard coded inside the verify_sig program. To change these
-- addresses the binary needs to be build again.
-- For every single usip in the list a new data block have to be generated and an individually signautre verification is
-- performed. Every signature is checked even if one already failed.
-- returns true if every signature is correct, otherwise false
function verifySignature(tPlugin, strPluginType, astrPathList, strTempPath, strSipperExePath, strVerifySigPath)
    -- NOTE: For more information of how the verify_sig program works and how the data block is structed and how the
    --       result register is structured take a look at https://kb.hilscher.com/x/VpbJBw
    -- be pessimistic
    local fOk = false
    local ulVerifySigResult
    local ulVerifySigDebug
    local strVerifySigDataPath
    local ulVerifySigDataLoadAddress = 0x000203c0
    local ulDataBlockLoadAddress = 0x000220c0
    local ulVerifySigResultAdd = 0x000220b8
    local ulVerifySigDebugAdd = 0x000220bc
    -- get verifysig programm data only
    local strVerifySigData, strMsg = tFlasherHelper.loadBin(strVerifySigPath)
    if strVerifySigData then
        -- cut out the programm data from the rest of the image
        -- this is the raw programm data
        strVerifySigData = string.sub(strVerifySigData, 1037, 3428)
        -- set the path for the verifySigData
        strVerifySigDataPath = path.join( strTempPath, "verify_sig_data.bin")
        local tFile
        tFile = io.open(strVerifySigDataPath, "wb")
        tFile:write(strVerifySigData)
        tFile:close()
        -- iterate over the path list to check the signature of every usip file
        for _, strSingleFilePath in ipairs(astrPathList) do
            -- verify the signature
            local strDataBlockPath = path.join( strTempPath, "data_block.bin")
            -- generate data block
            local strDataBlock, tGenDataBlockResult, strErrorMsg = tSipper:gen_data_block(strSingleFilePath, strDataBlockPath)

            -- check if the command executes without an error
            if tGenDataBlockResult == true then
                -- execute verify signature binary
                tLog.info("Start signature verification ...")
                tLog.debug("Clearing result areas ...")
                tPlugin:write_data32(ulVerifySigResultAdd, 0x00000000)
                tPlugin:write_data32(ulVerifySigDebugAdd, 0x00000000)
                -- todo add ethernet interface
                if strPluginType == 'romloader_jtag' or strPluginType == 'romloader_uart' then
                    fOk = loadIntramImage( tPlugin, strDataBlockPath, ulDataBlockLoadAddress )
                    if fOk then
                        fOk = loadIntramImage( tPlugin, strVerifySigDataPath, ulVerifySigDataLoadAddress )
                        if fOk then
                            tPlugin:call(
                                ulVerifySigDataLoadAddress + 1,
                                ulDataBlockLoadAddress ,
                                flasher.default_callback_message,
                                2)

                            ulVerifySigResult = tPlugin:read_data32(ulVerifySigResultAdd)
                            ulVerifySigDebug = tPlugin:read_data32(ulVerifySigDebugAdd)
                            tLog.debug( "ulVerifySigDebug: %s ", ulVerifySigDebug )
                            tLog.debug( "ulVerifySigResult: %s ", ulVerifySigResult )
                            -- if the verify sig program runs without errors the result
                            -- register has a value of 0x00000701
                            if ulVerifySigResult == 0x701 then
                                tLog.info( "Successfully verified the signature of file: %s", strSingleFilePath )
                            else
                                fOk = false
                                tLog.error( "Failed to verify the signature of file: %s", strSingleFilePath )
                            end
                        end
                    end
                else
                    -- netX90 rev_1 and ethernet deteced, this function is not supported
                    tLog.error( "This Interface is not yet supported! -> %s", strPluginType )
                end
            else
                tLog.error( tGenDataBlockOutput )
                tLog.error( "Failed to generate data_block for file: %s ", strSingleFilePath )
            end
        end
    else
        tLog.error(strMsg)
        tLog.error( "Could not load data from file: %s", strVerifySigPath )
    end

    return fOk
end

-- fResult verifySignatureSecure(
--    strPluginName,
--    astrPathList,
--    strVerifySigPath,
--    strTmpFolderPath,
--    strSipperExePath,
-- )
-- todo this will be removed as soon as the serial interface is removed from flasher commands
-- verify the signature of every usip file in the list
-- verifies the signature via the uart console interface.
-- If secure boot is enabled the verify_sig binary have to be signed because it is executed with the 'htbl' command in
-- the (secure-)console. If the signature of the verify_sig bianry is not correct or no signature is available, in
-- secure mode, the signautre verification will automatically fail.
-- The data block generation is performed inside the SIPper --verify_sig command.
-- returns true if every signature is correct, otherwise false
function verifySignatureSecure(strPluginName, astrPathList, strVerifySigPath, strTmpFolderPath, strSipperExePath)
    -- be optimistic
    local fResult = true
    local strSerialPort
    local iVerifySigResult
    local tVerifySigOutput
    -- iterate through the list of all files
    -- every file signautre is verified
    for _, strSingleFilePath in ipairs(astrPathList) do
        -- verify the signature
        -- set data block path
        local strDataBlockPath = path.join( strTmpFolderPath, "data_block.bin")
        -- set the serial port name
        strSerialPort = getSerialPort(strPluginName)
        -- load the usip file
        local strCommand = string.format(
            '%s verify_sig -p "%s" -i "%s" -o "%s" --verify_sig "%s"',
            strSipperExePath,
            strSerialPort,
            strSingleFilePath,
            strDataBlockPath,
            strVerifySigPath
        )
        -- execute the command
        -- verify the signature against the netX
        iVerifySigResult, tVerifySigOutput = executeCommand(strCommand, strTmpFolderPath)
        tLog.info(tVerifySigOutput)
        -- check if the command returns with a 0
        -- if that is the case the siganture verification was a success
        -- the SIPper returns a 1 if the siganture_verification failes
        if iVerifySigResult == 0 then
            tLog.info( "Successfully verified the signature of file: %s", strSingleFilePath )
            fResult = fResult and true
        else
            tLog.error( "Failed to verify signature for file -> %s", strSingleFilePath )
            fResult = false
        end
    end
    sleep(1)

    return fResult
end

-- fResult, strMsg extendBootswitch(strUsipPath, strTmpFolderPath, strBootswitchFilePath, strBootswitchParam)
-- extend the usip file with the bootswitch and the bootswitch parameter
-- the bootswitch supports three console interfaces, ETH, UART and MFW
-- more information about the bootswitch can be found in the KB: https://kb.hilscher.com/x/CcBwBw
-- more information about the bootswitch in combination with an usip can be found in the
-- KB: https://kb.hilscher.com/x/0s2gBw
-- returns true, nil if everything went right, else false and a error message
function extendBootswitch(strUsipPath, strTmpFolderPath, strBootswitchFilePath, strBootswitchParam)
    -- result variable, be pessimistic
    local fResult = false
    local strMsg
    local strUsipData
    local strBootswitchData
    local strBootSwitchOnlyPornParam
    local strCombinedUsipPath

    -- read the usip content
    -- print("Loading USIP content ... ")
    strUsipData, strMsg = tFlasherHelper.loadBin(strUsipPath)
    if strUsipData then
        -- read the bootswitch content
        -- print("Appending Bootswitch ... ")
        strBootswitchData, strMsg = tFlasherHelper.loadBin(strBootswitchFilePath)
        if strBootswitchData then
            -- set the bootswitch parameter
            if strBootswitchParam == "ETH" then
                -- open eth console after reset
                strBootSwitchOnlyPornParam = string.char(0x04, 0x00, 0x00, 0x00)
            elseif strBootswitchParam == "UART" then
                -- open uart console after reset
                strBootSwitchOnlyPornParam = string.char(0x14, 0x00, 0x00, 0x00)
            else
                -- start MFW after reset
                strBootSwitchOnlyPornParam = string.char(0x03, 0x00, 0x00, 0x00)
            end
        end
        -- cut the usip image ending and the bootswitch header and extend the bootswitch content
        -- this is necessary to have a regular image.
        -- The bootswitch and the usip needs their regular header/ending because they have to be executed
        -- individually. The bootswitch is an optional extension
        strUsipData = string.sub( strUsipData, 1, -5 ) .. string.sub( strBootswitchData, 65 )
        -- fill the image, so the bootswitch parameter are always at the same offset
        if string.len( strUsipData ) < 0x8000 then
            -- calculate the length of the fill up data
            local ulFillUpLength = 0x8000 - string.len(strUsipData)
            -- generate the fill up data
            local strFillUpData = string.rep(string.char(255), ulFillUpLength)
            -- extend the content with the fillup data - lenght of bootswitch parameter (-4)
            -- the bootswitch have a hard-coded offset where he looks for the only-porn-parameters
            -- to place the parameters at this offset the image must be extended to this predefined length
            -- extend the bootswitch only porn data
            strUsipData = strUsipData .. string.sub(strFillUpData, 1, -17) .. strBootSwitchOnlyPornParam
            -- extend with zeros to flush the image
            strUsipData = strUsipData .. string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

            if string.len( strUsipData ) == 0x8000 then
                -- set combined file path
                strCombinedUsipPath = path.join( strTmpFolderPath, "combined.usp")
                -- write the data back to the usip binary file
                local tFile
                tFile = io.open(strCombinedUsipPath, "wb")
                tFile:write(strUsipData)
                tFile:close()
                fResult = true
                strMsg = "Extendet bootswitch."
            else
                strMsg = "The combined image exceeds the size of 32kB. Choose a smaller USIP file!"
            end
        end
    end

    return fResult, strCombinedUsipPath, strMsg
end


-- fOk, strSingleUsipPath, strMsg extendExecReturn(strUsipPath, strTmpFolderPath, strExecReturnFilePath)
-- extend the usip file with an exec chunk that return immediately and activated the debugging
-- returns true and the file path to the combined file in case no error occur, otherwith an false and nil
-- returns always a info message.
function extendExecReturn(strUsipPath, strTmpFolderPath, strExecReturnFilePath)
    local fResult = false
    local strMsg
    local strUsipData
    local strExecReturnData
    local strCombinedUsipPath

    -- read the usip content
    strUsipData = tFlasherHelper.loadBin(strUsipPath)
    if strUsipData then
        -- read the exec-return content
        strExecReturnData = tFlasherHelper.loadBin(strExecReturnFilePath)
        if strExecReturnData then
            -- cut the usip image ending and extend the exec-return content without the boot header
            -- the first 64 bytes are the boot header
            strUsipData = string.sub( strUsipData, 1, -5 ) .. string.sub( strExecReturnData, 65 )
            -- set combined file path
            strCombinedUsipPath = path.join( strTmpFolderPath, "combined.usp")
            -- write the data back to the usip binary file
            local tFile
            tFile = io.open(strCombinedUsipPath, "wb")
            tFile:write(strUsipData)
            tFile:close()
            fResult = true
            strMsg = "Extended exec-return."
        else
            strMsg = "Can not read out the exec-return binary data."
        end
    else
        strMsg = "Can not read out the usip data."
    end

    return fResult, strCombinedUsipPath, strMsg
end


-- tPlugin loadUsip(strFilePath, tPlugin, strPluginType)
-- loads an usip file via a dedicated interface and checks if the chiptype is supported
-- returns the plugin, in case of a uart connection the plugin must be updated and a new plugin is returned
-- todo load usip with new m2m command if m2m version 3.1 and newer
function loadUsip(strFilePath, tPlugin, strPluginType)
    local fOk
    tLog.info( "Loading Usip %s via %s",strFilePath, strPluginType )
    tPlugin:Connect()
    if strPluginType == 'romloader_jtag' then
        -- jtag has no usip command, load the image into the intram and reset the netX via WDG
        fOk = execBinViaIntram(tPlugin, strFilePath)
        if fOk then
            tPlugin:Disconnect()
            sleep(2)
            -- get the jtag plugin with the attach option to not reset the netX
            tPlugin = tFlasherHelper.getPlugin(tPlugin:GetName(), strPluginType, atPluginOptions)
        end
    else
        if strPluginType == 'romloader_uart' then
            -- netX90 rev_1 and uart detected, process the usip via the intram
            fOk = execBinViaIntram(tPlugin, strFilePath)
            if fOk then
                tPlugin:Disconnect()
                sleep(2)
                -- get the uart plugin again
                tPlugin = tFlasherHelper.getPlugin(tPlugin:GetName(), strPluginType, atPluginOptions)
            end
        elseif strPluginType == 'romloader_eth' then
            -- netX90 rev_1 and ethernet deteced, this function is not supported
            tLog.error("The current verison does not support the Ethernet in this feature!")
        else
            tLog.error("This feature is not supported yet.")
            -- netX90 rev_2 detected, use the new usip commands
            -- loadUsipImage(tPlugin, strFilePath)
            -- call_usip(tPlugin)
        end
    end
    return fOk, tPlugin
end


-- tUsipLoadOutput, iLoadUsipResult loadSecureUsip(strUsipPath, strPluginName, strUsipGenExePath, strTempPath)
-- load an usip file via the native uart console to the netX
-- returns
--   usip load Output, message (from file write)
-- todo remove
function loadSecureUsip(strUsipPath, strPluginName, strUsipGenExePath, strTempPath)
    local strSerialPort
    local strUuencodedData
    local strUuencodedPath
    local tUsipLoadOutput
    local iLoadUsipResult
    strUuencodedPath = path.join( strTempPath, "uue_usip.uue")
    strUuencodedData = uuencode(strUsipPath)
    -- open a file in binary mode
    local tFile = io.open(strUuencodedPath, "wb")
    -- check if the file exists
    if tFile then
        -- write all data to file
        tFile:write(strUuencodedData)
        tFile:close()
        -- get the serial port
        strSerialPort = getSerialPort(strPluginName)
        -- load the usip file
        local strCommand = string.format(
            '%s load -f "%s" -p "%s"',
            strUsipGenExePath,
            strUuencodedPath,
            strSerialPort
        )
        -- execute the command
        -- load the usip via the uart console mode with the "usip" command call
        -- the "usip" command call resets the netX automatically
        iLoadUsipResult, tUsipLoadOutput = executeCommand(strCommand, strTempPath)
    else
        tUsipLoadOutput = "Could not uu-encode the usip binary."
        iLoadUsipResult = 1
    end

    return tUsipLoadOutput, iLoadUsipResult
end


-- tReadSipOutput, iReadSipResult readSipViaUart(strHbootPath, strPluginName, strSipperExePath, strTempPath)
-- load an hboot file via the native uart console to the netX
-- the hboot reads out the secure info page content and saves the content in a folder as
-- com.bin and app.bin
-- If secure boot is on the read_sip binary needs to be singed
-- returns
--   htbl Output, message (from file write)
function readSipViaUart(strHbootPath, strPluginName, strSipperExePath, strTempPath)
    local strSerialPort
    local strUuencodedData
    local strUuencodedPath
    local iReadSipResult
    local tReadSipOutput
    strUuencodedPath = path.join( strTempPath, "uue_hboot.uue")
    -- uu-encode the read-sip binary file
    -- the file needs to be uu-encoded because it is send with the 'htbl' command via the native uart console
    strUuencodedData = uuencode( strHbootPath )
    -- open a file in binary mode
    local tFile = io.open( strUuencodedPath, "wb" )
    -- check if the file exists
    if tFile then
        -- write all data to file
        tFile:write( strUuencodedData )
        tFile:close()
        -- get the serial port
        strSerialPort = getSerialPort(strPluginName)
        -- load the usip file
        local strCommand = string.format(
            '%s read_sip -p "%s" -o "%s" --read_sip "%s"',
            strSipperExePath, strSerialPort,
            strTempPath,
            strUuencodedPath
        )
        -- execute the command
        iReadSipResult, tReadSipOutput = executeCommand(strCommand, strTempPath)
    else
        tReadSipOutput = "Could not uu-encode the read-sip binary."
        iReadSipResult = 1
    end

    return tReadSipOutput, iReadSipResult
end

-- fOk verifyContent(strPluginType, tPlugin, strTmpFolderPath, strSipperExePath, strUsipConfigPath)
-- compare the content of a usip file with the data in a secure info page to verify the usip process
-- returns true if the verification process was a success, otherwise false
function verifyContent(
    strPluginType,
    tPlugin,
    strTmpFolderPath,
    strSipperExePath,
    tUsipConfigDict,
    strResetBootswitchPath,
    strResetExecReturnPath
)
    local fOk = false
    local strErrorMsg
    local iValidCom
    local iValidApp
    local strComSipData
    local strAppSipData
    local strComSipFilePath
    local strAppSipFilePath
    tLog.info("Verify USIP content ... ")
    tLog.debug( "Reading out SecureInfoPages via %s", strPluginType )
    -- validate the seucre info pages
    -- it is important to return the plugin at this point, because of the reset the romload_uart plugin
    -- changes
    iValidCom, iValidApp, tPlugin = validateSip(tPlugin, strResetBootswitchPath, strResetExecReturnPath)
    -- get the com sip data
    strComSipData, strAppSipData = readOutSipContent(iValidCom, iValidApp, tPlugin)
    -- check if for both sides a valid sip was found
    if strComSipData == nil or strAppSipData == nil then
        tLog.error("Unable to read out both SecureInfoPages.")
    else
        -- mask the kek
        strComSipData = string.sub(strComSipData, 0, 1855) .. string.rep(string.char(255), 192) .. string.sub(strComSipData, 2048)

        tLog.debug("Saving content to files...")
        -- save the content to a file if the flag is set
        -- set the sip file path to save the sip data
        strComSipFilePath = path.join( strTmpFolderPath, "com_sip.bin")
        strAppSipFilePath = path.join( strTmpFolderPath, "app_sip.bin")
        -- write the com sip data to a file
        tLog.debug("Saving COM SIP to %s ", strComSipFilePath)
        local tFile = io.open(strComSipFilePath, "wb")
        tFile:write(strComSipData)
        tFile:close()
        -- write the app sip data to a file
        tLog.debug("Saving APP SIP to %s ", strAppSipFilePath)
        tFile = io.open(strAppSipFilePath, "wb")
        tFile:write(strAppSipData)
        tFile:close()


        fOk, strErrorMsg = tSipper:verify_usip(tUsipConfigDict, strComSipFilePath, strAppSipFilePath, tPlugin)

        if fOk ~= true then
            self.tLog.error(strErrorMsg)
        end
    end

    return fOk
end


-- fOk verifyContentSecure(strPluginName, strTmpFolderPath, strReadSipPath, strSipperExePath, strUsipConfigPath)
-- compare the content of a usip file with the data in a secure info page to
-- verify the usip process
-- returns true if the verification process was a success, otherwise false
-- todo remove
function verifyContentSecure(strPluginName, strTmpFolderPath, strReadSipPath, strSipperExePath, strUsipConfigPath)
    local fOk = false
    local strComSipFilePath
    local strAppSipFilePath
    tLog.info("Verify USIP content ... ")
    -- validate the seucre info pages and read out the sip content
    local strOutput, iReadSipResult = readSipViaUart(strReadSipPath, strPluginName, strSipperExePath, strTmpFolderPath)
    if iReadSipResult == 0 then
        tLog.info(strOutput)
        strComSipFilePath = path.join( strTmpFolderPath, "com_sip.bin")
        strAppSipFilePath = path.join( strTmpFolderPath, "app_sip.bin")

        -- check if the usip was processed correctly
        local strCommand = string.format(
            '%s verify_usip -i "%s" --com_bin "%s" --app_bin "%s"',
            strSipperExePath,
            strUsipConfigPath,
            strComSipFilePath,
            strAppSipFilePath
        )
        -- execute the command
        local tVerifyUsipProcessedResult, tVerifyUsipProcessedOutput = executeCommand(strCommand, strTmpFolderPath)
        tLog.info(tVerifyUsipProcessedOutput)
        if tVerifyUsipProcessedResult == 0 then
            tLog.info(tVerifyUsipProcessedOutput)
            -- check if the verification success
            if tVerifyUsipProcessedOutput:find "VERIFICATION SUCCESS" then
                fOk = true
            end
        else
            tLog.error(tVerifyUsipProcessedOutput)
        end
    else
        tLog.error(strOutput)
    end

    return fOk
end


-- iValidCom, iValidApp, tPlugin validateSip(tPlugin, strResetBootswitchPath, strResetExecReturnPath)
-- check if a valid secure info page is available and can be used on the netX for further operations
-- a sip is valid if it is copied, not copied and not hidden
-- a sip is not valid if it is not copied and hidden, then a external process can not
-- use the sip content for fruther oprtations
-- returns a tuple (iValidCom, iValidApp) with the following pattern:
-- 1 if sip copy is valid (if a valid copy was found the sip in flash is not checked anymore)
-- 2 if sip in flash is valid
-- otherwise -1
function validateSip(tPlugin, strResetBootswitchPath, strResetExecReturnPath)
    local fCallSuccess
    local iValidCom = -1
    local iValidApp = -1
    -- check the sip copy at first
    tLog.info("Validating SecureInfoPages")
    tLog.debug("Validate Sip-Copies inside intram")
    -- create a mhash state for the com side
    mh_com = mhash.mhash_state()
    -- initialize the mhash state for a sha384
    mh_com:init(mhash.MHASH_SHA384)
    -- create a mhash state for the app side
    mh_app = mhash.mhash_state()
    -- initialize the mhash state for a sha384
    mh_app:init(mhash.MHASH_SHA384)
    -- set the copy addresses and sip size
    local ulComSipCopyAddr = 0x200a7000
    local ulAppSipCopyAddr = 0x200a6000
    local ulSipCopySize = 0x1000
    local ulHashSize = 0x20
    local strComSipContent
    local strAppSipContent
    local strResetImagePath
    -- get the plugin type
    local strPluginType = tPlugin:GetTyp()
    -- invalidate the secure info page copies and reset the netX to be sure the SIP copy is valid
    -- invalidte the hash of both secure info page copies
    local ulHashComSipCopyAddr = ulComSipCopyAddr + ulSipCopySize - ulHashSize
    local ulHashAppSipCopyAddr = ulAppSipCopyAddr + ulSipCopySize - ulHashSize
    -- invalidate the copy by writing zeros inside the hash area
    for i=0, ulHashSize, 4 do
        tPlugin:write_data32(ulHashComSipCopyAddr + i, 0)
        tPlugin:write_data32(ulHashAppSipCopyAddr + i, 0)
    end

    if tArgs.strBootswitchParams then
        if tArgs.strBootswitchParams == "JTAG" then
            -- use strResetExecReturnPath as if 'extend_exec' was selected
            strResetImagePath = strResetExecReturnPath
        else
            strResetImagePath = strResetBootswitchPath
        end
    end

    -- load the reset image
    if tArgs.strBootswitchParams then
        local ulLoadAddress = 0x20080000
        fOk = loadIntramImage(tPlugin, strResetImagePath, ulLoadAddress )
    else
        tLog.debug("Just reset without any image in the intram.")
    end
    -- reset via watchdog
    resetNetx90ViaWdg(tPlugin)
    tPlugin:Disconnect()
    sleep(2)
    -- just necessary if the uart plugin in used
    -- jtag works without getting a new plugin
    if strPluginType == 'romloader_uart' then
        tPlugin = tFlasherHelper.getPlugin(tPlugin:GetName(), strPluginType, atPluginOptions)
    end
    tPlugin:Connect()
    -- read out the potential sip content
    tLog.debug("Read out Sip-Copies")
    strComSipContent = flasher.read_image(tPlugin, ulComSipCopyAddr, ulSipCopySize )
    strAppSipContent = flasher.read_image(tPlugin, ulAppSipCopyAddr, ulSipCopySize )
    -- seperate the sip data from the sip hash
    -- the sip hash are the last 48 bytes of the SecureInfoPage the rest is SecureInfoPage data
    -- get the com sip data
    local strComSipData = string.sub(strComSipContent, 1, 4048)
    -- get the com sip hash
    local strComSipHash = string.sub(strComSipContent, 4049)
    -- get the app sip data
    local strAppSipData = string.sub(strAppSipContent, 1, 4048)
    -- get the app sip hash
    local strAppSipHash = string.sub(strAppSipContent, 4049)
    -- calculate the com sip hash with the com sip data
    mh_com:hash(strComSipData)
    -- get the com hash value
    sha384_hash_com = mh_com:hash_end()
    -- calculate the app sip hash with the app sip data
    mh_app:hash(strAppSipData)
    -- get the app hash value
    sha384_hash_app = mh_app:hash_end()

    -- compare the calculated com hash with the read out com hash
    -- if both hashs match the com sip copy is valid
    if sha384_hash_com == strComSipHash then
        tLog.debug("Com SecureInfoPage copy is valid.")
        -- set the com valid to 1 because the com sip is valid
        iValidCom = 1
    end

    -- compare the calculated app hash with the read out app hash
    -- if both hashs match the app sip copy is valid
    if sha384_hash_app == strAppSipHash then
        tLog.debug("App SecureInfoPage copy is valid.")
        -- set the com valid to 1 because the app sip is valid
        iValidApp = 1
    end

    -- if the hashes does not match the sip copy is not valid
    -- if iValidCom is not set the sip copy is not valid,  next check the sip
    -- inside the flash is valid
    if iValidCom ~= 1 then
        tLog.debug("Validate Com sip inside the flash.")
        -- initialize the mhash state for a sha384
        mh_com:init(mhash.MHASH_SHA384)
        -- show the com sip
        tPlugin:write_data32(0xff001cbc, 1)
        -- set the copy addresses and sip size
        local ulComSipAddr = 0x180000
        -- read out the potential sip content
        -- strComSipContent = flasher.read_image(tPlugin, ulComSipAddr, ulSipCopySize )
        fCallSuccess, strComSipContent = pcall(flasher.read_image, tPlugin, ulComSipAddr, ulSipCopySize )
        if fCallSuccess then
            -- seperate the sip data from the sip hash
            -- the sip hash are the last 48 bytes of the SecureInfoPage the rest is SecureInfoPage data
            -- get the com sip data
            strComSipData = string.sub(strComSipContent, 1, 4048)
            -- get the com sip hash
            strComSipHash = string.sub(strComSipContent, 4049)
            -- calculate the com sip hash with the com sip data
            mh_com:hash(strComSipData)
            -- get the com hash value
            sha384_hash_com = mh_com:hash_end()
            -- compare the calculated com hash with the read out com hash
            -- if both hashs match the com sip copy is valid
            if sha384_hash_com == strComSipHash then
                tLog.debug("Com SecureInfoPage is valid.")
                -- set the com valid to 1 because the com sip is valid
                iValidCom = 2
            else
                -- no valid com sip was found
                tLog.warning("Could not find valid Com SecureInfoPage.")
                iValidCom = -1
            end
        else
            -- no valid com sip was found
            tLog.error("Could not find valid Com SecureInfoPage.")
            iValidCom = -1
        end
        -- hide the com sip
        -- use a protected call to catch exeption
        pcall( function () tPlugin:write_data32(0xff001cbc, 1) end)
    end

    -- if the hashes does not match the sip copy is not valid
    -- if iValidApp is not set the sip copy is not valid,  next check the sip
    -- inside the flash is valid
    if iValidApp ~= 1 then
        tLog.debug("Validate App sip inside the flash.")
        -- initialize the mhash state for a sha384
        mh_app:init(mhash.MHASH_SHA384)
        -- show the app sip
        fCallSuccess = pcall( function () tPlugin:write_data32(0xff40143c, 1) end)
        if fCallSuccess then
            -- set the copy addresses and sip size
            local ulAppSipAddr = 0x200000
            -- read out the potential sip content
            fCallSuccess, strAppSipContent = pcall(flasher.read_image, tPlugin, ulAppSipAddr, ulSipCopySize )
            if fCallSuccess then
                -- seperate the sip data from the sip hash
                -- the sip hash are the last 48 bytes of the SecureInfoPage the rest is SecureInfoPage data
                -- get the app sip data
                strAppSipData = string.sub(strAppSipContent, 1, 4048)
                -- get the app sip hash
                strAppSipHash = string.sub(strAppSipContent, 4049)
                -- calculate the app sip hash with the app sip data
                mh_app:hash(strAppSipData)
                -- get the app hash value
                sha384_hash_app = mh_app:hash_end()
                -- compare the calculated app hash with the read out app hash
                -- if both hashs match the app sip copy is valid
                if sha384_hash_app == strAppSipHash then
                    tLog.debug("App SecureInfoPage is valid.")
                    -- set the app valid to 1 because the app sip is valid
                    iValidApp = 2
                else
                    -- no valid app sip was found
                    tLog.warning("Could not find valid App SecureInfoPage.")
                    iValidApp = -1
                end
            else
                -- no valid app sip was found
                tLog.warning("Could not find valid App SecureInfoPage.")
                iValidApp = -1
            end
        else
            -- no valid app sip was found
            tLog.error("Could not find valid App SecureInfoPage.")
            iValidApp = -1
        end
        -- hide the app sip
        -- use a protected call to catch exeption
        pcall( function () tPlugin:write_data32(0xff40143c, 0) end)
    end

    return iValidCom, iValidApp, tPlugin
end


-- strComSipData, strAppSipData readOutSipContent(iValidCom, iValidApp, tPlugin)
-- read out the secure info page content via MI-Interface or the JTAG-interface
-- the function needs a sip validation before it can be used.
function readOutSipContent(iValidCom, iValidApp, tPlugin)
    local strComSipData = nil
    local strAppSipData = nil
    if not ( iValidCom == -1 or iValidApp == -1 ) then
        -- check if the copy com sip area has a valid sip
        if iValidCom == 1 then
            tLog.info("Found valid COM copy Secure info page.")
            -- read out the copy com sip area
            strComSipData = flasher.read_image(tPlugin, 0x200a7000, 0x1000)
        else
            -- the copy com sip area has no valid sip check if a valid sip is in the flash
            if iValidCom == 2 then
                tLog.info("Found valid COM Secure info page.")
                -- read out the com sip from the flash
                -- show the sip
                tPlugin:write_data32(0xff001cbc, 1)
                -- read out the sip
                strComSipData = flasher.read_image(tPlugin, 0x180000, 0x1000)
                -- hide the sip
                tPlugin:write_data32(0xff001cbc, 0)
            -- no valid com sip found, set the strComSipData to nil
            else
                tLog.error(
                    "Can not find a valid COM-SecureInfoPage, please check if the COM-Page is hidden and not copied."
                )
                strComSipData = nil
            end
        end
        -- check if the copy app sip area has a valid sip
        if iValidApp == 1 then
            tLog.info("Found valid APP copy Secure info page.")
            -- read out the copy app sip area
            strAppSipData = flasher.read_image(tPlugin, 0x200a6000, 0x1000)
        else
            -- the copy app sip area has no valid sip check if a valid sip is in the flash
            if iValidApp == 2 then
                tLog.info("Found valid APP Secure info page.")
                -- read out the app sip from the flash
                -- show the sip
                tPlugin:write_data32(0xff40143c, 1)
                -- read out the sip
                strAppSipData = flasher.read_image(tPlugin, 0x200000, 0x1000)
                -- hide the sip
                tPlugin:write_data32(0xff40143c, 0)
            -- no valid app sip found, set the strAppSipData to nil
            else
                tLog.error(
                    "Can not find a valid APP-SecureInfoPage, please check if the APP-Page is hidden and not copied."
                )
                strAppSipData = nil
            end
        end
    end
    return strComSipData, strAppSipData
end


-- strDetectSecureOutput, iDetectSecureResult detectSecure(strPluginName, strSipperExePath, strTempPath)
-- detect the secure mode via the serial uart interface
-- the following secure states are possible
-- SECURE_BOOT_DISABLED (app and com side has no secure boot activate)
-- SECURE_BOOT_ENABLED (com side has secure boot enabled, app side secure state is unknown)
-- SECURE_BOOT_ONLY_APP_ENABLED (com side has not secure boot enabled, app side has secure boot enabled)
function detectSecure(strPluginName, strSipperExePath, strTempPath)
    local strSerialPort
    local iDetectSecureResult
    local strDetectSecureOutput
    -- get the serial port
    strSerialPort = getSerialPort(strPluginName)
    -- load the usip file
    local strCommand = string.format('%s detect_secure -p "%s"', strSipperExePath, strSerialPort)
    -- execute the command
    _, strDetectSecureOutput = executeCommand(strCommand, strTempPath)

    if strDetectSecureOutput:find "SECURE_BOOT_DISABLED" then
        iDetectSecureResult = 0
    elseif strDetectSecureOutput:find "SECURE_BOOT_ENABLED" then
        iDetectSecureResult = 5
    elseif strDetectSecureOutput:find "SECURE_BOOT_ONLY_APP_ENABLED" then
        iDetectSecureResult = 50
    else
        iDetectSecureResult = 1
    end

    return strDetectSecureOutput, iDetectSecureResult
end


-- iGetUidResult, strGetUidOutput getUid(strPluginName, strSipperExePath, strTempPath)
-- get the uid via the serial uart console
function getUid(strPluginName, strSipperExePath, strTempPath)
    local strSerialPort
    local iGetUidResult
    local strGetUidOutput
    -- get the serial port
    strSerialPort = getSerialPort(strPluginName)
    -- load the usip file
    local strCommand = string.format('%s get_uid -p "%s"', strSipperExePath, strSerialPort)
    -- execute the command
    iGetUidResult, strGetUidOutput = executeCommand(strCommand, strTempPath)
    return iGetUidResult, strGetUidOutput
end


function kekProcess(tPlugin, strCombinedHbootPath, strTempPath)
    local ulCombinedHbootLoadAddress = 0x000203c0
    local ulOptionUsipDataLoadAddress = 0x000220c0
    local ulDataStructureAddress = 0x000220c0
    local ulHbootResultAddress
    local fOk = false
    -- seperate the image data and the option + usip from the image
    -- this is necessary because the image must be loaded to 0x000203c0
    -- and not to 0x000200c0 like the "htbl" command does. If the image is
    -- loaded to that address it is not possible to start the image, the image is broken
    local strHbootData, strMsg = tFlasherHelper.loadBin(strCombinedHbootPath)
    if strHbootData then
        -- set the path for the strHbootData
        local strHbootDataPath = path.join( strTempPath, "set_kek_data.bin")
        -- set the path for the strOptionUsipData
        local strOptionUsipDataPath = path.join( strTempPath, "opt_usip_data.bin")
        -- seperate the data
        -- get the set_kek data
        -- this is the raw programm data
        local strSetKekData = string.sub(strHbootData, 1037, 5256)
        -- get the rest of the data (options and usip (incl. the image a second time and a second usip))
        local strOptionUsipData = string.sub(strHbootData, 8193)
        -- save the data in two seperate files
        local tFile
        tFile = io.open(strHbootDataPath, "wb")
        tFile:write(strSetKekData)
        tFile:close()
        if not tFile then
            tLog.error("Could not save set_kek data to a temp file: %s.", strHbootDataPath)
        else
            tFile = io.open(strOptionUsipDataPath, "wb")
            tFile:write(strOptionUsipData)
            tFile:close()
            if not tFile then
                tLog.error("Could not save option and usip data to temp file: %s", strOptionUsipDataPath)
            else
                fOk = loadIntramImage(tPlugin, strHbootDataPath, ulCombinedHbootLoadAddress)
                if not fOk then
                    tLog.error("Could not load the intram image to address: %s", ulCombinedHbootLoadAddress)
                else
                    fOk = loadIntramImage(tPlugin, strOptionUsipDataPath, ulOptionUsipDataLoadAddress)
                    if not fOk then
                        tLog.error("Could not load the intram image to address: %s", ulOptionUsipDataLoadAddress)
                    else
                        tLog.info("Start setting KEK ...")
                        ulHbootResultAddress = tPlugin:read_data32(ulDataStructureAddress)
                        tLog.debug("Delete result register")
                        tPlugin:write_data32(ulHbootResultAddress, 0)
                        tPlugin:call(
                            ulCombinedHbootLoadAddress + 1,
                            ulDataStructureAddress,
                            flasher.default_callback_message,
                            2)
                        tLog.debug("Finished call, disconnecting")
                        tPlugin:Disconnect()
                        tLog.debug("Wait 2 seconds to be sure the set_kek process is finished")
                        sleep(2)
                        -- get the uart plugin again
                        tPlugin = tFlasherHelper.getPlugin(tPlugin:GetName(), tPlugin:GetTyp(), atPluginOptions)
                        tPlugin:Connect()
                        ulHbootResultAddress = tPlugin:read_data32(ulDataStructureAddress)
                        local ulHbootResult = tPlugin:read_data32(ulHbootResultAddress)
                        tLog.debug( "ulHbootResult: %s ", ulHbootResult )
                        ulHbootResult = bit.band(ulHbootResult, 0x107)
                        -- TODO: include description
                        if ulHbootResult == 0x107 then
                            tLog.info( "Successfully set KEK" )
                        else
                            tLog.error( "Failed to set KEK" )
                            fOk = false
                        end
                    end
                end
            end
        end
    else
        tLog.error(strMsg)
    end

    return fOk, tPlugin
end


function kekProcessViaUart(strPluginName, strSipperExePath, strCombinedHbootPath, strTempPath)
    local strUuencodedPath
    local strUuencodedData
    local strSerialPort
    local iSetKekResult
    local strSetKekOutput

    strUuencodedPath = path.join( strTempPath, "kek_hboot_comb.uue")
    strUuencodedData = uuencode(strCombinedHbootPath)
    -- open a file in binary mode
    local tFile = io.open(strUuencodedPath, "wb")
    -- check if the file exists
    if not tFile then
        strSetKekOutput = "Could not uu-encode the kek_hboot binary."
        iSetKekResult = 1
    else
        -- write all data to file
        tFile:write(strUuencodedData)
        tFile:close()
        -- get the serial port
        strSerialPort = getSerialPort(strPluginName)
        -- load the usip file
        local strCommand = string.format(
            '%s load_htbl -p "%s" -i "%s"',
            strSipperExePath,
            strSerialPort,
            strUuencodedPath
        )
        -- execute the command
        iSetKekResult, strSetKekOutput = executeCommand(strCommand, strTempPath)
        tLog.debug("Wait 2 seconds to be sure the set_kek process is finished")
        sleep(2)
    end
    return strSetKekOutput, iSetKekResult
end

-----------------------------------------------------------------------------------------------------
-- FUNCTIONS
-----------------------------------------------------------------------------------------------------
function usip(
    tPlugin,
    strTmpFolderPath,
    strUsipGenExePath,
    strSipperExePath,
    astrPathList,
    fIsSecure,
    strReadSipPath,
    strResetReadSipPath,
    strBootswitchFilePath,
    strResetBootswitchPath,
    strExecReturnFilePath,
    strResetExecReturnPath,
    strUsipConfigPath
)

    local fOk
    local strPluginType
    local strPluginName

    -- get the plugin type
    strPluginType = tPlugin:GetTyp()
    -- get plugin name
    strPluginName = tPlugin:GetName()

    --------------------------------------------------------------------------
    -- verify the signature
    --------------------------------------------------------------------------
    -- does the user want to verify the signature of the usip image?
    if tArgs.fVerifySigEnable then
        -- check if every signature in the list is correct via MI
        fOk = verifySignature(
            tPlugin, strPluginType, astrPathList, strTmpFolderPath, strSipperExePath, strVerifySigPath
        )
    else
        -- set the signature verification to automatically to true
        fOk = true
    end

    -- just continue if the verification process was a success (or not enabled)
    if fOk then
        -- iterate over the usip file path list
        for _, strSingleUsipPath in ipairs(astrPathList) do
            -- check if usip needs extended by the bootswitch with parameters
            if tArgs.strBootswitchParams then
                tLog.debug("Extending USIP file with bootswitch.")
                fOk, strSingleUsipPath, strMsg = extendBootswitch(
                    strSingleUsipPath, strTmpFolderPath, strBootswitchFilePath, tArgs.strBootswitchParams
                )
                tLog.debug(strMsg)
            else
                fOk = true
            end

            -- continue check
            if fOk then
                -- check if the usip must be extended with an exec-return chunk
                if tArgs.strBootswitchParams == "JTAG" then
                    tLog.debug("Extending USIP file with exec.")
                    fOk, strSingleUsipPath, strMsg = extendExecReturn(
                        strSingleUsipPath, strTmpFolderPath, strExecReturnFilePath
                    )
                    tLog.debug(strMsg)
                else
                    fOk = true
                end

                -- continue check
                if fOk then

                    -- load an usip file via a dedicated interface
                    fOk, tPlugin = loadUsip(strSingleUsipPath, tPlugin, strPluginType)
                    -- NOTE: be aware after the loading the netX will make a reset
                    --       but in the function the tPlugin will be reconncted!
                    --       so after the function the tPlugin is connected!

                else
                    -- this is an error message from the extendExec function
                    tLog.error(strMsg)
                end
            else
                -- this is an error message from the extendBootswitch function
                tLog.error(strMsg)
            end
        end
    end

    -- check if a last reset is necessary to activate all data inside the secure info page
    if tArgs.strForceReset and fOk then

        local ulLoadAddress = 0x20080000
        local strResetImagePath = ""
        -- connect to the netX
        tPlugin:Connect()
        -- check if a bootswitch is necessary to force a dedicated interface after a reset
        if tArgs.strBootswitchParams then
            if tArgs.strBootswitchParams == "JTAG" then
                strResetImagePath = strResetExecReturnPath
            else
                strResetImagePath = strResetBootswitchPath
            end

            fOk = loadIntramImage(tPlugin, strResetImagePath, ulLoadAddress )
        else
            tLog.debug("Just reset without any image in the intram.")
        end

        if fOk then
            resetNetx90ViaWdg(tPlugin)
            tPlugin:Disconnect()
            sleep(2)
            -- just necessary if the uart plugin in used
            -- jtag works without getting a new plugin
            if strPluginType == 'romloader_uart' then
                tPlugin = tFlasherHelper.getPlugin(tPlugin:GetName(), strPluginType, atPluginOptions)
            end
        end
    end
    -- just validate the content if the validation is enabled and no error occued during the loading process
    if fOk then
        if not tArgs.fVerifyContentDisabled then
            -- check if strResetReadSipPath is set, if it is nil set it to the default path of the read sip binary
            -- this is the case if the content should be verified without a reset at the end
            if not strResetReadSipPath then
                strResetReadSipPath = strReadSipPath
            end

            tPlugin:Connect()
            fOk = verifyContent(
                strPluginType,
                tPlugin,
                strTmpFolderPath,
                strSipperExePath,
                strUsipConfigPath,
                strResetBootswitchPath,
                strResetExecReturnPath
            )

        end
    end

    return fOk
end

function set_sip_protection_cookie(tPlugin)
    local ulStartOffset = 0
    local iBus = 2
    local iUnit = 1
    local iChipSelect = 1
    local strData
    local strMsg
    local aAttr
    local ulDeviceSize
    local flasher_path = "netx/"
    -- be pessimistic
    local fOk = false

    strFilePath = path.join( "netx", "sip", "com_default_rom_init_ff_netx90_rev2.bin")
    -- Download the flasher.
    aAttr = flasher.download(tPlugin, flasher_path, nil, nil)
    -- if flasher returns with nil, flasher binary could not be downloaded
    if not aAttr then
        tLog.error("Error while downloading flasher binary")
    else
        -- check if the selected flash is present
        fOk = flasher.detect(tPlugin, aAttr, iBus, iUnit, iChipSelect)
        if not fOk then
            tLog.error("No Flash connected!")
        else
            ulDeviceSize = flasher.getFlashSize(tPlugin, aAttr)
            if not ulDeviceSize then
                tLog.error( "Failed to get the device size!" )
            else
                -- get the data to flash
                strData, strMsg = tFlasherHelper.loadBin(strFilePath)
                if not strData then
                    tLog.error(strMsg)
                else
                    ulLen = strData:len()
                    -- if offset/len are set, we require that offset+len is less than or equal the device size
                    if ulStartOffset~= nil and ulLen~= nil and ulStartOffset+ulLen > ulDeviceSize and ulLen ~= 0xffffffff and fOk == true then
                        tLog.error( "Offset+size exceeds flash device size: 0x%08x bytes", ulDeviceSize )
                    else
                        tLog.info( "Flash device size: %d/0x%08x bytes", ulDeviceSize, ulDeviceSize )
                    end
                end
            end
        end
        if fOk then
            fOk, strMsg = flasher.eraseArea(tPlugin, aAttr, ulStartOffset, ulLen)
        end
        if fOk then
            fOk, strMsg = flasher.flashArea(tPlugin, aAttr, ulStartOffset, strData)
            if not fOk then
                tLog.error(strMsg)
            else
                fOk = true
            end
        else
            tLog.error(strMsg)
        end
    end

    return fOk
end

function set_kek(
    tPlugin,
    strTmpFolderPath,
    strUsipGenExePath,
    strSipperExePath,
    astrPathList,
    fIsSecure,
    strReadSipPath,
    strResetReadSipPath,
    strBootswitchFilePath,
    strResetBootswitchPath,
    strExecReturnFilePath,
    strResetExecReturnPath,
    strUsipConfigPath,
    strKekHbootFilePath,
    strKekDummyUsipFilePath
)

    -- be optimistic
    local fOk = true
    local strPluginType
    local strKekHbootData
    local strKekDummyUsipData
    local strKekProcessOutput
    local strCombinedImageData
    local strFillUpData
    local strFirstUsipPath
    local strUsipToExtend
    local fProcessUsip = false
    local strMsg

    -- get the plugin type
    strPluginType = tPlugin:GetTyp()
    -- get plugin name
    strPluginName = tPlugin:GetName()
    -- the signature of the dummy USIP must not be verified because the data of the USIP
    -- are repaced by the new generated KEK and so the signature will change too

    if next(astrPathList) then
        fProcessUsip = true
        tLog.debug("Found general USIP to process.")
        -- lua tables start with 1
        strFirstUsipPath = astrPathList[1]
        table.remove(astrPathList, 1)
        -- load usip data
        strFirstUsipData, strMsg = tFlasherHelper.loadBin(strFirstUsipPath)
        if not strFirstUsipData then
            tLog.error(strMsg)
            fOk = false
        end
    else
        tLog.debug("No general USIP found.")
    end

    ---------------------------------------------------------------
    -- KEK process
    ---------------------------------------------------------------
    -- load kek-image data
    strKekHbootData, strMsg = tFlasherHelper.loadBin(strKekHbootFilePath)
    if not strKekHbootData and fOk then
        tLog.error(strMsg)
    else
        -- be pessimistic
        fOk = false
        local iMaxImageSizeInBytes = 0x2000
        local iMaxOptionSizeInBytes = 0x1000
        -- combine the images with fill data
        if string.len( strKekHbootData ) > iMaxImageSizeInBytes then
            tLog.error("KEK HBoot image is to big, something went wrong.")
        else
            -- calculate the length of the fill up data
            local ulFillUpLength = iMaxImageSizeInBytes - string.len(strKekHbootData)
            -- generate the fill up data
            strFillUpData = string.rep(string.char(255), ulFillUpLength)
            -- TODO: Add comment
            strCombinedImageData = strKekHbootData .. strFillUpData
            -- set option at the end of the fillup data
            -- result register address = 0x00024FE0
            local strSetKekOptions = string.char(0x00, 0xE0, 0x05, 0x00)
            -- load address = 0x000200c0
            strSetKekOptions = strSetKekOptions .. string.char(0xC0, 0x00, 0x02, 0x00)
            -- offset
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x30)
            -- options
            -- rev_1         0x0001
            -- rev_2         0x0002
            -- reserved      0x0004
            -- reserved      0x0008
            -- process USIP  0x0010 (set ON / not set OFF)
            -- is_secure     0x0020 (set ON / not set OFF)
            -- reserved      0x0040
            -- reserved      0x0080
            if fProcessUsip then
                strSetKekOptions = strSetKekOptions .. string.char(0x11, 0x00)
                -- size of copied data
                local iCopySizeInBytes = iMaxImageSizeInBytes + string.len(strFirstUsipData) + iMaxOptionSizeInBytes
                strSetKekOptions = strSetKekOptions .. string.char(
                    bit.band(iCopySizeInBytes, 0xff)
                )
                strSetKekOptions = strSetKekOptions .. string.char(
                    bit.band(bit.rshift(iCopySizeInBytes, 8), 0xff)
                )
                strSetKekOptions = strSetKekOptions .. string.char(
                    bit.band(bit.rshift(iCopySizeInBytes, 16), 0xff)
                )
                strSetKekOptions = strSetKekOptions .. string.char(
                    bit.band(bit.rshift(iCopySizeInBytes, 24), 0xff)
                )
            else
                strSetKekOptions = strSetKekOptions .. string.char(0x01, 0x00)
                -- set not used data to zero
                strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            end
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- fill options to 1000k bytes
            strSetKekOptions = strSetKekOptions .. string.rep(
                string.char(255), iMaxOptionSizeInBytes - string.len(strSetKekOptions)
            )
            -- TODO: Add comment
            strCombinedImageData = strCombinedImageData .. strSetKekOptions
            -- USIP image have an offset of 3k from the loadaddress of the set_kek image
            if fProcessUsip then
                tLog.debug("Getting first USIP from Usiplist.")
                tLog.debug("Set general USIP as extending USIP.")
                strUsipToExtend = strFirstUsipPath
            else
                tLog.debug("Set dummy USIP as extending USIP.")
                strUsipToExtend = strKekDummyUsipFilePath
            end
            -- extend usip with bootswitch/exec_return data if necessary
            -- check if usip needs extended by the bootswitch with parameters
            if tArgs.strBootswitchParams then
                tLog.debug("Extending USIP file with bootswitch.")
                fOk, strUsipToExtend, strMsg = extendBootswitch(
                    strUsipToExtend, strTmpFolderPath, strBootswitchFilePath, tArgs.strBootswitchParams
                )
                tLog.debug(strMsg)
            else
                fOk = true
            end
            -- continue check
            if fOk then
                -- check if the usip must be extended with a exec-return chunk
                if tArgs.strBootswitchParams == "JTAG" then
                    tLog.debug("Extending USIP file with exec.")
                    fOk, strUsipToExtend, strMsg = extendExecReturn(
                        strUsipToExtend, strTmpFolderPath, strExecReturnFilePath
                    )
                    tLog.debug(strMsg)
                else
                    fOk = true
                end
                if fProcessUsip then
                    strFirstUsipPath = strUsipToExtend
                else
                    strKekDummyUsipFilePath = strUsipToExtend
                end
                if fOk then
                    -- be pessimistic
                    fOk = false
                    -- load dummyUsip data
                    strKekDummyUsipData, strMsg = tFlasherHelper.loadBin(strKekDummyUsipFilePath)
                    if not strKekDummyUsipData then
                        tLog.error(strMsg)
                    else
                        tLog.debug("Combine the HBootImage with the DummyUsip.")
                        strCombinedImageData = strCombinedImageData .. strKekDummyUsipData
                        if not fProcessUsip then
                            fOk = true
                        else
                            -- load usip data
                            strFirstUsipData, strMsg = tFlasherHelper.loadBin(strFirstUsipPath)
                            if not strFirstUsipData then
                                tLog.error(strMsg)
                            else
                                tLog.debug("Combine the extended HBootImage with the general USIP Image.")
                                -- cut the ending and extend the content without the boot header
                                -- the first 64 bytes are the boot header
                                -- cut the ending of the dummy usip
                                strCombinedImageData = string.sub( strCombinedImageData, 1, -5 )
                                -- cut the header of the hboot image and add it
                                strCombinedImageData = strCombinedImageData .. string.sub( strKekHbootData, 65 )
                                -- add the fill data
                                -- calcualte fillUp data to have the same offset to the usip file with the
                                -- combined image. 68 is the number of bytes of a cut header and a cut end
                                ulFillUpLength = iMaxImageSizeInBytes - string.len(strKekHbootData) -
                                    string.len(strKekDummyUsipData) + 68
                                strFillUpData = string.rep(string.char(255), ulFillUpLength)
                                strCombinedImageData = strCombinedImageData .. strFillUpData
                                -- set option at the end of the fillup data
                                -- result register address = 0x00024FE0
                                strSetKekOptions = string.char(0x00, 0xE0, 0x05, 0x00)
                                -- load address = 0x000200c0
                                strSetKekOptions = strSetKekOptions .. string.char(0xC0, 0x00, 0x02, 0x00)
                                -- offset
                                strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x30)
                                -- options
                                -- rev_1         0x0001
                                -- rev_2         0x0002
                                -- reserved      0x0004
                                -- reserved      0x0008
                                -- process USIP  0x0010 (set ON / not set OFF)
                                -- is_secure     0x0020 (set ON / not set OFF)
                                -- reserved      0x0040
                                -- reserved      0x0080
                                strSetKekOptions = strSetKekOptions .. string.char(0x01, 0x00)
                                -- set not used data to zero
                                strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
                                -- reserved
                                strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
                                -- reserved
                                strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
                                -- reserved
                                strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
                                -- reserved
                                strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
                                -- fill options to 1000k bytes
                                strSetKekOptions = strSetKekOptions .. string.rep(
                                    string.char(255), iMaxOptionSizeInBytes - string.len(strSetKekOptions)
                                )
                                -- add the regular usip
                                strCombinedImageData = strCombinedImageData .. strSetKekOptions .. strFirstUsipData
                                fOk = true
                            end
                        end
                        if fOk then
                            -- be pessimistic again
                            fOk = false
                            -- save the combined file into the temporary folder
                            local strKekHbootCombPath = path.join( strTmpFolderPath, "kek_hboot_comb.bin")
                            local tFile = io.open( strKekHbootCombPath, "wb" )
                            -- check if the file exists
                            if not tFile then
                                tLog.error("Could not write data to file %s.", strKekHbootCombPath)
                            else
                                -- write all data to file
                                tFile:write( strCombinedImageData )
                                tFile:close()
                                -- load the combined image to the netX
                                tLog.info( "Using %s", strPluginType )
                                fOk, tPlugin = kekProcess(tPlugin, strKekHbootCombPath, strTmpFolderPath)

                                if fOk then
                                    -- check if an input file path is set
                                    if not fProcessUsip then
                                        tLog.warning(
                                            "No input file given. All other options that are just for the usip" ..
                                            " command will be ignored."
                                        )
                                    else
                                        fOk = usip(
                                            tPlugin,
                                            strTmpFolderPath,
                                            strUsipGenExePath,
                                            strSipperExePath,
                                            astrPathList,
                                            fIsSecure,
                                            strReadSipPath,
                                            strResetReadSipPath,
                                            strBootswitchFilePath,
                                            strResetBootswitchPath,
                                            strExecReturnFilePath,
                                            strResetExecReturnPath,
                                            strUsipConfigPath
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return fOk

end

function read_sip(
    tPlugin,
    strTmpFolderPath,
    strSipperExePath,
    fIsSecure,
    strReadSipPath,
    strResetBootswitchPath,
    strResetExecReturnPath
)

    local fOk = false
    local strPluginType
    local strPluginName

    -- get the plugin type
    strPluginType = tPlugin:GetTyp()
    -- get plugin name
    strPluginName = tPlugin:GetName()

    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------
    if fIsSecure and strPluginType == "romloader_uart" then
        tLog.info( "Using the UART in secure mode..." )
        -- load a secure htbl via the native uart console mode
        local strOutput, iReadSipResult = readSipViaUart(
            strReadSipPath, strPluginName, strSipperExePath, strTmpFolderPath
        )
        if iReadSipResult == 0 then
            tLog.info(strOutput)
            fOk = true
        else
            tLog.error(strOutput)
        end
    else
        tLog.info( "Reading out SecureInfoPages via %s", strPluginType )
        local iValidCom
        local iValidApp
        local strComSipData
        local strAppSipData
        -- validate the seucre info pages
        iValidCom, iValidApp, tPlugin = validateSip(tPlugin, strResetBootswitchPath, strResetExecReturnPath)
        -- get the com sip data
        strComSipData, strAppSipData = readOutSipContent(iValidCom, iValidApp, tPlugin)
        -- check if for both sides a valid sip was found
        if strComSipData == nil or strAppSipData == nil then
            tLog.error("Unable to read out both SecureInfoPages.")
        else
            -- mask the kek
            strComSipData = string.sub(strComSipData, 1, 1856) .. string.rep(string.char(255), 192) .. string.sub(strComSipData, 2049)
            tLog.info("Saving content to files...")
            -- save the content to a file if the flag is set
            local strComSipFilePath
            local strAppSipFilePath
            -- set the sip file path to save the sip data
            strComSipFilePath = path.join( strTmpFolderPath, "com_sip.bin")
            strAppSipFilePath = path.join( strTmpFolderPath, "app_sip.bin")
            -- write the com sip data to a file
            tLog.info("Saving COM SIP to %s ", strComSipFilePath)
            local tFile = io.open(strComSipFilePath, "wb")
            tFile:write(strComSipData)
            tFile:close()
            -- write the app sip data to a file
            tLog.info("Saving APP SIP to %s ", strAppSipFilePath)
            tFile = io.open(strAppSipFilePath, "wb")
            tFile:write(strAppSipData)
            tFile:close()
            fOk = true
        end
    end

    return fOk
end

function detect_secure_mode(tPlugin,
    strTempFolderPath,
    strSipperExePath,
    fIsSecure,
    strResetBootswitchPath,
    strResetExecReturnPath
)
    local strError
    local fCallSuccess
    local fUseSerial
    local iDetectSecureResult
    local strDetectSecureOutput
    local iComSecure
    local iAppSecure
    local iValidCom
    local iValidApp
    local strPluginType
    local strPluginName

    -- get the plugin type
    strPluginType = tPlugin:GetTyp()
    -- get plugin name
    strPluginName = tPlugin:GetName()

    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------
    if fIsSecure then
        -- netX is in secure or the --force_console option is set, try directly the serial uart console interface
        -- and skip the M2M connection attempt
        fUseSerial = true
    else
        tLog.debug( "Try to open a %s connection.", strPluginType )
        -- catch the romloader error to handle it correctly
        fCallSuccess, strError = pcall(function () tPlugin:Connect() end)
        if not fCallSuccess then
            -- failed to get a M2M interface, try the serial interface
            fUseSerial = true
            tLog.debug( strError )
        else
            -- found a valid M2M interface, no need to use the serial interface
            fUseSerial = false
            iValidCom , iValidApp, tPlugin = validateSip(tPlugin, strResetBootswitchPath, strResetExecReturnPath)

            if iValidCom ~= -1 and iValidApp ~= -1 then

                local ulSecureBootFlag = 0x0004
                local ulComProtOptFlagsVal
                local ulAppProtOptFlagsVal
                if iValidCom == 1 then

                    local ulComProtOptFlagsAddr = 0x200a722c
                    ulComProtOptFlagsVal = flasher.read_image(tPlugin, ulComProtOptFlagsAddr, 0x1 ):byte(1)

                elseif iValidCom == 2 then
                    -- show the com sip
                    tPlugin:write_data32(0xff001cbc, 1)
                    -- set the copy addresses and sip size
                    local ulComProtOptFlagsAddr = 0x0018022c
                    ulComProtOptFlagsVal = flasher.read_image(tPlugin, ulComProtOptFlagsAddr, 0x1 ):byte(1)
                    -- hide the com sip
                    tPlugin:write_data32(0xff001cbc, 0)
                else
                    tLog.error("Could not find a valid Com SecureInfoPage.")
                end

                if iValidApp == 1 then

                    local ulAppProtOptFlagsAddr = 0x200a6228
                    ulAppProtOptFlagsVal = flasher.read_image(tPlugin, ulAppProtOptFlagsAddr, 0x1 ):byte(1)

                elseif iValidApp == 2 then
                    -- show the app sip
                    tPlugin:write_data32(0xff40143c, 1)
                    local ulAppProtOptFlagsAddr = 0x00200228
                    ulAppProtOptFlagsVal = flasher.read_image(tPlugin, ulAppProtOptFlagsAddr, 0x1 ):byte(1)
                    -- hide the app sip
                    tPlugin:write_data32(0xff40143c, 1)
                else
                    tLog.error("Could not find a valid App SecureInfoPage.")
                end

                -- extract secure boot flag from protection option flags
                iComSecure = bit.band( ulComProtOptFlagsVal, ulSecureBootFlag)
                iAppSecure = bit.band( ulAppProtOptFlagsVal, ulSecureBootFlag)
                -- check if com is in secure
                if iComSecure == ulSecureBootFlag and iAppSecure ~= ulSecureBootFlag then
                    tLog.debug("only COM in secure")
                    tLog.info("SECURE_BOOT_ENABLED")
                    iDetectSecureResult = 5
                -- check if only app is in secure
                elseif iComSecure ~= ulSecureBootFlag and iAppSecure == ulSecureBootFlag then
                    tLog.debug("only APP in secure")
                    tLog.info("SECURE_BOOT_ONLY_APP_ENABLED")
                    iDetectSecureResult = 50
                -- check if com and app is in secure
                elseif iComSecure == ulSecureBootFlag and iAppSecure == ulSecureBootFlag then
                    tLog.debug("COM and APP in secure")
                    tLog.info("SECURE_BOOT_ENABLED")
                    iDetectSecureResult = 5
                -- check if com and app are not in secure
                elseif iComSecure ~= ulSecureBootFlag and iAppSecure ~= ulSecureBootFlag then
                    tLog.debug("COM and APP not in secure")
                    tLog.info("SECURE_BOOT_DISABLED")
                    iDetectSecureResult = 0
                else
                    tLog.error("Could not detect secure mode")
                    iDetectSecureResult = 1
                end
            else
                tLog.error("Could not detect secure mode because com or app sip is unavailable")
                iDetectSecureResult = 1
            end
        end
    end

    -- just do this in case the M2M connection attempt failed or secure is set
    -- if the secure mode was detected via M2M this part is skipped
    if fUseSerial then
        -- check if the selected interface is a uart interface, otherwise return error result (5)
        if strPluginType ~= "romloader_uart" then
            tLog.error( "Could not open %s interface.", strPluginType )
            iDetectSecureResult = 5
        else
            if not fIsSecure then
                -- if no secure is set the M2M interface connection attempt failed,
                -- give an extra error message in this case
                tLog.debug( "Failed to connect via M2M interface." )
            end
            -- try to get the secure mode in via the serial uart console interface
            tLog.debug( "Try to use uart serial interface." )
            strDetectSecureOutput, iDetectSecureResult = detectSecure(
                strPluginName, strSipperExePath, strTempFolderPath
            )
            tLog.info( strDetectSecureOutput )
        end
    end

    return iDetectSecureResult
end

function get_uid(tPlugin, strTempFolderPath, strSipperExePath)
    local fCallSuccess
    local iGetUidResult
    local strGetUidOutput
    local strPluginType
    local strPluginName
    local fOk = false

    -- get the plugin type
    strPluginType = tPlugin:GetTyp()
    -- get plugin name
    strPluginName = tPlugin:GetName()

    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------

    tLog.debug( "Using %s interface", strPluginType )
    -- what am i doing here...
    -- catch the romloader error to handle it correctly
    fCallSuccess, strError = pcall(function () tPlugin:Connect() end)
    if fCallSuccess then
        -- get the chiptype
        iChiptype = tPlugin:GetChiptyp()
        tLog.debug( "Found Chip type: %d", iChiptype )
        -- set the addresses
        local ulUidStartAddr = 0xff40129c
        local iUidSize = 0xc
        local ulUidEndAddr = ulUidStartAddr + iUidSize -1

        local strUidVal = ""

        for ulReadAddr = ulUidStartAddr, ulUidEndAddr, 1 do
            strUidVal = strUidVal .. string.format( "%02x", flasher.read_image(tPlugin, ulReadAddr, 0x1 ):byte(1))
        end

        -- print out the complete unique ID
        tLog.info( " [UNIQUE_ID] %s", strUidVal )
        fOk = true
    else
        tLog.debug(strError)
        tLog.error( "Could not open %s interface.", strPluginType )
    end


    return fOk
end

function verify_content(
    tPlugin,
    strTempFolderPath,
    strSipperExePath,
    strUsipGenExePath,
    fIsSecure,
    strUsipFilePath,
    strReadSipPath,
    strResetBootswitchPath,
    strResetExecReturnPath
)
    local strPluginType
    local strPluginName
    local fOk = false

    -- get the plugin type
    strPluginType = tPlugin:GetTyp()
    -- get plugin name
    strPluginName = tPlugin:GetName()
    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------

    --------------------------------------------------------------------------
    -- analyze the usip file
    --------------------------------------------------------------------------

    local tResult, strErrorMsg, tUsipConfigDict = tUsipGen:analyze_usip(strUsipFilePath)
    if tResult == true then

        --------------------------------------------------------------------------
        -- verify the content
        --------------------------------------------------------------------------

        -- verify the content via the MI
        fOk = verifyContent(
            strPluginType,
            tPlugin,
            strTempFolderPath,
            strSipperExePath,
            tUsipConfigDict,
            strResetBootswitchPath,
            strResetExecReturnPath
        )

    else
        tLog.error(tUsipAnalyzeOutput)
    end

    return fOk
end

-- print args
printArgs(tArgs, tLog)

--------------------------------------------------------------------------
-- variables
--------------------------------------------------------------------------
local tPlugin
local iChiptype = nil
local strPluginType
local strPluginName
local strNetxName
local fIsSecure
local strUsipFilePath = nil
local strUsipGenExePath
local strSipperExePath



local strSecureOption
if tArgs.strSecureOption ~= nil then
    strSecureOption = path.abspath(tArgs.strSecureOption)
else
    strSecureOption = path.abspath(tFlasher.DEFAULT_HBOOT_OPTION)
end

local strReadSipPath
local strBootswitchFilePath
local strKekHbootFilePath
local strKekDummyUsipFilePath
local strExecReturnFilePath
local astrPathList = {}
local strTmpFolderPath = tempFolderConfPath
local strUsipConfigPath
local strResetExecReturnPath
local strResetBootswitchPath
local strResetReadSipPath
-- set fFinalResult to false, be pessimistic
fFinalResult = false

--------------------------------------------------------------------------
-- INITIAL VALUES
--------------------------------------------------------------------------


-- todo change this to detect_secure_mode?
-- set secure mode
if strSecureOption ~= tFlasher.DEFAULT_HBOOT_OPTION then
    fIsSecure = true
else
    fIsSecure = false
end



--------------------------------------------------------------------------
-- INITIAL CHECKS
--------------------------------------------------------------------------
-- check if the usip file exists
if tArgs.strUsipFilePath and not fileExists(tArgs.strUsipFilePath) then
    tLog.error( "Could not find file %s", tArgs.strUsipFilePath )
    -- return here because of initial error
    os.exit(1)
else
    tLog.info("Found USIP file ... ")
    strUsipFilePath = tArgs.strUsipFilePath
end


-- check for a Plugin
-- get the plugin
fCallSuccess, tPlugin = pcall(tFlasherHelper.getPlugin, tArgs.strPluginName, tArgs.strPluginType, atPluginOptionsFirstConnect)
if fCallSuccess then
    if not tPlugin then
        tLog.error('No plugin selected, nothing to do!')
        -- return here because of initial error
        os.exit(1)
    else
        -- get the plugin type
        strPluginType = tPlugin:GetTyp()
        -- get plugin name
        strPluginName = tPlugin:GetName()


        if not tArgs.fCommandDetectSelected then
            -- catch the romloader error to handle it correctly
            fCallSuccess, strError = pcall(function () tPlugin:Connect() end)
            if fCallSuccess then
                -- get the chiptype
                iChiptype = tPlugin:GetChiptyp()
                tLog.debug( "Found Chip type: %d", iChiptype )
            else
                tLog.debug(strError)
                tLog.error( "Could not open %s interface.", strPluginType )
                os.exit(1)
            end
        end
    end
else
    if tArgs.strPluginName then
        tLog.error( "Could not get selected interface -> %s.", tArgs.strPluginName )
    else
        tLog.error( "Could not get the interactive selected interface" )
    end
    -- this is a bit missleading, but in case of an error the pcall function returns as second paramater
    -- the error message. But because the first return parameter of the getPlugin function is the tPlugin
    -- the parameter name convention is a bit off ...
    tLog.error(tPlugin)
    os.exit(1)
end

-- assumption at this point:
-- * working M2M-Interface
-- * working JTAG
-- * working uart serial connection

-- these checks can only be made in non secure mode or via jtag in secure mode
if iChiptype then
    strNetxName = chiptypeToName(iChiptype)
    if not strNetxName then
        tLog.error("Can not associate the chiptype with a netx name!")
        os.exit(1)
    end
    -- check if the netX is supported
    if strNetxName ~= "netx90" then
        tLog.error("The connected netX (%s) is not supported.", strNetxName)
        tLog.error("Only netX90_rev1 and newer netX90 Chips are supported.")
        os.exit(1)
    elseif iChiptype == 14 then
        tLog.debug("Detected netX90 rev1")
        fIsRev2 = false
    elseif iChiptype == 18 then
        tLog.debug("Detected netX90 rev2")
        fIsRev2 = true
    end
else
    -- (!) TODO: FIX THIS TO A SOLUTION WHERE NOT JUST THE NETX90 IS SUPPORTED! (!)
    -- (!) TODO: provide a function to detect a netX via uart terminal mode     (!)
    strNetxName = "netx90"
    tLog.warning("Behavior is undefined if connected to a different netX then netX90!")
end

-- define special paths for reset handling
if tArgs.strForceReset then
    if tArgs.strForceReset ~= tFlasher.DEFAULT_HBOOT_OPTION then

        strResetExecReturnPath = path.join(
            tArgs.strForceReset, strNetxName, "return_exec.bin"
        )
        strResetBootswitchPath = path.join(
            tArgs.strForceReset, strNetxName, "bootswitch.bin"
        )
        strResetReadSipPath = path.join(
            tArgs.strForceReset, strNetxName, "read_sip.bin"
        )
    else
        -- todo can this be removed??
        strResetExecReturnPath = path.join(
            "netx", "hboot", "unsigned", strNetxName, "return_exec.bin"
        )
        strResetBootswitchPath = path.join(
            "netx", "hboot", "unsigned", strNetxName, "bootswitch.bin"
        )
        strResetReadSipPath = path.join(
            "netx", "hboot", "unsigned", strNetxName ,"read_sip.bin"
        )
    end
    fExists, strError = exists(strResetExecReturnPath)
    if not fExists then
        tLog.error(strError)
        -- return here because of initial error
        os.exit(1)
    end
    fExists, strError = exists(strResetBootswitchPath)
    if not fExists then
        tLog.error(strError)
        -- return here because of initial error
        os.exit(1)
    end
    fExists, strError = exists(strResetReadSipPath)
    if not fExists then
        tLog.error(strError)
        -- return here because of initial error
        os.exit(1)
    end
end

-- set read sip path

strReadSipPath = path.join(strSecureOption, strNetxName, "read_sip.bin")
-- check if the read_sip file exists
if not fileExists(strReadSipPath) then
    tLog.error( "Could not find file %s", strReadSipPath )
    -- return here because of initial error
    os.exit(1)
end

-- set verify sig path
strVerifySigPath = path.join(strSecureOption, strNetxName, "verify_sig.bin")
-- check if the verify_sig file exists
if not fileExists(strVerifySigPath) then
    tLog.error( "Could not find file %s", strVerifySigPath )
    -- return here because of initial error
    os.exit(1)
end

-- set bootswitch path
strBootswitchFilePath = path.join(strSecureOption, strNetxName, "bootswitch.bin")
-- check if the bootswitch file exists
if not fileExists(strBootswitchFilePath) then
    tLog.error( "Bootswitch binary is not available at: %s", strBootswitchFilePath )
    -- return here because of initial error
    os.exit(1)
end

if tArgs.fCommandKekSelected then
    -- set kek image paths
    strKekHbootFilePath = path.join(strSecureOption, strNetxName, "set_kek.bin")
    strKekDummyUsipFilePath = path.join(strSecureOption, strNetxName, "set_kek.usp")
    -- check if the set_kek file exists
    if not fileExists(strKekHbootFilePath) then
        tLog.error( "Set-KEK binary is not available at: %s", strKekHbootFilePath )
        -- return here because of initial error
        os.exit(1)
    end
    -- check if the dummy kek usip file exists
    if not fileExists(strKekDummyUsipFilePath) then
        tLog.error( "Dummy kek usip is not available at: %s", strKekDummyUsipFilePath )
        -- return here because of initial error
        os.exit(1)
    end
end

-- check if the ExecReturn file is necessary
if tArgs.strBootswitchParams == "JTAG" then
    -- the --extend_exec option is only supported for the jtag interface
    -- check if secure mode is active
    if strPluginType == "romloader_jtag" then
        -- set return_exec path
        strExecReturnFilePath = path.join(strSecureOption, strNetxName, "return_exec.bin")
        -- check if the execReturn file exists
        if not fileExists(strExecReturnFilePath) then
            tLog.error( "ExecReturn binary is not available at: %s", strExecReturnFilePath )
            -- return here because of initial error
            os.exit(1)
        end
    else
        tLog.error( "The --extend_exec option is only available for the JTAG interface!" )
        os.exit(1)
    end
end


-- check if valid bootswitch parameter are set
if tArgs.strBootswitchParams then
    if not (
        tArgs.strBootswitchParams == "UART" or tArgs.strBootswitchParams == "ETH" or tArgs.strBootswitchParams == "MFW" or tArgs.strBootswitchParams == "JTAG"
    ) then
        tLog.error("Wrong Bootswitch parameter, please choose between UART, ETH or MFW.")
        tLog.error("If the boot process should continue normal do not use the bootswitch parameter.")
        -- return here because of initial error
        os.exit(1)
    end
end

-- check if the executables are available

-- check for usip generator executable
strUsipGenExePath =  path.join( "ext", "USIP_Generator_CLI", "USIP_Generator_CLI")
if not fileExeExists(strUsipGenExePath) then
    tLog.error( "Can not find the USIP-Generator executable at: %s", strUsipGenExePath )
    -- return here because of initial error
    os.exit(1)
end

-- check for sipper executable
strSipperExePath =  path.join( "ext", "SIPper", "SIPper")
if not fileExeExists(strSipperExePath) then
    tLog.error( "Can not find the SIPper executable at: %s", strSipperExePath )
    -- return here because of initial error
    os.exit(1)
end

-- check if the temp folder exists, if it does not exists, create it
if not exists(strTmpFolderPath) then
    -- (!) TODO: This is not os independent! (!)
    os.execute("mkdir " .. strTmpFolderPath)
end

--------------------------------------------------------------------------
-- analyze the usip file
--------------------------------------------------------------------------
if tArgs.strUsipFilePath then
    strUsipConfigPath = path.join( strTmpFolderPath, "usip_config.json")
    -- analyze the usip file
    local tResult, strErrorMsg, tUsipConfigDict = tUsipGen:analyze_usip(strUsipFilePath)

    -- print out the command output
    -- tLog.info(tUsipAnalyzeOutput)
    -- list of all usip files
    local iGenMultiResult
    -- check if multiple usip where found
    if tResult ~= true then
        tLog.error(strErrorMsg)
        os.exit(1)
    else
        iGenMultiResult, astrPathList = genMultiUsips(strTmpFolderPath, tUsipConfigDict)
    end
end

-- check if this is a secure run
-- if the console mode is forced in non-secure mode, no signature verification is necessary
-- do not verify the signature of the helper files if the read command is selected
if fIsSecure  and not tArgs.fCommandReadSelected then
    -- verify the signature of the used HTBL files
    -- make a list of necessary files
    local tblHtblFilePaths = {}
    local fDoVerify = false
    if (tArgs.fVerifySigEnable or not tArgs.fVerifyContentDisabled) and strPluginType == "romloader_uart" then
        fDoVerify = true
        table.insert( tblHtblFilePaths, strReadSipPath )
    end
    if tArgs.strBootswitchParams then
        fDoVerify = true
        if tArgs.strBootswitchParams == "JTAG" then
            table.insert( tblHtblFilePaths, strExecReturnFilePath )
        else
            table.insert( tblHtblFilePaths, strBootswitchFilePath )
        end
    end

    if tArgs.fCommandKekSelected and strPluginType == "romloader_uart" then
        fDoVerify = true
        table.insert( tblHtblFilePaths, strKekHbootFilePath )
    end
    -- TODO: how to be sure that the verify sig will work correct?
    -- NOTE: If the verify_sig file is not signed correctly the process will fail
    -- is there a way to verify the signature of the verify_sig itself?
    -- if tArgs.fVerifySigEnable then
    --     fDoVerify = true
    --     table.insert( tblHtblFilePaths, strVerifySigPath )

    if fDoVerify then
        tLog.info("Checking signatures of support files...")

        -- check if every signature in the list is correct via MI
        fOk = verifySignature(
            tPlugin, strPluginType, tblHtblFilePaths, strTmpFolderPath, strSipperExePath, strVerifySigPath
        )

        if not fOk then
            tLog.error( "The Signatures of the support-files can not be verified." )
            tLog.error( "Please check if the supported files are signed correctly" )
            os.exit(1)
        end
    end
end

-- check if the usip command is selected
--------------------------------------------------------------------------
-- USIP COMMAND
--------------------------------------------------------------------------
if tArgs.fCommandUsipSelected then
    tLog.info("######################################")
    tLog.info("# RUNNING USIP COMMAND               #")
    tLog.info("######################################")
    fFinalResult = usip(
        tPlugin,
        strTmpFolderPath,
        strUsipGenExePath,
        strSipperExePath,
        astrPathList,
        fIsSecure,
        strReadSipPath,
        strResetReadSipPath,
        strBootswitchFilePath,
        strResetBootswitchPath,
        strExecReturnFilePath,
        strResetExecReturnPath,
        strUsipConfigPath
    )

--------------------------------------------------------------------------
-- Set SIP Command
--------------------------------------------------------------------------
elseif tArgs.fCommandSipSelected then
    tLog.info("######################################")
    tLog.info("# RUNNING SET SIP PROTECTION COMMAND #")
    tLog.info("######################################")
    fFinalResult = set_sip_protection_cookie(
        tPlugin
    )
--------------------------------------------------------------------------
-- Set Key Exchange Key
--------------------------------------------------------------------------
elseif tArgs.fCommandKekSelected then
    tLog.info("######################################")
    tLog.info("# RUNNING SET KEK COMMAND            #")
    tLog.info("######################################")
    fFinalResult = set_kek(
        tPlugin,
        strTmpFolderPath,
        strUsipGenExePath,
        strSipperExePath,
        astrPathList,
        fIsSecure,
        strReadSipPath,
        strResetReadSipPath,
        strBootswitchFilePath,
        strResetBootswitchPath,
        strExecReturnFilePath,
        strResetExecReturnPath,
        strUsipConfigPath,
        strKekHbootFilePath,
        strKekDummyUsipFilePath
    )
--------------------------------------------------------------------------
-- READ SIP
--------------------------------------------------------------------------
elseif tArgs.fCommandReadSelected then
    tLog.info("######################################")
    tLog.info("# RUNNING READ SIP COMMAND           #")
    tLog.info("######################################")
    local strOutputFolderPath

    if tArgs.strOutputFolder then
        strOutputFolderPath = tArgs.strOutputFolder
    else
        strOutputFolderPath = strTmpFolderPath
    end

    fFinalResult = read_sip(
        tPlugin,
        strOutputFolderPath,
        strSipperExePath,
        fIsSecure,
        strReadSipPath,
        strResetBootswitchPath,
        strResetExecReturnPath
    )
--------------------------------------------------------------------------
-- DETECT SECURE MODE
--------------------------------------------------------------------------
elseif tArgs.fCommandDetectSelected then
    tLog.info("######################################")
    tLog.info("# RUNNING DETECT SECURE MODE COMMAND #")
    tLog.info("######################################")
    fFinalResult = detect_secure_mode(
        tPlugin,
        strTmpFolderPath,
        strSipperExePath,
        fIsSecure,
        strResetBootswitchPath,
        strResetExecReturnPath
    )
    -- the os.exit at this point is mandatory to get a clear output of the command
    os.exit(fFinalResult)

--------------------------------------------------------------------------
-- GET UNIQUE ID
--------------------------------------------------------------------------
elseif tArgs.fCommandGetUidSelected then
    tLog.info("######################################")
    tLog.info("# RUNNING GET UID COMMAND            #")
    tLog.info("######################################")
    fFinalResult = get_uid(
        tPlugin,
        strTmpFolderPath,
        strSipperExePath
    )

    if not fFinalResult then
        os.exit(1)
    else
        os.exit(0)
    end

--------------------------------------------------------------------------
-- VERIFY CONTENT
--------------------------------------------------------------------------
elseif tArgs.fCommandVerifySelected then
    tLog.info("######################################")
    tLog.info("# RUNNINF VERIFY CONTENT COMMAND     #")
    tLog.info("######################################")
    fFinalResult = verify_content(
        tPlugin,
        strTmpFolderPath,
        strSipperExePath,
        strUsipGenExePath,
        fIsSecure,
        strUsipFilePath,
        strReadSipPath,
        strResetBootswitchPath,
        strResetExecReturnPath
    )

else
    tLog.error("No valid command. Use -h/--help for help.")
    fFinalResult = false
end

-- print OK if everything works
if fFinalResult then
    tLog.info('')
    tLog.info(' #######  ##    ## ')
    tLog.info('##     ## ##   ##  ')
    tLog.info('##     ## ##  ##   ')
    tLog.info('##     ## #####    ')
    tLog.info('##     ## ##  ##   ')
    tLog.info('##     ## ##   ##  ')
    tLog.info(' #######  ##    ## ')
    tLog.info('')
    tLog.info('RESULT: OK')
    os.exit(0)
else
    -- print ERROR if an error occurred
    tLog.error("")
    tLog.error("######## #######  #######   ######  ####### ")
    tLog.error("##       ##    ## ##    ## ##    ## ##    ##")
    tLog.error("##       ##    ## ##    ## ##    ## ##    ##")
    tLog.error("#######  #######  #######  ##    ## ####### ")
    tLog.error("##       ## ##    ## ##    ##    ## ## ##   ")
    tLog.error("##       ##  ##   ##  ##   ##    ## ##  ##  ")
    tLog.error("######## ##   ##  ##   ##   ######  ##   ## ")
    tLog.error("")
    tLog.error('RESULT: ERROR')
    os.exit(1)
end

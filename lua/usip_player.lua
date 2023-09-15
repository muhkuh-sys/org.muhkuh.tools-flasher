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
local path = require 'pl.path'
local tHelperFiles = require 'helper_files'
local tVerifySignature = require 'verify_signature'


-- uncomment for debugging with LuaPanda
-- require("LuaPanda").start("127.0.0.1",8818)

local NETX90_DEFAULT_COM_SIP_BIN = path.join(tFlasher.HELPER_FILES_PATH, "netx90", "com_sip_default_ff.bin")
local NETX90_DEFAULT_APP_SIP_BIN = path.join(tFlasher.HELPER_FILES_PATH, "netx90", "app_sip_default_ff.bin")


-- global variables
-- all supported log levels
local atLogLevels = {
    'debug',
    'info',
    'warning',
    'error',
    'fatal'
}



--------------------------------------------------------------------------
-- ArgParser
--------------------------------------------------------------------------

local strUsipPlayerGeneralHelp = [[
    The USIP-Player is a Flasher extension to modify, read-out and verify the Secure-Info-Pages on a netX90.

    The secure info pages (SIPs) are a part of the secure boot functionality of the netX90 and are not supposed
    to modify directly as a security feature. There is a SIP for the COM and a SIP for the APP side of the netX90.

    To actually modify the secure info pages a update-secure-info-page (USIP) file is necessary. These USIP files
    can be generated with the newest netX-Studio version.

    Folder structure inside flasher:
    |- flasher_cli-X.Y.Z                     -- main folder
    |- .tmp                                  -- temporary folder created by the usip_player to save temp files
    |- doc
    |- lua                                   -- more lua files
    |- lua_plugins                            -- lua plugins
    |- netx
       |- hboot                             -- hboot images, necessary for for the flasher
          |- unsigned                       -- unsigned hboot images
             |- netx90                      -- netx specific folder containing hboot images
             |- netx90_usip                 -- netx specific folder containing usip images
       |- helper
          |- netx90                         -- helper files that can't be signed

    |- lua5.4(.exe)                         -- lua executable
    |- usip_player.lua                      -- usip_player lua file


    To use the usip_player in secure mode:
        - create a dedicated folder for signed images (e.g. 'netx/hboot/signed')
        - sign the images found in netx/hboot/unsigned/netx90 with the firmware key and copy them into the signed
          folder into a subdirectory named 'netx90'( e.g. 'netx/hboot/signed/netx90')
        - sign the images found in netx/hboot/unsigned/netx90_usip with the master key and copy them into the signed
          folder into a subdirectory named 'netx90'( e.g. 'netx/hboot/signed/netx90_usip')
        - use the created folder as the handover parameter for the parameters '--sec' and '--sec_p2'

]]
local tParser = argparse('usip_player', strUsipPlayerGeneralHelp):command_target("strSubcommand")

-- Add a hidden flag to disable the version checks on helper files.
tParser:flag "--disable_helper_version_check":hidden(true)
    :description "Disable version checks on helper files."
    :action(function()
        tHelperFiles.disableHelperFileChecks()
    end)

-- Add a hidden flag to disable the version checks on helper files.
tParser:flag "--enable_temp_files":hidden(true)
    :description "Enable writing some temporary data to files for debugging."
    :action(function()
        tFlasherHelper.enableStoreTempFiles()
    end)

-- Add the "usip" command and all its options.
local strBootswitchHelp = [[
    Control the boot process after the execution of the sip update.

    Options:
     - 'UART' (Open uart-console-mode)
     - 'ETH' (Open ethernet-console-mode)
     - 'MFW' (Start MFW)
     - 'JTAG' (Use an execute-chunk to activate JTAG)
]]

-- todo change help string
local strHelpSecP2 = [[
    Path to helper files that are used after the last usip was executed.
]]


local strUsipHelp = [[
    Loads an usip file on the netX, reset the netX and process
    the usip file to update the SecureInfoPage and continue standard boot process.
]]


local tParserCommandUsip = tParser:command('usip u', strUsipHelp):target('fCommandUsipSelected')
tParserCommandUsip:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
tParserCommandUsip:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandUsip:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandUsip:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserCommandUsip:flag('--verify_sig'):description(
    "Verify the signature of an usip image against a netX, if the signature does not match, cancel the process!"
):target('fVerifySigEnable')
tParserCommandUsip:flag('--no_verify'):description(
    "Do not verify the content of an usip image against a netX SIP content after writing the usip."
):target('fVerifyContentDisabled')
tParserCommandUsip:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)

-- tParserCommandUsip:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserCommandUsip:flag('--extend_exec'):description(
--     "Extends the usip file with an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserCommandUsip:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
-- todo add more help here
tParserCommandUsip:option('--sec'):description("Path to signed image directory"):target(
    'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserCommandUsip:option('--sec_phase2 --sec_p2'):description(strHelpSecP2):target(
    'strSecureOptionPhaseTwo'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserCommandUsip:flag('--no_reset'
):description('Skip the last reset after booting an USIP. Without the reset, verifying the content is also disabled.'
):target('fDisableReset'):default(false)


-- NXTFLASHER-565
local strWriteSipsHelp = [[
    write APP and COM secure info page (SIP) based on default values
    the default values can be modified with the data from an USIP file
    the calibration values 'atTempDiode' inside the APP SIP will be updated with the values from the CAL SIP
]]
local tParserWriteSips = tParser:command('write_sips ws', strWriteSipsHelp):target('fCommandWriteSips')
tParserWriteSips:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
tParserWriteSips:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserWriteSips:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserWriteSips:option('--com_sip'):description("com SIP binary size 4kB"):target(
    'strComSipBinPath'):default(NETX90_DEFAULT_COM_SIP_BIN):hidden(true)
tParserWriteSips:option('--app_sip'):description("app SIP binary size 4kB"):target(
    'strAppSipBinPath'):default(NETX90_DEFAULT_APP_SIP_BIN):hidden(true)
tParserWriteSips:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
-- maybe keep option '--_no_verify'
tParserWriteSips:flag('--no_verify'):description(
    "Do not verify the content of an usip image against a netX SIP content after writing the usip."
):target('fVerifyContentDisabled')
tParserWriteSips:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)
tParserWriteSips:flag('--set_sip_protection')
    :description('Set the SIP protection cookie.')
    :target('fSetSipProtectionCookie')
    :default(false)
tParserWriteSips:option('--com_sip_output')
    :description('Write the generated COM SIP page to COM_OUTPUT_FILE. Do not flash it to the device.')
    :argname('<COM_OUTPUT_FILE>')
    :target('strComOutputFile')
tParserWriteSips:option('--app_sip_output')
    :description('Write the generated APP SIP page to APP_OUTPUT_FILE. Do not flash it to the device.')
    :argname('<APP_OUTPUT_FILE>')
    :target('strAppOutputFile')


-- NXTFLASHER-692
local strVerifyInitialModeHelp = [[
    verify that the netX is in an initial state which means:
    - SIP protection cookie is not set
    - secure boot mode is not enabled
    - SIPs are not hidden
    - CAL SIP rom func mode cookie is set
]]
local tParserVerifyInitialMode = tParser:command('verify_inital_mode vim', strVerifyInitialModeHelp):target('fCommandVerifyInitialMode')
tParserVerifyInitialMode:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
tParserVerifyInitialMode:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserVerifyInitialMode:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserVerifyInitialMode:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserVerifyInitialMode:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)

-- NXTFLASHER-603
-- NXTFLASHER-550

-- Add the "disable_security" command and all its options.
local strDisableSecurityHelp = [[
    Disable security settings at COM and APP SIPs.

    The following parameters will be set:
    COM SIP:
    - Security Access Level (SAL): OFF
    - Secure Boot Mode (SBM) :     OFF
    - SIP will be copied
    - SIP will be visible
    - (ENABLE_MI_UART_IN_SECURE :  OFF)  reserved for netX 90 rev2

    APP SIP:
    - Security Access Level (SAL): OFF
    - Secure Boot Mode (SBM) :     OFF
    - SIP will be copied
    - SIP will be visible
    - (ASIG_SIGNED_BINDING :       OFF) reserved for netX 90 rev2

]]

local tParserCommandDisableSecurity = tParser:command('disable_security ds', strDisableSecurityHelp):target(
    'fCommandDisableSecurity')
tParserCommandDisableSecurity:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandDisableSecurity:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandDisableSecurity:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserCommandDisableSecurity:flag('--no_verify_usip_sig'):description(
    "Do not verify the signature of the usip images against a netX; if the signature does not match, cancel the process!"
):target('fVerifyUsipSigDisable')
tParserCommandDisableSecurity:flag('--no_verify_sip_content'):description(
    "Do not verify the content of an usip image against a netX SIP content after writing the usip."
):target('fVerifySipContentDisabled')
tParserCommandDisableSecurity:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
-- todo add more help here
tParserCommandDisableSecurity:option('--sec'):description("Path to signed helper image directory"):target(
    'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserCommandDisableSecurity:flag('--no_reset'
):description('Skip the last reset after booting an USIP. Without reset, verifying the content is also disabled.'
):target('fDisableReset'):default(false)
tParserCommandDisableSecurity:option('--signed_usip'):description("Path to the signed USIP file"):target(
    'strUsipFilePath'):default(path.join("netx", "hboot", "unsigned", "netx90_usip", "disable_security_settings.usp"))



-- Add the "set_sip_protection" command and all its options.
local strSetSipProtectionHelp = [[
    Set the SipProtectionCookie, enable protection of SIPs.

    The default COM SIP page for netX 90 rev2 is written.

    That means all of the following parameter will be overwritten:
    - remove secure boot mode
    - remove all keys
    - remove protection level => set to protection level 0 := open mode
    - Enable all ROOT ROMkeys
    - remove protection option flags
        - SIPs will not be copied
        - SIPs will be visible
    - update counter will be reset to zero
]]

local tParserCommandSip = tParser:command('set_sip_protection ssp', strSetSipProtectionHelp):target(
    'fCommandSipSelected')
tParserCommandSip:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandSip:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserCommandSip:option('-p --plugin_name'):description("plugin name"):target('strPluginName')


-- Add the "set_kek" command and all its options.
local strSetKekHelp = [[
    Set the KEK (Key exchange key).
    If the input parameter is set an usip file is afterwards loaded on the netX,
    reset the netX and process \n the usip file to update the SecureInfoPage and
    continue standard boot process.
]]
local tParserCommandKek = tParser:command('set_kek sk', strSetKekHelp):target('fCommandKekSelected')
tParserCommandKek:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
tParserCommandKek:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandKek:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandKek:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserCommandKek:flag('--verify_sig'):description(
    "Verify the signature of an usip image against a netX, if the signature does not match, cancel the process!"
):target('fVerifySigEnable')
tParserCommandKek:flag('--no_verify'):description(
    "Do not verify the content of an usip image against a netX."
):target('fVerifyContentDisabled')
tParserCommandKek:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)
-- tParserCommandKek:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserCommandKek:flag('--extend_exec'):description(
--     "Extends the usip file with an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserCommandKek:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserCommandKek:option('--sec'):description("Path to signed image directory"):target('strSecureOption'
):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserCommandKek:option('--sec_phase2 --sec_p2'):description(strHelpSecP2):target('strSecureOptionPhaseTwo'
):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserCommandKek:flag('--no_reset'
):description('Skip the last reset after booting an USIP. Without the reset, verifying the content is also disabled.'
):target('fDisableReset'):default(false)
-- Add the "verify_content" command and all its options.
local strVerifyHelp = [[
    Verify the content of a usip file against the content of a secure info page
]]
local tParserVerifyContent = tParser:command('verify v', strVerifyHelp):target('fCommandVerifySelected')
tParserVerifyContent:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserVerifyContent:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserVerifyContent:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserVerifyContent:option('-i --input'):description("USIP binary file path"):target('strUsipFilePath')
-- tParserVerifyContent:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
-- tParserVerifyContent:flag('--extend_exec'):description(
--     "Use an execute-chunk to activate JTAG."
-- ):target('fExtendExec')
tParserVerifyContent:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserVerifyContent:option('--sec'):description("Path to signed image directory"):target(
    'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserVerifyContent:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)

local strCheckCookieHelp = [[
    Check if the SIP protection cookie is set
]]
local tParserCheckSIPCookie = tParser:command('detect_sip_protection dsp', strCheckCookieHelp):target(
    'fCommandCheckSIPCookie')
tParserCheckSIPCookie:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCheckSIPCookie:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserCheckSIPCookie:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCheckSIPCookie:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserCheckSIPCookie:option('--sec'):description("Path to signed image directory"):target(
    'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserCheckSIPCookie:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)

-- Add the "read_sip" command and all its options.
local strReadHelp = [[
    Read out the sip content and save it into a temporary folder
]]
local tParserReadSip = tParser:command('read r', strReadHelp):target('fCommandReadSelected')
tParserReadSip:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserReadSip:argument('output'):description(
    "Set the output directory."
):target("strOutputFolder")
tParserReadSip:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserReadSip:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserReadSip:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserReadSip:option('--sec'):description("Path to signed image directory"):target(
    'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserReadSip:flag('--read_cal'):description(
        "additional read out and store the cal secure info page"):target('fReadCal')
tParserReadSip:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)


-- Add the "detect_secure_mode" command and note, that it is moved to "cli_flash.lua"

local strDetectSecureModeHelp = [[
This command was moved into cli_flash.lua.
]]
tParser:command(
    'detect_secure_mode', strDetectSecureModeHelp
):target('fCommandDetectSelected')


-- Add the "get_uid" command and all its options.
local tParserGetUid = tParser:command('get_uid gu', 'Get the unique ID.'):target('fCommandGetUidSelected')
tParserGetUid:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserGetUid:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserGetUid:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserGetUid:option('--bootswitch'):description(strBootswitchHelp):target('strBootswitchParams')
tParserGetUid:option('--sec'):description("Path to signed image directory"):target(
    'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
tParserGetUid:flag('--disable_helper_signature_check')
    :description('Disable signature checks on helper files.')
    :target('fDisableHelperSignatureChecks')
    :default(false)

-- Add command check_helper_signature chs
local tParserCommandVerifyHelperSig = tParser:command('check_helper_signature chs', strUsipHelp):target(
    'fCommandCheckHelperSignatureSelected')
tParserCommandVerifyHelperSig:option(
    '-V --verbose'
):description(
    string.format(
        'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
    )
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandVerifyHelperSig:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandVerifyHelperSig:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
tParserCommandVerifyHelperSig:option('--sec'):description("Path to signed image directory"):target(
    'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)


-- parse args
local tArgs = tParser:parse()

if tArgs.strSecureOption == nil then
    tArgs.strSecureOption = tFlasher.DEFAULT_HBOOT_OPTION
end
if tArgs.strSecureOptionPhaseTwo == nil then
    tArgs.strSecureOptionPhaseTwo = tFlasher.DEFAULT_HBOOT_OPTION
end
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
require("romloader_eth")
require("romloader_uart")
require("romloader_jtag")

-- options for the jtag plugin
-- with this option the jtag plug does no soft or hard reset in the connect routine of the jtag interface plugin
-- the jtag just attach to a device. This is necessary in case secure boot is enabled via an usip file. If the
-- jtag plugin would perform a reset the usip flags would directly be activated and it could be possible that
-- the debugging is disabled and the jtag is no longer available.

-- options for the UART plugin
-- Pass a boot image that starts the machine interface if the netx is in the UART terminal console.
local strMsg
local strnetX90M2MImageBin
local strnetX90HelperPath

local strnetX90HelperPath = path.join(tArgs.strSecureOption, "netx90")
local strnetX90M2MImageBin, strMsg = tHelperFiles.getHelperFile(strnetX90HelperPath, "start_mi")

if strnetX90M2MImageBin == nil then
    tLog.info(strMsg or "Error: Failed to load netX 90 M2M image (unknown error)")
    os.exit(1)
end

local atPluginOptions = {
    romloader_jtag = {
    jtag_reset = "Attach", -- HardReset, SoftReset or Attach
    jtag_frequency_khz = 6000 -- optional
    },
    romloader_uart = {
    netx90_m2m_image = strnetX90M2MImageBin,
    }
}

local atResetPluginOptions

if tArgs.strSecureOption ~= tArgs.strSecureOptionPhaseTwo then
    local strNetX90ResetM2MImageBin
    local strNetX90ResetM2MImagePath

    strNetX90ResetM2MImagePath = path.join(tArgs.strSecureOptionPhaseTwo,
     "netx90", "hboot_start_mi_netx90_com_intram.bin")
    tLog.info("Trying to load netX 90 M2M image from %s", strNetX90ResetM2MImagePath)
    strNetX90ResetM2MImageBin, strMsg = tFlasherHelper.loadBin(strNetX90ResetM2MImagePath)
    if strNetX90ResetM2MImageBin then
        tLog.info("%d bytes loaded.", strNetX90ResetM2MImageBin:len())
    else
        tLog.info("Error: Failed to load netX 90 M2M image: %s", strMsg or "unknown error")
        os.exit(1)
    end

    atResetPluginOptions = {
        romloader_jtag = {
        jtag_reset = "Attach", -- HardReset, SoftReset or Attach
        jtag_frequency_khz = 6000 -- optional
        },
        romloader_uart = {
        netx90_m2m_image = strNetX90ResetM2MImageBin,
        }
    }
else
    atResetPluginOptions = atPluginOptions
end

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
    },
    romloader_uart = {
    netx90_m2m_image = strnetX90M2MImageBin
    }
}

--------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------



local function check_file(strFilePath)
    tLog.info("Checking if file exists: %s", strFilePath)
    if not path.exists(strFilePath) then
        tLog.error( "Could not find file %s", strFilePath)
        -- return here because of initial error
        os.exit(1)
    end
    tLog.info("found it!")
end


-- exists(folder)
-- check if a folder exists
-- returns true if the folder exists, otherwise false and an error message
local function exists(folder)
    local ok, err, code = os.rename(folder, folder)
    if not ok then
       if code == 13 then
          -- Permission denied, but it exists
          return true, "permission denied"
       end
    end
    return ok, err
end


-- printTable(tTable, ulIndent)
-- Print all elements from a table
-- returns
--   nothing
local function printTable(tTable, ulIndent)
    local strIndentSpace = string.rep(" ", ulIndent)
    for key, value in pairs(tTable) do
        if type(value) == "table" then
            tLog.info( "%s%s",strIndentSpace, key )
            printTable(value, ulIndent + 4)
        else
            tLog.info( "%s%s%s%s",strIndentSpace, key, " = ", tostring(value) )
        end
    end
    if next(tTable) == nil then
        tLog.info( "%s%s",strIndentSpace, " -- empty --" )
    end
end


-- printArgs(tArguments)
-- Print all arguments in a table
-- returns
--   nothing
local function printArgs(tArguments)
    tLog.info("")
    tLog.info("run usip_player.lua with the following args:")
    tLog.info("--------------------------------------------")
    printTable(tArguments, 0)
    tLog.info("")
end


-- strNetxName chiptypeToName(iChiptype)
-- transfer integer chiptype into a netx name
-- returns netX name as a string otherwise nil
local function chiptypeToName(iChiptype)
    local romloader = _G.romloader
    local strNetxName
    -- First catch the unlikely case that "iChiptype" is nil.
	-- Otherwise each ROMLOADER_CHIPTYP_* which is also nil will match.
	if iChiptype==romloader.ROMLOADER_CHIPTYP_NETX500 or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX100 then
		strNetxName = 'netx500'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX50 then
		strNetxName = 'netx50'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX10 then
		strNetxName = 'netx10'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX56 or iChiptype==romloader.ROMLOADER_CHIPTYP_NETX56B then
		strNetxName = 'netx56'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX4000_RELAXED or
            iChiptype==romloader.ROMLOADER_CHIPTYP_NETX4000_FULL or
            iChiptype==romloader.ROMLOADER_CHIPTYP_NETX4100_SMALL then
		strNetxName = 'netx4000'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90_MPW then
		strNetxName = 'netx90_mpw'
    elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90 then
		strNetxName = 'netx90_rev_0'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or
            iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C or
            iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D or
            iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D_INTRAM then
		strNetxName = 'netx90'
	elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETIOLA or
            iChiptype==romloader.ROMLOADER_CHIPTYP_NETIOLB then
		strNetxName = 'netiol'
    else
        strNetxName = nil
	end
    return strNetxName
end


--------------------------------------------------------------------------
-- loading images
--------------------------------------------------------------------------


local function loadDataToIntram(tPlugin, strData, ulLoadAddress)
    tLog.debug( "Loading image to 0x%08x", ulLoadAddress )
    -- write the image to the netX
    tFlasher.write_image(tPlugin, ulLoadAddress, strData)
    tLog.info("Writing image complete!")
    return true
end

-- LoadImage(tPlugin, strPath, ulLoadAddress, fnCallbackProgress)
-- load an image to a dedicated address
-- returns nothing, in case of a romlaoder error MUHKUH_PLUGIN_ERROR <- ??
local function loadImage(tPlugin, strPath, ulLoadAddress)
    local fResult = false
    if path.exists(strPath) then
        tLog.info( "Loading image path: '%s'", strPath )

        -- get the binary data from the file
        local tFile, strMsg = io.open(strPath, 'rb')
        -- check if the file exists
        if tFile then
            -- read out all the binary data
            local strFileData = tFile:read('*all')
            tFile:close()
            if strFileData ~= nil and strFileData ~= "" then
                fResult = loadDataToIntram(tPlugin, strFileData, ulLoadAddress)
            else
                tLog.error( "Could not read from file %s", strPath )
            end
        -- error message if the file does not exist
        else
            tLog.error( 'Failed to open file "%s" for reading: %s', strPath, strMsg )
        end
    end
    return fResult
end


-- fResult loadUsipImage(tPlugin, strPath, fnCallbackProgress)
-- Load an USIP image to 0x000200C0
-- return true if the image was loaded correctly otherwise false
local function loadUsipImage(tPlugin, strPath, fnCallbackProgress)
    local fResult
    -- this address is necessary for the new usip commands in the MI-Interfaces
    local ulLoadAddress = 0x000200C0
    fResult = loadImage(tPlugin, strPath, ulLoadAddress)
    return fResult
end


-- fResult LoadIntramImage(tPlugin, strPath, ulLoadAddress)
-- Load an image in the intram to probe it after an reset
-- intram3 address is 0x20080000
-- return true if the image was loaded correctly otherwise false
local function loadIntramImage(tPlugin, strPath, ulIntramLoadAddress)
    local fResult
    local ulLoadAddress
    if ulIntramLoadAddress  then
        ulLoadAddress = ulIntramLoadAddress
    else
        -- this address is the intram 3 address. This address will be probed at the startup
        ulLoadAddress = 0x20080000
    end
    fResult = loadImage(tPlugin, strPath, ulLoadAddress)

    return fResult
end


-- resetNetx90ViaWdg(tPlugin)
-- make a reset via the WatchDog of the netX90, the reset will be triggert after 1 second
-- returns
--   nothing
local function resetNetx90ViaWdg(tPlugin)
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


-- execBinViaIntram(tPlugin, strFilePath, ulIntramLoadAddress)
-- loads an image into the intram, flushes the data and reset via watchdog
-- returns
--    nothing
local function execBinViaIntram(tPlugin, strUsipData, ulIntramLoadAddress)
    local fResult
    local ulLoadAddress
    if ulIntramLoadAddress == nil then
        ulLoadAddress = 0x20080000
    else
        ulLoadAddress = ulIntramLoadAddress
    end
        -- load an image into the intram
    fResult = loadDataToIntram(tPlugin, strUsipData ,ulLoadAddress)

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

        -- resetNetx90ViaWdg(tPlugin)
        tFlasherHelper.reset_netx_via_watchdog(nil, tPlugin)
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
-- The header is not relevant at this point, because the header of the usip file is just checked once if
-- the hash is correct and is not relevant for the usip process
-- returns a list of all generated usip file paths and the output of the command
local function genMultiUsips(strTmpFolderPath, tUsipConfigDict)
    local tResult
    local aDataList
    local tUsipNames
    -- list of all generated usip file paths
    if tFlasherHelper.getStoreTempFiles() then
        tResult, aDataList, tUsipNames = tUsipGen:gen_multi_usip_hboot(tUsipConfigDict, strTmpFolderPath)
    else
        aDataList, tUsipNames = tUsipGen:gen_multi_usip(tUsipConfigDict)
        tResult = true
    end
    

    return tResult, aDataList, tUsipNames
end



local function extendBootswitchData(strUsipData, strTmpFolderPath, strBootswitchParam)
    -- result variable, be pessimistic
    local fResult = false
    local strMsg
    local strBootswitchData
    local strBootSwitchOnlyPornParam
    local strCombinedUsipPath
    local strUsipData = strUsipData

    -- read the bootswitch content
    -- print("Appending Bootswitch ... ")
    -- strBootswitchData, strMsg = tFlasherHelper.loadBin(strBootswitchFilePath)
    strBootswitchData, strMsg = tHelperFiles.getHelperFile(strnetX90HelperPath, "bootswitch")
    if strBootswitchData == nil then
        tLog.info(strMsg or "Error: Failed to load bootswitch (unknown error)")
        os.exit(1)
    end
    -- note: the case that bootswitch cannot be found/loaded is not handled.
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
            if tFlasherHelper.getStoreTempFiles() then
                -- only store temporary file when it is enabled
                strCombinedUsipPath = path.join( strTmpFolderPath, "combined.usp")  -- todo use handover parameter for file name
                -- write the data back to the usip binary file
                local tFile
                tFile = io.open(strCombinedUsipPath, "wb")
                tFile:write(strUsipData)
                tFile:close()
            end
            fResult = true
            strMsg = "Extendet bootswitch."
        else
            strUsipData = nil
            strMsg = "The combined image exceeds the size of 32kB. Choose a smaller USIP file!"
        end
    end

    return fResult, strUsipData, strMsg
end


-- fResult, strMsg extendBootswitch(strUsipPath, strTmpFolderPath, strBootswitchFilePath, strBootswitchParam)
-- extend the usip file with the bootswitch and the bootswitch parameter
-- the bootswitch supports three console interfaces, ETH, UART and MFW
-- more information about the bootswitch can be found in the KB: https://kb.hilscher.com/x/CcBwBw
-- more information about the bootswitch in combination with an usip can be found in the
-- KB: https://kb.hilscher.com/x/0s2gBw
-- returns true, nil if everything went right, else false and a error message
local function extendBootswitch(strUsipPath, strTmpFolderPath, strBootswitchParam)
    local fResult = false

    -- read the usip content
    -- print("Loading USIP content ... ")
    local strUsipData, strMsg = tFlasherHelper.loadBin(strUsipPath)
    if strUsipData then
        fResult, strUsipData, strMsg = extendBootswitchData(strUsipData, strTmpFolderPath, strBootswitchParam)
    else
        tLog.info(strMsg or "Error: Failed to load '%s'", strUsipPath)
    end

    return fResult, strUsipData, strMsg
end


local function extendExecReturnData(strUsipData, strTmpFolderPath, strExecReturnFilePath, strOutputFileName)
    local fResult = false
    local strMsg
    local strExecReturnData
    local strCombinedUsipPath
    local strUsipData = strUsipData


    -- read the exec-return content
    strExecReturnData = tFlasherHelper.loadBin(strExecReturnFilePath)
    if strExecReturnData then
        -- cut the usip image ending and extend the exec-return content without the boot header
        -- the first 64 bytes are the boot header
        -- todo: find better way to strip the last 0 values (end indication of hboot image)
        strUsipData = string.sub( strUsipData, 1, -5 ) .. string.sub( strExecReturnData, 65 )
        if tFlasherHelper.getStoreTempFiles() then
            -- set combined file path
            if strOutputFileName == nil then
                strCombinedUsipPath = path.join( strTmpFolderPath, "combined.usp")
            else
                strCombinedUsipPath = path.join( strTmpFolderPath, strOutputFileName)
            end
            -- write the data back to the usip binary file
            local tFile
            tFile = io.open(strCombinedUsipPath, "wb")
            tFile:write(strUsipData)
            tFile:close()
        end

        fResult = true
        strMsg = "Extended exec-return."
    else
        strMsg = "Can not read out the exec-return binary data."
    end


    return fResult, strUsipData, strMsg
end


-- fOk, strSingleUsipPath, strMsg extendExecReturn(strUsipPath, strTmpFolderPath, strExecReturnFilePath)
-- extend the usip file with an exec chunk that return immediately and activated the debugging
-- returns true and the file path to the combined file in case no error occur, otherwith an false and nil
-- returns always a info message.
local function extendExecReturn(strUsipPath, strTmpFolderPath, strExecReturnFilePath, strOutputFileName)
    local fResult = false
    local strMsg
    local strUsipData
       -- read the usip content
    strUsipData = tFlasherHelper.loadBin(strUsipPath)
    if strUsipData then
        fResult, strUsipData, strMsg = extendExecReturnData(
                strUsipPath, strTmpFolderPath,
                strExecReturnFilePath, strOutputFileName)
    else
        strMsg = "Can not read out the usip data."
    end

    return fResult, strUsipData, strMsg
end


-- tPlugin loadUsip(strFilePath, tPlugin, strPluginType)
-- loading an usip file
-- loads an usip file via a dedicated interface and checks if the chiptype is supported
-- returns the plugin, in case of a uart connection the plugin must be updated and a new plugin is returned

local function loadUsip(strUsipData, tPlugin, strPluginType)

    local ulRetries = 5
    local strError

    local fOk
    tLog.info( "Loading Usip via %s", strPluginType )

    fOk, strError = tFlasherHelper.connect_retry(tPlugin, 5)
    if fOk == false then
        tLog.error(strError)
    end
    local strPluginName = tPlugin:GetName()

    local ulM2MMinor = tPlugin:get_mi_version_min()
    local ulM2MMajor = tPlugin:get_mi_version_maj()
    if ulM2MMajor == 3 and ulM2MMinor >= 1 then
        local ulUsipLoadAddress = 0x200C0
        loadDataToIntram(tPlugin, strUsipData ,ulUsipLoadAddress)
        tFlasher.call_usip(tPlugin)
        fOk = true
    else
        -- we have a netx90 with either jtag or M2M interface older than 3.1
        if strPluginType == 'romloader_jtag' or strPluginType == 'romloader_uart' then
            fOk = execBinViaIntram(tPlugin, strUsipData)

        elseif strPluginType == 'romloader_eth' then
            -- netX90 rev_1 and ethernet detected, this function is not supported
            tLog.error("The current version does not support the Ethernet in this feature!")
        else
            tLog.error("Unknown plugin type '%s'!", strPluginType)
        end
    end

    if fOk then
        tPlugin:Disconnect()
        tFlasherHelper.sleep_s(3)
        -- get the jtag plugin with the attach option to not reset the netX

        while ulRetries > 0 do
            tPlugin = tFlasherHelper.getPlugin(strPluginName, strPluginType, atPluginOptions)
            ulRetries = ulRetries-1
            if tPlugin ~= nil then
                break
            end
            tFlasherHelper.sleep_s(1)  -- todo use the same sleep everywhere
        end
    end

    if tPlugin == nil then
        fOk = false
        tLog.error("Could not get plugin again")
    end
    return fOk, tPlugin
end




local function readSip(strHbootPath, tPlugin, strTmpFolderPath, atPluginOptions, strExecReturnPath)
    local fResult = true
    local strErrorMsg = ""

    local ulHbootLoadAddress = 0x000200c0
    local ulDataLoadAddress = 0x60000
    local ulReadSipDataAddress = 0x00062000

    -- magic cookie address to check if the result is valid
    local ulReadSipMagicAddress = 0x00065004
    local MAGIC_COOKIE_INIT = 0x5541494d    -- magic cookie used for initial identification
    local MAGIC_COOKIE_END = 0x464f4f57     -- magic cookie used for identification */

    -- read sip result address and bit masks to interprate the result
    local ulReadSipResultAddress = 0x00065000
    local COM_SIP_CPY_VALID_MSK = 0x0001
    local COM_SIP_VALID_MSK = 0x0002
    local COM_SIP_INVALID_MSK = 0x0010
    local APP_SIP_CPY_VALID_MSK = 0x0100
    local APP_SIP_VALID_MSK = 0x0200
    local APP_SIP_INVALID_MSK = 0x1000

    local ulReadUUIDAddress = 0x00061ff0

    local ulM2MMajor = tPlugin:get_mi_version_maj()
    local ulM2MMinor = tPlugin:get_mi_version_min()
    local strPluginType = tPlugin:GetTyp()

    local ulReadSipResult

    local strCalSipData
    local strComSipData
    local strAppSipData
    local aStrUUIDs = {}

    local uLRetries = 5

    local strPluginName = tPlugin:GetName()
    local strReadSipData = tFlasherHelper.loadBin(strHbootPath)

    local fOk
    if tArgs.strBootswitchParams ~= nil and tArgs.strBootswitchParams ~= "JTAG" then
        tLog.debug("Extending USIP file with bootswitch.")
        fOk, strReadSipData, strMsg = extendBootswitchData(
            strReadSipData, strTmpFolderPath, tArgs.strBootswitchParams
        )
        tLog.debug(strMsg)
    elseif tArgs.strBootswitchParams == "JTAG" or
     (strPluginType == 'romloader_jtag' and  tArgs.strBootswitchParams == nil) then
        tLog.debug("Extending USIP file with exec.")
        -- todo why do we still hand over the path (strExecReturnPath) instead of using helper files method
        fOk, strReadSipData, strMsg = extendExecReturnData(
            strReadSipData, strTmpFolderPath, strExecReturnPath
        )
    else
        -- tLog.debug(strMsg)
        fOk = true
    end


    -- get verify sig program data only

    if strReadSipData then
        tLog.info("download read_sip hboot image to 0x%08x", ulHbootLoadAddress)
        tFlasher.write_image(tPlugin, ulHbootLoadAddress, strReadSipData)


        -- reset the value of the read sip result address
        tLog.info("reset the value of the read sip result address 0x%08x", ulReadSipResultAddress)
        tPlugin:write_data32(ulReadSipResultAddress, 0x00000000)
        tPlugin:write_data32(ulReadSipMagicAddress, 0x00000000)

        if strPluginType == 'romloader_jtag' or strPluginType == 'romloader_uart' or strPluginType == 'romloader_eth' then
            if ulM2MMajor == 3 and ulM2MMinor >= 1 then
                -- M2M protocol for rev2
                tLog.info("Start read sip hboot image inside intram")
                tFlasher.call_hboot(tPlugin, nil, true)
            elseif strPluginType ~= 'romloader_jtag' then
                -- M2M protocol for rev1
                tLog.info("download the split data to 0x%08x", ulDataLoadAddress)
                local strReadSipDataSplit = string.sub(strReadSipData, 0x40D)
                -- reset the value of the read sip result address
                tFlasher.write_image(tPlugin, ulDataLoadAddress, strReadSipDataSplit)

                tLog.info("Start read sip binary via call no answer")
                tFlasher.call_no_answer(
                        tPlugin,
                        ulDataLoadAddress + 1,
                        ulReadSipResultAddress
                )
            else
                -- jtag interface for all versions
                tLog.info("download the split data to 0x%08x", ulDataLoadAddress)
                local strReadSipDataSplit = string.sub(strReadSipData, 0x40D)
                -- reset the value of the read sip result address
                tFlasher.write_image(tPlugin, ulDataLoadAddress, strReadSipDataSplit)
                tLog.info("Start read sip binary via call")
                tFlasher.call(
                        tPlugin,
                        ulDataLoadAddress + 1,
                        ulReadSipResultAddress
                )
            end

            tLog.info("Disconnect from Plugin and reconnect again")
            -- can there be timing issues with different OS
            tPlugin:Disconnect()
            -- wait at least 2 sec for signature verification of read sip binary
            tFlasherHelper.sleep_s(3)

            while uLRetries > 0 do
                tLog.info("try to get the Plugin again after read sip reset")
                -- tPlugin = tFlasherHelper.getPlugin(strPluginName, strPluginType, atPluginOptions)
                local fCallSuccess
                fCallSuccess, tPlugin = pcall(
                        tFlasherHelper.getPlugin, strPluginName, strPluginType, atPluginOptions)
                if fCallSuccess then
                    break
                end
                uLRetries = uLRetries - 1
                tFlasherHelper.sleep_s(1)
            end

            if tPlugin then
                tFlasherHelper.connect_retry(tPlugin, 10)

            else
                strErrorMsg = "Could not reach plugin after reset"
                fResult = false
            end
            local ulMagicResult
            if fResult then
                ulMagicResult = tPlugin:read_data32(ulReadSipMagicAddress)
                if ulMagicResult == MAGIC_COOKIE_END then
                    fResult = true
                    tLog.info("Found MAGIC_COOKIE_END")
                elseif ulMagicResult == MAGIC_COOKIE_INIT then
                    tLog.info("Read sip is not done yet! Wait a second")
                    tFlasherHelper.sleep_s(1)
                    fResult = false
                else
                    strErrorMsg = "Could not find MAGIC_COOKIE"
                    fResult = false
                end
            end
            if fResult then
                ulReadSipResult = tPlugin:read_data32(ulReadSipResultAddress)
                if ((ulReadSipResult & COM_SIP_CPY_VALID_MSK) ~= 0 or (ulReadSipResult & COM_SIP_VALID_MSK) ~= 0) and
                        ((ulReadSipResult & APP_SIP_CPY_VALID_MSK) ~= 0 or (ulReadSipResult & APP_SIP_VALID_MSK) ~= 0) then
                    strCalSipData = tFlasher.read_image(tPlugin, ulReadSipDataAddress, 0x1000)
                    strComSipData = tFlasher.read_image(tPlugin, ulReadSipDataAddress + 0x1000, 0x1000)
                    strAppSipData = tFlasher.read_image(tPlugin, ulReadSipDataAddress + 0x2000, 0x1000)

                    aStrUUIDs[1] = tFlasherHelper.switch_endian(tPlugin:read_data32(ulReadUUIDAddress))
                    aStrUUIDs[2] = tFlasherHelper.switch_endian(tPlugin:read_data32(ulReadUUIDAddress + 4))
                    aStrUUIDs[3] = tFlasherHelper.switch_endian(tPlugin:read_data32(ulReadUUIDAddress + 8))
                elseif (ulReadSipResult & COM_SIP_INVALID_MSK) ~= 0 then
                    strErrorMsg = "Could not get a valid copy of the COM SIP"
                    fResult = false
                elseif (ulReadSipResult & APP_SIP_INVALID_MSK) ~= 0 then
                    strErrorMsg = "Could not get a valid copy of the APP SIP"
                    fResult = false
                end
            end
        else
            strErrorMsg = string.format("Unsupported plugin type '%s'", strPluginType)
            fResult = false
        end
    end
    return fResult, strErrorMsg, strCalSipData, strComSipData, strAppSipData, aStrUUIDs
end


-- fOk verifyContent(strPluginType, tPlugin, strTmpFolderPath, strSipperExePath, strUsipConfigPath)
-- compare the content of a usip file with the data in a secure info page to verify the usip process
-- returns true if the verification process was a success, otherwise false
local function verifyContent(
    strPluginType,
    tPlugin,
    strTmpFolderPath,
    strReadSipPath,
    tUsipConfigDict,
    atPluginOptions,
    strExecReturnPath
)
    local uVerifyResult = tSipper.VERIFY_RESULT_OK

    tLog.info("Verify USIP content ... ")
    tLog.debug( "Reading out SecureInfoPages via %s", strPluginType )
    -- validate the seucre info pages
    -- it is important to return the plugin at this point, because of the reset the romload_uart plugin
    -- changes

    -- get the com sip data -- todo add bootswitch here?
    local fOk, strErrorMsg, _, strComSipData, strAppSipData, _ = readSip(
        strReadSipPath, tPlugin, strTmpFolderPath, atPluginOptions, strExecReturnPath)
    -- check if for both sides a valid sip was found
    if fOk~= true or strComSipData == nil or strAppSipData == nil then
        uVerifyResult = tSipper.VERIFY_RESULT_ERROR
    else

        if tFlasherHelper.getStoreTempFiles() then
            tLog.debug("Saving content to files...")
            -- save the content to a file if the flag is set
            -- set the sip file path to save the sip data
            local strComSipFilePath = path.join( strTmpFolderPath, "com_sip.bin")
            local strAppSipFilePath = path.join( strTmpFolderPath, "app_sip.bin")


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
        end

        uVerifyResult, strErrorMsg = tSipper:verify_usip(tUsipConfigDict, strComSipData, strAppSipData, tPlugin)
    end

    return uVerifyResult, strErrorMsg
end


-- strComSipData, strAppSipData readOutSipContent(iValidCom, iValidApp, tPlugin)
-- read out the secure info page content via MI-Interface or the JTAG-interface
-- the function needs a sip validation before it can be used.
local function readOutSipContent(iValidCom, iValidApp, tPlugin)
    local strComSipData = nil
    local strAppSipData = nil
    if not ( iValidCom == -1 or iValidApp == -1 ) then
        -- check if the copy com sip area has a valid sip
        if iValidCom == 1 then
            tLog.info("Found valid COM copy Secure info page.")
            -- read out the copy com sip area
            strComSipData = tFlasher.read_image(tPlugin, 0x200a7000, 0x1000)
        else
            -- the copy com sip area has no valid sip check if a valid sip is in the flash
            if iValidCom == 2 then
                tLog.info("Found valid COM Secure info page.")
                -- read out the com sip from the flash
                -- show the sip
                tPlugin:write_data32(0xff001cbc, 1)
                -- read out the sip
                strComSipData = tFlasher.read_image(tPlugin, 0x180000, 0x1000)
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
            strAppSipData = tFlasher.read_image(tPlugin, 0x200a6000, 0x1000)
        else
            -- the copy app sip area has no valid sip check if a valid sip is in the flash
            if iValidApp == 2 then
                tLog.info("Found valid APP Secure info page.")
                -- read out the app sip from the flash
                -- show the sip
                tPlugin:write_data32(0xff40143c, 1)
                -- read out the sip
                strAppSipData = tFlasher.read_image(tPlugin, 0x200000, 0x1000)
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



--function kekProcess(tPlugin, strCombinedHbootPath, strTempPath)
local function kekProcess(tPlugin, strCombinedImageData, strTempPath)

    local ulHbootLoadAddress = 0x000200c0 -- boot address for start_hboot command
    local ulHbootDataLoadAddress = 0x00060000 -- address where the set_kek boot image is copied and executed
    local ulDataStructureAddress = 0x000220c0
    local ulHbootResultAddress = 0x00065000
    local fOk = false
    -- separate the image data and the option + usip from the image
    -- this is necessary because the image must be loaded to 0x000203c0
    -- and not to 0x000200c0 like the "htbl" command does. If the image is
    -- loaded to that address it is not possible to start the image, the image is broken


    tFlasher.write_image(tPlugin, ulHbootLoadAddress, strCombinedImageData)

    -- reset result value
    tPlugin:write_data32(ulHbootResultAddress, 0)

    local ulM2MMajor = tPlugin:get_mi_version_maj()
    local ulM2MMinor = tPlugin:get_mi_version_min()
    local strPluginType = tPlugin:GetTyp()

    if ulM2MMajor == 3 and ulM2MMinor >= 1 then
        tFlasher.call_hboot(tPlugin)
    else
        local strSetKekData = string.sub(strCombinedImageData, 1037)
        tFlasher.write_image(tPlugin, ulHbootDataLoadAddress, strSetKekData)

        if strPluginType ~= "romloader_jtag" then
            tFlasher.call_no_answer(
                tPlugin,
                ulHbootDataLoadAddress + 1,
                ulDataStructureAddress
            )
        else
            tPlugin:call(
                ulHbootDataLoadAddress + 1,
                ulDataStructureAddress,
                tFlasher.default_callback_message,
                2
            )
        end
    end
    tLog.debug("Finished call, disconnecting")
    tPlugin:Disconnect()
    tLog.debug("Wait 3 seconds to be sure the set_kek process is finished")
    tFlasherHelper.sleep_s(3)
    -- todo check results of connect and getPlugin before continuing
    -- get the uart plugin again
    tPlugin = tFlasherHelper.getPlugin(tPlugin:GetName(), tPlugin:GetTyp(), atPluginOptions)
    if tPlugin then
        local strError
        fOk, strError = tFlasherHelper.connect_retry(tPlugin, 5)
        if fOk == false then
            tLog.error(strError)
        end
    else
        tLog.error("Failed to get plugin after set KEK")
        fOk = false
    end

    local ulHbootResult = tPlugin:read_data32(ulHbootResultAddress)

    tLog.debug( "ulHbootResult: %s ", ulHbootResult )
    ulHbootResult = ulHbootResult & 0x107
    -- TODO: include description
    if ulHbootResult == 0x107 then
        tLog.info( "Successfully set KEK" )
        fOk = true
    else
        tLog.error( "Failed to set KEK" )
        fOk = false
    end

    return fOk, tPlugin
end


-----------------------------------------------------------------------------------------------------
-- FUNCTIONS
-----------------------------------------------------------------------------------------------------
local function usip(
        tPlugin,
        tUsipDataList,
        tUsipPathList,
        tUsipConfigDict,
        strTmpFolderPath,
        strExecReturnPath,
        strVerifySigPath,
        strResetExecReturnPath,
        strResetBootswitchPath,
        strResetReadSipPath
    )

    local fOk
    local uVerifyResult
    local strPluginType
    local strPluginName
    local ulM2MMajor = tPlugin:get_mi_version_maj()
    local ulM2MMinor = tPlugin:get_mi_version_min()

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
        fOk = tVerifySignature.verifySignature(
            tPlugin, strPluginType, tUsipDataList, tUsipPathList, strTmpFolderPath, strVerifySigPath
        )
    else
        -- set the signature verification to automatically to true
        fOk = true
    end

    -- just continue if the verification process was a success (or not enabled)
    if fOk then
        -- iterate over the usip file path list
        for _, strSingleUsipData in ipairs(tUsipDataList) do
            -- check if usip needs extended by the bootswitch with parameters
            if tArgs.strBootswitchParams ~= nil and tArgs.strBootswitchParams ~= "JTAG" then
                tLog.debug("Extending USIP file with bootswitch.")
                fOk, strSingleUsipData, strMsg = extendBootswitchData(
                    strSingleUsipData, strTmpFolderPath, tArgs.strBootswitchParams
                )
                tLog.debug(strMsg)
            elseif tArgs.strBootswitchParams == "JTAG" then
                tLog.debug("Extending USIP file with exec.")
                fOk, strSingleUsipData, strMsg = extendExecReturnData(
                    strSingleUsipData, strTmpFolderPath, strExecReturnPath
                )
            else
                -- tLog.debug(strMsg)
                fOk = true
            end

            -- continue check
            if fOk then

                -- load an usip file via a dedicated interface
                fOk, tPlugin = loadUsip(strSingleUsipData, tPlugin, strPluginType)
                -- NOTE: be aware after the loading the netX will make a reset
                --       but in the function the tPlugin will be reconncted!
                --       so after the function the tPlugin is connected!
            else
                -- this is an error message from the extendExec function
                tLog.error(strMsg)
            end

        end
    end
	-- Phase 2 starts after this reset
	-- For phase 2 we use the helpfer images from tArgs.strSecureOptionPhaseTwo argument
    -- Check if a last reset is necessary to activate all data inside the secure info page
    if not tArgs.fDisableReset and fOk then

        local ulLoadAddress = 0x20080000
        local strResetImagePath = ""

        -- netx90 rev2 uses call_usip command to reset, therefore we copy the image into USER_DATA_AREA
        if ulM2MMajor == 3 and ulM2MMinor >= 1 then
            ulLoadAddress = 0x000200C0
        else
            ulLoadAddress = 0x20080000
        end

        -- connect to the netX
        local strError
        fOk, strError = tFlasherHelper.connect_retry(tPlugin, 5)
        if fOk == false then
            tLog.error(strError)
        end
        -- tFlasherHelper.dump_trace(tPlugin, strTmpFolderPath, "trace_after_usip.bin")
        -- tFlasherHelper.dump_intram(tPlugin, 0x20080000, 0x1000, strTmpFolderPath, "dump_after_usip.bin")
        -- check if a bootswitch is necessary to force a dedicated interface after a reset
        if tArgs.strBootswitchParams then
            if tArgs.strBootswitchParams == "JTAG" then
                strResetImagePath = strResetExecReturnPath
            else
                strResetImagePath = strResetBootswitchPath
            end

            fOk = loadIntramImage(tPlugin, strResetImagePath, ulLoadAddress )
        else
            -- overwrite possible boot cookie to avoid accidentaly booting an old image
            tPlugin:write_data32(ulLoadAddress, 0x00000000)
            tPlugin:write_data32(ulLoadAddress + 4, 0x00000000)
            tPlugin:write_data32(ulLoadAddress + 8, 0x00000000)
            tLog.debug("Just reset without any image in the intram.")
        end

        if fOk then

            if ulM2MMajor == 3 and ulM2MMinor >= 1 then
                tLog.debug("use call usip command to reset netx")
                tFlasher.call_usip(tPlugin) -- use call usip command as workaround to trigger reset
            else
                tLog.debug("reset netx via watchdog")
                tFlasherHelper.reset_netx_via_watchdog(nil, tPlugin)
            end

            tPlugin:Disconnect()
            tFlasherHelper.sleep_s(2)
            -- just necessary if the uart plugin in used
            -- jtag works without getting a new plugin

        end
    end

    if not tArgs.fVerifyContentDisabled and not tArgs.fDisableReset then
        -- just validate the content if the validation is enabled and no error occued during the loading process
        if strPluginType ~= 'romloader_jtag' then
            tPlugin = tFlasherHelper.getPlugin(strPluginName, strPluginType, atResetPluginOptions)
        end
        -- check if strResetReadSipPath is set, if it is nil set it to the default path of the read sip binary
        -- this is the case if the content should be verified without a reset at the end

        if tPlugin then
            local strErrorMsg
            fOk, strErrorMsg = tFlasherHelper.connect_retry(tPlugin, 5)
            if fOk == false then
                tLog.error(strErrorMsg)
            end
        else
            tLog.error("Failed to get plugin after set KEK")
            fOk = false
        end

        if fOk then
            local strErrorMsg
            uVerifyResult, strErrorMsg = verifyContent(
                    strPluginType,
                    tPlugin,
                    strTmpFolderPath,
                    strResetReadSipPath,
                    tUsipConfigDict,
                    atResetPluginOptions,
                    strResetExecReturnPath
            )
            if uVerifyResult == tSipper.VERIFY_RESULT_OK then
                fOk = true
            else
                fOk = false
                tLog.error(strErrorMsg)
            end
        end

    end

    return fOk
end

local function set_sip_protection_cookie(tPlugin)
    local ulStartOffset = 0
    local iBus = 2
    local iUnit = 1
    local iChipSelect = 1
    local strData
    local strMsg
    local ulLen
    local ulDeviceSize
    local flasher_path = "netx/"
    -- be pessimistic
    local fOk = false

    local strFilePath = path.join("netx", "helper", "netx90", "com_default_rom_init_ff_netx90_rev2.bin")
    -- Download the flasher.
    local aAttr = tFlasher.download(tPlugin, flasher_path, nil, nil, tArgs.strSecureOption)
    -- if flasher returns with nil, flasher binary could not be downloaded
    if not aAttr then
        tLog.error("Error while downloading flasher binary")
    else
        -- check if the selected flash is present
        fOk = tFlasher.detect(tPlugin, aAttr, iBus, iUnit, iChipSelect)
        if not fOk then
            tLog.error("No Flash connected!")
        else
            ulDeviceSize = tFlasher.getFlashSize(tPlugin, aAttr)
            if not ulDeviceSize then
                tLog.error( "Failed to get the device size!" )
                fOk = false
            else
                -- get the data to flash
                strData, strMsg = tFlasherHelper.loadBin(strFilePath)
                if not strData then
                    tLog.error(strMsg)
                    fOk = false
                else
                    ulLen = strData:len()
                    -- if offset/len are set, we require that offset+len is less than or equal the device size
                    if ulStartOffset~= nil and ulLen~= nil and ulStartOffset+ulLen > ulDeviceSize and ulLen ~= 0xffffffff and fOk == true then
                        tLog.error( "Offset+size exceeds flash device size: 0x%08x bytes", ulDeviceSize )
                        fOk = false
                    else
                        tLog.info( "Flash device size: %d/0x%08x bytes", ulDeviceSize, ulDeviceSize )
                    end
                end
            end
        end
        if fOk then
            fOk, strMsg = tFlasher.eraseArea(tPlugin, aAttr, ulStartOffset, ulLen)
        end
        if fOk then
            fOk, strMsg = tFlasher.flashArea(tPlugin, aAttr, ulStartOffset, strData)
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

local function set_kek(
    tPlugin,
    strTmpFolderPath,
    tUsipDataList,
    tUsipPathList,
    strExecReturnPath,
    strVerifySigPath,
    strResetReadSipPath,
    strResetBootswitchPath,
    strResetExecReturnPath,
    tUsipConfigDict,
    strKekHbootFilePath,
    strKekDummyUsipFilePath,
    iChiptype
)

    -- be optimistic
    local fOk = true
    local strKekHbootData
    local strCombinedImageData
    local strFillUpData
    local strUsipToExtendData
    local strKekDummyUsipData
    local fProcessUsip = false
    local strMsg
    local strFirstUsipData
    local romloader = _G.romloader

    -- get the plugin type
    local strPluginType = tPlugin:GetTyp()
    -- get plugin name
    local strPluginName = tPlugin:GetName()
    -- the signature of the dummy USIP must not be verified because the data of the USIP
    -- are replaced by the new generated KEK and so the signature will change too

    -- check if an USIP file was provided
    if next(tUsipDataList) then
        fProcessUsip = true
        tLog.debug("Found general USIP to process.")
        -- lua tables start with 1
        strFirstUsipData = tUsipDataList[1]
        table.remove(tUsipDataList, 1)
    else
        tLog.debug("No general USIP found.")
    end

    strKekDummyUsipData = tFlasherHelper.loadBin(strKekDummyUsipFilePath)
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
        local iCopyUsipSize = 0x0
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
            -- set option at the end of the fill up data

            -- result register address = 0x00065000
            local strSetKekOptions = string.char(0x00, 0x50, 0x06, 0x00)
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
                if iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90A or
                        iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or
                        iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C then
                    strSetKekOptions = strSetKekOptions .. string.char(0x11, 0x00)
                elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D then
                    strSetKekOptions = strSetKekOptions .. string.char(0x12, 0x00)
                else
                    -- todo how to we act here?
                end

                iCopyUsipSize = string.len(strFirstUsipData)

            else
                strSetKekOptions = strSetKekOptions .. string.char(0x01, 0x00)  -- todo change for rev2?
            end
            
            -- size of copied data
            local iCopySizeInBytes = iMaxImageSizeInBytes + iCopyUsipSize + iMaxOptionSizeInBytes

            strSetKekOptions = strSetKekOptions .. string.char(
                iCopySizeInBytes & 0xff
            )
            strSetKekOptions = strSetKekOptions .. string.char(
                (iCopySizeInBytes >> 8) & 0xff
            )
            strSetKekOptions = strSetKekOptions .. string.char(
                (iCopySizeInBytes >> 16) & 0xff
            )
            strSetKekOptions = strSetKekOptions .. string.char(
                (iCopySizeInBytes >> 24) & 0xff
            )
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- reserved
            strSetKekOptions = strSetKekOptions .. string.char(0x00, 0x00, 0x00, 0x00)
            -- fill options to 4k bytes
            strSetKekOptions = strSetKekOptions .. string.rep(
                string.char(255), iMaxOptionSizeInBytes - string.len(strSetKekOptions)
            )
            -- TODO: Add comment
            strCombinedImageData = strCombinedImageData .. strSetKekOptions
            -- USIP image has an offset of 3k from the load address of the set_kek image
            if fProcessUsip then
                tLog.debug("Getting first USIP from Usiplist.")
                tLog.debug("Set general USIP as extending USIP.")
                strUsipToExtendData = strFirstUsipData
            else
                tLog.debug("Set dummy USIP as extending USIP.")
                strUsipToExtendData = strKekDummyUsipData
            end
            -- extend usip with bootswitch/exec_return data if necessary
            -- check if usip needs extended by the bootswitch with parameters
            if tArgs.strBootswitchParams == "JTAG" then
                tLog.debug("Extending USIP file with exec.")
                fOk, strUsipToExtendData, strMsg = extendExecReturnData(
                    strUsipToExtendData, strTmpFolderPath, strExecReturnPath
                )
                tLog.debug(strMsg)
            else if tArgs.strBootswitchParams ~= nil then
                tLog.debug("Extending USIP file with bootswitch.")
                fOk, strUsipToExtendData, strMsg = extendBootswitchData(
                    strUsipToExtendData, strTmpFolderPath, tArgs.strBootswitchParams
                )
                tLog.debug(strMsg)
            else
                fOk = true
            end

        end
            -- continue check
            if fOk then

                if fProcessUsip then
                    strFirstUsipData = strUsipToExtendData
                else
                    strKekDummyUsipData = strUsipToExtendData
                end
                if fOk then
                    -- be pessimistic
                    fOk = false
                    -- load dummyUsip data
                    if not strKekDummyUsipData then
                        tLog.error(strMsg)
                    else
                        tLog.debug("Combine the HBootImage with the DummyUsip.")
                        strCombinedImageData = strCombinedImageData .. strKekDummyUsipData
                        if not fProcessUsip then
                            fOk = true
                        else
                            -- load usip data
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
                                -- calculate fillUp data to have the same offset to the usip file with the
                                -- combined image. 68 is the number of bytes of a cut header and a cut end
                                ulFillUpLength = iMaxImageSizeInBytes - string.len(strKekHbootData) -
                                    string.len(strKekDummyUsipData) + 68
                                strFillUpData = string.rep(string.char(255), ulFillUpLength)
                                strCombinedImageData = strCombinedImageData .. strFillUpData
                                -- set option at the end of the fill up data

                                -- todo if we want to actually use the second options:
                                --      we have to implement a copy function inside set_kek.bin
                                --      that copies the second options from offset 0x250c0 to offset 0x220c0
                                --      before copying the usip to intram3
                                --      both options must use the same value for result register address

                                -- result register address = 0x00065000
                                local strSetKekOptions = string.char(0x00, 0x50, 0x06, 0x00)
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

                                if iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90A or
                                        iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or
                                        iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C then
                                    strSetKekOptions = strSetKekOptions .. string.char(0x01, 0x00)
                                elseif iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D then
                                    strSetKekOptions = strSetKekOptions .. string.char(0x02, 0x00)
                                end

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
                                -- fill options to 4k bytes
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

                            if tFlasherHelper.getStoreTempFiles() then

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
                                end
                            end
                            -- load the combined image to the netX
                            tLog.info( "Using %s", strPluginType )
                            --fOk, tPlugin = kekProcess(tPlugin, strKekHbootCombPath, strTmpFolderPath)
                            fOk, tPlugin = kekProcess(tPlugin, strCombinedImageData, strTmpFolderPath)

                            -- todo if not further usip are provided we do not make a final reset to activate the last usip file

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
                                            tUsipDataList,
                                            tUsipPathList,
                                            tUsipConfigDict,
                                            strTmpFolderPath,
                                            strExecReturnPath,
                                            strVerifySigPath,
                                            strResetExecReturnPath,
                                            strResetBootswitchPath,
                                            strResetReadSipPath
                                    )
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

local function read_sip(
    tPlugin,
    strTmpFolderPath,
    strReadSipPath,
    strOutputFolderPath,
    fReadCal,
    strExecReturnPath
)

    local fOk = false

    -- get the plugin type
    local strPluginType = tPlugin:GetTyp()
    -- get plugin name
    local strPluginName = tPlugin:GetName()

    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------

    local iReadSipResult, strErrorMsg, strCalSipData, strComSipData, strAppSipData, _ =  readSip(
        strReadSipPath, tPlugin, strTmpFolderPath, atPluginOptions, strExecReturnPath)


    if iReadSipResult then
        -- set the sip file path to save the sip data
        if strOutputFolderPath == nil then
            strOutputFolderPath = strTmpFolderPath
        end
        if not path.exists(strOutputFolderPath) then
            path.mkdir(strOutputFolderPath)
        end


        local strComSipFilePath = path.join( strOutputFolderPath, "com_sip.bin")
        local strAppSipFilePath = path.join( strOutputFolderPath, "app_sip.bin")
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

        if fReadCal then
            local strCalSipFilePath = path.join( strOutputFolderPath, "cal_sip.bin")
            -- write the com sip data to a file
            tLog.info("Saving CAL SIP to %s ", strCalSipFilePath)
            local tFile = io.open(strCalSipFilePath, "wb")
            tFile:write(strCalSipData)
            tFile:close()
        end
    else
        tLog.error(strErrorMsg)
    end

    return fOk
end


local function get_uid(
    tPlugin,
    strTmpFolderPath,
    strReadSipPath,
    atPluginOptions,
    strExecReturnPath)

    local fOk = false

    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------

    -- get the plugin type
    local strPluginType = tPlugin:GetTyp()

    tLog.debug( "Using %s interface", strPluginType )
    -- what am i doing here...
    -- catch the romloader error to handle it correctly
    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------

    local iReadSipResult, strErrorMsg, _, _, _, aStrUUIDs = readSip(
        strReadSipPath, tPlugin, strTmpFolderPath, atPluginOptions, strExecReturnPath)

    if iReadSipResult then
            local strUidVal = string.format("%08x%08x%08x", aStrUUIDs[1], aStrUUIDs[2], aStrUUIDs[3])

        -- print out the complete unique ID
        tLog.info( " [UNIQUE_ID] %s", strUidVal )
        fOk = true
    else
       tLog.error(strErrorMsg)
    end

    return fOk
end

local function verify_content(
    tPlugin,
    strTmpFolderPath,
    strUsipFilePath,
    strReadSipPath,
    strExecReturnPath
)
    local uVerifyResult

    -- get the plugin type
    local strPluginType = tPlugin:GetTyp()

    --------------------------------------------------------------------------
    -- analyze the usip file
    --------------------------------------------------------------------------

    local tResult, strErrorMsg, tUsipConfigDict = tUsipGen:analyze_usip(strUsipFilePath)
    if tResult == true then

        --------------------------------------------------------------------------
        -- verify the content
        --------------------------------------------------------------------------

        -- verify the content via the MI
        uVerifyResult, strErrorMsg = verifyContent(
            strPluginType,
            tPlugin,
            strTmpFolderPath,
            strReadSipPath,
            tUsipConfigDict,
            atPluginOptions,
            strExecReturnPath
        )

    else
        uVerifyResult = tSipper.VERIFY_RESULT_ERROR
        tLog.error(strErrorMsg)
    end

    return uVerifyResult, strErrorMsg
end

local SIP_ATTRIBUTES = {
    CAL={iBus=2, iUnit=0,iChipSelect=1},
    COM={iBus=2, iUnit=1,iChipSelect=1},
    APP={iBus=2, iUnit=2,iChipSelect=1}
}

-- read out a selected secure info page
-- APP and COM SIP: verify the hash of the read out data
-- returns strReadData, strMsg -> strReadData is nil if read was not successful
local function readSIPviaFLash(tPlugin, strSipPage, aAttr)
    local ulOffset = 0x0
    local ulSize = 0x1000
    local strReadData
    local strMsg

    -- check if the selected flash is present
    local fDetectResult = tFlasher.detect(
        tPlugin, aAttr,
        SIP_ATTRIBUTES[strSipPage].iBus,
        SIP_ATTRIBUTES[strSipPage].iUnit,
        SIP_ATTRIBUTES[strSipPage].iChipSelect)

    if not fDetectResult then
        strMsg = "No Flash connected!"
    else
        strReadData, strMsg = tFlasher.readArea(tPlugin, aAttr, ulOffset, ulSize)

        if strReadData ~= nil and strSipPage ~= "CAL" then
            local strNewHash
            local sipStringHandle = tFlasherHelper.StringHandle(strReadData)
            local strHashableData = sipStringHandle:read(0xFD0)
            local strReferenceHash = sipStringHandle:read(0x30)
            local tChunkHash = mhash.mhash_state()
            tChunkHash:init(mhash.MHASH_SHA384)
            tChunkHash:hash(strHashableData)
            strNewHash = tChunkHash:hash_end()
            if strNewHash ~= strReferenceHash then
                strReadData = nil
                strMsg = string.format("hash verification failed for %s SIP", strSipPage)
            end
        end
    end
    return strReadData, strMsg
end

-- write SIP data (4kB) into sekected SIP
-- create a new hash for the data
local function writeSIPviaFLash(tPlugin, strSipPage, strSipData, aAttr)
    local strMsg
    local strWriteData
    local strNewHash
    local fResult
    local fDetectResult

    -- check if the selected flash is present
    fDetectResult = tFlasher.detect(
        tPlugin, aAttr,
        SIP_ATTRIBUTES[strSipPage].iBus,
        SIP_ATTRIBUTES[strSipPage].iUnit,
        SIP_ATTRIBUTES[strSipPage].iChipSelect)

    if not fDetectResult then
        strMsg = "No Flash connected!"
    else
        -- get the write data from the handover parameter
        local sipStringHandle = tFlasherHelper.StringHandle(strSipData)
        strWriteData = sipStringHandle:read(0xFD0)
        -- create a new hash
        local tChunkHash = mhash.mhash_state()
        tChunkHash:init(mhash.MHASH_SHA384)
        tChunkHash:hash(strWriteData)
        strNewHash = tChunkHash:hash_end()
        -- apend the hash to the new data
        strWriteData = strWriteData .. strNewHash

        -- duplicate the data and write both mirrors at once
        strWriteData = strWriteData .. strWriteData

        -- erase flash before Writing
        fResult, strMsg = tFlasher.eraseArea(tPlugin, aAttr, 0x0, 0x2000)
        if fResult then
            -- write first mirror of SIP
            fResult, strMsg = tFlasher.flashArea(tPlugin, aAttr, 0x0, strWriteData)
        end
    end

    return fResult, strMsg
end

-- take the data of the COM and APP SIP and check if the secure boot flags are set
-- returns flags for each secure boot flag fSecureFlagComSet, fSecureFlagAppSet (true is set; False if not set)
local function check_secure_boot_flag(strComSipData, strAppSipData)
    local COM_SIP_SECURE_BOOT_ENABLED = 0x0004
    local APP_SIP_SECURE_BOOT_ENABLED = 0x0004
    local fSecureFlagComSet
    local fSecureFlagAppSet
    -- sip protection cookie
    local fComSipStringHandle
    local fAppSipStringHandle
    local strComProtectionOptionFLags
    local strAppProtectionOptionFLags
    local ulProtectionOptionFLags


    if strComSipData then
        fComSipStringHandle = tFlasherHelper.StringHandle(strComSipData)
        fComSipStringHandle:seek("set", 0x22C)
        strComProtectionOptionFLags = fComSipStringHandle:read(0x2)
        ulProtectionOptionFLags = tFlasherHelper.bytes_to_uint32(strComProtectionOptionFLags)
        if (ulProtectionOptionFLags & COM_SIP_SECURE_BOOT_ENABLED) ~= 0 then
            fSecureFlagComSet = true
        else
            fSecureFlagComSet = false
        end
    end
    if strAppSipData then
        fAppSipStringHandle = tFlasherHelper.StringHandle(strAppSipData)
        fAppSipStringHandle:seek("set", 0x228)
        strAppProtectionOptionFLags = fAppSipStringHandle:read(0x2)
        ulProtectionOptionFLags = tFlasherHelper.bytes_to_uint32(strAppProtectionOptionFLags)
        if (ulProtectionOptionFLags & APP_SIP_SECURE_BOOT_ENABLED) ~= 0 then
            fSecureFlagAppSet = true
        else
            fSecureFlagAppSet = false
        end
    end

    return fSecureFlagComSet, fSecureFlagAppSet

end

-- takes the data of the COM SIP and checks if the SIP protection flag is set
-- returns fCookieSet (true is set; False if not set)
local function check_sip_protection_cookie_via_flash(strComSipData)

    local fCookieSet
    local strSipProtectionCookie
    -- sip protection cookie
    local strSipProtectionCookieLocked = string.char(0x8b, 0x42, 0x3b, 0x75, 0xe2, 0x63, 0x25, 0x62,
     0x8a, 0x1e, 0x31, 0x6b, 0x28, 0xb4, 0xd7, 0x03)
    local fComSipStringHandle

    fComSipStringHandle = tFlasherHelper.StringHandle(strComSipData)
    strSipProtectionCookie = fComSipStringHandle:read(0x10)
    -- first check if the SIP protection cookie is set

    if strSipProtectionCookie == strSipProtectionCookieLocked then
        fCookieSet = true
    else
        fCookieSet = false
    end
    return fCookieSet
end

-- take the data of the CAL SIP and check if the rom func mode cookie is set
-- returns fCookieSet (true is set; False if not set)
local function checkRomFuncModeCookie(strCalSipData)

    local fCookieSet
    local strExpectedRomFuncModeCookie = string.char(0x43, 0xC4, 0xF2, 0xB2, 0x45, 0x40, 0x02, 0xC8, 0x78, 0x79, 0xDD, 0x94, 0xF7, 0x13, 0xB5, 0x4A)
    local fComSipStringHandle
    local strRomFuncModeCookie

    fComSipStringHandle = tFlasherHelper.StringHandle(strCalSipData)
    strRomFuncModeCookie = fComSipStringHandle:read(0x10)
    -- first check if the SIP protection cookie is set

    if strRomFuncModeCookie == strExpectedRomFuncModeCookie then
        fCookieSet = true
    else
        fCookieSet = false
    end
    return fCookieSet
end


-- read out register iflash_special_cfg0|1|2 to determine if any of the secure info pages are hidden
-- if the register can't be accessed we assume the netX is in secure boot mode (M2M mode access denied)
-- returns fHideSet, strErrorMsg, fSecureBootEnabled
local function checkHideSipRegister(tPlugin)
    local IFLASH_SPECIAL_CFG_CAL = 0xff001c48
    local IFLASH_SPECIAL_CFG_COM = 0xff001cc8
    local IFLASH_SPECIAL_CFG_APP = 0xff401448
    local ulValCal
    local ulValCom
    local ulValApp
    local fHideSet = false
    local strErrorMsg
    local fSecureBootEnabled = false

    ulValCal, strErrorMsg = pcall(tPlugin.read_data32, tPlugin, IFLASH_SPECIAL_CFG_CAL)
    if ulValCal == false then
        fSecureBootEnabled = true
    else
        ulValCom, strErrorMsg = pcall(tPlugin.read_data32, tPlugin, IFLASH_SPECIAL_CFG_COM)
        ulValApp, strErrorMsg = pcall(tPlugin.read_data32, tPlugin, IFLASH_SPECIAL_CFG_APP)

        ulValCal = tPlugin:read_data32(IFLASH_SPECIAL_CFG_CAL)
        ulValCom = tPlugin:read_data32(IFLASH_SPECIAL_CFG_COM)
        ulValApp = tPlugin:read_data32(IFLASH_SPECIAL_CFG_APP)
        if (ulValCal & 0xF) ~= 0 then
            fHideSet = true
            strErrorMsg = "CAL page hide flag is set"
        elseif (ulValCom & 0xF) ~= 0 then
            fHideSet = true
            strErrorMsg = "COM page hide flag is set"
        elseif (ulValApp & 0xF) ~= 0 then
            fHideSet = true
            strErrorMsg = "APP page hide flag is set"
        end
    end

    return fHideSet, strErrorMsg, fSecureBootEnabled
end

local WS_RESULT_OK = 0
local WS_RESULT_ERROR_UNSPECIFIED = 1
local WS_RESULT_ERROR_SIP_PROTECTION_SET = 2
local WS_RESULT_ERROR_SECURE_BOOT_ENABLED = 3
local WS_RESULT_ERROR_SIP_HIDDEN = 4
local WS_RESULT_ROM_FUNC_MODE_COOKIE_NOT_SET = 5
-- veriify that the netX is in an initial state
-- the netX is not in an initial state if:
-- * one or mode secure info pages are hidden
-- * the netX is in secure boot mode
-- * the SIP protection cookie is set
-- * the rom func mode cookie is not set
-- returns iResult, strMsg, strCalSipData
local function verifyInitialMode(tPlugin, aAttr)
    local iResult = WS_RESULT_OK
    local strComSipData
    local strAppSipData
    local strCalSipData
    local fComSecureBootEnabled
    local fAppSecureBootEnabled
    local fSipHidden
    local strMsg
    local fSipCookieSet
    local fRomFuncCookieSet

    -- check if any of the secure info pages are hidden
    fSipHidden, strMsg, fComSecureBootEnabled = checkHideSipRegister(tPlugin)
    if fComSecureBootEnabled then
        iResult = WS_RESULT_ERROR_SECURE_BOOT_ENABLED
        tLog.info("ERROR: Secure boot is enabled. End command.")
    elseif fSipHidden then
        iResult = WS_RESULT_ERROR_SIP_HIDDEN
        tLog.info("ERROR: one or more secure info page is hidden.")
    end


    -- read out CAL secure info pages
    if iResult == WS_RESULT_OK then
        strCalSipData, strMsg = readSIPviaFLash(tPlugin, "CAL", aAttr)
        if strCalSipData == nil then
            iResult = WS_RESULT_ERROR_UNSPECIFIED
        end
    end

    -- read out COM secure info pages
    if iResult == WS_RESULT_OK then
        strComSipData, strMsg = readSIPviaFLash(tPlugin, "COM", aAttr)
        if strComSipData == nil then
            iResult = WS_RESULT_ERROR_UNSPECIFIED
        end
    end

    -- read out APP secure info pages
    if iResult == WS_RESULT_OK then
        strAppSipData, strMsg = readSIPviaFLash(tPlugin, "APP", aAttr)
        if strAppSipData == nil then
            iResult = WS_RESULT_ERROR_UNSPECIFIED
        end
    end

    if iResult == WS_RESULT_OK then
        -- check for secure boot flags
        fComSecureBootEnabled, fAppSecureBootEnabled = check_secure_boot_flag(strComSipData, strAppSipData)
        -- check for sip protection cookie
        fSipCookieSet = check_sip_protection_cookie_via_flash(strComSipData)
        -- check if the fum func mode cookie is set
        fRomFuncCookieSet = checkRomFuncModeCookie(strCalSipData)

        if fComSecureBootEnabled or fAppSecureBootEnabled then
            iResult = WS_RESULT_ERROR_SECURE_BOOT_ENABLED
            tLog.info("ERROR: Secure boot is enabled. End command.")
        elseif fSipCookieSet then
            iResult = WS_RESULT_ERROR_SIP_PROTECTION_SET
            tLog.info("ERROR: SIP protection cookie is set. End command.")
        elseif not fRomFuncCookieSet then
            iResult = WS_RESULT_ROM_FUNC_MODE_COOKIE_NOT_SET
            tLog.info("ERROR: rom func mode cookie not set")
        end
    end
    return iResult, strMsg, strCalSipData
end

-- upate the calibration values 'atTempDiode' inside the APP SIP with the values from the CAL SIP
-- * copied from: CAL SIP offset 2192 (0x890) size: 48 (0x30)
-- * copied to:   APP SIP offset 2048 (0x800) size: 48 (0x30)
local function apply_temp_diode_data(strAppSipData, strCalSipData)
    -- apply temp diode parameter from cal page to app page
    local strTempDiodeData = string.sub(strCalSipData, 0x890+1, 0x890 + 0x30)
    local strNewAppSipData = string.format(
        "%s%s%s",
        string.sub(strAppSipData, 1, 0x800),
        strTempDiodeData,
        string.sub(strAppSipData, 0x800 + 1)
    )
    print(string.len(strNewAppSipData))
    return strNewAppSipData
end


-- write APP and COM secure info page (SIP) based on default values
-- update temp diode calibratino values from CAL SIP to APP SIP
-- the default values can be modified with the data from an USIP file
local function writeAllSips(tPlugin, strBaseComSipData, strBaseAppSipData, tUsipConfigDict, strSecureOption
                            fSetSipProtectionCookie, strComOutputFile, strAppOutputFile)
    local iResult
    local strMsg
    local fResult
    local aAttr
    local flasher_path = "netx/"
    local strCalSipData
    local strComSipData = strBaseComSipData
    local strAppSipData = strBaseAppSipData

    if strSecureOption == nil then
        strSecureOption = tFlasher.DEFAULT_HBOOT_OPTION
    end

    local fConnected
    fConnected, strMsg = tFlasherHelper.connect_retry(tPlugin)
    if fConnected then
        aAttr = tFlasher.download(tPlugin, flasher_path, nil, true, strSecureOption)
    end

    -- check if any of the secure info pages are hidden
    iResult, strMsg, strCalSipData = verifyInitialMode(tPlugin, aAttr)

    if iResult == WS_RESULT_OK then
        -- Set the SIP protection cookie if requested.
        if fSetSipProtectionCookie then
            strComSipData = tUsipGen:setSipProtectionCookie(strComSipData)
        end

        strAppSipData = apply_temp_diode_data(strAppSipData, strCalSipData)
        if tUsipConfigDict ~= nil then
            strComSipData, strAppSipData = tUsipGen.apply_usip_data(strComSipData, strAppSipData, tUsipConfigDict)
        end
    end

    if iResult == WS_RESULT_OK then
        -- write the SIPs
        if strComOutputFile~=nil then
            local utils = require 'pl.utils'
            local fWriteResult, strWriteMessage = utils.writefile(strComOutputFile, strComSipData, true)
            if fWriteResult~=true then
                strMsg = string.format(
                    'Failed to write the generated COM page to the output file "%s": %s',
                    strComOutputFile,
                    strWriteMessage
                )
                iResult = WS_RESULT_ERROR_UNSPECIFIED
            end
        else
            fResult, strMsg = writeSIPviaFLash(tPlugin, "COM", strComSipData, aAttr)
            if not fResult then
                iResult = WS_RESULT_ERROR_UNSPECIFIED
            end
        end
    end

    if iResult == WS_RESULT_OK then
        -- write the SIPs
        if strAppOutputFile~=nil then
            local utils = require 'pl.utils'
            local fWriteResult, strWriteMessage = utils.writefile(strAppOutputFile, strAppSipData, true)
            if fWriteResult~=true then
                strMsg = string.format(
                    'Failed to write the generated APP page to the output file "%s": %s',
                    strComOutputFile,
                    strWriteMessage
                )
                iResult = WS_RESULT_ERROR_UNSPECIFIED
            end
        else
            fResult, strMsg = writeSIPviaFLash(tPlugin, "APP", strAppSipData, aAttr)
            if not fResult then
                iResult = WS_RESULT_ERROR_UNSPECIFIED
            end
        end
    end
    return iResult, strMsg
end

-- print args
printArgs(tArgs)
local strHelperFileStatus = tHelperFiles.getStatusString()
tLog.info(strHelperFileStatus)
tLog.info("")

--------------------------------------------------------------------------
-- variables
--------------------------------------------------------------------------
local tPlugin
local iChiptype = nil
local strPluginType
local strNetxName
local fIsSecure
local strUsipFilePath = nil
local strSecureOption = tArgs.strSecureOption
local strReadSipPath
local strExecReturnPath
local strVerifySigPath
local strBootswitchFilePath
local strKekHbootFilePath
local strKekDummyUsipFilePath
local tUsipDataList = {}
local tUsipPathList = {}
local strTmpFolderPath = tempFolderConfPath
local strResetExecReturnPath
local strResetVerifySigPath
local strResetBootswitchPath
local strResetReadSipPath
local tResult
local strErrorMsg
local tUsipConfigDict
local strFileData
local strData

-- set fFinalResult to false, be pessimistic
local fFinalResult = false
local iWriteSipResult
local uResultCode = tSipper.VERIFY_RESULT_ERROR
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
if tArgs.strUsipFilePath and not path.exists(tArgs.strUsipFilePath) then
    tLog.error( "Could not find file %s", tArgs.strUsipFilePath )
    -- return here because of initial error
    os.exit(1)
else
    -- note: this is also entered if tArgs.strUsipFilePath is not set.
    tLog.info("Found USIP file ... ")
    strUsipFilePath = tArgs.strUsipFilePath
end


-- check for a Plugin
-- get the plugin
local fCallSuccess
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
        local strPluginName = tPlugin:GetName()

        tArgs.strPluginType = strPluginType
        tArgs.strPluginName = strPluginName


        if not tArgs.fCommandDetectSelected then
            -- catch the romloader error to handle it correctly
            fFinalResult, strErrorMsg = tFlasherHelper.connect_retry(tPlugin, 5)
            if fFinalResult == false then
                tLog.error(strErrorMsg)
                os.exit(1)
            else
                iChiptype = tPlugin:GetChiptyp()
                tLog.debug( "Found Chip type: %d", iChiptype )
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
    local romloader = _G.romloader
    if strNetxName ~= "netx90" then
        tLog.error("The connected netX (%s) is not supported.", strNetxName)
        tLog.error("Only netX90_rev1 and newer netX90 Chips are supported.")
        os.exit(1)
    elseif iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90A or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B or
            iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C then
        tLog.debug("Detected netX90 rev1")
    elseif iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90D then
        tLog.debug("Detected netX90 rev2")
    end
else
    -- (!) TODO: FIX THIS TO A SOLUTION WHERE NOT JUST THE NETX90 IS SUPPORTED! (!)
    -- (!) TODO: provide a function to detect a netX via uart terminal mode     (!)
    strNetxName = "netx90"
    tLog.warning("Behavior is undefined if connected to a different netX then netX90!")
end

-- set read sip path
strReadSipPath = path.join(strSecureOption, strNetxName, "read_sip_M2M.bin")
-- set exec return path
strExecReturnPath = path.join(strSecureOption, strNetxName, "return_exec.bin")
-- set verify sig path
strVerifySigPath = path.join(strSecureOption, strNetxName, "verify_sig.bin")
-- set bootswitch path
strBootswitchFilePath = path.join(strSecureOption, strNetxName, "bootswitch.bin")

-- check if the files exist
check_file(strReadSipPath)
check_file(strExecReturnPath)
check_file(strVerifySigPath)
check_file(strBootswitchFilePath)


-- check the file versions
-- todo: combine both checks
local strSecureOptionDir = path.join(strSecureOption, strNetxName)
local astrHelpersToCheck = {"read_sip_m2m", "return_exec", "verify_sig", "bootswitch"}

local fHelpersOk = tHelperFiles.checkHelperFiles({strSecureOptionDir}, astrHelpersToCheck)
if not fHelpersOk then
    tLog.error("Error during file version checks.")
    os.exit(1)
end

if tArgs.strSecureOptionPhaseTwo ~= strSecureOption then
    -- set paths for second process after last reset

    -- set verify sig path for after last reset
    strResetVerifySigPath = path.join(tArgs.strSecureOptionPhaseTwo, strNetxName, "verify_sig.bin")
    -- check if the verify_sig file exists

    -- todo why not use get helper file function?
    strResetExecReturnPath = path.join(
    tArgs.strSecureOptionPhaseTwo, strNetxName, "return_exec.bin"
    )
    strResetBootswitchPath = path.join(
        tArgs.strSecureOptionPhaseTwo, strNetxName, "bootswitch.bin"
    )
    strResetReadSipPath = path.join(
        tArgs.strSecureOptionPhaseTwo, strNetxName, "read_sip_M2M.bin"
    )

    -- TODO: check only the files that are actually required.
    check_file(strResetVerifySigPath)
    check_file(strResetExecReturnPath)
    check_file(strResetBootswitchPath)
    check_file(strResetReadSipPath)


    local strSecureOptionPhaseTwoDir = path.join(tArgs.strSecureOptionPhaseTwo, strNetxName)
    local fHelpersOk = tHelperFiles.checkHelperFiles({strSecureOptionPhaseTwoDir}, astrHelpersToCheck)
    if not fHelpersOk then
        tLog.error("Error during file version checks.")
        os.exit(1)
    end

else
    -- if the files for the second process after the last reset are the same, we can use the same helper files
    strResetReadSipPath = strReadSipPath
    strResetVerifySigPath = strVerifySigPath
    strResetExecReturnPath = strExecReturnPath
    strResetBootswitchPath = strBootswitchFilePath
end


if tArgs.fCommandKekSelected then
    -- set kek image paths
    strKekHbootFilePath = path.join(strSecureOption, strNetxName, "set_kek.bin")
    check_file(strKekHbootFilePath)

    -- strKekDummyUsipFilePath = path.join(strSecureOption, strNetxName, "set_kek.usp")
    -- todo add flasher root path here
    strKekDummyUsipFilePath = path.join("netx", "helper", "netx90", "set_kek.usp")
    -- check if the set_kek file exists
    if not path.exists(strKekHbootFilePath) then
        tLog.error( "Set-KEK binary is not available at: %s", strKekHbootFilePath )
        -- return here because of initial error
        os.exit(1)
    end
    -- todo: check version
    local strSetKekBin, strMsg = tHelperFiles.getHelperFile(strSecureOptionDir, "set_kek")
    if not strSetKekBin then
        tLog.error(strMsg or "unknown error")
        tLog.error("Error during file version checks.")
        -- return here because of initial error
        os.exit(1)
    end
    -- check if the dummy kek usip file exists
    if not path.exists(strKekDummyUsipFilePath) then
        tLog.error( "Dummy kek usip is not available at: %s", strKekDummyUsipFilePath )
        -- return here because of initial error
        os.exit(1)
    end
end


-- check if valid bootswitch parameter are set
if tArgs.strBootswitchParams then
    if not (
        tArgs.strBootswitchParams == "UART" or tArgs.strBootswitchParams == "ETH" or tArgs.strBootswitchParams == "MFW" or tArgs.strBootswitchParams == "JTAG"
    ) then
        tLog.error("Wrong Bootswitch parameter, please choose between JTAG, UART, ETH or MFW.")
        tLog.error("If the boot process should continue normal do not use the bootswitch parameter.")
        -- return here because of initial error
        os.exit(1)
    end
end

-- check if the temp folder exists, if it does not exists, create it
if not exists(strTmpFolderPath) and tFlasherHelper.getStoreTempFiles() then
    path.mkdir(strTmpFolderPath)
end

-- set the path for set_sip_protection_cookie.usp
if tArgs.fCommandCheckSIPCookie then
    -- todo move to helper files folder (this will not be signed)
    strUsipFilePath = path.join(strSecureOption, "netx90_usip" ,"set_sip_protection_cookie.usp")
end

--------------------------------------------------------------------------
-- analyze the usip file
--------------------------------------------------------------------------
if tArgs.strUsipFilePath then

    -- analyze the usip file
    tResult, strErrorMsg, tUsipConfigDict = tUsipGen:analyze_usip(strUsipFilePath)

    -- print out the command output
    -- tLog.info(tUsipAnalyzeOutput)
    -- list of all usip files
    local iGenMultiResult
    -- check if multiple usip where found
    if tResult ~= true then
        tLog.error(strErrorMsg)
        os.exit(1)
    else
        if (iChiptype == 14  or iChiptype == 17) and tUsipConfigDict["num_of_chunks"] > 1  then
            iGenMultiResult, tUsipDataList, tUsipPathList = genMultiUsips(strTmpFolderPath, tUsipConfigDict)
        else
            strData, strMsg = tFlasherHelper.loadBin(strUsipFilePath)
            if strData then
                tUsipDataList = {strData}
                tUsipPathList = {strUsipFilePath}
                iGenMultiResult = true
            end
        end
    end
end

-- check if this is a secure run
-- do not verify the signature of the helper files if the read command is selected  -- why?
-- todo: this seems incomplete, e.g. no checks are made for the verify command.
-- old: if fIsSecure  and not tArgs.fCommandReadSelected then
if fIsSecure and not tArgs.fCommandCheckHelperSignatureSelected then
    if tArgs.fDisableHelperSignatureChecks==true then
        tLog.info("Skipping signature checks for support files.")

    else
        -- verify the signature of the used HTBL files
        -- make a list of necessary files
        local tblHtblFileData = {}
        local tPathList = {}
        local fDoVerify = false
        if (tArgs.fVerifySigEnable or not tArgs.fVerifyContentDisabled) then
            fDoVerify = true
            strFileData = tFlasherHelper.loadBin(strReadSipPath)
            if strData == nil then
                fFinalResult = false
            end
            table.insert(tblHtblFileData, strFileData)
            table.insert( tPathList, strReadSipPath)
        end
        if tArgs.strBootswitchParams then
            fDoVerify = true
            if tArgs.strBootswitchParams == "JTAG" then
                strFileData = tFlasherHelper.loadBin(strExecReturnPath)
                if strData == nil then
                    fFinalResult = false
                end
                table.insert( tblHtblFileData, strFileData)
                table.insert( tPathList, strExecReturnPath)
            else
                strFileData = tFlasherHelper.loadBin(strBootswitchFilePath)
                if strData == nil then
                    fFinalResult = false
                end
                table.insert( tblHtblFileData, strFileData)
                table.insert( tPathList, strBootswitchFilePath)
            end
        end

        -- maybe only verify if set kek command selected
        if tArgs.fCommandKekSelected then
            strFileData, strErrorMsg = tFlasherHelper.loadBin(strKekHbootFilePath)
            if strData == nil then
                fFinalResult = false
            end
            table.insert(tblHtblFileData, strFileData)
            table.insert( tPathList, strKekHbootFilePath)
        end

        -- TODO: how to be sure that the verify sig will work correct?
        -- NOTE: If the verify_sig file is not signed correctly the process will fail
        -- is there a way to verify the signature of the verify_sig itself?
        -- if tArgs.fVerifySigEnable then
        --     fDoVerify = true
        --     table.insert( tblHtblFileData, strVerifySigPath )

        if fDoVerify then
            tLog.info("Checking signatures of support files...")

            -- check if every signature in the list is correct via MI
            local fOk = tVerifySignature.verifySignature(
                tPlugin, strPluginType, tblHtblFileData, tPathList, strTmpFolderPath, strVerifySigPath
            )

            if not fOk then
                tLog.error( "The Signatures of the support-files can not be verified." )
                tLog.error( "Please check if the supported files are signed correctly" )
                os.exit(1)
            end
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
        tUsipDataList,
        tUsipPathList,
        tUsipConfigDict,
        strTmpFolderPath,
        strExecReturnPath,
        strVerifySigPath,
        strResetExecReturnPath,
        strResetBootswitchPath,
        strResetReadSipPath
    )
--------------------------------------------------------------------------
-- VERIFY INITIAL MODE
--------------------------------------------------------------------------
elseif tArgs.fCommandVerifyInitialMode then
    tLog.info("#######################################")
    tLog.info("# RUNNING VERIFY INITIAL MODE COMMAND #")
    tLog.info("#######################################")

    local aAttr
    local flasher_path = "netx/"
    local iVerifyInitialModeResult

    if strSecureOption == nil then
        strSecureOption = tFlasher.DEFAULT_HBOOT_OPTION
    end

    local fConnected
    fConnected, strErrorMsg = tFlasherHelper.connect_retry(tPlugin)
    if fConnected then
        aAttr = tFlasher.download(tPlugin, flasher_path, nil, true, strSecureOption)
    end
    iVerifyInitialModeResult, strErrorMsg = verifyInitialMode(tPlugin, aAttr)

    if iVerifyInitialModeResult == WS_RESULT_OK then
        fFinalResult = true
    else
        tLog.error("")
        tLog.error("######## #######  #######   ######  ####### ")
        tLog.error("##       ##    ## ##    ## ##    ## ##    ##")
        tLog.error("##       ##    ## ##    ## ##    ## ##    ##")
        tLog.error("#######  #######  #######  ##    ## ####### ")
        tLog.error("##       ## ##    ## ##    ##    ## ## ##   ")
        tLog.error("##       ##  ##   ##  ##   ##    ## ##  ##  ")
        tLog.error("######## ##   ##  ##   ##   ######  ##   ## ")
        tLog.error("")
        if iVerifyInitialModeResult == WS_RESULT_ERROR_SECURE_BOOT_ENABLED then
            tLog.error('RESULT: secure boot enabled')
        elseif iVerifyInitialModeResult == WS_RESULT_ERROR_SIP_PROTECTION_SET then
            tLog.error('RESULT: SIP protection cookie is set')
        elseif iVerifyInitialModeResult == WS_RESULT_ERROR_UNSPECIFIED then
            tLog.error('RESULT:unspecified error occured')
        elseif iVerifyInitialModeResult == WS_RESULT_ERROR_SIP_HIDDEN then
            tLog.error('RESULT: one or more secure info page is hidden')
        end
        tLog.error(strErrorMsg)
        tLog.info('RETURN: '.. iVerifyInitialModeResult)
        os.exit(iVerifyInitialModeResult)
    end
--------------------------------------------------------------------------
-- WRITE SIP COMMAND
--------------------------------------------------------------------------
elseif tArgs.fCommandWriteSips then
    tLog.info("######################################")
    tLog.info("# RUNNING WRITE SIP COMMAND          #")
    tLog.info("######################################")
    local strComSipBaseData
    strComSipBaseData, strErrorMsg = tFlasherHelper.loadBin(tArgs.strComSipBinPath)
    if strComSipBaseData == nil then
        tLog.error(strErrorMsg)
    end
    local strAppSipBaseData, strErrorMsg = tFlasherHelper.loadBin(tArgs.strAppSipBinPath)
    if strAppSipBaseData == nil then
        tLog.error(strErrorMsg)
    end
    iWriteSipResult, strErrorMsg = writeAllSips(
        tPlugin,
        strComSipBaseData,
        strAppSipBaseData,
        tUsipConfigDict,
        nil,
        tArgs.fSetSipProtectionCookie,
        tArgs.strComOutputFile,
        tArgs.strAppOutputFile
    )
    if iWriteSipResult == WS_RESULT_OK then
        fFinalResult = true
    else
        tLog.error("")
        tLog.error("######## #######  #######   ######  ####### ")
        tLog.error("##       ##    ## ##    ## ##    ## ##    ##")
        tLog.error("##       ##    ## ##    ## ##    ## ##    ##")
        tLog.error("#######  #######  #######  ##    ## ####### ")
        tLog.error("##       ## ##    ## ##    ##    ## ## ##   ")
        tLog.error("##       ##  ##   ##  ##   ##    ## ##  ##  ")
        tLog.error("######## ##   ##  ##   ##   ######  ##   ## ")
        tLog.error("")
        if iWriteSipResult == WS_RESULT_ERROR_SECURE_BOOT_ENABLED then
            tLog.error('RESULT: secure boot enabled')
        elseif iWriteSipResult == WS_RESULT_ERROR_SIP_PROTECTION_SET then
            tLog.error('RESULT: SIP protection cookie is set')
        elseif iWriteSipResult == WS_RESULT_ERROR_UNSPECIFIED then
            tLog.error('RESULT:unspecified error occured')
        elseif iWriteSipResult == WS_RESULT_ERROR_SIP_HIDDEN then
            tLog.error('RESULT: one or more secure info page is hidden')
        end
        tLog.error(strErrorMsg)
        tLog.info('RETURN: '.. iWriteSipResult)
        os.exit(iWriteSipResult)
    end

--------------------------------------------------------------------------
-- Disable Security COMMAND
--------------------------------------------------------------------------
elseif tArgs.fCommandDisableSecurity then
    tLog.info("##############################################")
    tLog.info("# RUNNING Disable Security Setting COMMAND   #")
    tLog.info("##############################################")

    fFinalResult = usip(
        tPlugin,
        tUsipDataList,
        tUsipPathList,
        tUsipConfigDict,
        strTmpFolderPath,
        strExecReturnPath,
        strVerifySigPath,
        strResetExecReturnPath,
        strResetBootswitchPath,
        strResetReadSipPath
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
        tUsipDataList,
        tUsipPathList,
        strExecReturnPath,
        strVerifySigPath,
        strResetReadSipPath,
        strResetBootswitchPath,
        strResetExecReturnPath,
        tUsipConfigDict,
        strKekHbootFilePath,
        strKekDummyUsipFilePath,
        iChiptype
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

    fFinalResult =  read_sip(
        tPlugin,
        strTmpFolderPath,
        strReadSipPath,
        strOutputFolderPath,
        tArgs.fReadCal,
        strExecReturnPath
    )

--------------------------------------------------------------------------
-- DETECT SECURE MODE
--------------------------------------------------------------------------
elseif tArgs.fCommandDetectSelected then
    tLog.warning("Command detect_secure_mode was moved to cli_flash.lua")
    os.exit(1)

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
        strReadSipPath,
        atPluginOptions,
        strExecReturnPath
    )

--------------------------------------------------------------------------
-- VERIFY CONTENT
--------------------------------------------------------------------------
elseif tArgs.fCommandVerifySelected then

    tLog.info("######################################")
    tLog.info("# RUNNING VERIFY CONTENT COMMAND     #")
    tLog.info("######################################")
        uResultCode, strErrorMsg = verify_content(
        tPlugin,
        strTmpFolderPath,
        strUsipFilePath,
        strReadSipPath,
        strExecReturnPath
    )
    if uResultCode == tSipper.VERIFY_RESULT_OK then
        fFinalResult = true
    else
        fFinalResult = false
        tLog.error(strErrorMsg)
    end

elseif tArgs.fCommandCheckSIPCookie then

    tLog.info("################################################")
    tLog.info("# RUNNING DETECT SIP PROTECTION COOKIE COMMAND #")
    tLog.info("################################################")

    uResultCode, strErrorMsg = verify_content(
        tPlugin,
        strTmpFolderPath,
        strUsipFilePath,
        strReadSipPath,
        strExecReturnPath
    )
    if uResultCode == tSipper.VERIFY_RESULT_OK then
        tLog.info('')
        tLog.info('####  ######      ######  ######## ######## ')
        tLog.info(' ##  ##    ##    ##    ## ##          ##    ')
        tLog.info(' ##  ##          ##       ##          ##    ')
        tLog.info(' ##   ######      ######  ######      ##    ')
        tLog.info(' ##        ##          ## ##          ##    ')
        tLog.info(' ##  ##    ##    ##    ## ##          ##    ')
        tLog.info('####  ######      ######  ########    ##    ')
        tLog.info('')
        tLog.info('RESULT: SIP protection cookie is set')
    elseif uResultCode == tSipper.VERIFY_RESULT_ERROR then
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
    elseif uResultCode == tSipper.VERIFY_RESULT_FALSE then
        -- print NOT SET if verify_content came back negative
        tLog.error("")
        tLog.error("##    ##  #######  ########     ######  ######## ######## ")
        tLog.error("###   ## ##     ##    ##       ##    ## ##          ##    ")
        tLog.error("####  ## ##     ##    ##       ##       ##          ##    ")
        tLog.error("## ## ## ##     ##    ##        ######  ######      ##    ")
        tLog.error("##  #### ##     ##    ##             ## ##          ##    ")
        tLog.error("##   ### ##     ##    ##       ##    ## ##          ##    ")
        tLog.error("##    ##  #######     ##        ######  ########    ##    ")
        tLog.error("")
        tLog.error('RESULT: SIP protection cookie not set')
    end
    tLog.info('RETURN: '.. uResultCode)
    os.exit(uResultCode)


--------------------------------------------------------------------------
-- VERIFY_HELPER_SIGNATURE COMMAND
--------------------------------------------------------------------------
elseif tArgs.fCommandCheckHelperSignatureSelected then
    tLog.info("############################################")
    tLog.info("# RUNNING VERIFY_HELPER_SIGNATURES COMMAND #")
    tLog.info("############################################")

    tLog.info("Checking signatures of support files...**")

    local usipPlayerConf = require 'usip_player_conf'
    local tempFolderConfPath = usipPlayerConf.tempFolderConfPath
    local strTmpFolderPath = tempFolderConfPath

    local strVerifySigPath = path.join(strSecureOption, "netx90", "verify_sig.bin")

    local strPath = path.join(strSecureOption, "netx90")
    local tSigCheckDataList, tPathList = tHelperFiles.getAllHelperFilesData({strPath})
    local atResults
    local strPluginType = tPlugin:GetTyp()

    fFinalResult, atResults = tVerifySignature.verifySignature(
        tPlugin, strPluginType, tSigCheckDataList, tPathList, strTmpFolderPath, strVerifySigPath
    )

    tHelperFiles.showFileCheckResults(atResults)

    if fFinalResult then
        tLog.info("The signatures of the helper files have been successfully verified.")
    else
        tLog.error( "The signatures of the helper files could not be verified." )
        tLog.error( "Please check if the helper files are signed correctly." )
    end

else
    tLog.error("No valid command. Use -h/--help for help.")
    fFinalResult = false
end

tPlugin:Disconnect()
tPlugin = nil
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
    tLog.info('RETURN: 0')
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
    tLog.error('RETURN: 1')

    os.exit(1)

end

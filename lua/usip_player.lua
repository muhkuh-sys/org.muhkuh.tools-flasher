-----------------------------------------------------------------------------
-- Copyright (C) 2021 Hilscher Gesellschaft fuer Systemautomation mbH
--
-- Description:
--   usip_player.lua: command line usip loader tool
--
-----------------------------------------------------------------------------

-- requirements
local argparse = require 'argparse'
local tFlasherHelper = require 'flasher_helper'
local tHelperFiles = require 'helper_files'
local tFlasher = require 'flasher'
local path = require 'pl.path'



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


local function setup_argparser()
    local strUsipPlayerGeneralHelp = [[
        The USIP-Player is a Flasher extension to modify, read-out and verify the Secure-Info-Pages on a netX90.
    
        The secure info pages (SIPs) are a part of the secure boot functionality of the netX90 and are not supposed
        to modify directly as a security feature. There is a SIP for the COM and a SIP for the APP side of the netX90.
    
        To actually modify the secure info pages a update-secure-info-page (USIP) file is necessary. These USIP files
        can be generated with the newest netX-Studio version.
    
        Folder structure inside flasher:
        |- flasher_cli-X.Y.Z                     -- main folder
           |- .tmp                               -- temporary folder created by the usip_player to save temp files
           |- doc
           |- lua                                -- more lua files
           |- lua_plugins                        -- lua plugins
           |- netx
              |- hboot                           -- hboot images, necessary for for the flasher
                 |- unsigned                     -- unsigned hboot images
                    |- netx90                    -- netx specific folder containing hboot images
                    |- netx90_usip               -- netx specific folder containing usip images
              |- helper
                 |- netx90                       -- helper files that must not be signed
           
           |- lua5.4(.exe)                       -- lua executable
           |- usip_player.lua                    -- usip_player lua file
    
    
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
        Load an USIP file to a netX 90, reset the netX , update SecureInfoPage, and continue boot process.
    ]]
    
    
    local tParserCommandUsip = tParser:command('usip u', strUsipHelp):target('fCommandUsipSelected')
    -- todo: make mandatory:
    tParserCommandUsip:option('-i --input'):count("1"):description("USIP image file path (image may only contain USIP chunks)"):target('strUsipFilePath')
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
        "Verify the signature of an usip image against a netX, stop if the signature is invalid. \n" ..
        "The netX will ignore USIP images with an invalid signature."
    ):target('fVerifySigEnable')
    :default(false)
    tParserCommandUsip:flag('--no_reset'
    ):description('Skip the last reset after booting an USIP. Without the reset, verifying the content is also disabled.'
    ):target('fDisableReset'):default(false)
    tParserCommandUsip:flag('--no_verify'):description(
        "Do not verify the content of a USIP image against a netX SIP content after writing the USIP. The reset, that activates the USIP data is still executed."
    ):target('fVerifyContentDisabled')
    :default(false)
    tParserCommandUsip:flag('--disable_helper_signature_check')
        :description('Disable signature checks on helper files.')
        :target('fDisableHelperSignatureChecks')
        :default(false)
    
    -- tParserCommandUsip:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
    -- tParserCommandUsip:flag('--extend_exec'):description(
    --     "Extends the usip file with an execute-chunk to activate JTAG."
    -- ):target('fExtendExec')
    -- todo add more help here
    tParserCommandUsip:option('--sec'):description("Path to signed image directory"):target('strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
    tParserCommandUsip:option('--sec_phase2 --sec_p2'):description(strHelpSecP2):target('strSecureOptionPhaseTwo')
    tParserCommandUsip:flag('--no_reset'
    ):description('Skip the last reset after booting an USIP. Without the reset, verifying the content is also disabled.'
    ):target('fDisableReset'):default(false)
    
    
    -- NXTFLASHER-565
    -- NXTFLASHER-906
    local strWriteSipPmHelp = [[
        Write Secure Info Pages (SIP) in production mode based on default values.
        The default values can be modified with the data from an USIP file.
        The calibration values 'atTempDiode' inside the APP SIP will be updated with the values from the CAL SIP
        Restrictions: netX 90 must be in initial mode (no active SIP protection, secure boot mode)
        Production mode: The data in the SIP is not yet activated and the the netX 90 is in initial mode
    ]]
    local tParserWriteSips = tParser:command('write_sip_pm wsp', strWriteSipPmHelp):target('fCommandWriteSipsSelected')
    tParserWriteSips:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
    tParserWriteSips:option(
        '-V --verbose'
    ):description(
        string.format(
            'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
        )
    ):argname('<LEVEL>'):default('debug'):target('strLogLevel')
    tParserWriteSips:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
    tParserWriteSips:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
    tParserWriteSips:option('--com_sip'):description("com SIP binary size 4kB"):target(
        'strComSipBinPath'):default(tFlasherHelper.NETX90_DEFAULT_COM_SIP_BIN):hidden(true)
    tParserWriteSips:option('--app_sip'):description("app SIP binary size 4kB"):target(
        'strAppSipBinPath'):default(tFlasherHelper.NETX90_DEFAULT_APP_SIP_BIN):hidden(true)

    -- maybe keep option '--_no_verify'
    tParserWriteSips:flag('--no_verify'):description(
        "Do not verify the content of a USIP image against a netX SIP content after writing the USIP. The reset, that activates the USIP data is still executed."
    ):target('fVerifyContentDisabled')
    tParserWriteSips:flag('--disable_helper_signature_check')
        :description('Disable signature checks on helper files.')
        :target('fDisableHelperSignatureChecks')
        :default(false)
    tParserWriteSips:flag('--set_sip_protection')
        :description('Set the SIP protection cookie.')
        :target('fSetSipProtectionCookie')
        :default(false)
    tParserWriteSips:flag('--set_kek')
        :description('Set the KEK (Key exchange key).')
        :target('fSetKek')
        :default(false)

    -- NXTFLASHER-906
    local strReadSipsPmHelp = [[
        Read Secure Info Pages (SIP) in production mode.
        Restrictions: netX 90 must be in initial mode (no active SIP protection, secure boot mode)
        Production mode: The data in the SIP is not yet activated and the the netX 90 is in initial mode
    ]]
    local tParserReadSipPm = tParser:command('read_sip_pm rsp', strReadSipsPmHelp):target('fCommandReadSipPmSelected')
    tParserReadSipPm:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
    tParserReadSipPm:option(
        '-V --verbose'
    ):description(
        string.format(
            'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
        )
    ):argname('<LEVEL>'):default('debug'):target('strLogLevel')
    tParserReadSipPm:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
    tParserReadSipPm:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
    tParserReadSipPm:argument('output'):description(
        "Set the output directory."
    ):target("strOutputFolder")
    tParserReadSipPm:flag('--read_cal'):description(
        "additional read out and store the cal secure info page"):target('fReadCal')

    -- NXTFLASHER-906
    local strVerifySipsPmHelp = [[
        Verify content of Secure Info Pages (SIP) in production mode.
        Restrictions: netX 90 must be in initial mode (no active SIP protection, secure boot mode)
        Production mode: The data in the SIP is not yet activated and the the netX 90 is in initial mode
    ]]
    local tParserVerifySipPm = tParser:command(
        'verify_sip_pm vsp', strVerifySipsPmHelp):target('fCommandVerifySipPmSelected')
    tParserVerifySipPm:option('-i --input'):description("USIP image file path"):target('strUsipFilePath')
    tParserVerifySipPm:option(
        '-V --verbose'
    ):description(
        string.format(
            'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
        )
    ):argname('<LEVEL>'):default('debug'):target('strLogLevel')
    tParserVerifySipPm:option('--com_sip'):description("com SIP binary size 4kB"):target(
        'strComSipBinPath'):default(tFlasherHelper.NETX90_DEFAULT_COM_SIP_BIN):hidden(true)
    tParserVerifySipPm:option('--app_sip'):description("app SIP binary size 4kB"):target(
        'strAppSipBinPath'):default(tFlasherHelper.NETX90_DEFAULT_APP_SIP_BIN):hidden(true)
    tParserVerifySipPm:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
    tParserVerifySipPm:option('-t --plugin_type'):description("plugin type"):target("strPluginType")

    tParserVerifySipPm:flag('--check_kek'):description(
        "additional read out and store the cal secure info page"):target('fCheckKek')
    tParserVerifySipPm:flag('--check_sip_protection'):description(
        "additional read out and store the cal secure info page"):target('fCheckSipProtection')
    local strConvertUsipHelp = [[
        apply data of an usip file to the default values of the secure info pages and export these as binary files
    ]]
    local tParserConvertUsip = tParser:command('convert_usip cu', strConvertUsipHelp):target('fCommandConvertUsipSelected')
    tParserConvertUsip:argument('input_file'):description("USIP image file path"):target('strUsipFilePath')
    tParserConvertUsip:option(
        '-V --verbose'
    ):description(
        string.format(
            'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
        )
    ):argname('<LEVEL>'):default('debug'):target('strLogLevel')
    tParserConvertUsip:argument('output')
        :description('Write the generated SIP pages to output directory.')
        :target('strOutputDir')
    tParserConvertUsip:flag('--set_sip_protection')
        :description('Set the SIP protection cookie.')
        :target('fSetSipProtectionCookie')
        :default(false)

    -- NXTFLASHER-692
    local strVerifyInitialModeHelp = [[
        verify that the netX is in an initial state which means:
        - SIP protection cookie is not set
        - secure boot mode is not enabled
        - SIPs are not hidden
        - CAL SIP rom func mode cookie is set
    ]]
    local tParserVerifyInitialMode = tParser:command('verify_initial_mode vim', strVerifyInitialModeHelp):target(
            'fCommandVerifyInitialModeSelected')
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
    
    tParserCommandDisableSecurity:flag('--verify_sig'):description(
        "Verify the signature of an usip image against a netX, stop if the signature is invalid. \n" .. 
        "The netX will ignore USIP images with an invalid signature."
    ):target('fVerifySigEnable')
    :default(false)
    tParserCommandDisableSecurity:flag('--no_reset'
    ):description('Skip the last reset after booting an USIP. Without the reset, verifying the content is also disabled.'
    ):target('fDisableReset'):default(false)
    tParserCommandDisableSecurity:flag('--no_verify'):description(
        "Do not verify the content of a USIP image against a netX SIP content after writing the USIP. The reset, that activates the USIP data is still executed."
    ):target('fVerifyContentDisabled')
    :default(false)
    
    -- todo add more help here
    tParserCommandDisableSecurity:option('--sec'):description("Path to signed helper image directory"):target(
        'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
    tParserCommandDisableSecurity:option('--signed_usip'):description("Path to the signed USIP file"):target(
        'strUsipFilePath'):default(path.join("netx", "hboot", "unsigned", "netx90_usip", "disable_security_settings.usp"))
    
    tParserCommandDisableSecurity:flag('--disable_helper_signature_check')
        :description('Disable signature checks on helper files.')
        :target('fDisableHelperSignatureChecks')
        :default(false)
    
    
    
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
        "Verify the signature of an usip image against a netX, stop if the signature is not valid. \n" .. 
        "The netX will ignore USIP images with an invalid signature."
    ):target('fVerifySigEnable')
    :default(false)
    tParserCommandKek:flag('--no_verify'):description(
        "Do not verify the content of a USIP image against a netX SIP content after writing the USIP. The reset, that activates the USIP data is still executed."
    ):target('fVerifyContentDisabled')
    tParserCommandKek:flag('--disable_helper_signature_check')
        :description('Disable signature checks on helper files.')
        :target('fDisableHelperSignatureChecks')
        :default(false)
    -- tParserCommandKek:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
    -- tParserCommandKek:flag('--extend_exec'):description(
    --     "Extends the usip file with an execute-chunk to activate JTAG."
    -- ):target('fExtendExec')
    tParserCommandKek:option('--sec'):description("Path to signed image directory"):target('strSecureOption'
    ):default(tFlasher.DEFAULT_HBOOT_OPTION)
    tParserCommandKek:option('--sec_phase2 --sec_p2'):description(strHelpSecP2):target('strSecureOptionPhaseTwo')
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
    tParserVerifyContent:option('-i --input'):count("1"):description("USIP binary file path"):target('strUsipFilePath')
    -- tParserVerifyContent:flag('--force_console'):description("Force the uart serial console."):target('fForceConsole')
    -- tParserVerifyContent:flag('--extend_exec'):description(
    --     "Use an execute-chunk to activate JTAG."
    -- ):target('fExtendExec')
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
    tParserReadSip:option('--sec'):description("Path to signed image directory"):target(
        'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
    tParserReadSip:flag('--read_cal'):description(
            "additional read out and store the cal secure info page"):target('fReadCal')
    tParserReadSip:flag('--disable_helper_signature_check')
        :description('Disable signature checks on helper files.')
        :target('fDisableHelperSignatureChecks')
        :default(false)
    
    
    -- Add the "detect_secure_mode" command and note, that it is moved to "cli_flash.lua"
    
    strDetectSecureModeHelp = [[
        This command was moved into cli_flash.lua and renamed to 'detect_secure_boot_mode' ('dsbm').
    ]]
    tParser:command(
        'detect_secure_mode', strDetectSecureModeHelp
    ):target('fCommandDetectSelected')
    
    
    -- Add the "get_uid" command and all its options.
    
    strGetUidHelp = [[
        Get the unique ID.
    ]]
    
    local tParserGetUid = tParser:command('get_uid gu', strGetUidHelp):target('fCommandGetUidSelected')
    tParserGetUid:option(
        '-V --verbose'
    ):description(
        string.format(
            'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', ')
        )
    ):argname('<LEVEL>'):default('debug'):target('strLogLevel')
    tParserGetUid:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
    tParserGetUid:option('-t --plugin_type'):description("plugin type"):target("strPluginType")
    tParserGetUid:option('--sec'):description("Path to signed image directory"):target(
        'strSecureOption'):default(tFlasher.DEFAULT_HBOOT_OPTION)
    tParserGetUid:flag('--disable_helper_signature_check')
        :description('Disable signature checks on helper files.')
        :target('fDisableHelperSignatureChecks')
        :default(false)
    
    -- Add command check_helper_signature chs
    local tParserCommandVerifyHelperSig = tParser:command('check_helper_signature chs', 'Verify the signatures of the helper files.'):target(
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

    return tArgs
    --------------------------------------------------------------------------
    -- ArgParser
    --------------------------------------------------------------------------
end


local function main()
    --------------------------------------------------------------------------
    -- Arugments
    --------------------------------------------------------------------------
    local tArgs = setup_argparser()

    -------------------------------------------------------------------------
    -- Logger
    --------------------------------------------------------------------------
    local tLogWriterConsole = require 'log.writer.console'.new()
    local tLogWriterFilter = require 'log.writer.filter'.new(tArgs.strLogLevel, tLogWriterConsole)
    local tLogWriter = require 'log.writer.prefix'.new('[Main] ', tLogWriterFilter)
    local tLog = require 'log'.new('trace', tLogWriter, require 'log.formatter.format'.new())

    -- print args
    tFlasherHelper:printArgs(tArgs, "usip_player.lua", tLog)

    local usip_gen = require 'usip_generator'
    local sipper = require 'sipper'
    local tUsipGenerator = usip_gen(tLog)
    local tSipper = sipper(tLog)


    --------------------------------------------------------------------------
    -- variables
    --------------------------------------------------------------------------
    local fFinalResult = false
    local strErrorMsg
  
    local iChiptype = nil

    -- set fFinalResult to false, be pessimistic

    local iWriteSipResult
    local uResultCode = tSipper.VERIFY_RESULT_ERROR

    local usip_player = require 'lua.usip_player_class'

    local tUsipPlayer = usip_player(
        tLog,
        tArgs.strSecureOption,
        tArgs.strSecureOptionPhaseTwo,
        tArgs.strPluginName,
        tArgs.strPluginType,
        tArgs.fDisableHelperSignatureChecks
    )

    -- set the path for set_sip_protection_cookie.usp
    if tArgs.fCommandCheckSIPCookie then
        tArgs.strUsipFilePath = path.join(tFlasher.HELPER_FILES_PATH, "netx90", "set_sip_protection_cookie.usp")
    end


    -- check if the usip command is selected
    --------------------------------------------------------------------------
    -- USIP COMMAND
    --------------------------------------------------------------------------
    if tArgs.fCommandUsipSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING USIP COMMAND               #")
        tLog.info("######################################")
        fFinalResult, strErrorMsg = tUsipPlayer:commandUsip(
            tArgs.strUsipFilePath,
            tArgs.fVerifyContentDisabled,
            tArgs.fDisableReset,
            tArgs.fVerifySigEnable
        )

    --------------------------------------------------------------------------
    -- VERIFY INITIAL MODE
    --------------------------------------------------------------------------
    elseif tArgs.fCommandVerifyInitialModeSelected then
        tLog.info("#######################################")
        tLog.info("# RUNNING VERIFY INITIAL MODE COMMAND #")
        tLog.info("#######################################")
        local iVerifyInitialModeResult

        iVerifyInitialModeResult, strErrorMsg = tUsipPlayer:commandVerifyInitialMode()

        if iVerifyInitialModeResult == tUsipPlayer.WS_RESULT_OK then
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
            if iVerifyInitialModeResult == tUsipPlayer.WS_RESULT_ERROR_SECURE_BOOT_ENABLED then
                tLog.error('RESULT: secure boot enabled')
            elseif iVerifyInitialModeResult == tUsipPlayer.WS_RESULT_ERROR_SIP_PROTECTION_SET then
                tLog.error('RESULT: SIP protection cookie is set')
            elseif iVerifyInitialModeResult == tUsipPlayer.WS_RESULT_ERROR_UNSPECIFIED then
                tLog.error('RESULT:unspecified error occured')
            elseif iVerifyInitialModeResult == tUsipPlayer.WS_RESULT_ERROR_SIP_HIDDEN then
                tLog.error('RESULT: one or more secure info page is hidden')
            end
            tLog.error(strErrorMsg)
            tLog.info('RETURN: '.. iVerifyInitialModeResult)
            os.exit(iVerifyInitialModeResult)
        end
    --------------------------------------------------------------------------
    -- CONVERT USIP COMMAND
    --------------------------------------------------------------------------
    elseif tArgs.fCommandConvertUsipSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING CONVERT USIP COMMAND       #")
        tLog.info("######################################")
        local strComSipData
        local strAppSipData

        fFinalResult, strErrorMsg = tUsipPlayer:commandConvertUsipToBin(
            tArgs.strUsipFilePath,
            tFlasherHelper.NETX90_DEFAULT_COM_SIP_BIN,
            tFlasherHelper.NETX90_DEFAULT_APP_SIP_BIN,
            tArgs.fSetSipProtectionCookie,
            tArgs.strOutputDir
        )

    --------------------------------------------------------------------------
    -- WRITE SIP PM COMMAND
    --------------------------------------------------------------------------
    elseif tArgs.fCommandWriteSipsSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING WRITE SIP PM COMMAND       #")
        tLog.info("######################################")
        local strComSipBaseData
        local strAppSipBaseData
        local strErrorMsg


        iWriteSipResult, strErrorMsg = tUsipPlayer:writeAllSips(
            tArgs.strComSipBinPath,
            tArgs.strAppSipBinPath,
            tArgs.strUsipFilePath,
            nil,
            tArgs.fSetSipProtectionCookie,
            tArgs.fSetKek,
            tArgs.strComOutputFile,
            tArgs.strAppOutputFile
        )
        if iWriteSipResult == tUsipPlayer.WS_RESULT_OK then
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
            if iWriteSipResult == tUsipPlayer.WS_RESULT_ERROR_SECURE_BOOT_ENABLED then
                tLog.error('RESULT: secure boot enabled')
            elseif iWriteSipResult == tUsipPlayer.WS_RESULT_ERROR_SIP_PROTECTION_SET then
                tLog.error('RESULT: SIP protection cookie is set')
            elseif iWriteSipResult == tUsipPlayer.WS_RESULT_ERROR_UNSPECIFIED then
                tLog.error('RESULT:unspecified error occured')
            elseif iWriteSipResult == tUsipPlayer.WS_RESULT_ERROR_SIP_HIDDEN then
                tLog.error('RESULT: one or more secure info page is hidden')
            end
            tLog.error(strErrorMsg)
            tLog.info('RETURN: '.. iWriteSipResult)
            os.exit(iWriteSipResult)
        end
    --------------------------------------------------------------------------
    -- WRITE SIP PM COMMAND
    --------------------------------------------------------------------------
    elseif tArgs.fCommandReadSipPmSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING READ SIP PM COMMAND        #")
        tLog.info("######################################")

        fFinalResult, strErrorMsg = tUsipPlayer:commandReadSipPm(tArgs.strOutputFolder, tArgs.fReadCal)

    --------------------------------------------------------------------------
    -- WRITE SIP PM COMMAND
    --------------------------------------------------------------------------
    elseif tArgs.fCommandVerifySipPmSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING VERIFY SIP PM COMMAND      #")
        tLog.info("######################################")

        fFinalResult, strErrorMsg = tUsipPlayer:commandVerifySipPm(
            tArgs.strUsipFilePath,
            tArgs.strAppSipBinPath,
            tArgs.strComSipBinPath,
            tArgs.fCheckKek,
            tArgs.fCheckSipProtection
        )

    --------------------------------------------------------------------------
    -- Disable Security COMMAND
    --------------------------------------------------------------------------
    elseif tArgs.fCommandDisableSecurity then
        tLog.info("##############################################")
        tLog.info("# RUNNING Disable Security Setting COMMAND   #")
        tLog.info("##############################################")

        fFinalResult, strErrorMsg = tUsipPlayer:commandUsip(
            tArgs.strUsipFilePath,
            tArgs.fVerifyContentDisabled,
            tArgs.fDisableReset,
            tArgs.fVerifySigEnable
        )


    --------------------------------------------------------------------------
    -- Set SIP Command
    --------------------------------------------------------------------------
    elseif tArgs.fCommandSipSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING SET SIP PROTECTION COMMAND #")
        tLog.info("######################################")
        fFinalResult, strErrorMsg = tUsipPlayer:set_sip_protection_cookie()
    --------------------------------------------------------------------------
    -- Set Key Exchange Key
    --------------------------------------------------------------------------
    elseif tArgs.fCommandKekSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING SET KEK COMMAND            #")
        tLog.info("######################################")
        fFinalResult, strErrorMsg = tUsipPlayer:commandSetKek(
            tArgs.strUsipFilePath,
            tArgs.fVerifyContentDisabled,
            tArgs.fDisableReset,
            tArgs.fVerifySigEnable
        )

    --------------------------------------------------------------------------
    -- READ SIP
    --------------------------------------------------------------------------
    elseif tArgs.fCommandReadSelected then
        tLog.info("######################################")
        tLog.info("# RUNNING READ SIP COMMAND           #")
        tLog.info("######################################")

        fFinalResult, strErrorMsg =  tUsipPlayer:commandReadSip(
            tArgs.strOutputFolder,
            tArgs.fReadCal
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
        fFinalResult = tUsipPlayer:getUidCommand()

    --------------------------------------------------------------------------
    -- VERIFY CONTENT
    --------------------------------------------------------------------------
    elseif tArgs.fCommandVerifySelected then

        tLog.info("######################################")
        tLog.info("# RUNNING VERIFY CONTENT COMMAND     #")
        tLog.info("######################################")
        uResultCode, strErrorMsg = tUsipPlayer:commandVerify(
        tArgs.strUsipFilePath
        )
    --    if uResultCode == tSipper.VERIFY_RESULT_OK then
    --        tLog.info("The data in the info page(s) is equal to the data in the USIP file.")
    --        if strErrorMsg then 
    --            tLog.info(strErrorMsg)
    --        end
    --        fFinalResult = true
    --    elseif uResultCode == tSipper.VERIFY_RESULT_FALSE then
    --        tLog.error("The data in the info page(s) differs from the data in the USIP file:")
    --        tLog.error(strErrorMsg or "Unknown error")
    --        fFinalResult = false
    --    else
    --        tLog.info("The data in the info page(s) could not compared to the data in the USIP file as an error occurred:")
    --        tLog.error(strErrorMsg or "Unknown error")
    --        fFinalResult = false
    --    end
        print("uResultCode: " .. uResultCode)
        if uResultCode == tSipper.VERIFY_RESULT_OK then
            tLog.info('')
            tLog.error("")
            tLog.error("########  ######   ##    ##  ######  ##      ")
            tLog.error("##       ##    ##  ##    ## ##    ## ##      ")
            tLog.error("##       ##    ##  ##    ## ##    ## ##      ")
            tLog.error("#######  ##    ##  ##    ## ######## ##      ")
            tLog.error("##       ##  ####  ##    ## ##    ## ##      ")
            tLog.error("##       ##   ###  ##    ## ##    ## ##      ")
            tLog.error("########  ##### ##  ######  ##    ## ########")
            tLog.info('')
            tLog.info('RESULT: The data in the info page(s) is equal to the data in the USIP file.')
            if strErrorMsg then 
                tLog.info(strErrorMsg)
            end

        elseif uResultCode == tSipper.VERIFY_RESULT_FALSE then
            tLog.error("")
            tLog.error("##    ##  #######  ########     ########  ######   ##    ##  ######  ##      ")
            tLog.error("###   ## ##     ##    ##        ##       ##    ##  ##    ## ##    ## ##      ")
            tLog.error("####  ## ##     ##    ##        ##       ##    ##  ##    ## ##    ## ##      ")
            tLog.error("## ## ## ##     ##    ##        #######  ##    ##  ##    ## ######## ##      ")
            tLog.error("##  #### ##     ##    ##        ##       ##  ####  ##    ## ##    ## ##      ")
            tLog.error("##   ### ##     ##    ##        ##       ##   ###  ##    ## ##    ## ##      ")
            tLog.error("##    ##  #######     ##        ########  ##### ##  ######  ##    ## ########")
            tLog.error("")
            tLog.error("RESULT: The data in the info page(s) differs from the data in the USIP file:")
            tLog.error(strErrorMsg or "Unknown error")

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
            tLog.info("RESULT: The data in the info page(s) could not be checked as an error has occurred:")
            tLog.error(strErrorMsg or "Unknown error")

        end
        tLog.info('RETURN: '.. uResultCode)
        os.exit(uResultCode)


    elseif tArgs.fCommandCheckSIPCookie then

        tLog.info("################################################")
        tLog.info("# RUNNING DETECT SIP PROTECTION COOKIE COMMAND #")
        tLog.info("################################################")
        uResultCode, strErrorMsg = tUsipPlayer:commandVerify(
        tArgs.strUsipFilePath
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

        tLog.info("Checking signatures of helper files...**")

        fFinalResult, strErrorMsg = tUsipPlayer:verifyHelperSignatures()



        if fFinalResult then
            tLog.info("The signatures of the helper files have been successfully verified.")
        else
            tLog.error(strErrorMsg)
            tLog.error( "The signatures of the helper files could not be verified." )
            tLog.error( "Please check if the helper files are signed correctly." )
        end

    else
        tLog.error("No valid command. Use -h/--help for help.")
        fFinalResult = false
    end

    if not tArgs.fCommandConvertUsipSelected then
        tUsipPlayer:_deinit()
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
end


if pcall(debug.getlocal, 4, 1) then
    -- print("Sipper used as Library")
    -- do nothing
else
    -- print("Main file")
    main()
end

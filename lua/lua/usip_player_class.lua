local class = require 'pl.class'
local mhash = require 'mhash'
local path = require 'pl.path'
local archive = require 'archive'


local SIP_ATTRIBUTES = {
    CAL={iBus=2, iUnit=0,iChipSelect=1},
    COM={iBus=2, iUnit=1,iChipSelect=3},
    APP={iBus=2, iUnit=2,iChipSelect=3},
}



local UsipPlayer = class()


function UsipPlayer:_init(tLog, strSecureOption, strSecureOptionPhaseTwo, strPluginName, strPluginType, fDisableHelperSignatureChecks, fDoReset)
    --tLog.info("initialize UsipPlayer")
    self.tLog = tLog

    -- todo check if all of these are requried all the time
    local usip_gen = require 'usip_generator'
    local sipper = require 'sipper'

    self.WS_RESULT_OK = 0
    self.WS_RESULT_ERROR_UNSPECIFIED = 1
    self.WS_RESULT_ERROR_SIP_PROTECTION_SET = 2
    self.WS_RESULT_ERROR_SECURE_BOOT_ENABLED = 3
    self.WS_RESULT_ERROR_SIP_HIDDEN = 4
    self.WS_RESULT_ROM_FUNC_MODE_COOKIE_NOT_SET = 5

    self.COM_SIP_KEK_SET                    = 0xA11C0DED    -- KEK was programmed into the SIP
    self.COM_SIP_KEK_NOT_SET                = 0xBA1DBA1D    -- KEK area is bald (no kek is set)
    self.COM_SIP_SIP_PROTECTION_SET         = 0xAFFEDEAD    -- sip protection closed monkey dead
    self.COM_SIP_SIP_PROTECTION_NOT_SET     = 0x0A11C001    -- sip protection not set all cool

    self.tFlasher = require 'flasher'
    self.tFlasherHelper = require 'flasher_helper'
    self.tHelperFiles = require 'helper_files'
    self.tVerifySignature = require 'verify_signature'

    if fDoReset == nil then
        self.fDoReset = true
    else
        self.fDoReset = fDoReset
    end

    self.tUsipGenerator = usip_gen(tLog)
    self.tSipper = sipper(tLog)

    self.tPlugin = nil
    self.strPluginName = nil
    self.strPluginType = nil
    self.fDisableHelperSignatureChecks = fDisableHelperSignatureChecks

    if strPluginName then
        self.strPluginName = strPluginName
    end
    if strPluginType then
        self.strPluginType = strPluginType
    end

    local usipPlayerConf = require 'usip_player_conf'
    self.tempFolderConfPath = usipPlayerConf.tempFolderConfPath

    -- check if the temp folder exists, if it does not exists, create it
    if not path.exists(self.tempFolderConfPath) and self.tFlasherHelper.getStoreTempFiles() then
        path.mkdir(self.tempFolderConfPath)
    end

    local strHelperFileStatus = self.tHelperFiles.getStatusString()
    tLog.info(strHelperFileStatus)
    tLog.info("")

    if strSecureOption == nil then
        self.strSecureOption = self.tFlasher.DEFAULT_HBOOT_OPTION
    else
        self.strSecureOption = strSecureOption
    end
    if strSecureOptionPhaseTwo == nil then
        self.strSecureOptionPhaseTwo = self.strSecureOption
    else
        self.strSecureOptionPhaseTwo = strSecureOptionPhaseTwo
    end
    

    if self.strSecureOption ~= self.tFlasher.DEFAULT_HBOOT_OPTION then
        self.fIsSecure = true
    else
        self.fIsSecure = false
    end

    self:setHelperPaths()
    -- self:setPluginOptions()
end

function UsipPlayer:_deinit()
    if self.tPlugin then
        self.tPlugin:Disconnect()
        self.tPlugin = nil
    end
end

function UsipPlayer:dumpSipFiles(strOutputFolderPath, strComSipData, strAppSipData, strCalSipData)
    local tResult
    local strErrorMsg = ""

    -- set the sip file path to save the sip data
    if strOutputFolderPath == nil then
        strOutputFolderPath = self.tempFolderConfPath
    end
    if not path.exists(strOutputFolderPath) then
        self.tFlasherHelper.create_directory_path(strOutputFolderPath)
    end

    local strComSipFilePath = path.join( strOutputFolderPath, "com_sip.bin")
    local strAppSipFilePath = path.join( strOutputFolderPath, "app_sip.bin")
    -- write the com sip data to a file
    self.tLog.info("Saving COM SIP to %s ", strComSipFilePath)
    local tFile = io.open(strComSipFilePath, "wb")
    tFile:write(strComSipData)
    tFile:close()
    -- write the app sip data to a file
    self.tLog.info("Saving APP SIP to %s ", strAppSipFilePath)
    tFile = io.open(strAppSipFilePath, "wb")
    tFile:write(strAppSipData)
    tFile:close()

    if strCalSipData ~= nil then
        local strCalSipFilePath = path.join( strOutputFolderPath, "cal_sip.bin")
        -- write the com sip data to a file
        self.tLog.info("Saving CAL SIP to %s ", strCalSipFilePath)
        local tFile = io.open(strCalSipFilePath, "wb")
        tFile:write(strCalSipData)
        tFile:close()
    end
    tResult = true
    return tResult, strErrorMsg
end

function UsipPlayer:commandReadSip(
    strOutputFolderPath,
    fReadCal,
    tPlugin,
    fStoreFile
)

    local tResult
    local strErrorMsg
    local astrHelpersTmp = {"verify_sig", "read_sip_m2m"}
    local iReadSipResult
    local strCalSipData
    local strComSipData
    local strAppSipData
    if fStoreFile == nil then
        fStoreFile = true
    end

    if strOutputFolderPath == nil then
        strOutputFolderPath = self.tempFolderConfPath
    end


    tResult, strErrorMsg = self:prepareInterface(true, tPlugin)

    if tResult then
        tResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
    end

    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------
    if tResult then
        iReadSipResult, strErrorMsg, strCalSipData, strComSipData, strAppSipData =  self:readSip(
            self.strReadSipPath, self.atPluginOptions, self.strExecReturnPath)

        if iReadSipResult and fStoreFile then
            tResult, strErrorMsg = self:dumpSipFiles(strOutputFolderPath, strComSipData, strAppSipData, strCalSipData)
        elseif iReadSipResult and fStoreFile == false then
            self.tLog.info("do not save output files")
        else
            tResult = false
            self.tLog.error(strErrorMsg)
        end
    end
    return tResult, strErrorMsg, strCalSipData, strComSipData, strAppSipData
end


function UsipPlayer:commandVerifyInitialMode()
    local tResult
    local strErrorMsg
    local aAttr
    local flasher_path = "netx/"
    local fConnected
    local astrHelpersTmp = {"flasher_netx90_hboot"}
    local ulConsoleMode


    tResult, strErrorMsg, ulConsoleMode = self:prepareInterface(true)

    if self.strPluginType == "romloader_uart" then
        table.insert(astrHelpersTmp,  "start_mi")
    end

    if tResult then
        tResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
        if tResult then
            tResult = self.WS_RESULT_OK
        end
    elseif tResult == false and ulConsoleMode == 1 then
        tResult = self.WS_RESULT_ERROR_SECURE_BOOT_ENABLED
    end

    if tResult == self.WS_RESULT_OK  then
        -- fConnected, strErrorMsg = self.tFlasherHelper.connect_retry(self.tPlugin)

        aAttr = self.tFlasher.download(self.tPlugin, flasher_path, nil, true, self.strSecureOption)
        tResult = self.WS_RESULT_OK

    end

    if tResult == self.WS_RESULT_OK then
        -- check if any of the secure info pages are hidden
        tResult, strErrorMsg = self:verifyInitialMode(aAttr)
    end
    return tResult, strErrorMsg
end
function UsipPlayer:commandVerify(strUsipFilePath)
    local uVerifyResult
    local strErrorMsg
    local tResult
    local tUsipDataList
    local tUsipPathList
    local tUsipConfigDict
    local astrHelpersTmp = {"verify_sig", "read_sip_m2m"}

    tResult, strErrorMsg = self:prepareInterface(true)

    if tResult then
        tResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
    end
    if tResult then

        tResult, strErrorMsg, tUsipDataList, tUsipPathList, tUsipConfigDict = self:prepareUsip(strUsipFilePath)
    end

    if tResult then

    uVerifyResult, strErrorMsg = self:verifyContent(
        self.strReadSipPath,
        tUsipConfigDict,
        self.atPluginOptions,
        self.strExecReturnPath
    )
    else
        uVerifyResult = self.tSipper.VERIFY_RESULT_ERROR
    end

    return uVerifyResult, strErrorMsg

end

function UsipPlayer:commandUsip(
    strUsipFilePath,
    fVerifyContentDisabled,
    fDisableReset,
    fVerifySigEnable
)
    local tResult
    local strErrorMsg
    local tUsipDataList
    local tUsipPathList
    local tUsipConfigDict
    local astrHelpersTmp = {"verify_sig"}

    -- only check signature of read sip binary if we also read out the content after booting usip
    if not fVerifyContentDisabled then
        table.insert(astrHelpersTmp,  "read_sip_m2m")
    end

    tResult, strErrorMsg = self:prepareInterface(true)

    if tResult then
        tResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
    end

    if tResult then

        tResult, strErrorMsg, tUsipDataList, tUsipPathList, tUsipConfigDict = self:prepareUsip(strUsipFilePath)
    end

    if tResult then
        tResult, strErrorMsg = self:usip(
            tUsipDataList,
            tUsipPathList,
            tUsipConfigDict,
            fVerifyContentDisabled,
            fDisableReset,
            fVerifySigEnable
        )
    end
    return tResult, strErrorMsg
end

function UsipPlayer:commandSetKek(
    strUsipFilePath,
    fVerifyContentDisabled,
    fDisableReset,
    fVerifySigEnable
)
    local tResult
    local strErrorMsg
    local tUsipDataList = {}
    local tUsipPathList = {}
    local tUsipConfigDict
    local astrHelpersTmp = {"verify_sig"}

    -- only check signature of read sip binary if we also read out the content after booting usip
    if not fVerifyContentDisabled then
        table.insert(astrHelpersTmp,  "read_sip_m2m")
    end

    tResult, strErrorMsg = self:prepareInterface(true)

    if tResult then
        tResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
    end

    if tResult then
        if strUsipFilePath ~= nil then
            tResult, strErrorMsg, tUsipDataList, tUsipPathList, tUsipConfigDict = self:prepareUsip(
                strUsipFilePath,
                false
            )
        end

    end

    if tResult then
        tResult, strErrorMsg = self:setKek(
            tUsipDataList,
            tUsipPathList,
            tUsipConfigDict,
            fVerifyContentDisabled,
            fDisableReset,
            fVerifySigEnable
        )
    end
    return tResult, strErrorMsg
end

function UsipPlayer:prepareInterface(fConnect, tPlugin)
    local tResult
    local strErrorMsg
    local fCallSuccess
    local strNetxName
    local ulConsoleMode
    self:setPluginOptions()

    -- TODO: no longer used
    -- more requirements
    -- Set the search path for LUA plugins.
    package.cpath = package.cpath .. ";lua_plugins/?.dll"

    -- Set the search path for LUA modules.
    package.path = package.path .. ";lua/?.lua;lua/?/init.lua"

    -- Load the common romloader plugins.
    require("romloader_eth")
    require("romloader_uart")
    require("romloader_jtag")
    if tPlugin == nil then
        fCallSuccess, tPlugin = pcall(
            self.tFlasherHelper.getPlugin,
            self.strPluginName,
            self.strPluginType,
            self.atPluginOptionsFirstConnect
        )
    else
        fCallSuccess = true
    end
    if fCallSuccess then
        self.tPlugin = tPlugin
        if self.strPluginName == nil then
            self.strPluginName = tPlugin:GetName()
        end
        if  self.strPluginType == nil then
            self.strPluginType = tPlugin:GetTyp()
        end

        if self.strPluginType == "romloader_eth" then
            self.strBootswitchParams = "ETH"
        elseif self.strPluginType == "romloader_uart" then
            self.strBootswitchParams = "UART"
        elseif self.strPluginType == "romloader_jtag" then
            self.strBootswitchParams = "JTAG"
        end

        if fConnect then
            -- catch the romloader error to handle it correctly
            tResult, strErrorMsg, ulConsoleMode = self.tFlasherHelper.connect_retry(tPlugin, 5)
            if tResult == false then
                self.tLog.error(strErrorMsg)
            else
                self.iChiptype = tPlugin:GetChiptyp()
                self.tLog.debug( "Found Chip type: %d", self.iChiptype)

                strNetxName = self.tFlasherHelper.chiptypeToName(self.iChiptype)
                if not strNetxName then
                    self.tLog.error("Can not associate the chiptype with a netx name!")
                    strErrorMsg = "Can not associate the chiptype with a netx name!"
                    tResult = false
                end
                -- check if the netX is supported
                local romloader = _G.romloader
                if strNetxName ~= "netx90" then
                    self.tLog.error("The connected netX (%s) is not supported.", strNetxName)
                    self.tLog.error("Only netX90_rev1 and newer netX90 Chips are supported.")
                    tResult = false
                    strErrorMsg = string.format("The connected netX (%s) is not supported.", strNetxName)
                elseif self.iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90A or
                        self.iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B or
                        self.iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C then
                    self.tLog.debug("Detected netX90 rev1")
                elseif self.iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90D then
                    self.tLog.debug("Detected netX90 rev2")
                end
            end
            self.ulPluginM2MMajor = self.tPlugin:get_mi_version_maj()
            self.ulPluginM2MMinor = self.tPlugin:get_mi_version_min()
        end

    else
        if self.strPluginName then
			self.tLog.error( "Could not get selected interface -> %s.", self.strPluginName )
		else
			self.tLog.error( "Could not get the interactive selected interface" )
		end
		-- this is a bit missleading, but in case of an error the pcall function returns as second paramater
		-- the error message. But because the first return parameter of the getPlugin function is the tPlugin
		-- the parameter name convention is a bit off ...
		self.tLog.error(tPlugin)
        strErrorMsg = tPlugin
		tResult = false
    end
    return tResult, strErrorMsg, ulConsoleMode
end

function UsipPlayer:prepareUsip(strUsipFilePath, fNoBootswitch)
    local tResult
    local strErrorMsg
    local tUsipConfigDict
    local tUsipDataList
    local tUsipPathList

    if path.exists(strUsipFilePath) then
        self.tLog.info("Found USIP file ... ")
    else
        -- exit with an error if the file does not exist
        self.tLog.error( "Could not find file %s", strUsipFilePath)
        os.exit(1)
    end

    -- analyze the usip file
    tResult, strErrorMsg, tUsipConfigDict = self.tUsipGenerator:analyze_usip(strUsipFilePath)


    -- check if multiple usip where found
    if tResult == true then
        if (self.iChiptype == 14  or self.iChiptype == 17) and tUsipConfigDict["num_of_chunks"] > 1  then
            tResult, tUsipDataList, tUsipPathList = self:genMultiUsips(tUsipConfigDict)
        else
            local strData, strMsg = self.tFlasherHelper.loadBin(strUsipFilePath)
            if strData then
                tUsipDataList = {strData}
                tUsipPathList = {strUsipFilePath}
                tResult = true
            else
                strErrorMsg = strMsg
                tResult = false
            end
        end
    end


    -- extent all usip data strings with either a bootswitch or extend exec image
    local tUsipDataListOld = tUsipDataList
    tUsipDataList = {}
    for _, strSingleUsipData in ipairs(tUsipDataListOld) do
        if fNoBootswitch ~= false then
            -- check if usip needs extended by the bootswitch with parameters
            if self.strBootswitchParams ~= nil and self.strBootswitchParams ~= "JTAG" then
                self.tLog.debug("Extending USIP file with bootswitch.")
                tResult, strSingleUsipData, strErrorMsg = self:extendBootswitchData(
                    strSingleUsipData, self.strBootswitchParams
                )
                self.tLog.debug(strErrorMsg)
            elseif self.strBootswitchParams == "JTAG" then
                self.tLog.debug("Extending USIP file with exec.")
                tResult, strSingleUsipData, strErrorMsg = self:extendExecReturnData(
                    strSingleUsipData, self.strExecReturnPath
                )
            else
                -- tLog.debug(strMsg)
                tResult = true
            end
        else
            tResult = true
        end

        -- continue check
        if not tResult then
            -- this is an error message from the extendBootswitchData 
            -- or extendExecReturnData function
                self.tLog.error(strErrorMsg)
            break
        end
        table.insert(tUsipDataList, strSingleUsipData)
    end

    return tResult, strErrorMsg, tUsipDataList, tUsipPathList, tUsipConfigDict
end

function UsipPlayer:setHelperPaths()
    local strMsg
    self.strnetX90HelperPath = path.join(self.strSecureOption, "netx90")
    self.strnetX90M2MImageBin, strMsg = self.tHelperFiles.getHelperFile(self.strnetX90HelperPath, "start_mi")
    if self.strnetX90M2MImageBin == nil then
        self.tLog.error(strMsg or "Error: Failed to load netX 90 M2M image (unknown error)")
        os.exit(1)
    end

    if self.strSecureOption ~= self.strSecureOptionPhaseTwo then

        self.strnetX90ResetHelperPath = path.join(self.strSecureOptionPhaseTwo, "netx90")
        self.strNetX90ResetM2MImageBin, strMsg = self.tHelperFiles.getHelperFile(
            self.strnetX90ResetHelperPath,
             "start_mi"
            )

        if self.strNetX90ResetM2MImageBin == nil then
            self.tLog.error(strMsg or "Error: Failed to load netX 90 M2M image (unknown error)")
            os.exit(1)
        end
    end

    self.strSecureOptionDir = path.join(self.strSecureOption, "netx90")
    self.strSecureOptionPhaseTwoDir = path.join(self.strSecureOptionPhaseTwo, "netx90")

    self.strReadSipPath         = self.tHelperFiles.getHelperPath(self.strSecureOptionDir, "read_sip_m2m")
    self.strExecReturnPath      = self.tHelperFiles.getHelperPath(self.strSecureOptionDir, "return_exec")
    self.strVerifySigPath       = self.tHelperFiles.getHelperPath(self.strSecureOptionDir, "verify_sig")
    self.strBootswitchFilePath  = self.tHelperFiles.getHelperPath(self.strSecureOptionDir, "bootswitch")
    self.strKekHbootFilePath    = self.tHelperFiles.getHelperPath(self.strSecureOptionDir, "set_kek")

    self.strResetReadSipPath    = self.tHelperFiles.getHelperPath(self.strSecureOptionPhaseTwoDir, "read_sip_m2m")
    self.strResetExecReturnPath = self.tHelperFiles.getHelperPath(self.strSecureOptionPhaseTwoDir, "return_exec")
    self.strResetBootswitchPath = self.tHelperFiles.getHelperPath(self.strSecureOptionPhaseTwoDir, "bootswitch")
    self.strResetVerifySigPath  = self.tHelperFiles.getHelperPath(self.strSecureOptionPhaseTwoDir, "verify_sig")



end
function UsipPlayer:verifyHelperSignatures()
    local tResult
    local astrFileData
    local astrPaths
    local atResults
    local strErrorMsg
    local strPath = path.join(self.strSecureOption, "netx90")
    tResult, strErrorMsg = self:prepareInterface(true)
    astrFileData, astrPaths = self.tHelperFiles.getAllHelperFilesData(
        {strPath}
    )
    if not astrFileData then
        -- This error should not occur, as all files have previously been checked.
        self.tLog.error("Error during file checks: could not read all helper binaries.")
        strErrorMsg = "Error during file checks: could not read all helper binaries."
    elseif not tResult then
        self.tLog.error(strErrorMsg)
    else
        -- TODO: how to be sure that the verify sig will work correct?
        -- NOTE: If the verify_sig file is not signed correctly the process will fail
        -- is there a way to verify the signature of the verify_sig itself?
        tResult, atResults = self.tVerifySignature.verifySignature(
            self.tPlugin,
            self.strPluginType,
            astrFileData,
            astrPaths,
            self.tempFolderConfPath,
            self.strVerifySigPath
        )

        self.tHelperFiles.showFileCheckResults(atResults)

        -- TODO: kann die Fehlermeldung geändert werden?
        if not tResult then
            self.tLog.error( "The signatures of the helper binaries could not be verified." )
            self.tLog.error( "Please check if the helper binaries are signed correctly" )
            strErrorMsg = "Error during file checks: could not read all helper binaries." ..
            " Please check if the helper binaries are signed correctly."
        end
    end
    return tResult, strErrorMsg
end

function UsipPlayer:prepareHelperFiles( astrHelpersToCheck, fCheckInterfaceImages)
    local atResults
    local tResult
    local strErrorMsg
    local astrFileData
    local astrPaths
    local astrVersionCheckDirs

    if fCheckInterfaceImages then
        if self.strPluginType == "romloader_eth" then
            table.insert(astrHelpersToCheck,  "bootswitch")
        elseif self.strPluginType == "romloader_uart" then
            table.insert(astrHelpersToCheck,  "bootswitch")
            table.insert(astrHelpersToCheck,  "start_mi")
        elseif self.strPluginType == "romloader_jtag" then
            table.insert(astrHelpersToCheck,  "return_exec")
        end
    end

    if self.strSecureOptionPhaseTwoDir == self.strSecureOptionDir then
        astrVersionCheckDirs = {self.strSecureOptionDir}
    else
        astrVersionCheckDirs = {self.strSecureOptionDir, self.strSecureOptionPhaseTwoDir}
    end

    tResult = self.tHelperFiles.checkHelperFiles(astrVersionCheckDirs, astrHelpersToCheck)
    if not tResult then
        self.tLog.error("Error during file version checks.")
        strErrorMsg = "Error during file version checks."
    else
        if self.fDisableHelperSignatureChecks then
            self.tLog.info("Skipping signature checks for helper files.")
        elseif self.fIsSecure then
            self.tLog.info("Checking signatures of helper files...")

            tResult, astrFileData, astrPaths = self.tHelperFiles.getHelperDataAndPaths(
                {self.strSecureOptionDir},
                astrHelpersToCheck
            )
            if not tResult then
                -- This error should not occur, as all files have previously been checked.
                self.tLog.error("Error during file checks: could not read all helper binaries.")
                strErrorMsg = "Error during file checks: could not read all helper binaries."
            else
                -- TODO: how to be sure that the verify sig will work correct?
                -- NOTE: If the verify_sig file is not signed correctly the process will fail
                -- is there a way to verify the signature of the verify_sig itself?
                tResult, atResults = self.tVerifySignature.verifySignature(
                    self.tPlugin,
                    self.strPluginType,
                    astrFileData,
                    astrPaths,
                    self.tempFolderConfPath,
                    self.strVerifySigPath
                )

                self.tHelperFiles.showFileCheckResults(atResults)

                -- TODO: kann die Fehlermeldung geändert werden?
                if not tResult then
                    self.tLog.error( "The signatures of the helper binaries could not be verified." )
                    self.tLog.error( "Please check if the helper binaries are signed correctly" )
                    strErrorMsg = "Error during file checks: could not read all helper binaries." ..
                    " Please check if the helper binaries are signed correctly."
                end
            end
            if self.strSecureOptionPhaseTwo ~= self.tFlasher.DEFAULT_HBOOT_OPTION and
            self.strSecureOptionPhaseTwo ~= self.strSecureOption then
                self.tLog.warning("The signatures of the helper files in the secure option phase two")
                self.tLog.warning("directory cannot be checked, as the key might differ from the one")
                self.tLog.warning("stored in the info pages.")
            end
        end
    end



    return tResult, strErrorMsg
end

function UsipPlayer:setPluginOptions()

    self.atPluginOptions = {
        romloader_jtag = {
            jtag_reset = "Attach", -- HardReset, SoftReset or Attach
            jtag_frequency_khz = 6000 -- optional
        },
        romloader_uart = {
            netx90_m2m_image = self.strnetX90M2MImageBin,
        }
    }

    if self.strSecureOption ~= self.strSecureOptionPhaseTwo then
        self.atResetPluginOptions = {
            romloader_jtag = {
                jtag_reset = "Attach", -- HardReset, SoftReset or Attach
                jtag_frequency_khz = 6000 -- optional
            },
            romloader_uart = {
                netx90_m2m_image = self.strNetX90ResetM2MImageBin
            }
        }
    else
        self.atResetPluginOptions = self.atPluginOptions
    end
    if self.fDoReset then
        self.atPluginOptionsFirstConnect = {
            romloader_jtag = {
                jtag_reset = "HardReset", -- HardReset, SoftReset or Attach
                jtag_frequency_khz = 6000 -- optional
            },
            romloader_uart = {
                netx90_m2m_image = self.strnetX90M2MImageBin
            }
        }
    else
        self.atPluginOptionsFirstConnect = self.atPluginOptions
    end
end

function UsipPlayer:loadDataToIntram(strData, ulLoadAddress)
    self.tLog.debug( "Loading image to 0x%08x", ulLoadAddress )
    -- write the image to the netX
    self.tFlasher.write_image(self.tPlugin, ulLoadAddress, strData)
    self.tLog.info("Writing image complete!")
    return true
end

-- loadLmage(tPlugin, strPath, ulLoadAddress, fnCallbackProgress)
-- load an image to a dedicated address
-- returns nothing, in case of a romlaoder error MUHKUH_PLUGIN_ERROR <- ??
function UsipPlayer:loadImage(strPath, ulLoadAddress)
    local fResult = false
    if path.exists(strPath) then
        self.tLog.info( "Loading image path: '%s'", strPath )

        -- get the binary data from the file
        local tFile, strMsg = io.open(strPath, 'rb')
        -- check if the file exists
        if tFile then
            -- read out all the binary data
            local strFileData = tFile:read('*all')
            tFile:close()
            if strFileData ~= nil and strFileData ~= "" then
                fResult = self:loadDataToIntram(strFileData, ulLoadAddress)
            else
                self.tLog.error( "Could not read from file %s", strPath )
            end
        -- error message if the file does not exist
        else
            self.tLog.error( 'Failed to open file "%s" for reading: %s', strPath, strMsg )
        end
    end
    return fResult
end

-- fResult LoadIntramImage(tPlugin, strPath, ulLoadAddress)
-- Load an image in the intram to probe it after an reset
-- intram3 address is 0x20080000
-- return true if the image was loaded correctly otherwise false
function UsipPlayer:loadIntramImage(strPath, ulIntramLoadAddress)
    local fResult
    local ulLoadAddress
    if ulIntramLoadAddress  then
        ulLoadAddress = ulIntramLoadAddress
    else
        -- this address is the intram 3 address. This address will be probed at the startup
        ulLoadAddress = 0x20080000
    end
    fResult = self:loadImage(strPath, ulLoadAddress)

    return fResult
end

-- execBinViaIntram(tPlugin, strFilePath, ulIntramLoadAddress)
-- loads an image into the intram, flushes the data and reset via watchdog
-- returns
--    nothing
function UsipPlayer:execBinViaIntram(strUsipData, ulIntramLoadAddress)
    local tResult
    local strErrorMsg
    local ulLoadAddress
    if ulIntramLoadAddress == nil then
        ulLoadAddress = 0x20080000
    else
        ulLoadAddress = ulIntramLoadAddress
    end
        -- load an image into the intram
    tResult = self:loadDataToIntram(strUsipData ,ulLoadAddress)

    if tResult then
        -- flush the image
        -- flush the intram by reading 32 bit and write them back
        -- the flush only works if the file is grater than 4byte and smaller then 64kb
        -- the read address must be an other DWord address as the last used
        -- if a file is greater than the 64kb the file size exeeds the intram area space, so every
        -- intram has to be flushed separately
        -- the flush only works if the file is greater than 4byte and smaller then 64kb
        self.tLog.debug( "Flushing...")
        -- read 32 bit
        local data = self.tPlugin:read_data32(ulLoadAddress)
        -- write the data back
        self.tPlugin:write_data32(ulLoadAddress, data)
        -- reset via the watchdog

        -- resetNetx90ViaWdg(tPlugin)
        tResult, strErrorMsg = self.tFlasherHelper.reset_netx_via_watchdog(nil, self.tPlugin)
    end

    return tResult, strErrorMsg
end

-- astrUsipPathList, tUsipGenMultiOutput, tUsipGenMultiResult genMultiUsips(
--    strUsipGenExePath, strTmpPath, strUsipConfigPath
-- )
-- generates depending on the usip-config json file multiple usip files. The config json file is generated
-- with the usip generator. Every single generated usip file has the same header and differs just in the body part.
-- The header is not relevant at this point, because the header of the usip file is just checked once if
-- the hash is correct and is not relevant for the usip process
-- returns a list of all generated usip file paths and the output of the command
function UsipPlayer:genMultiUsips(tUsipConfigDict)
    local tResult
    local aDataList
    local tUsipNames
    -- list of all generated usip file paths
    if self.tFlasherHelper.getStoreTempFiles() then
        tResult, aDataList, tUsipNames = self.tUsipGenerator:gen_multi_usip_hboot(tUsipConfigDict, self.tempFolderConfPath)
    else
        aDataList, tUsipNames = self.tUsipGenerator:gen_multi_usip(tUsipConfigDict)
        tResult = true
    end
    return tResult, aDataList, tUsipNames
end

function UsipPlayer:extendBootswitchData(strUsipData, strBootswitchParam)
    -- result variable, be pessimistic
    local fResult = false
    local strMsg = ""
    local strBootswitchData
    local strBootSwitchOnlyPornParam
    local strCombinedUsipPath
    local strUsipData = strUsipData

    -- read the bootswitch content
    -- print("Appending Bootswitch ... ")
    -- strBootswitchData, strMsg = tFlasherHelper.loadBin(strBootswitchFilePath)
    strBootswitchData, strMsg = self.tHelperFiles.getHelperFile(self.strnetX90HelperPath, "bootswitch")
    if strBootswitchData == nil then
        self.tLog.info(strMsg or "Error: Failed to load bootswitch (unknown error)")
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
    end

    if string.len( strUsipData ) == 0x8000 then
        -- set combined file path
        if self.tFlasherHelper.getStoreTempFiles() then
            -- only store temporary file when it is enabled
            strCombinedUsipPath = path.join( self.tempFolderConfPath, "combined.usp")
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


    return fResult, strUsipData, strMsg
end


-- fResult, strMsg extendBootswitch(strUsipPath, strBootswitchFilePath, strBootswitchParam)
-- extend the usip file with the bootswitch and the bootswitch parameter
-- the bootswitch supports three console interfaces, ETH, UART and MFW
-- more information about the bootswitch can be found in the KB: https://kb.hilscher.com/x/CcBwBw
-- more information about the bootswitch in combination with an usip can be found in the
-- KB: https://kb.hilscher.com/x/0s2gBw
-- returns true, nil if everything went right, else false and a error message
function UsipPlayer:extendBootswitch(strUsipPath, strBootswitchParam)
    local fResult = false

    -- read the usip content
    -- print("Loading USIP content ... ")
    local strUsipData, strMsg = self.tFlasherHelper.loadBin(strUsipPath)
    if strUsipData then
        fResult, strUsipData, strMsg = self:extendBootswitchData(strUsipData, strBootswitchParam)
    else
        self.tLog.info(strMsg or "Error: Failed to load '%s'", strUsipPath)
    end

    return fResult, strUsipData, strMsg
end


function UsipPlayer:extendExecReturnData(strUsipData, strExecReturnFilePath, strOutputFileName)
    local fResult = false
    local strMsg
    local strExecReturnData
    local strCombinedUsipPath

    -- read the exec-return content
    strExecReturnData = self.tFlasherHelper.loadBin(strExecReturnFilePath)
    if strExecReturnData then
        -- cut the usip image ending and extend the exec-return content without the boot header
        -- the first 64 bytes are the boot header
        -- todo: find better way to strip the last 0 values (end indication of hboot image)
        strUsipData = string.sub( strUsipData, 1, -5 ) .. string.sub( strExecReturnData, 65 )
        if self.tFlasherHelper.getStoreTempFiles() then
            -- set combined file path
            if strOutputFileName == nil then
                strCombinedUsipPath = path.join( self.tempFolderConfPath, "combined.usp")
            else
                strCombinedUsipPath = path.join( self.tempFolderConfPath, strOutputFileName)
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


-- fOk, strSingleUsipPath, strMsg extendExecReturn(strUsipPath, strExecReturnFilePath)
-- extend the usip file with an exec chunk that return immediately and activated the debugging
-- returns true and the file path to the combined file in case no error occur, otherwith an false and nil
-- returns always a info message.
function UsipPlayer:extendExecReturn(strUsipPath, strExecReturnFilePath, strOutputFileName)
    local fResult = false
    local strMsg
    local strUsipData
       -- read the usip content
    strUsipData = self.tFlasherHelper.loadBin(strUsipPath)
    if strUsipData then
        fResult, strUsipData, strMsg = self:extendExecReturnData(
                strUsipPath, strExecReturnFilePath, strOutputFileName)
    else
        strMsg = "Can not read out the usip data."
    end

    return fResult, strUsipData, strMsg
end

-- tPlugin loadUsip(strFilePath, tPlugin, strPluginType)
-- loading an usip file
-- loads an usip file via a dedicated interface and checks if the chiptype is supported
-- returns the plugin, in case of a uart connection the plugin must be updated and a new plugin is returned

function UsipPlayer:loadUsip(strUsipData, strPluginType)

    local ulRetries = 5
    local strErrorMsg

    local tResult
    self.tLog.info( "Loading Usip via %s", strPluginType )

    tResult, strErrorMsg = self.tFlasherHelper.connect_retry(self.tPlugin, 5)
    if tResult == false then
        self.tLog.error(strErrorMsg)
    end


    if self.ulPluginM2MMajor == 3 and self.ulPluginM2MMinor >= 1 then
        local ulUsipLoadAddress = 0x200C0
        self:loadDataToIntram(strUsipData ,ulUsipLoadAddress)
        self.tFlasher.call_usip(self.tPlugin)
        -- TODO: can we just set tResult to true and continue?
        tResult = true
    else
        -- we have a netx90 with either jtag or M2M interface older than 3.1
        if self.strPluginType == 'romloader_jtag' or self.strPluginType == 'romloader_uart' then
            tResult, strErrorMsg = self:execBinViaIntram(strUsipData)

        elseif self.strPluginType == 'romloader_eth' then
            -- netX90 rev_1 and ethernet detected, this function is not supported
                self.tLog.error("The current version does not support the Ethernet in this feature!")
        else
            self.tLog.error("Unknown plugin type '%s'!", self.strPluginType)
        end
    end

    if tResult then
        self.tPlugin:Disconnect()
        self.tFlasherHelper.sleep_s(3)
        -- get the jtag plugin with the attach option to not reset the netX

        while ulRetries > 0 do
            self.tPlugin = self.tFlasherHelper.getPlugin(self.strPluginName, self.strPluginType, self.atPluginOptions)
            ulRetries = ulRetries-1
            if self.tPlugin ~= nil then
                break
            end
            self.tFlasherHelper.sleep_s(1)  -- todo use the same sleep everywhere
        end
    end

    if self.tPlugin == nil then
        tResult = false
        self.tLog.error("Could not get plugin again")
        strErrorMsg = "Could not get plugin again"
    end
    return tResult, strErrorMsg
end


function UsipPlayer:readSip(strReadSipPath, atPluginOptions, strExecReturnPath, fGetUidOnly)
    local fResult = true
    local strErrorMsg = ""
    local strMsg

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
    local UID_CPY_MSK    =      0x0004

    local GET_UUID_ONLY = 0x00020000  -- write this value to the ulReadSipResultAddress to only copy uuid to intram and end

    local ulReadUUIDAddress = 0x00061ff0

    local ulReadSipResult

    local strCalSipData
    local strComSipData
    local strAppSipData
    local aStrUUIDs = {}

    local uLRetries = 5

    local strReadSipData = self.tFlasherHelper.loadBin(strReadSipPath)

    local fOk
    if self.strBootswitchParams ~= nil and self.strBootswitchParams ~= "JTAG" then
        self.tLog.debug("Extending read sip binary with bootswitch.")
        fOk, strReadSipData, strMsg = self:extendBootswitchData(
            strReadSipData, self.strBootswitchParams
        )
        self.tLog.debug(strMsg)
    elseif self.strBootswitchParams == "JTAG" then
        self.tLog.debug("Extending read sip binary with exec.")
        -- todo why do we still hand over the path (strExecReturnPath) instead of using helper files method
        fOk, strReadSipData, strMsg = self:extendExecReturnData(
            strReadSipData, strExecReturnPath
        )
        self.tLog.debug(strMsg)
    else
        fOk = true
    end


    -- get verify sig program data only

    if strReadSipData and fOk then
        self.tLog.info("download read_sip hboot image to 0x%08x", ulHbootLoadAddress)
        self.tFlasher.write_image(self.tPlugin, ulHbootLoadAddress, strReadSipData)


        -- reset the value of the read sip result address
        self.tLog.info("reset the value of the read sip result address 0x%08x", ulReadSipResultAddress)

        self.tPlugin:write_data32(ulReadSipMagicAddress, 0x00000000)

        self.tLog.info("download the split data to 0x%08x", ulDataLoadAddress)
        local strReadSipDataSplit = string.sub(strReadSipData, 0x40D)
        -- reset the value of the read sip result address
        self.tFlasher.write_image(self.tPlugin, ulDataLoadAddress, strReadSipDataSplit)

        if fGetUidOnly then
            -- tell the read_sip.binary to only read the uid and end without a reset
            self.tPlugin:write_data32(ulReadSipResultAddress, GET_UUID_ONLY)
        else
            self.tPlugin:write_data32(ulReadSipResultAddress, 0x00000000)
        end


        if self.strPluginType == 'romloader_jtag' or self.strPluginType == 'romloader_uart' or self.strPluginType == 'romloader_eth' then
            if self.ulPluginM2MMajor == 3 and self.ulPluginM2MMinor >= 1 then
                -- M2M protocol for rev2
                self.tLog.info("Start read sip hboot image inside intram")
                local fSkipAnswer = not fGetUidOnly
                self.tFlasher.call_hboot(self.tPlugin, nil, fSkipAnswer)
            elseif self.strPluginType ~= 'romloader_jtag' and not fGetUidOnly then
                -- M2M protocol for rev1

                self.tLog.info("Start read sip binary via call no answer")
                self.tFlasher.call_no_answer(
                        self.tPlugin,
                        ulDataLoadAddress + 1,
                        ulReadSipResultAddress
                )
            else
                self.tLog.info("Start read sip binary via call")
                self.tFlasher.call(
                    self.tPlugin,
                        ulDataLoadAddress + 1,
                        ulReadSipResultAddress
                )
            end


            self.tLog.info("Disconnect from Plugin and reconnect again")
            -- can there be timing issues with different OS
            self.tPlugin:Disconnect()
            -- wait at least 2 sec for signature verification of read sip binary
            self.tFlasherHelper.sleep_s(3)

            while uLRetries > 0 do
                self.tLog.info("try to get the Plugin again after read sip reset")
                local fCallSuccess
                fCallSuccess, self.tPlugin = pcall(
                    self.tFlasherHelper.getPlugin, self.strPluginName, self.strPluginType, atPluginOptions)
                if fCallSuccess then
                    break
                end
                uLRetries = uLRetries - 1
                self.tFlasherHelper.sleep_s(1)
            end

            if self.tPlugin then
                self.tFlasherHelper.connect_retry(self.tPlugin, 10)

            else
                strErrorMsg = "Could not reach plugin after reset"
                fResult = false
            end

            if fResult then
                local ulMagicResult
                ulMagicResult = self.tPlugin:read_data32(ulReadSipMagicAddress)
                if ulMagicResult == MAGIC_COOKIE_END then
                    fResult = true
                    self.tLog.info("Found MAGIC_COOKIE_END")
                elseif ulMagicResult == MAGIC_COOKIE_INIT then
                    self.tLog.info("Read sip is not done yet! Wait a second")
                    self.tFlasherHelper.sleep_s(1)
                    fResult = false
                else
                    strErrorMsg = "Could not find MAGIC_COOKIE"
                    fResult = false
                end
            end

            if fResult then

                ulReadSipResult = self.tPlugin:read_data32(ulReadSipResultAddress)
                if not fGetUidOnly then
                    if ulReadSipResult == 0xFFFFFFFF then
                            strErrorMsg = "Could not get proper result"
                            fResult = false
                    elseif ((ulReadSipResult & COM_SIP_CPY_VALID_MSK) ~= 0 or (ulReadSipResult & COM_SIP_VALID_MSK) ~= 0) and
                            ((ulReadSipResult & APP_SIP_CPY_VALID_MSK) ~= 0 or (ulReadSipResult & APP_SIP_VALID_MSK) ~= 0) then
                        strCalSipData = self.tFlasher.read_image(self.tPlugin, ulReadSipDataAddress, 0x1000)
                        strComSipData = self.tFlasher.read_image(self.tPlugin, ulReadSipDataAddress + 0x1000, 0x1000)
                        strAppSipData = self.tFlasher.read_image(self.tPlugin, ulReadSipDataAddress + 0x2000, 0x1000)

                    elseif (ulReadSipResult & COM_SIP_INVALID_MSK) ~= 0 then
                        strErrorMsg = "Could not get a valid copy of the COM SIP"
                        fResult = false
                    elseif (ulReadSipResult & APP_SIP_INVALID_MSK) ~= 0 then
                        strErrorMsg = "Could not get a valid copy of the APP SIP"
                        fResult = false
                    end
                else
                    if ulReadSipResult & UID_CPY_MSK ~= 0 then
                        aStrUUIDs[1] = self.tFlasherHelper.switch_endian(self.tPlugin:read_data32(ulReadUUIDAddress))
                        aStrUUIDs[2] = self.tFlasherHelper.switch_endian(self.tPlugin:read_data32(ulReadUUIDAddress + 4))
                        aStrUUIDs[3] = self.tFlasherHelper.switch_endian(self.tPlugin:read_data32(ulReadUUIDAddress + 8))
                    else
                        strErrorMsg = "Could not receive uuid"
                        fResult = false
                    end
                end
            end
        else
            strErrorMsg = string.format("Unsupported plugin type '%s'", self.strPluginType)
            fResult = false
        end
    end

    if fGetUidOnly then
        return fResult, strErrorMsg, aStrUUIDs
    else
        return fResult, strErrorMsg, strCalSipData, strComSipData, strAppSipData
    end
end

-- fOk verifyContent(tPlugin, strSipperExePath, strUsipConfigPath)
-- compare the content of a usip file with the data in a secure info page to verify the usip process
-- returns true if the verification process was a success, otherwise false
function UsipPlayer:verifyContent(
    strReadSipPath,
    tUsipConfigDict,
    atPluginOptions,
    strExecReturnPath
)
    local uVerifyResult = self.tSipper.VERIFY_RESULT_OK

    self.tLog.info("Verify USIP content ... ")
    self.tLog.debug( "Reading out SecureInfoPages via %s", self.strPluginType )
    -- validate the seucre info pages
    -- it is important to return the plugin at this point, because of the reset the romload_uart plugin
    -- changes

    -- get the com sip data -- todo add bootswitch here?
    local fOk, strErrorMsg, _, strComSipData, strAppSipData = self:readSip(
        strReadSipPath, atPluginOptions, strExecReturnPath)
    -- check if for both sides a valid sip was found
    if fOk~= true or strComSipData == nil or strAppSipData == nil then
        uVerifyResult = self.tSipper.VERIFY_RESULT_ERROR
    else

        if self.tFlasherHelper.getStoreTempFiles() then
            self.tLog.debug("Saving content to files...")
            -- save the content to a file if the flag is set
            -- set the sip file path to save the sip data
            local strComSipFilePath = path.join(self.tempFolderConfPath, "com_sip.bin")
            local strAppSipFilePath = path.join(self.tempFolderConfPath, "app_sip.bin")


            -- write the com sip data to a file
            self.tLog.debug("Saving COM SIP to %s ", strComSipFilePath)
            local tFile = io.open(strComSipFilePath, "wb")
            tFile:write(strComSipData)
            tFile:close()
            -- write the app sip data to a file
            self.tLog.debug("Saving APP SIP to %s ", strAppSipFilePath)
            tFile = io.open(strAppSipFilePath, "wb")
            tFile:write(strAppSipData)
            tFile:close()
        end

        uVerifyResult, strErrorMsg = self.tSipper:verify_usip(tUsipConfigDict, strComSipData, strAppSipData, self.tPlugin)
    end

    return uVerifyResult, strErrorMsg
end


-- strComSipData, strAppSipData readOutSipContent(iValidCom, iValidApp)
-- read out the secure info page content via MI-Interface or the JTAG-interface
-- the function needs a sip validation before it can be used.
function UsipPlayer:readOutSipContent(iValidCom, iValidApp)
    local strComSipData = nil
    local strAppSipData = nil
    if not ( iValidCom == -1 or iValidApp == -1 ) then
        -- check if the copy com sip area has a valid sip
        if iValidCom == 1 then
            self.tLog.info("Found valid COM copy Secure info page.")
            -- read out the copy com sip area
            strComSipData = self.tFlasher.read_image(self.tPlugin, 0x200a7000, 0x1000)
        else
            -- the copy com sip area has no valid sip check if a valid sip is in the flash
            if iValidCom == 2 then
                self.tLog.info("Found valid COM Secure info page.")
                -- read out the com sip from the flash
                -- show the sip
                self.tPlugin:write_data32(0xff001cbc, 1)
                -- read out the sip
                strComSipData = self.tFlasher.read_image(self.tPlugin, 0x180000, 0x1000)
                -- hide the sip
                self.tPlugin:write_data32(0xff001cbc, 0)
            -- no valid com sip found, set the strComSipData to nil
            else
                self.tLog.error(
                    "Can not find a valid COM-SecureInfoPage, please check if the COM-Page is hidden and not copied."
                )
                strComSipData = nil
            end
        end
        -- check if the copy app sip area has a valid sip
        if iValidApp == 1 then
            self.tLog.info("Found valid APP copy Secure info page.")
            -- read out the copy app sip area
            strAppSipData = self.tFlasher.read_image(self.tPlugin, 0x200a6000, 0x1000)
        else
            -- the copy app sip area has no valid sip check if a valid sip is in the flash
            if iValidApp == 2 then
                self.tLog.info("Found valid APP Secure info page.")
                -- read out the app sip from the flash
                -- show the sip
                self.tPlugin:write_data32(0xff40143c, 1)
                -- read out the sip
                strAppSipData = self.tFlasher.read_image(self.tPlugin, 0x200000, 0x1000)
                -- hide the sip
                self.tPlugin:write_data32(0xff40143c, 0)
            -- no valid app sip found, set the strAppSipData to nil
            else
                self.tLog.error(
                    "Can not find a valid APP-SecureInfoPage, please check if the APP-Page is hidden and not copied."
                )
                strAppSipData = nil
            end
        end
    end
    return strComSipData, strAppSipData
end


--function kekProcess(tPlugin, strCombinedHbootPath)
function UsipPlayer:kekProcess(strCombinedImageData)

    local ulHbootLoadAddress = 0x000200c0 -- boot address for start_hboot command
    local ulHbootDataLoadAddress = 0x00060000 -- address where the set_kek boot image is copied and executed
    local ulDataStructureAddress = 0x000220c0
    local ulHbootResultAddress = 0x00065000
    local fOk = false
    -- separate the image data and the option + usip from the image
    -- this is necessary because the image must be loaded to 0x000203c0
    -- and not to 0x000200c0 like the "htbl" command does. If the image is
    -- loaded to that address it is not possible to start the image, the image is broken


    self.tFlasher.write_image(self.tPlugin, ulHbootLoadAddress, strCombinedImageData)

    -- reset result value
    self.tPlugin:write_data32(ulHbootResultAddress, 0)


    if self.ulPluginM2MMajor == 3 and self.ulPluginM2MMinor >= 1 then
        self.tFlasher.call_hboot(self.tPlugin)
    else
        local strSetKekData = string.sub(strCombinedImageData, 1037)
        self.tFlasher.write_image(self.tPlugin, ulHbootDataLoadAddress, strSetKekData)

        if self.strPluginType ~= "romloader_jtag" then
            self.tFlasher.call_no_answer(
                self.tPlugin,
                ulHbootDataLoadAddress + 1,
                ulDataStructureAddress
            )
        else
            self.tPlugin:call(
                ulHbootDataLoadAddress + 1,
                ulDataStructureAddress,
                self.tFlasher.default_callback_message,
                2
            )
        end
    end
    self.tLog.debug("Finished call, disconnecting")
    self.tPlugin:Disconnect()
    self.tLog.debug("Wait 3 seconds to be sure the set_kek process is finished")
    self.tFlasherHelper.sleep_s(3)
    -- todo check results of connect and getPlugin before continuing
    -- get the uart plugin again
    self.tPlugin = self.tFlasherHelper.getPlugin(self.strPluginName, self.strPluginType, self.atPluginOptions)
    if self.tPlugin then
        local strError
        fOk, strError = self.tFlasherHelper.connect_retry(self.tPlugin, 5)
        if fOk == false then
            self.tLog.error(strError)
        end
    else
        self.tLog.error("Failed to get plugin after set KEK")
        fOk = false
    end

    local ulHbootResult = self.tPlugin:read_data32(ulHbootResultAddress)

    self.tLog.debug( "ulHbootResult: 0x%08x ", ulHbootResult )
    ulHbootResult = ulHbootResult & 0x107
    -- TODO: include description
    if ulHbootResult == 0x107 then
        self.tLog.info( "Successfully set KEK" )
        fOk = true
    else
        self.tLog.error( "Failed to set KEK" )
        fOk = false
    end

    return fOk
end


----------------------------------------------------------------------------------------------------
-- FUNCTIONS
-----------------------------------------------------------------------------------------------------
function UsipPlayer:usip(
    tUsipDataList,
    tUsipPathList,
    tUsipConfigDict,
    fVerifyContentDisabled,
    fDisableReset,
    fVerifySigEnable
)

    local strErrorMsg
    local tResult
    local uVerifyResult

    --------------------------------------------------------------------------
    -- verify the signatures of the USIP chunks.
    --------------------------------------------------------------------------
    -- does the user want to verify the signature of the usip chunk?
    if fVerifySigEnable then
        -- check if every signature in the list is correct via MI
        tResult = self.tVerifySignature.verifySignature(
            self.tPlugin, self.strPluginType, tUsipDataList, tUsipPathList,
            self.tempFolderConfPath, self.strVerifySigPath
        )
    else
        -- set the signature verification to automatically to true
        tResult = true
    end

    -- just continue if the verification process was a success (or not enabled)
    if tResult then
        -- iterate over the usip file path list
        for _, strSingleUsipData in ipairs(tUsipDataList) do
            -- load an usip file via a dedicated interface
            tResult = self:loadUsip(strSingleUsipData, self.strPluginType)
            -- NOTE: be aware after the loading the netX will make a reset
            --       but in the function the tPlugin will be reconncted!
            --       so after the function the tPlugin is connected!
            if not tResult then
                self.tLog.error("Failed to execute USIP")
                strErrorMsg = "Failed to execute USIP"
                break
            end
        end
    end
    -- Phase 2 starts after this reset
    -- For phase 2 we use the helpfer images from tArgs.strSecureOptionPhaseTwo argument
    -- Check if a last reset is necessary to activate all data inside the secure info page
    if not fDisableReset and tResult then

        local ulLoadAddress
        local strResetImagePath

        -- netx90 rev2 uses call_usip command to reset, therefore we copy the image into USER_DATA_AREA
        if self.ulPluginM2MMajor == 3 and self.ulPluginM2MMinor >= 1 then
            ulLoadAddress = 0x000200C0
        else
            ulLoadAddress = 0x20080000
        end

        -- connect to the netX
        local strError
        tResult, strErrorMsg = self.tFlasherHelper.connect_retry(self.tPlugin, 5)
        if tResult == false then
            self.tLog.error(strError)
        end

        if tResult then
            -- tFlasherHelper.dump_trace(tPlugin, strTmpFolderPath, "trace_after_usip.bin")
            -- tFlasherHelper.dump_intram(tPlugin, 0x20080000, 0x1000, strTmpFolderPath, "dump_after_usip.bin")
            -- check if a bootswitch is necessary to force a dedicated interface after a reset
            if self.strBootswitchParams then
                if self.strBootswitchParams == "JTAG" then
                    strResetImagePath = self.strResetExecReturnPath
                else
                    strResetImagePath = self.strResetBootswitchPath
                end

                tResult = self:loadIntramImage(strResetImagePath, ulLoadAddress )
            else
                -- overwrite possible boot cookie to avoid accidentaly booting an old image
                self.tPlugin:write_data32(ulLoadAddress, 0x00000000)
                self.tPlugin:write_data32(ulLoadAddress + 4, 0x00000000)
                self.tPlugin:write_data32(ulLoadAddress + 8, 0x00000000)
                self.tLog.debug("Just reset without any image in the intram.")
            end
        end

        if tResult then

            if self.ulPluginM2MMajor == 3 and self.ulPluginM2MMinor >= 1 then
                self.tLog.debug("use call usip command to reset netx")
                self.tFlasher.call_usip(self.tPlugin) -- use call usip command as workaround to trigger reset
            else
                self.tLog.debug("reset netx via watchdog")
                self.tFlasherHelper.reset_netx_via_watchdog(nil, self.tPlugin)
            end

            self.tPlugin:Disconnect()
            self.tFlasherHelper.sleep_s(2)
            -- just necessary if the uart plugin in used
            -- jtag works without getting a new plugin

        end
    end

    if tResult and not fVerifyContentDisabled and not fDisableReset then
        -- just validate the content if the validation is enabled and no error occued during the loading process
        if self.strPluginType ~= 'romloader_jtag' then
            self.tPlugin = self.tFlasherHelper.getPlugin(self.strPluginName, self.strPluginType, self.atResetPluginOptions)
        end

        if self.tPlugin then
            tResult, strErrorMsg = self.tFlasherHelper.connect_retry(self.tPlugin, 5)
            if tResult == false then
                self.tLog.error(strErrorMsg)
            end
        else
            self.tLog.error("Failed to get plugin after executing USIP image")
            tResult = false
        end

        if tResult then
            uVerifyResult, strErrorMsg = self:verifyContent(
                    self.strResetReadSipPath,
                    tUsipConfigDict,
                    self.atResetPluginOptions,
                    self.strResetExecReturnPath
            )
            if uVerifyResult == self.tSipper.VERIFY_RESULT_OK then
                tResult = true
            else
                tResult = false
                self.tLog.error(strErrorMsg)
            end
        end
    end
    return tResult, strErrorMsg
end

function UsipPlayer:set_sip_protection_cookie()
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
    local strErrorMsg
    local fOk = false

    local astrHelpersTmp = {"read_sip_m2m", "verify_sig"}


    fOk, strErrorMsg = self:prepareInterface(true)

    if fOk then
        fOk, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
    end
    local strFilePath = path.join("netx", "helper", "netx90", "com_default_rom_init_ff_netx90_rev2.bin")
    -- Download the flasher.
    local aAttr = self.tFlasher.download(self.tPlugin, flasher_path, nil, nil, self.strSecureOption)
    -- if flasher returns with nil, flasher binary could not be downloaded
    if not aAttr then
        self.tLog.error("Error while downloading flasher binary")
    else
        -- check if the selected flash is present
        fOk = self.tFlasher.detect(self.tPlugin, aAttr, iBus, iUnit, iChipSelect)
        if not fOk then
            self.tLog.error("No Flash connected!")
        else
            ulDeviceSize = self.tFlasher.getFlashSize(self.tPlugin, aAttr)
            if not ulDeviceSize then
                self.tLog.error( "Failed to get the device size!" )
                fOk = false
            else
                -- get the data to flash
                strData, strMsg = self.tFlasherHelper.loadBin(strFilePath)
                if not strData then
                    self.tLog.error(strMsg)
                    fOk = false
                else
                    ulLen = strData:len()
                    -- if offset/len are set, we require that offset+len is less than or equal the device size
                    if ulStartOffset~= nil and ulLen~= nil and ulStartOffset+ulLen > ulDeviceSize and
                     ulLen ~= 0xffffffff and fOk == true then
                        self.tLog.error( "Offset+size exceeds flash device size: 0x%08x bytes", ulDeviceSize )
                        fOk = false
                    else
                        self.tLog.info( "Flash device size: %d/0x%08x bytes", ulDeviceSize, ulDeviceSize )
                    end
                end
            end
        end
        if fOk then
            fOk, strErrorMsg = self.tFlasher.eraseArea(self.tPlugin, aAttr, ulStartOffset, ulLen)
        end
        if fOk then
            fOk, strErrorMsg = self.tFlasher.flashArea(self.tPlugin, aAttr, ulStartOffset, strData)
            if not fOk then
                self.tLog.error(strErrorMsg)
            else
                fOk = true
            end
        else
            self.tLog.error(strErrorMsg)
        end
    end

    return fOk, strErrorMsg
end

function UsipPlayer:setKek(
    tUsipDataList,
    tUsipPathList,
    tUsipConfigDict,
    fVerifyContentDisabled,
    fDisableReset,
    fVerifySigEnable
)

    -- be optimistic
    local fOk = true
    local strKekHbootData
    local strCombinedImageData
    local strFillUpData
    local strUsipToExtendData
    local strKekDummyUsipData
    local fProcessUsip = false
    local strErrorMsg
    local strFirstUsipData
    local romloader = _G.romloader


    self.strKekDummyUsipFilePath = path.join(self.tFlasher.HELPER_FILES_PATH, "netx90", "set_kek.usp")

    if not path.exists(self.strKekDummyUsipFilePath) then
        self.tLog.error( "Dummy kek usip is not available at: %s", self.strKekDummyUsipFilePath )
        -- return here because of initial error
        os.exit(1)
    end

    -- the signature of the dummy USIP must not be verified because the data of the USIP
    -- are replaced by the new generated KEK and so the signature will change too

    -- check if an USIP file was provided
    if next(tUsipDataList) then
        fProcessUsip = true
        self.tLog.debug("Found general USIP to process.")
        -- lua tables start with 1
        strFirstUsipData = tUsipDataList[1]
        table.remove(tUsipDataList, 1)
    else
        self.tLog.debug("No general USIP found.")
    end

    strKekDummyUsipData = self.tFlasherHelper.loadBin(self.strKekDummyUsipFilePath)
    ---------------------------------------------------------------
    -- KEK process
    ---------------------------------------------------------------
    -- load kek-image data
    strKekHbootData, strErrorMsg = self.tFlasherHelper.loadBin(self.strKekHbootFilePath)
    if not strKekHbootData and fOk then
        self.tLog.error(strErrorMsg)
    else
        -- be pessimistic
        fOk = false
        local iMaxImageSizeInBytes = 0x2000
        local iMaxOptionSizeInBytes = 0x1000
        local iCopyUsipSize = 0x0
        -- combine the images with fill data
        if string.len( strKekHbootData ) > iMaxImageSizeInBytes then
            self.tLog.error("KEK HBoot image is to big, something went wrong.")
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
                if self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90A or
                    self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or
                    self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C then
                    strSetKekOptions = strSetKekOptions .. string.char(0x11, 0x00)
                elseif self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D then
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
                self.tLog.debug("Getting first USIP from Usiplist.")
                self.tLog.debug("Set general USIP as extending USIP.")
                strUsipToExtendData = strFirstUsipData
            else
                self.tLog.debug("Set dummy USIP as extending USIP.")
                strUsipToExtendData = strKekDummyUsipData
            end
            -- extend usip with bootswitch/exec_return data if necessary
            -- check if usip needs extended by the bootswitch with parameters
            if self.strBootswitchParams == "JTAG" then
                self.tLog.debug("Extending USIP file with exec.")
                fOk, strUsipToExtendData, strErrorMsg = self:extendExecReturnData(
                    strUsipToExtendData, self.strExecReturnPath
                )
                self.tLog.debug(strErrorMsg)
            else if self.strBootswitchParams ~= nil then
                self.tLog.debug("Extending USIP file with bootswitch.")
                fOk, strUsipToExtendData, strErrorMsg = self:extendBootswitchData(
                    strUsipToExtendData, self.strBootswitchParams
                )
                self.tLog.debug(strErrorMsg)
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
                        self.tLog.error(strErrorMsg)
                    else
                        self.tLog.debug("Combine the HBootImage with the DummyUsip.")
                        strCombinedImageData = strCombinedImageData .. strKekDummyUsipData
                        if not fProcessUsip then
                            fOk = true
                        else
                            -- load usip data
                            if not strFirstUsipData then
                                self.tLog.error(strErrorMsg)
                            else
                                self.tLog.debug("Combine the extended HBootImage with the general USIP Image.")
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

                                if self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90A or
                                    self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or
                                    self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C then
                                    strSetKekOptions = strSetKekOptions .. string.char(0x01, 0x00)
                                elseif self.iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90D then
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

                            if self.tFlasherHelper.getStoreTempFiles() then

                                -- save the combined file into the temporary folder
                                local strKekHbootCombPath = path.join( self.tempFolderConfPath, "kek_hboot_comb.bin")
                                local tFile = io.open( strKekHbootCombPath, "wb" )
                                -- check if the file exists
                                if not tFile then
                                    self.tLog.error("Could not write data to file %s.", strKekHbootCombPath)
                                else
                                    -- write all data to file
                                    tFile:write( strCombinedImageData )
                                    tFile:close()
                                end
                            end
                            -- load the combined image to the netX
                            self.tLog.info( "Using %s", self.strPluginType )
                            fOk = self:kekProcess(strCombinedImageData)

                            -- todo if not further usip are provided we do not make a final reset to activate the last usip file

                            if fOk then
                                -- check if an input file path is set
                                if not fProcessUsip then
                                    self.tLog.warning(
                                        "No input file given. All other options that are just for the usip" ..
                                        " command will be ignored."
                                    )
                                else
                                    fOk, strErrorMsg = self:usip(
                                            tUsipDataList,
                                            tUsipPathList,
                                            tUsipConfigDict,
                                            fVerifyContentDisabled,
                                            fDisableReset,
                                            fVerifySigEnable
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return fOk, strErrorMsg
end



function UsipPlayer:getUidCommand()

    local strErrorMsg
    local fResult = true
    local iReadSipResult
    local aStrUUIDs

    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------

    local astrHelpersTmp = {"read_sip_m2m", "verify_sig"}

    if fResult then
        fResult, strErrorMsg = self:prepareInterface(true)

        if fResult then
            fResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
        end
    end
    -- what am i doing here...
    -- catch the romloader error to handle it correctly
    --------------------------------------------------------------------------
    -- PROCESS
    --------------------------------------------------------------------------

    iReadSipResult, strErrorMsg, aStrUUIDs = self:readSip(
        self.strReadSipPath, self.atPluginOptions, self.strExecReturnPath, true)

    if iReadSipResult then
        local strUidVal = string.format("%08x%08x%08x", aStrUUIDs[1], aStrUUIDs[2], aStrUUIDs[3])

        -- print out the complete unique ID
        self.tLog.info( " [UNIQUE_ID] %s", strUidVal )
        fResult = true
    else
        self.tLog.error(strErrorMsg)
    end

    return fResult, strErrorMsg
end

function UsipPlayer:verifyContentCommand(
    strUsipFilePath,
    strReadSipPath,
    strExecReturnPath
)
    local uVerifyResult

    -- get the plugin type
    local strPluginType = self.tPlugin:GetTyp()

    --------------------------------------------------------------------------
    -- analyze the usip file
    --------------------------------------------------------------------------

    local tResult, strErrorMsg, tUsipConfigDict = self.tUsipGenerator:analyze_usip(strUsipFilePath)
    if tResult == true then

        --------------------------------------------------------------------------
        -- verify the content
        --------------------------------------------------------------------------

        -- verify the content via the MI
        uVerifyResult, strErrorMsg = self:verifyContent(
            strReadSipPath,
            tUsipConfigDict,
            self.atPluginOptions,
            strExecReturnPath
        )

    else
        uVerifyResult = self.tSipper.VERIFY_RESULT_ERROR
        self.tLog.error(strErrorMsg)
    end

    return uVerifyResult, strErrorMsg
end



-- read out a selected secure info page
-- APP and COM SIP: verify the hash of the read out data
-- returns strReadData, strMsg -> strReadData is nil if read was not successful
function UsipPlayer:readSIPviaFLash(strSipPage, aAttr)
    local ulOffset = 0x0
    local ulSize = 0x1000
    local strReadData
    local strMsg

    -- check if the selected flash is present
    local fDetectResult = self.tFlasher.detect(
        self.tPlugin, aAttr,
        SIP_ATTRIBUTES[strSipPage].iBus,
        SIP_ATTRIBUTES[strSipPage].iUnit,
        SIP_ATTRIBUTES[strSipPage].iChipSelect)

    if not fDetectResult then
        strMsg = "No Flash connected!"
    else
        strReadData, strMsg = self.tFlasher.readArea(self.tPlugin, aAttr, ulOffset, ulSize)

        if strReadData ~= nil and strSipPage ~= "CAL" then
            local strNewHash
            local sipStringHandle = self.tFlasherHelper.StringHandle(strReadData)
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
function UsipPlayer:verifySIPviaFLash(
    strSipPage,
    strSipData,
    aAttr
)
    local fResult
    local fDetectResult
    local iBus
    local iUnit
    local iChipSelect
    local strMsg
    local ulKekInfo
    local ulSipProtectionInfo
    local fKekSet 
    local fSipProtectionSet

    iBus = SIP_ATTRIBUTES[strSipPage].iBus
    iUnit = SIP_ATTRIBUTES[strSipPage].iUnit

    iChipSelect = 3

    -- check if the selected flash is present
    fDetectResult = self.tFlasher.detect(
        self.tPlugin, aAttr,
        iBus,
        iUnit,
        iChipSelect
    )

    if not fDetectResult then
        strMsg = "No Flash connected!"
    else
        -- write to the flash
        fResult, strMsg, ulKekInfo, ulSipProtectionInfo = self.tFlasher.verifyArea(self.tPlugin, aAttr, 0x0, strSipData)
        if not fResult then
            strMsg = "verification failed for " .. strSipPage .. " SIP"
        end
        if ulKekInfo == self.COM_SIP_KEK_SET then
            fKekSet = true
        elseif ulKekInfo == self.COM_SIP_KEK_NOT_SET then
            fKekSet = false
        end
        if ulSipProtectionInfo == self.COM_SIP_SIP_PROTECTION_SET then
            fSipProtectionSet = true
        elseif ulSipProtectionInfo == self.COM_SIP_SIP_PROTECTION_NOT_SET then
            fSipProtectionSet = false
        end
    end

    return fResult, strMsg, fKekSet, fSipProtectionSet
end

-- write SIP data (4kB) into sekected SIP
-- create a new hash for the data
function UsipPlayer:writeSIPviaFLash(
    strSipPage,
    strSipData,
    aAttr,
    fNewChipSelect
)
    local fResult
    local fDetectResult
    local iBus
    local iUnit
    local iChipSelect
    local fDuplicate
    local iEraseSize
    local strMsg

    iBus = SIP_ATTRIBUTES[strSipPage].iBus
    iUnit = SIP_ATTRIBUTES[strSipPage].iUnit
    if fNewChipSelect then
        iChipSelect = 3
        fDuplicate = false
        iEraseSize = 0x1000
    else
        fDuplicate = true
        iChipSelect = 1
        iEraseSize = 0x2000
    end

    -- check if the selected flash is present
    fDetectResult = self.tFlasher.detect(
        self.tPlugin, aAttr,
        iBus,
        iUnit,
        iChipSelect)

    if not fDetectResult then
        strMsg = "No Flash connected!"
    else

        -- only duplicate if we do not use new chip_select method
        if fDuplicate then
            -- duplicate the data and write both mirrors at once
            strSipData = strSipData .. strSipData
        end


        -- erase flash before Writing
        fResult, strMsg = self.tFlasher.eraseArea(self.tPlugin, aAttr, 0x0, iEraseSize)
        if fResult then
            -- write to the flash
            fResult, strMsg = self.tFlasher.flashArea(self.tPlugin, aAttr, 0x0, strSipData)
        end
    end

    return fResult, strMsg
end

-- take the data of the COM and APP SIP and check if the secure boot flags are set
-- returns flags for each secure boot flag fSecureFlagComSet, fSecureFlagAppSet (true is set; False if not set)
function UsipPlayer:checkSecureBootFlag(
    strComSipData,
    strAppSipData
)
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
        fComSipStringHandle = self.tFlasherHelper.StringHandle(strComSipData)
        fComSipStringHandle:seek("set", 0x22C)
        strComProtectionOptionFLags = fComSipStringHandle:read(0x2)
        ulProtectionOptionFLags = self.tFlasherHelper.bytes_to_uint32(strComProtectionOptionFLags)
        if (ulProtectionOptionFLags & COM_SIP_SECURE_BOOT_ENABLED) ~= 0 then
            fSecureFlagComSet = true
        else
            fSecureFlagComSet = false
        end
    end
    if strAppSipData then
        fAppSipStringHandle = self.tFlasherHelper.StringHandle(strAppSipData)
        fAppSipStringHandle:seek("set", 0x228)
        strAppProtectionOptionFLags = fAppSipStringHandle:read(0x2)
        ulProtectionOptionFLags = self.tFlasherHelper.bytes_to_uint32(strAppProtectionOptionFLags)
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
function UsipPlayer:checkSipProtectionCookieViaFlash(
    strComSipData
)

    local fCookieSet
    local strSipProtectionCookie
    -- sip protection cookie
    local strSipProtectionCookieLocked = string.char(0x8b, 0x42, 0x3b, 0x75, 0xe2, 0x63, 0x25, 0x62,
     0x8a, 0x1e, 0x31, 0x6b, 0x28, 0xb4, 0xd7, 0x03)
    local fComSipStringHandle

    fComSipStringHandle = self.tFlasherHelper.StringHandle(strComSipData)
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
function UsipPlayer:checkRomFuncModeCookie(strCalSipData)

    local fCookieSet
    local strExpectedRomFuncModeCookie = string.char(
        0x43, 0xC4, 0xF2, 0xB2, 0x45, 0x40, 0x02, 0xC8, 0x78, 0x79, 0xDD, 0x94, 0xF7, 0x13, 0xB5, 0x4A)
    local fComSipStringHandle
    local strRomFuncModeCookie

    fComSipStringHandle = self.tFlasherHelper.StringHandle(strCalSipData)
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
function UsipPlayer:checkHideSipRegister()
    local IFLASH_SPECIAL_CFG_CAL = 0xff001c48
    local IFLASH_SPECIAL_CFG_COM = 0xff001cc8
    local IFLASH_SPECIAL_CFG_APP = 0xff401448
    local ulValCal
    local ulValCom
    local ulValApp
    local fHideSet = false
    local strErrorMsg
    local fSecureBootEnabled = false

    ulValCal, strErrorMsg = pcall(self.tPlugin.read_data32, self.tPlugin, IFLASH_SPECIAL_CFG_CAL)
    if ulValCal == false then
        fSecureBootEnabled = true
    else
        -- ulValCom, strErrorMsg = pcall(tPlugin.read_data32, tPlugin, IFLASH_SPECIAL_CFG_COM)
        -- ulValApp, strErrorMsg = pcall(tPlugin.read_data32, tPlugin, IFLASH_SPECIAL_CFG_APP)

        ulValCal = self.tPlugin:read_data32(IFLASH_SPECIAL_CFG_CAL)
        ulValCom = self.tPlugin:read_data32(IFLASH_SPECIAL_CFG_COM)
        ulValApp = self.tPlugin:read_data32(IFLASH_SPECIAL_CFG_APP)
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


function UsipPlayer:commandVerifySipPm(
    strUsipFilePath,
    strRawAppSipPath,
    strRawComSipPath,
    fCheckKek,
    fCheckSipProtection
)
    local tResult = true
    local fResult
    local strErrorMsg
    local aAttr
    local flasher_path = "netx/"
    local astrHelpersTmp = {"flasher_netx90_hboot"}
    local ulConsoleMode
    local strComSipData
    local strAppSipData
    local tUsipDataList
    local tUsipPathList
    local tUsipConfigDict
    local fKekSet
    local fSipProtectionSet
    local strCalSipData
    local fCookieIsSet

    if strUsipFilePath ~= nil then
        tResult, strErrorMsg, tUsipDataList, tUsipPathList, tUsipConfigDict = self:prepareUsip(strUsipFilePath)
    end

    if tResult then
        tResult, strErrorMsg, strComSipData, strAppSipData = self.tUsipGenerator:convertUsipToBin(
            strRawComSipPath,
            strRawAppSipPath,
            tUsipConfigDict,
            false
        )
    end
    if tResult then
        tResult, strErrorMsg, ulConsoleMode = self:prepareInterface(true)
    end
    if self.strPluginType == "romloader_uart" then
        table.insert(astrHelpersTmp,  "start_mi")
    end

    if tResult then
        tResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
        if tResult then
            tResult = self.tSipper.VERIFY_RESULT_OK
        end
    elseif tResult == false and ulConsoleMode == 1 then
        tResult = self.tSipper.VERIFY_RESULT_ERROR
    end

    if tResult == self.tSipper.VERIFY_RESULT_OK  then
        -- fConnected, strErrorMsg = self.tFlasherHelper.connect_retry(self.tPlugin)

        aAttr = self.tFlasher.download(self.tPlugin, flasher_path, nil, true, self.strSecureOption)
        tResult = self.tSipper.VERIFY_RESULT_OK

    end

    if tResult == self.tSipper.VERIFY_RESULT_OK then
        -- check if any of the secure info pages are hidden
        tResult, strErrorMsg, strCalSipData, fCookieIsSet = self:verifyInitialMode(aAttr, true)
    end

    if tResult == self.tSipper.VERIFY_RESULT_OK then
        fResult, strErrorMsg, fKekSet, fSipProtectionSet = self:verifySIPviaFLash("COM", strComSipData, aAttr)

        if not fResult then
            tResult = self.tSipper.VERIFY_RESULT_FALSE
        end
        if fKekSet then
            self.tLog.info("KEK is set.")
        else
            self.tLog.info("KEK is not set.")
            if fCheckKek then
                tResult = self.tSipper.VERIFY_RESULT_FALSE
                strErrorMsg = "KEK is not set."
            end
        end
        if fSipProtectionSet then
            self.tLog.info("SIP protection cookie is set.")
        else
            self.tLog.info("SIP protection cookie is not set.")
            if fCheckSipProtection then
                tResult = self.tSipper.VERIFY_RESULT_FALSE
                strErrorMsg = "SIP protection cookie is not set."
            end
        end

    end
    if tResult == self.tSipper.VERIFY_RESULT_OK then
        fResult, strErrorMsg = self:verifySIPviaFLash("APP", strAppSipData, aAttr)
        if not fResult then
            tResult = self.tSipper.VERIFY_RESULT_FALSE
        end
    end
    return tResult, strErrorMsg
end

function UsipPlayer:commandReadSipPm(
    strOutputdir,
    fReadCal
)
    local tResult
    local strErrorMsg
    local aAttr
    local flasher_path = "netx/"
    local astrHelpersTmp = {"flasher_netx90_hboot"}
    local ulConsoleMode
    local strCalSipData
    local strComSipData
    local strAppSipData


    tResult, strErrorMsg, ulConsoleMode = self:prepareInterface(true)

    if self.strPluginType == "romloader_uart" then
        table.insert(astrHelpersTmp,  "start_mi")
    end

    if tResult then
        tResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
        if tResult then
            tResult = self.WS_RESULT_OK
        end
    elseif tResult == false and ulConsoleMode == 1 then
        tResult = self.WS_RESULT_ERROR_SECURE_BOOT_ENABLED
    end

    if tResult == self.WS_RESULT_OK  then
        -- fConnected, strErrorMsg = self.tFlasherHelper.connect_retry(self.tPlugin)

        aAttr = self.tFlasher.download(self.tPlugin, flasher_path, nil, true, self.strSecureOption)
        tResult = self.WS_RESULT_OK

    end

    if tResult == self.WS_RESULT_OK then
        -- check if any of the secure info pages are hidden
        tResult, strErrorMsg = self:verifyInitialMode(aAttr, true)
    end

    -- read out CAL secure info pages
    if tResult == self.WS_RESULT_OK and fReadCal then
        strCalSipData, strErrorMsg = self:readSIPviaFLash("CAL", aAttr)
        if strCalSipData == nil then
            tResult = self.WS_RESULT_ERROR_UNSPECIFIED
        end
    end

    -- read out COM secure info pages
    if tResult == self.WS_RESULT_OK then
        strComSipData, strErrorMsg = self:readSIPviaFLash("COM", aAttr)
        if strComSipData == nil then
            tResult = self.WS_RESULT_ERROR_UNSPECIFIED
        end
    end

    -- read out APP secure info pages
    if tResult == self.WS_RESULT_OK then
        strAppSipData, strErrorMsg = self:readSIPviaFLash("APP", aAttr)
        if strAppSipData == nil then
            tResult = self.WS_RESULT_ERROR_UNSPECIFIED
        end
    end

    self:dumpSipFiles(strOutputdir, strComSipData, strAppSipData, strCalSipData)

    return tResult, strErrorMsg
end

-- veriify that the netX is in an initial state
-- the netX is not in an initial state if:
-- * one or mode secure info pages are hidden
-- * the netX is in secure boot mode
-- * the SIP protection cookie is set
-- * the rom func mode cookie is not set
-- returns iResult, strMsg, strCalSipData
function UsipPlayer:verifyInitialMode(
    aAttr,
    fProductionMode
)
    local iResult = self.WS_RESULT_OK
    local strComSipData
    local strAppSipData
    local strCalSipData
    local fComSecureBootEnabled
    local fAppSecureBootEnabled
    local fSipHidden
    local strMsg
    local fSipCookieSet
    local fRomFuncCookieSet
    if fProductionMode == nil then
        fProductionMode = false
    end

    -- check if any of the secure info pages are hidden
    fSipHidden, strMsg, fComSecureBootEnabled = self:checkHideSipRegister(self.tPlugin)
    if fComSecureBootEnabled then
        iResult = self.WS_RESULT_ERROR_SECURE_BOOT_ENABLED
        self.tLog.info("ERROR: Secure boot is enabled. End command.")
    elseif fSipHidden then
        iResult = self.WS_RESULT_ERROR_SIP_HIDDEN
        self.tLog.info("ERROR: one or more secure info page is hidden.")
    end
    if fProductionMode then
        -- read out COM secure info pages
        if iResult == self.WS_RESULT_OK then
            strComSipData, strMsg = self:readSIPviaFLash("COM", aAttr)
            if strComSipData == nil then
                iResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        end
        fSipCookieSet = self:checkSipProtectionCookieViaFlash(strComSipData)

    else
        -- read out CAL secure info pages
        if iResult == self.WS_RESULT_OK then
            strCalSipData, strMsg = self:readSIPviaFLash("CAL", aAttr)
            if strCalSipData == nil then
                iResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        end

        -- read out COM secure info pages
        if iResult == self.WS_RESULT_OK then
            strComSipData, strMsg = self:readSIPviaFLash("COM", aAttr)
            if strComSipData == nil then
                iResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        end

        -- read out APP secure info pages
        if iResult == self.WS_RESULT_OK then
            strAppSipData, strMsg = self:readSIPviaFLash("APP", aAttr)
            if strAppSipData == nil then
                iResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        end

        if iResult == self.WS_RESULT_OK then
            -- check for secure boot flags
            fComSecureBootEnabled, fAppSecureBootEnabled = self:checkSecureBootFlag(strComSipData, strAppSipData)
            -- check for sip protection cookie
            fSipCookieSet = self:checkSipProtectionCookieViaFlash(strComSipData)
            -- check if the fum func mode cookie is set
            fRomFuncCookieSet = self:checkRomFuncModeCookie(strCalSipData)

            if fComSecureBootEnabled or fAppSecureBootEnabled then
                iResult = self.WS_RESULT_ERROR_SECURE_BOOT_ENABLED
                self.tLog.info("ERROR: Secure boot is enabled. End command.")
            elseif fSipCookieSet then
                iResult = self.WS_RESULT_ERROR_SIP_PROTECTION_SET
                self.tLog.info("ERROR: SIP protection cookie is set. End command.")
            elseif not fRomFuncCookieSet then
                iResult = self.WS_RESULT_ROM_FUNC_MODE_COOKIE_NOT_SET
                self.tLog.info("ERROR: rom func mode cookie not set")
            end
        end
    end
    return iResult, strMsg, strCalSipData, fSipCookieSet
end

-- upate the calibration values 'atTempDiode' inside the APP SIP with the values from the CAL SIP
-- * copied from: CAL SIP offset 2192 (0x890) size: 48 (0x30)
-- * copied to:   APP SIP offset 2048 (0x800) size: 48 (0x30)
function UsipPlayer:applyTempDiodeData(strAppSipData, strCalSipData)
    -- apply temp diode parameter from cal page to app page
    local strTempDiodeData = string.sub(strCalSipData, 0x890+1, 0x890 + 0x30)
    local strNewAppSipData = string.format(
        "%s%s%s",
        string.sub(strAppSipData, 1, 0x800),
        strTempDiodeData,
        string.sub(strAppSipData, 0x800 + 1)
    )
    self.tlog.info(string.len(strNewAppSipData))
    return strNewAppSipData
end

function UsipPlayer:commandConvertUsipToBin(strUsipFilePath, strComSipBinPath, strAppSipBinPath, fSetSipProtectionCookie, strOutputDir)
    local fResult
    local strErrorMsg
    local tUsipDataList
    local tUsipPathList
    local tUsipConfigDict
    local strComSipData
    local strAppSipData

    fResult, strErrorMsg, tUsipDataList, tUsipPathList, tUsipConfigDict = self:prepareUsip(strUsipFilePath)
    if fResult then
        fResult, strErrorMsg, strComSipData, strAppSipData = self.tUsipGenerator:convertUsipToBin(
            strComSipBinPath,
            strAppSipBinPath,
            tUsipConfigDict,
            fSetSipProtectionCookie
        )
    end
    if fResult then
        local utils = require 'pl.utils'
        local fWriteResult
        local strWriteMessage
        local strComOutputFile = path.join(strOutputDir, "COM_SIP.bin")
        local strAppOutputFile = path.join(strOutputDir, "APP_SIP.bin")


        local strAbspath = path.abspath(strOutputDir)
        fResult, strErrorMsg = self.tFlasherHelper.create_directory_path(strAbspath)
        --local strMsg = os.mkdir(strAbspath)

        if fResult then
            fWriteResult, strWriteMessage  = utils.writefile(strComOutputFile, strComSipData, true)
            self.tLog.info("Write COM SIP binary to ".. strComOutputFile)
            if fWriteResult~=true then
                strErrorMsg = string.format(
                    'Failed to write the generated COM page to the output file "%s": %s',
                    strComOutputFile,
                    strWriteMessage
                )
                fResult = false
            end
            if fWriteResult then
                fWriteResult, strWriteMessage = utils.writefile(strAppOutputFile, strAppSipData, true)
                self.tLog.info("Write APP SIP binary to ".. strAppOutputFile)
                if fWriteResult~=true then
                    strErrorMsg = string.format(
                        'Failed to write the generated App page to the output file "%s": %s',
                        strAppOutputFile,
                        strWriteMessage
                    )
                    fResult = false
                end
            end
        end
    end


    return fResult, strErrorMsg
end

-- write APP and COM secure info page (SIP) based on default values
-- update temp diode calibratino values from CAL SIP to APP SIP
-- the default values can be modified with the data from an USIP file
function UsipPlayer:writeAllSips(
    strComSipBinPath,
    strAppSipBinPath,
    strUsipFilePath,
    strSecureOption,
    fSetSipProtectionCookie,
    fSetKek,
    strComOutputFile,
    strAppOutputFile
)
    local tResult = self.WS_RESULT_OK
    local strErrorMsg = ""
    local fResult = true
    local aAttr
    local flasher_path = "netx/"
    local fNewChipSelect = false
    local strComSipData
    local strAppSipData
    local tUsipDataList
    local tUsipPathList
    local tUsipConfigDict

    local astrHelpersTmp = {"flasher_netx90_hboot"}

    if strSecureOption == nil then
        strSecureOption = self.tFlasher.DEFAULT_HBOOT_OPTION
    end

    if strUsipFilePath ~= nil then
        fResult, strErrorMsg, tUsipDataList, tUsipPathList, tUsipConfigDict = self:prepareUsip(strUsipFilePath)
    end
    if fResult then
        fResult, strErrorMsg = self:prepareInterface(true)
        if tResult then
            fResult, strErrorMsg = self:prepareHelperFiles(astrHelpersTmp, true)
        end
    end

    if fResult then
        local fConnected
        fConnected, strErrorMsg = self.tFlasherHelper.connect_retry(self.tPlugin)
        if fConnected then
            aAttr = self.tFlasher.download(self.tPlugin, flasher_path, nil, true, strSecureOption)
            tResult = self.WS_RESULT_OK
        else
            tResult = self.WS_RESULT_ERROR_UNSPECIFIED
        end
    end
    if tResult == self.WS_RESULT_OK then
        -- check if any of the secure info pages are hidden
        tResult, strErrorMsg = self:verifyInitialMode(aAttr, true)
    end

    if tResult == self.WS_RESULT_OK then
        -- apply usip data to SIP pages
        fResult, strErrorMsg, strComSipData, strAppSipData = self.tUsipGenerator:convertUsipToBin(
            strComSipBinPath,
            strAppSipBinPath,
            tUsipConfigDict,
            fSetSipProtectionCookie
        )
        if not fResult then
            tResult = self.WS_RESULT_ERROR_UNSPECIFIED
        end
    end

    if tResult == self.WS_RESULT_OK then
        -- write the SIPs
        if strComOutputFile~=nil then
            local utils = require 'pl.utils'
            local fWriteResult, strWriteMessage = utils.writefile(strComOutputFile, strComSipData, true)
            if fWriteResult~=true then
                strErrorMsg = string.format(
                    'Failed to write the generated COM page to the output file "%s": %s',
                    strComOutputFile,
                    strWriteMessage
                )
                tResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        else
            if fSetKek then
                print("set kek selected")
                fNewChipSelect = true
            end
            fResult, strErrorMsg = self:writeSIPviaFLash("COM", strComSipData, aAttr, fNewChipSelect)
            if not fResult then
                tResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        end
    end

    if tResult == self.WS_RESULT_OK then
        -- write the SIPs
        if strAppOutputFile~=nil then
            local utils = require 'pl.utils'
            local fWriteResult, strWriteMessage = utils.writefile(strAppOutputFile, strAppSipData, true)
            if fWriteResult~=true then
                strErrorMsg = string.format(
                    'Failed to write the generated APP page to the output file "%s": %s',
                    strComOutputFile,
                    strWriteMessage
                )
                tResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        else
            -- always use new chip_select for APP SIP -> always update temp diode calibration
            fNewChipSelect = true
            fResult, strErrorMsg = self:writeSIPviaFLash("APP", strAppSipData, aAttr, fNewChipSelect)
            if not fResult then
                tResult = self.WS_RESULT_ERROR_UNSPECIFIED
            end
        end
    end
    if tResult == self.WS_RESULT_OK then
        strErrorMsg = "SIPs written successfully."
    end
    return tResult, strErrorMsg
end

return UsipPlayer